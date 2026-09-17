from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix='OMOTERRA_', env_file='.env', extra='ignore')
    environment: str = 'development'
    database_url: str = 'postgresql+psycopg://omoterra:omoterra@localhost:5432/omoterra'
    ops_token: str = ''
    otp_secret: str = 'local-only-change-before-deployment'
    otp_length: int = 6
    otp_ttl_seconds: int = 300
    otp_resend_seconds: int = 60
    reservation_minutes: int = 15
    freshness_hours: int = 48
    session_days: int = 30
    payment_provider: str = 'disabled'
    sms_provider: str = 'development'
    media_directory: str = './media'
    upload_max_bytes: int = 8 * 1024 * 1024
    support_phone: str = ''
    terms_text: str = ''
    privacy_text: str = ''

    def validate_runtime(self):
        if not 4 <= self.otp_length <= 8:
            raise RuntimeError('OTP length must be between 4 and 8')
        if self.environment != 'development':
            # Fail closed until actual provider adapters are configured and implemented.
            raise RuntimeError('Production SMS/payment adapters and deployment review are required')
        if not self.database_url.startswith('postgresql'):
            raise RuntimeError('PostgreSQL is required for inventory locking')


@lru_cache
def settings():
    return Settings()
