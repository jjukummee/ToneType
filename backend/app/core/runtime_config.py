import os
from dataclasses import dataclass
from importlib.metadata import PackageNotFoundError, version


def _package_version() -> str:
    try:
        return version("tonetype-prosody")
    except PackageNotFoundError:
        return "0.0.0"


@dataclass(frozen=True, slots=True)
class RuntimeConfig:
    environment: str
    version: str
    docs_enabled: bool
    allowed_hosts: tuple[str, ...]

    @classmethod
    def from_environment(cls) -> "RuntimeConfig":
        environment = os.getenv("APP_ENV", "development").strip().lower()
        docs_enabled = os.getenv(
            "ENABLE_API_DOCS",
            "false" if environment == "production" else "true",
        ).lower() in {"1", "true", "yes"}
        hosts = tuple(
            host.strip()
            for host in os.getenv("ALLOWED_HOSTS", "*").split(",")
            if host.strip()
        )
        return cls(
            environment=environment,
            version=os.getenv("APP_VERSION", _package_version()),
            docs_enabled=docs_enabled,
            allowed_hosts=hosts or ("*",),
        )
