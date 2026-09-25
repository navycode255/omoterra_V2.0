from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_prefix='OMOTERRA_',
        env_file=(
            str(Path(__file__).resolve().parents[1] / '.env'),
            str(Path(__file__).resolve().parents[2] / '.env'),
        ),
        extra='ignore',
    )
    # 'development': local machine, sqlite-free but otherwise unrestricted.
    # 'live': a real deployment serving real users and real data (e.g. the
    # hosted omoterra.jopex.co.tz + Neon setup). This is independent of
    # sms_provider below — a live deployment can still keep OTP delivery in
    # dev mode on purpose while no SMS budget/provider is set up yet.
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
    # 'development': no SMS is sent; the OTP code is returned in the API
    # response so the app can show it on-screen. This is the only supported
    # value until a real SMS provider adapter is built — keep it 'development'
    # on the live server too, on purpose, to avoid SMS charges while testing.
    sms_provider: str = 'development'
    # Apply pending backend/migrations/*.sql at startup. Tests turn it off
    # because they build their schema from the models.
    auto_migrate: bool = True
    media_directory: str = './media'
    # 'disabled' until a YouTube channel adapter exists; see app/video.py.
    video_provider: str = 'disabled'
    video_upload_max_bytes: int = 500 * 1024 * 1024
    supplier_photo_limit: int = 30
    upload_max_bytes: int = 8 * 1024 * 1024
    stock_video_max_bytes: int = 60 * 1024 * 1024
    # 'disabled': notifications stay in the in-app inbox only. 'fcm': also
    # pushed to phones through Firebase Cloud Messaging, authenticated with the
    # service-account key at fcm_credentials_file (keep it out of git and the
    # web root).
    # Opens "Admin setup" on the dashboard sign-in screen. Empty turns admin
    # setup off. Once an admin exists, setup also needs an existing admin's
    # phone code, so this alone never creates an admin.
    admin_setup_passphrase: str = ''
    push_provider: str = 'disabled'
    fcm_credentials_file: str = ''
    support_phone: str = ''
    terms_text: str = ''
    privacy_text: str = ''

    def validate_runtime(self):
        if not 4 <= self.otp_length <= 8:
            raise RuntimeError('OTP length must be between 4 and 8')
        if self.environment not in ('development', 'live'):
            raise RuntimeError("OMOTERRA_ENVIRONMENT must be 'development' or 'live'")
        if self.sms_provider != 'development':
            # Fail closed until a real SMS provider adapter is implemented.
            raise RuntimeError('No SMS provider adapter is implemented; OMOTERRA_SMS_PROVIDER must stay development')
        if self.payment_provider != 'disabled':
            # Fail closed until a real payment provider adapter is implemented.
            raise RuntimeError('No payment provider adapter is implemented; OMOTERRA_PAYMENT_PROVIDER must stay disabled')
        if self.video_provider != 'disabled':
            # Fail closed until the YouTube upload adapter is implemented.
            raise RuntimeError('No video provider adapter is implemented; OMOTERRA_VIDEO_PROVIDER must stay disabled')
        if self.admin_setup_passphrase and len(self.admin_setup_passphrase) < 8:
            raise RuntimeError('OMOTERRA_ADMIN_SETUP_PASSPHRASE must be at least 8 characters (or empty to turn admin setup off)')
        if self.push_provider not in ('disabled', 'fcm'):
            raise RuntimeError("OMOTERRA_PUSH_PROVIDER must be 'disabled' or 'fcm'")
        if self.push_provider == 'fcm':
            import json
            try:
                key = json.loads(Path(self.fcm_credentials_file).read_text())
            except (OSError, ValueError) as exc:
                raise RuntimeError('OMOTERRA_FCM_CREDENTIALS_FILE must point to the Firebase service-account JSON key') from exc
            if key.get('type') != 'service_account' or not key.get('project_id'):
                raise RuntimeError('OMOTERRA_FCM_CREDENTIALS_FILE is not a Firebase service-account key')
        if self.environment == 'live' and self.otp_secret == 'local-only-change-before-deployment':
            raise RuntimeError('Set a real OMOTERRA_OTP_SECRET before running a live deployment')
        if self.environment == 'live' and not self.ops_token:
            raise RuntimeError('Set OMOTERRA_OPS_TOKEN before running a live deployment')
        if not self.database_url.startswith('postgresql'):
            raise RuntimeError('PostgreSQL is required for inventory locking')


@lru_cache
def settings():
    return Settings()
