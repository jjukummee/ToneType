import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/models/app_language.dart';
import '../../../core/state/app_scope.dart';
import '../../../core/text/korean_text_normalizer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/tone_stage.dart';
import '../../../core/widgets/tonetype_glass_surface.dart';
import '../data/conversation_audio_api_client.dart';
import '../data/conversation_result_source.dart';
import '../data/live_conversation_api_client.dart';
import '../data/live_speech_input_service.dart';
import '../data/prosody_api_client.dart';
import '../data/prosody_conversation_enhancer.dart';
import '../data/speech_input_service.dart';
import '../audio/voice_visualization_analyzer.dart';
import '../models/conversation_state.dart';
import '../models/kinetic_segment.dart';
import '../models/speech_capture_mode.dart';
import '../kinetic/realtime/realtime_kinetic_planner.dart';
import '../kinetic/realtime/recorded_prosody_adapter.dart';
import '../kinetic/realtime/realtime_kinetic_types.dart';
import '../kinetic/realtime/realtime_prosody_tracker.dart';
import '../widgets/kinetic_text.dart';
import '../widgets/microphone_control.dart';
import '../widgets/realtime_kinetic_text.dart';
import '../widgets/tone_analysis_sheet.dart';
import '../../history/models/conversation_record.dart';
import 'conversation_completed_screen.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    this.resultSource = const SameLanguageConversationResultSource(),
    this.audioAnalysisSource,
    this.speechInputService,
    this.liveConversationSource,
    this.liveSpeechInputService,
    this.embedded = false,
    this.onConversationEnded,
  });

  final ConversationResultSource resultSource;
  final ConversationAudioAnalysisSource? audioAnalysisSource;
  final SpeechInputService? speechInputService;
  final LiveConversationSource? liveConversationSource;
  final LiveSpeechInputService? liveSpeechInputService;
  final bool embedded;
  final VoidCallback? onConversationEnded;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  static const _maximumLiveWarmupBytes = 16000 * 2 * 8;

  ConversationStateModel _model = const ConversationStateModel.idle();
  late final SpeechInputService _speechInput =
      widget.speechInputService ?? DeviceSpeechInputService();
  late final ConversationAudioAnalysisSource _audioAnalysis =
      widget.audioAnalysisSource ??
      ConversationAudioApiClient.fromEnvironment();
  late final LiveConversationSource _liveConversation =
      widget.liveConversationSource ??
      LiveConversationApiClient.fromEnvironment();
  late final LiveSpeechInputService _liveSpeechInput =
      widget.liveSpeechInputService ?? DeviceLiveSpeechInputService();
  bool _speechInitialized = false;
  bool _liveSpeechInitialized = false;
  bool _liveFinishing = false;
  bool _liveTransportReady = false;
  int _liveSessionId = 0;
  final List<Uint8List> _liveWarmupAudio = [];
  int _liveWarmupBytes = 0;
  SpeechCaptureMode _activeCaptureMode = SpeechCaptureMode.single;
  StreamSubscription<LiveConversationUpdate>? _liveUpdateSubscription;
  final ScrollController _contentScrollController = ScrollController();
  final RealtimeKineticPlanner _realtimeKineticPlanner =
      RealtimeKineticPlanner();
  final RealtimeProsodyTracker _realtimeProsodyTracker =
      RealtimeProsodyTracker();
  RealtimeKineticPlan _realtimeKineticPlan = const RealtimeKineticPlan.empty();
  String _recognizedText = '';
  final ValueNotifier<double> _visualAmplitude = ValueNotifier(0);
  final ValueNotifier<VoiceVisualSignal> _singleVoiceSignal = ValueNotifier(
    const VoiceVisualSignal(),
  );
  Timer? _completionTimer;

  bool get _active => _model.state == ConversationUiState.listening;

  @override
  void dispose() {
    _completionTimer?.cancel();
    unawaited(_speechInput.dispose());
    unawaited(_liveUpdateSubscription?.cancel());
    unawaited(_liveSpeechInput.dispose());
    unawaited(_liveConversation.close());
    _contentScrollController.dispose();
    _visualAmplitude.dispose();
    _singleVoiceSignal.dispose();
    if (_audioAnalysis case ConversationAudioApiClient client) {
      client.close();
    }
    super.dispose();
  }

  Future<void> _toggleMicrophone() async {
    if (_model.state == ConversationUiState.requestingPermission ||
        _model.state == ConversationUiState.processing) {
      return;
    }
    if (_active) {
      if (_activeCaptureMode == SpeechCaptureMode.live) {
        await _completeLiveRecording();
      } else {
        await _completeAudioRecording();
      }
      return;
    }
    await _startListening();
  }

  Future<void> _startListening() async {
    final mode = AppScope.of(context, listen: false).speechCaptureMode;
    _activeCaptureMode = mode;
    if (mode == SpeechCaptureMode.live) {
      await _startLiveListening();
    } else {
      await _startFileListening();
    }
  }

  Future<void> _startFileListening() async {
    _completionTimer?.cancel();
    final pair = AppScope.of(context, listen: false).languagePair;
    if (!pair.isSameLanguage) {
      setState(
        () => _model = ConversationStateModel.error(
          '실제 음성 분석은 현재 같은 언어 설정에서 사용할 수 있어요. 설정에서 두 언어를 같게 맞춰주세요.',
        ),
      );
      return;
    }
    setState(() {
      _model = ConversationStateModel.requestingPermission;
      _recognizedText = '';
      _visualAmplitude.value = 0;
      _singleVoiceSignal.value = const VoiceVisualSignal();
    });
    if (!_speechInitialized) {
      final availability = await _speechInput.initialize();
      if (!mounted) return;
      if (availability == SpeechAvailability.permissionDenied) {
        setState(
          () => _model = const ConversationStateModel.permissionDenied(),
        );
        return;
      }
      if (availability == SpeechAvailability.unavailable) {
        setState(
          () => _model = ConversationStateModel.error(
            '이 기기에서 음성 인식을 시작할 수 없어요. 키보드 입력을 이용해주세요.',
          ),
        );
        return;
      }
      _speechInitialized = true;
    }

    setState(() => _model = ConversationStateModel.listening);
    try {
      await _speechInput.start(onVisualSignal: _handleSingleVoiceSignal);
      _completionTimer = Timer(
        const Duration(seconds: 30),
        () => unawaited(_completeAudioRecording()),
      );
    } on Object catch (_) {
      if (!mounted) return;
      setState(
        () => _model = ConversationStateModel.error(
          '음성 인식을 시작하지 못했어요. 잠시 후 다시 시도해주세요.',
        ),
      );
    }
  }

  Future<void> _startLiveListening() async {
    _completionTimer?.cancel();
    final controller = AppScope.of(context, listen: false);
    _realtimeKineticPlanner.reset();
    _realtimeProsodyTracker.reset();
    final sessionId = ++_liveSessionId;
    _liveTransportReady = false;
    _clearLiveWarmupAudio();
    setState(() {
      _model = ConversationStateModel.requestingPermission;
      _recognizedText = '';
      _visualAmplitude.value = 0;
      _liveFinishing = false;
      _realtimeKineticPlan = const RealtimeKineticPlan.empty();
    });
    if (!_liveSpeechInitialized) {
      final availability = await _liveSpeechInput.initialize();
      if (!mounted) return;
      if (availability == SpeechAvailability.permissionDenied) {
        setState(
          () => _model = const ConversationStateModel.permissionDenied(),
        );
        return;
      }
      if (availability == SpeechAvailability.unavailable) {
        setState(
          () => _model = ConversationStateModel.error(
            '이 기기에서 실시간 음성 인식을 시작할 수 없어요. 한 번 분석 모드를 이용해주세요.',
          ),
        );
        return;
      }
      _liveSpeechInitialized = true;
    }

    setState(
      () => _model = const ConversationStateModel(
        state: ConversationUiState.requestingPermission,
        statusMessage: '실시간 음성 분석 서버에 연결하고 있어요.',
      ),
    );
    try {
      // Open the transport and microphone in parallel. Audio that arrives
      // during the handshake is retained and flushed once the server is ready.
      final connection = _liveConversation.start(
        languagePair: controller.languagePair,
        conversationContext: controller.defaultContext,
        dictionary: controller.dictionary,
      );
      await _liveSpeechInput.start(
        onAudioChunk: _handleLiveAudioChunk,
        onSoundLevel: _handleSoundLevel,
        onError: (error) => unawaited(_handleLiveFailure(error)),
      );
      if (!mounted || sessionId != _liveSessionId) {
        await _liveSpeechInput.cancel();
        await _liveConversation.cancel();
        return;
      }
      setState(
        () => _model = const ConversationStateModel(
          state: ConversationUiState.listening,
          isLive: true,
        ),
      );
      _scrollContentToTop();
      final updates = await connection;
      if (!mounted || sessionId != _liveSessionId || _liveFinishing) {
        await _liveSpeechInput.cancel();
        await _liveConversation.cancel();
        return;
      }
      await _liveUpdateSubscription?.cancel();
      _liveUpdateSubscription = updates.listen(
        _handleLiveUpdate,
        onError: (Object error, StackTrace _) =>
            unawaited(_handleLiveFailure(error)),
      );
      _liveTransportReady = true;
      _flushLiveWarmupAudio();
    } on ProsodyApiException catch (error) {
      if (sessionId != _liveSessionId) return;
      await _liveSpeechInput.cancel();
      await _liveConversation.cancel();
      if (!mounted) return;
      setState(() => _model = ConversationStateModel.error(error.message));
    } on Object {
      if (sessionId != _liveSessionId) return;
      await _liveSpeechInput.cancel();
      await _liveConversation.cancel();
      if (!mounted) return;
      setState(
        () => _model = ConversationStateModel.error(
          '실시간 음성 인식을 시작하지 못했어요. 서버 연결을 확인해주세요.',
        ),
      );
    }
  }

  void _handleLiveUpdate(LiveConversationUpdate update) {
    if (!mounted || _liveFinishing) return;
    final controller = AppScope.of(context, listen: false);
    final korean = controller.languagePair.target == AppLanguage.korean;
    final preview = korean
        ? KoreanTextNormalizer.normalize(update.text)
        : update.text.trim();
    final committed = korean
        ? KoreanTextNormalizer.normalize(update.committedText)
        : update.committedText.trim();
    if (preview == _model.livePreviewText &&
        committed == _model.liveCommittedText) {
      return;
    }
    _recognizedText = committed.isNotEmpty ? committed : preview;
    final prosody = _realtimeProsodyTracker.snapshot(
      preview: preview,
      committed: committed,
    );
    final livePlan = _realtimeKineticPlanner.plan(
      preview: preview,
      committed: committed,
      stability: update.stability,
      prosody: prosody,
    );
    setState(() {
      _realtimeKineticPlan = livePlan;
      _model = ConversationStateModel(
        state: ConversationUiState.listening,
        isLive: true,
        livePreviewText: preview,
        liveCommittedText: committed,
        finalTranslation: committed,
      );
    });
  }

  void _handleLiveAudioChunk(Uint8List chunk) {
    _realtimeProsodyTracker.addAudio(chunk);
    if (_liveTransportReady) {
      _liveConversation.addAudio(chunk);
      return;
    }
    if (chunk.isEmpty) return;
    final retained = Uint8List.fromList(chunk);
    _liveWarmupAudio.add(retained);
    _liveWarmupBytes += retained.length;
    while (_liveWarmupBytes > _maximumLiveWarmupBytes &&
        _liveWarmupAudio.length > 1) {
      _liveWarmupBytes -= _liveWarmupAudio.removeAt(0).length;
    }
  }

  void _flushLiveWarmupAudio() {
    if (!_liveTransportReady) return;
    for (final chunk in _liveWarmupAudio) {
      _liveConversation.addAudio(chunk);
    }
    _clearLiveWarmupAudio();
  }

  void _clearLiveWarmupAudio() {
    _liveWarmupAudio.clear();
    _liveWarmupBytes = 0;
  }

  Future<void> _completeLiveRecording() async {
    if (!mounted || _liveFinishing) return;
    _liveFinishing = true;
    try {
      await _liveSpeechInput.stop();
      if (!_liveTransportReady) {
        ++_liveSessionId;
        _clearLiveWarmupAudio();
        await _liveConversation.cancel();
        if (!mounted) return;
        setState(() => _model = const ConversationStateModel.idle());
        return;
      }
      if (!mounted) return;
      setState(() {
        _model = ConversationStateModel.processing;
        _visualAmplitude.value = 0;
        _singleVoiceSignal.value = const VoiceVisualSignal();
      });
      final completed = await _liveConversation.finish();
      if (!mounted) return;
      final controller = AppScope.of(context, listen: false);
      final transcript = completed.transcript.trim();
      final resultText = controller.languagePair.target == AppLanguage.korean
          ? KoreanTextNormalizer.normalize(transcript)
          : transcript;
      final baseResult = ConversationStateModel(
        state: ConversationUiState.finalTranslation,
        originalText: '“$transcript”',
        finalTranslation: resultText,
      );
      // Style whatever was still provisional when the speaker stopped, so the
      // retained composition covers the entire transcript.
      _realtimeKineticPlanner.plan(
        preview: resultText,
        committed: resultText,
        stability: 1,
        prosody: _realtimeProsodyTracker.snapshot(
          preview: resultText,
          committed: resultText,
        ),
      );
      final result = const ProsodyConversationEnhancer()
          .enhance(
            translation: baseResult,
            prosody: completed.prosody,
            analysisMode: SpeechCaptureMode.live,
          )
          .withRealtimeComposition(_realtimeKineticPlanner.composition);
      setState(() => _model = result);
      _scrollContentToTop();
      final durationSeconds = completed.prosody.segments.isEmpty
          ? null
          : completed.prosody.segments
                .map((segment) => segment.end)
                .reduce((current, next) => next > current ? next : current);
      controller.addConversationRecord(
        ConversationRecord.create(
          languagePair: controller.languagePair,
          context: controller.defaultContext,
          originalText: transcript,
          resultText: result.finalTranslation,
          kineticComposition: result.realtimeComposition,
          durationSeconds: durationSeconds,
          tone: result.tone,
        ),
      );
    } on ProsodyApiException catch (error) {
      if (!mounted) return;
      setState(() => _model = ConversationStateModel.error(error.message));
    } on Object {
      if (!mounted) return;
      setState(
        () => _model = ConversationStateModel.error(
          '실시간 음성을 마무리하지 못했어요. 다시 시도해주세요.',
        ),
      );
    } finally {
      _liveTransportReady = false;
      _clearLiveWarmupAudio();
      _liveFinishing = false;
      await _liveUpdateSubscription?.cancel();
      _liveUpdateSubscription = null;
    }
  }

  Future<void> _handleLiveFailure(Object error) async {
    if (_liveFinishing) return;
    _liveFinishing = true;
    ++_liveSessionId;
    _liveTransportReady = false;
    _clearLiveWarmupAudio();
    await _liveSpeechInput.cancel();
    await _liveConversation.cancel();
    if (mounted) {
      final message = error is ProsodyApiException
          ? error.message
          : '실시간 음성 인식이 중단됐어요. 연결을 확인하고 다시 시도해주세요.';
      setState(() => _model = ConversationStateModel.error(message));
    }
    _liveFinishing = false;
  }

  Future<void> _completeRecognition(String text) async {
    if (!mounted) return;
    _completionTimer?.cancel();
    _recognizedText = text.trim().isEmpty ? _recognizedText : text.trim();
    setState(() {
      _model = ConversationStateModel.processing;
      _visualAmplitude.value = 0;
    });
    final pair = AppScope.of(context, listen: false).languagePair;
    final result = await widget.resultSource.finalResult(
      recognizedText: _recognizedText,
      languagePair: pair,
    );
    if (!mounted) return;
    setState(() => _model = result);
    if (result.state == ConversationUiState.finalTranslation) {
      final controller = AppScope.of(context, listen: false);
      controller.addConversationRecord(
        ConversationRecord.create(
          languagePair: pair,
          context: controller.defaultContext,
          originalText: _recognizedText,
          resultText: result.finalTranslation,
          kineticComposition: result.realtimeComposition,
        ),
      );
    }
  }

  Future<void> _completeAudioRecording() async {
    if (!mounted || _model.state == ConversationUiState.processing) return;
    _completionTimer?.cancel();
    String? audioPath;
    try {
      audioPath = await _speechInput.stop();
      if (!mounted) return;
      if (audioPath == null) {
        setState(
          () => _model = ConversationStateModel.error('녹음 파일을 만들지 못했어요.'),
        );
        return;
      }
      setState(() {
        _model = ConversationStateModel.processing;
        _visualAmplitude.value = 0;
      });
      final controller = AppScope.of(context, listen: false);
      final analysis = await _audioAnalysis.analyzeAudio(
        audioPath: audioPath,
        languagePair: controller.languagePair,
        conversationContext: controller.defaultContext,
        kineticMode: controller.kineticGenerationMode,
      );
      if (!mounted) return;
      final transcript = analysis.transcript.trim();
      final resultText = controller.languagePair.target == AppLanguage.korean
          ? KoreanTextNormalizer.normalize(transcript)
          : transcript;
      final baseResult = ConversationStateModel(
        state: ConversationUiState.finalTranslation,
        originalText: '“$transcript”',
        finalTranslation: resultText,
      );
      // Both capture modes compose through the same engine now, so a sentence
      // reads the same whether it was streamed or recorded and analysed after.
      final result = const ProsodyConversationEnhancer()
          .enhance(
            translation: baseResult,
            prosody: analysis.prosody,
            analysisMode: SpeechCaptureMode.single,
            kineticPlan: analysis.kineticPlan,
            kineticSource: analysis.kineticSource,
            kineticInterpretation: analysis.kineticInterpretation,
          )
          .withRealtimeComposition(
            RecordedProsodyAdapter.compose(
              displayText: resultText,
              prosody: analysis.prosody,
            ),
          );
      setState(() => _model = result);
      final durationSeconds = analysis.prosody.segments.isEmpty
          ? null
          : analysis.prosody.segments
                .map((segment) => segment.end)
                .reduce((current, next) => next > current ? next : current);
      controller.addConversationRecord(
        ConversationRecord.create(
          languagePair: controller.languagePair,
          context: controller.defaultContext,
          originalText: transcript,
          resultText: result.finalTranslation,
          kineticComposition: result.realtimeComposition,
          durationSeconds: durationSeconds,
          tone: result.tone,
        ),
      );
      await _finishAudioFile(audioPath, keep: controller.storeAudioSamples);
      audioPath = null;
    } on ProsodyApiException catch (error) {
      if (!mounted) return;
      setState(() => _model = ConversationStateModel.error(error.message));
    } on Object {
      if (!mounted) return;
      setState(
        () => _model = ConversationStateModel.error(
          '음성을 분석하지 못했어요. 서버 연결을 확인하고 다시 시도해주세요.',
        ),
      );
    } finally {
      if (audioPath != null) {
        await _deleteIfExists(audioPath);
      }
    }
  }

  Future<void> _finishAudioFile(String path, {required bool keep}) async {
    final source = File(path);
    if (!await source.exists()) return;
    if (!keep) {
      await source.delete();
      return;
    }
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory('${documents.path}/ToneType Audio');
    await directory.create(recursive: true);
    final filename = path.split(Platform.pathSeparator).last;
    await source.rename('${directory.path}/$filename');
  }

  Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  void _handleSoundLevel(double rawLevel) {
    if (!mounted) return;
    if (_activeCaptureMode == SpeechCaptureMode.live) {
      _realtimeProsodyTracker.addSoundLevel(rawLevel);
    }
    final normalized = ((rawLevel + 45) / 45).clamp(0.0, 1.0);
    _visualAmplitude.value = _visualAmplitude.value * 0.82 + normalized * 0.18;
  }

  void _handleSingleVoiceSignal(VoiceVisualSignal signal) {
    if (!mounted || _activeCaptureMode != SpeechCaptureMode.single) return;
    _singleVoiceSignal.value = signal;
  }

  void _scrollContentToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_contentScrollController.hasClients) return;
      _contentScrollController.jumpTo(0);
    });
  }

  Future<void> _showKeyboardInput() async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      builder: (_) => const _KeyboardInputSheet(),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    _recognizedText = text.trim();
    final pair = AppScope.of(context, listen: false).languagePair;
    if (!pair.isSameLanguage) {
      setState(
        () =>
            _model = ConversationStateModel.error('다른 언어로 번역하는 서버가 연결되지 않았어요.'),
      );
      return;
    }
    setState(() => _model = ConversationStateModel.processing);
    await _completeRecognition(_recognizedText);
  }

  Future<void> _pickContext() async {
    final controller = AppScope.of(context, listen: false);
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      builder: (_) => _ContextPickerSheet(selected: controller.defaultContext),
    );
    if (selected == null || !mounted) return;
    controller.setDefaultContext(selected);
  }

  Future<void> _pickKineticMode() async {
    final controller = AppScope.of(context, listen: false);
    final selected = await showModalBottomSheet<KineticGenerationMode>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.scrim,
      builder: (_) =>
          _KineticModePickerSheet(selected: controller.kineticGenerationMode),
    );
    if (selected == null || !mounted) return;
    controller.setKineticGenerationMode(selected);
  }

  void _endConversation() {
    final callback = widget.onConversationEnded;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute<void>(
        builder: (_) => const ConversationCompletedScreen(),
      ),
    );
  }

  Future<void> _resetConversation() async {
    _completionTimer?.cancel();
    ++_liveSessionId;
    _liveTransportReady = false;
    _clearLiveWarmupAudio();
    if (_active && _activeCaptureMode == SpeechCaptureMode.live) {
      await _liveSpeechInput.cancel();
      await _liveConversation.cancel();
    } else if (_active) {
      await _speechInput.cancel();
    }
    await _liveUpdateSubscription?.cancel();
    _liveUpdateSubscription = null;
    if (!mounted) return;
    setState(() {
      _model = const ConversationStateModel.idle();
      _recognizedText = '';
      _visualAmplitude.value = 0;
      _singleVoiceSignal.value = const VoiceVisualSignal();
      _realtimeKineticPlan = const RealtimeKineticPlan.empty();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final liveSession =
        _model.state == ConversationUiState.listening && _model.isLive;
    final transient =
        _model.state == ConversationUiState.processing ||
        _model.state == ConversationUiState.requestingPermission;
    return ToneStage(
      safeBottom: !widget.embedded,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Column(
          children: [
            const SizedBox(height: 10),
            _ConversationOptions(
              pair: controller.languagePair,
              conversationContext: controller.defaultContext,
              kineticMode: controller.kineticGenerationMode,
              onContextTap: _pickContext,
              onKineticModeTap: _pickKineticMode,
            ),
            if (liveSession) ...[
              const SizedBox(height: 14),
              const _LiveSessionHeader(),
            ],
            Expanded(
              child: ClipRect(
                child: _ConversationContentViewport(
                  model: _model,
                  controller: _contentScrollController,
                  onRetry: _startListening,
                  expressionMode: controller.expressionMode,
                  captureMode: controller.speechCaptureMode,
                  realtimePlan: _realtimeKineticPlan,
                  liveAmplitude: _visualAmplitude,
                ),
              ),
            ),
            if (liveSession) ...[
              ValueListenableBuilder<double>(
                valueListenable: _visualAmplitude,
                builder: (context, amplitude, _) => _LiveControlDock(
                  amplitude: amplitude,
                  onStop: _toggleMicrophone,
                ),
              ),
              const SizedBox(height: 12),
            ] else if (_model.state ==
                ConversationUiState.finalTranslation) ...[
              _ResultControlDock(
                onKeyboard: _showKeyboardInput,
                onNewTranslation: _resetConversation,
              ),
              const SizedBox(height: 14),
            ] else if (transient) ...[
              const SizedBox(height: 18),
            ] else ...[
              _CaptureModeToggle(
                selected: controller.speechCaptureMode,
                enabled: !_active,
                onSelected: controller.setSpeechCaptureMode,
              ),
              const SizedBox(height: 14),
              ValueListenableBuilder<VoiceVisualSignal>(
                valueListenable: _singleVoiceSignal,
                builder: (context, signal, _) => MicrophoneControl(
                  active: _active,
                  amplitude: signal.amplitude,
                  pitch: signal.pitch,
                  pitchConfidence: signal.pitchConfidence,
                  voiceReactive:
                      _active && _activeCaptureMode == SpeechCaptureMode.single,
                  onPressed: _toggleMicrophone,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CompactAction(
                    label: '직접 입력',
                    icon: CupertinoIcons.keyboard,
                    onTap: _showKeyboardInput,
                  ),
                  if (_model.state == ConversationUiState.error ||
                      _model.state == ConversationUiState.permissionDenied) ...[
                    const SizedBox(width: 10),
                    _CompactAction(
                      label: '새 번역',
                      icon: CupertinoIcons.arrow_counterclockwise,
                      onTap: _resetConversation,
                    ),
                  ] else if (!widget.embedded) ...[
                    const SizedBox(width: 10),
                    _CompactAction(
                      label: '대화 마치기',
                      icon: CupertinoIcons.checkmark_alt,
                      onTap: _endConversation,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 22),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConversationContentViewport extends StatelessWidget {
  const _ConversationContentViewport({
    required this.model,
    required this.controller,
    required this.onRetry,
    required this.expressionMode,
    required this.captureMode,
    required this.realtimePlan,
    required this.liveAmplitude,
  });

  final ConversationStateModel model;
  final ScrollController controller;
  final VoidCallback onRetry;
  final String expressionMode;
  final SpeechCaptureMode captureMode;
  final RealtimeKineticPlan realtimePlan;
  final ValueListenable<double> liveAmplitude;

  @override
  Widget build(BuildContext context) {
    if (model.state == ConversationUiState.listening && model.isLive) {
      return _LiveStageFrame(
        child: _LiveTranscriptStage(
          plan: realtimePlan,
          amplitude: liveAmplitude,
        ),
      );
    }
    final content = _TranslationArea(
      model: model,
      onRetry: onRetry,
      expressionMode: expressionMode,
      captureMode: captureMode,
    );
    if (model.state == ConversationUiState.finalTranslation) {
      return Scrollbar(
        controller: controller,
        child: SingleChildScrollView(
          key: const ValueKey('final-result-scroll'),
          controller: controller,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Center(child: content),
        ),
      );
    }
    return Center(child: content);
  }
}

/// Holds the live composition in a fixed frame, anchored to its bottom.
///
/// There is nothing to scroll here by design: the stage is a window onto the
/// speech happening right now. Older words rise out of the top and are simply
/// gone from the live view — they are still retained for the final result. A
/// scroll view invited the reader to chase content that was moving on its own,
/// and any drift of its position left the newest words off screen entirely.
class _LiveStageFrame extends StatelessWidget {
  const _LiveStageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      // Fades whatever reaches the top edge. When the composition is short it
      // sits low in the frame, so the gradient falls on empty space and is
      // invisible; once speech fills the frame it softens the words leaving it.
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
        stops: [0, 0.16],
      ).createShader(bounds),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.bottomCenter,
          maxHeight: double.infinity,
          child: child,
        ),
      ),
    );
  }
}

class _LiveSessionHeader extends StatelessWidget {
  const _LiveSessionHeader();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '실시간 번역 중',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _ListeningDot(),
          const SizedBox(width: 8),
          const Text('실시간 번역 중', style: AppTypography.bodyStrong),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentSoft.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: const Text(
              '정확도 우선',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveControlDock extends StatelessWidget {
  const _LiveControlDock({required this.amplitude, required this.onStop});

  final double amplitude;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const ValueKey('live-control-dock'),
      constraints: const BoxConstraints(maxWidth: 350),
      child: ToneTypeGlassSurface(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        shadows: AppShadows.card,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.accentSoft.withValues(alpha: 0.72),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.waveform,
                size: 17,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 11),
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('계속 듣고 있어요', style: AppTypography.bodyStrong),
                  SizedBox(height: 1),
                  Text('완료하면 말투 분석을 더해요', style: AppTypography.caption),
                ],
              ),
            ),
            MicrophoneControl(
              active: true,
              compact: true,
              amplitude: amplitude,
              onPressed: onStop,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultControlDock extends StatelessWidget {
  const _ResultControlDock({
    required this.onKeyboard,
    required this.onNewTranslation,
  });

  final VoidCallback onKeyboard;
  final VoidCallback onNewTranslation;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const ValueKey('result-control-dock'),
      constraints: const BoxConstraints(maxWidth: 350),
      child: ToneTypeGlassSurface(
        radius: AppRadius.pill,
        padding: const EdgeInsets.all(5),
        shadows: AppShadows.card,
        child: Row(
          children: [
            Expanded(
              child: _DockAction(
                label: '직접 입력',
                icon: CupertinoIcons.keyboard,
                onTap: onKeyboard,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _DockAction(
                label: '새 번역',
                icon: CupertinoIcons.arrow_counterclockwise,
                primary: true,
                onTap: onNewTranslation,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockAction extends StatelessWidget {
  const _DockAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary ? AppColors.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: primary ? Colors.white : AppColors.inkSoft,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: primary ? Colors.white : AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationOptions extends StatelessWidget {
  const _ConversationOptions({
    required this.pair,
    required this.conversationContext,
    required this.kineticMode,
    required this.onContextTap,
    required this.onKineticModeTap,
  });

  final LanguagePair pair;
  final String conversationContext;
  final KineticGenerationMode kineticMode;
  final VoidCallback onContextTap;
  final VoidCallback onKineticModeTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(child: _LanguageCapsule(pair: pair)),
        const SizedBox(width: 8),
        _ContextCapsule(label: conversationContext, onTap: onContextTap),
        const SizedBox(width: 8),
        _KineticModeCapsule(mode: kineticMode, onTap: onKineticModeTap),
      ],
    );
  }
}

class _CaptureModeToggle extends StatelessWidget {
  const _CaptureModeToggle({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final SpeechCaptureMode selected;
  final bool enabled;
  final ValueChanged<SpeechCaptureMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '음성 인식 방식 ${selected.title}',
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.ink.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.ink.withValues(alpha: 0.045)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in SpeechCaptureMode.values)
              _CaptureModeItem(
                mode: mode,
                selected: mode == selected,
                enabled: enabled,
                onTap: () => onSelected(mode),
              ),
          ],
        ),
      ),
    );
  }
}

class _CaptureModeItem extends StatelessWidget {
  const _CaptureModeItem({
    required this.mode,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final SpeechCaptureMode mode;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${mode.title} 선택',
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.92)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              boxShadow: selected ? AppShadows.card : const [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  mode == SpeechCaptureMode.live
                      ? CupertinoIcons.waveform_path_ecg
                      : CupertinoIcons.mic,
                  size: 14,
                  color: enabled
                      ? selected
                            ? AppColors.accent
                            : AppColors.inkSoft
                      : AppColors.inkFaint,
                ),
                const SizedBox(width: 6),
                Text(
                  mode.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: enabled ? AppColors.ink : AppColors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageCapsule extends StatelessWidget {
  const _LanguageCapsule({required this.pair});

  final LanguagePair pair;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '현재 번역 언어 ${pair.label}. 설정 탭에서 변경할 수 있습니다.',
      child: ToneTypeGlassSurface(
        radius: AppRadius.pill,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        shadows: const [
          BoxShadow(
            color: Color(0x16202733),
            blurRadius: 18,
            spreadRadius: -6,
            offset: Offset(0, 8),
          ),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              pair.source.label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(width: 6),
            const Icon(
              CupertinoIcons.arrow_right,
              size: 14,
              color: AppColors.accent,
            ),
            const SizedBox(width: 6),
            Text(
              pair.target.label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextCapsule extends StatelessWidget {
  const _ContextCapsule({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '대화 상황 $label 변경',
      child: Material(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.bubble_left_bubble_right,
                  size: 14,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  CupertinoIcons.chevron_down,
                  size: 11,
                  color: AppColors.inkFaint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KineticModeCapsule extends StatelessWidget {
  const _KineticModeCapsule({required this.mode, required this.onTap});

  final KineticGenerationMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hybrid = mode == KineticGenerationMode.hybrid;
    return Semantics(
      button: true,
      label: '키네틱 생성 방식 ${mode.title} 변경',
      child: Material(
        color: hybrid
            ? AppColors.accent.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hybrid ? CupertinoIcons.sparkles : CupertinoIcons.waveform,
                  size: 14,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 5),
                Text(
                  mode.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  CupertinoIcons.chevron_down,
                  size: 10,
                  color: AppColors.inkFaint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContextPickerSheet extends StatelessWidget {
  const _ContextPickerSheet({required this.selected});

  final String selected;

  static const contexts = ['일상', '여행', '학교', '비즈니스', '개발'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        decoration: const BoxDecoration(
          color: Color(0xFAFAFBFD),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('대화 상황', style: AppTypography.sectionTitle),
            const SizedBox(height: 5),
            const Text(
              '현재 대화에 가장 가까운 상황을 선택해주세요.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 14),
            for (final item in contexts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item, style: AppTypography.bodyStrong),
                trailing: item == selected
                    ? const Icon(
                        CupertinoIcons.checkmark_alt,
                        color: AppColors.accent,
                      )
                    : null,
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      ),
    );
  }
}

class _KineticModePickerSheet extends StatelessWidget {
  const _KineticModePickerSheet({required this.selected});

  final KineticGenerationMode selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        decoration: const BoxDecoration(
          color: Color(0xFAFAFBFD),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('키네틱 생성 방식', style: AppTypography.sectionTitle),
            const SizedBox(height: 5),
            const Text(
              '선택한 방식은 다음 음성 분석부터 적용돼요.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 12),
            for (final mode in KineticGenerationMode.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  mode == KineticGenerationMode.hybrid
                      ? CupertinoIcons.sparkles
                      : CupertinoIcons.waveform,
                  color: AppColors.accent,
                ),
                title: Text(mode.title, style: AppTypography.bodyStrong),
                subtitle: Text(mode.description, style: AppTypography.caption),
                trailing: mode == selected
                    ? const Icon(
                        CupertinoIcons.checkmark_alt,
                        color: AppColors.accent,
                      )
                    : null,
                onTap: () => Navigator.pop(context, mode),
              ),
          ],
        ),
      ),
    );
  }
}

class _TranslationArea extends StatelessWidget {
  const _TranslationArea({
    required this.model,
    required this.onRetry,
    required this.expressionMode,
    required this.captureMode,
  });

  final ConversationStateModel model;
  final VoidCallback onRetry;
  final String expressionMode;
  final SpeechCaptureMode captureMode;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.normal,
      curve: AppMotion.premiumCurve,
      child: switch (model.state) {
        ConversationUiState.idle => Text(
          captureMode == SpeechCaptureMode.live
              ? '말하는 동안 문장을 바로 번역해드릴게요.'
              : '말한 뒤 멈추면 말투까지 분석해드릴게요.',
          key: ValueKey('idle'),
          textAlign: TextAlign.center,
          style: AppTypography.body,
        ),
        ConversationUiState.requestingPermission => _StatusState(
          message: model.statusMessage,
          loading: true,
        ),
        ConversationUiState.listening => _ListeningState(model: model),
        ConversationUiState.processing => _StatusState(
          message: model.statusMessage,
          loading: true,
        ),
        ConversationUiState.finalTranslation => _FinalTranslation(
          model: model,
          expressionMode: expressionMode,
        ),
        ConversationUiState.permissionDenied => _StatusState(
          message: model.statusMessage,
          actionLabel: '다시 확인',
          onAction: onRetry,
        ),
        ConversationUiState.error => _StatusState(
          message: model.statusMessage,
          actionLabel: '다시 시도',
          onAction: onRetry,
        ),
      },
    );
  }
}

class _StatusState extends StatelessWidget {
  const _StatusState({
    required this.message,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading) ...[
          const CupertinoActivityIndicator(color: AppColors.accent),
          const SizedBox(height: 14),
        ],
        Text(message, textAlign: TextAlign.center, style: AppTypography.body),
        if (actionLabel != null) ...[
          const SizedBox(height: 16),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}

class _ListeningState extends StatelessWidget {
  const _ListeningState({required this.model});

  final ConversationStateModel model;

  @override
  Widget build(BuildContext context) {
    if (!model.isLive) {
      return const Column(
        key: ValueKey('listening'),
        mainAxisSize: MainAxisSize.min,
        children: [
          _ListeningDot(),
          SizedBox(height: 12),
          Text('듣고 있어요', style: AppTypography.bodyStrong),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class _LiveTranscriptStage extends StatelessWidget {
  const _LiveTranscriptStage({required this.plan, required this.amplitude});

  final RealtimeKineticPlan plan;
  final ValueListenable<double> amplitude;

  @override
  Widget build(BuildContext context) {
    if (plan.isEmpty) {
      return SizedBox(
        height: 250,
        child: Center(
          child: ValueListenableBuilder<double>(
            valueListenable: amplitude,
            builder: (context, level, _) => _LiveAcousticDraft(level: level),
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 350),
      child: Column(
        key: const ValueKey('live-listening'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (plan.currentLine.isNotEmpty || plan.provisionalLine.isNotEmpty)
            ToneTypeGlassSurface(
              radius: AppRadius.card,
              padding: const EdgeInsets.fromLTRB(18, 15, 18, 18),
              tint: Colors.white.withValues(alpha: 0.78),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.waveform,
                        size: 13,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE TYPOGRAPHY',
                        style: TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                      ),
                      if (plan.dominantWord != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            plan.dominantWord!,
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  RealtimeKineticText(
                    key: const ValueKey('realtime-kinetic-stage'),
                    plan: plan,
                  ),
                ],
              ),
            ),
          // Breathing room between the newest line and the controls below.
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _LiveAcousticDraft extends StatelessWidget {
  const _LiveAcousticDraft({required this.level});

  final double level;

  @override
  Widget build(BuildContext context) {
    final active = level > 0.08;
    return Semantics(
      liveRegion: true,
      label: active ? '음성을 듣는 중' : '말하기를 기다리는 중',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: active ? 1 : 0.72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final distance = (index - 3).abs();
                final scale = (level * (1 - distance * 0.09)).clamp(0.06, 1.0);
                return AnimatedContainer(
                  key: ValueKey('live-draft-bar-$index'),
                  duration: const Duration(milliseconds: 80),
                  curve: Curves.easeOutCubic,
                  width: 3,
                  height: 8 + 24 * scale,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: AppColors.inkFaint.withValues(
                      alpha: active ? 0.58 : 0.24,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 15),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 140),
              child: Text(
                active ? '듣는 대로 옮기고 있어요…' : '말하면 연한 글자로 먼저 나타나요.',
                key: ValueKey(active ? 'live-draft-active' : 'live-draft-idle'),
                style: AppTypography.body.copyWith(color: AppColors.inkFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListeningDot extends StatelessWidget {
  const _ListeningDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.accent,
      ),
    );
  }
}

class _FinalTranslation extends StatefulWidget {
  const _FinalTranslation({required this.model, required this.expressionMode});

  final ConversationStateModel model;
  final String expressionMode;

  @override
  State<_FinalTranslation> createState() => _FinalTranslationState();
}

class _FinalTranslationState extends State<_FinalTranslation> {
  int _replaySeed = 0;

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    return Column(
      key: const ValueKey('final'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(model.originalText, style: AppTypography.originalSpeech),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 15, 18, 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: Colors.white),
              boxShadow: AppShadows.card,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.waveform,
                      size: 13,
                      color: AppColors.accent,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '키네틱 결과',
                      style: TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (model.realtimeComposition.isNotEmpty)
                  RealtimeKineticTranscript(
                    key: ValueKey('live-final-${model.finalTranslation}'),
                    segments: model.realtimeComposition,
                  )
                else
                  KineticText(
                    key: ValueKey(
                      'kinetic-${model.finalTranslation}-$_replaySeed',
                    ),
                    plan:
                        model.kineticPlan ??
                        KineticPlan.neutral(model.finalTranslation),
                    emphasizedWord: model.tone?.emphasizedWord,
                    mode: switch (widget.expressionMode) {
                      'minimal' => KineticExpressionMode.minimal,
                      'immersive' => KineticExpressionMode.immersive,
                      _ => KineticExpressionMode.standard,
                    },
                  ),
                const SizedBox(height: 12),
                // A retained live composition is a record of what was already
                // watched being built, so there is no entrance to replay.
                if (model.realtimeComposition.isEmpty)
                  Semantics(
                    button: true,
                    label: '모션 다시 보기',
                    child: CupertinoButton(
                      minimumSize: const Size(34, 34),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      borderRadius: BorderRadius.circular(999),
                      color: AppColors.accentSoft,
                      onPressed: () => setState(() => _replaySeed++),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.arrow_clockwise,
                            size: 15,
                            color: AppColors.accent,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '다시 보기',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (model.tone != null ||
            model.kineticSource != KineticResultSource.basic) ...[
          const SizedBox(height: 26),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (model.kineticSource != KineticResultSource.basic)
                _KineticSourceBadge(
                  source: model.kineticSource,
                  interpretation: model.kineticInterpretation,
                ),
              if (model.tone != null)
                Semantics(
                  button: true,
                  label: '말투 분석 상세 보기',
                  child: ActionChip(
                    onPressed: () => _showToneDetail(context, model.tone!),
                    side: BorderSide(
                      color: AppColors.ink.withValues(alpha: 0.08),
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.68),
                    avatar: const Icon(
                      CupertinoIcons.waveform,
                      size: 13,
                      color: AppColors.accent,
                    ),
                    label: const Text(
                      '말투 분석',
                      style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _KineticSourceBadge extends StatelessWidget {
  const _KineticSourceBadge({
    required this.source,
    required this.interpretation,
  });

  final KineticResultSource source;
  final String? interpretation;

  @override
  Widget build(BuildContext context) {
    final hybrid = source == KineticResultSource.hybrid;
    final label = hybrid ? 'AI 하이브리드' : 'AI 대신 기본 분석';
    return Tooltip(
      message:
          interpretation ??
          (hybrid ? 'Google AI가 문맥과 의미를 반영했어요.' : 'AI 연결에 실패해 기본 분석으로 완성했어요.'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hybrid
              ? AppColors.accent.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.ink.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hybrid
                  ? CupertinoIcons.sparkles
                  : CupertinoIcons.exclamationmark_circle,
              size: 13,
              color: hybrid ? AppColors.accent : AppColors.inkSoft,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyboardInputSheet extends StatefulWidget {
  const _KeyboardInputSheet();

  @override
  State<_KeyboardInputSheet> createState() => _KeyboardInputSheetState();
}

class _KeyboardInputSheetState extends State<_KeyboardInputSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
        decoration: const BoxDecoration(
          color: Color(0xFAFAFBFD),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('직접 입력', style: AppTypography.sectionTitle),
            const SizedBox(height: 8),
            const Text(
              '입력한 문장을 기록에 저장합니다. 음성 말투와 AI 키네틱 분석은 포함되지 않아요.',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: _controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              placeholder: '문장을 입력하세요.',
              padding: const EdgeInsets.all(15),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _controller.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(context, _controller.text.trim()),
                child: const Text('적용하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showToneDetail(
  BuildContext context,
  ConversationToneSummary tone,
) {
  return showToneAnalysisSheet(context, tone);
}

class _CompactAction extends StatelessWidget {
  const _CompactAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppColors.inkSoft),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
