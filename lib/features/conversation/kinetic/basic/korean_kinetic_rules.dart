abstract final class KoreanKineticRules {
  static const phraseSequences = <List<String>>[
    ['지금', '당장'],
    ['한', '적', '없어'],
    ['할', '수', '없어'],
    ['것', '같아'],
    ['하지', '마'],
    ['보고', '싶어'],
    ['그럴', '리', '없어'],
    ['말하지', '마'],
    ['안', '돼'],
    ['못', '해'],
    ['안', '해'],
    ['해도', '돼'],
  ];

  static const emphasis = {'진짜', '정말', '완전', '너무', '엄청', '굉장히', '절대', '제일'};
  static const urgent = {'지금', '당장', '빨리', '잠깐', '멈춰', '조심해', '안 돼'};
  static const negative = {'안', '못', '아니', '아냐', '절대', '없어', '하지 마'};
  static const exclamation = {'와', '헐', '대박', '미쳤다', '미쳤어', '최고'};
  static const softener = {'조금', '아마', '혹시', '그냥', '살짝', '어쩌면'};
  static const hesitation = {'음', '어', '글쎄', '뭐랄까', '그게', '아니'};
  static const firm = {'반드시', '확실히', '절대', '무조건', '끝', '안 해', '못 해'};
  static const secret = {'쉿', '조용히', '아무한테도', '말하지 마', '비밀'};
  static const calm = {'괜찮아', '천천히', '편하게', '걱정 마', '괜찮아요'};

  static const standalone = {
    ...emphasis,
    ...urgent,
    ...exclamation,
    ...hesitation,
    '쉿',
  };
}
