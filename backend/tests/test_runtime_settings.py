"""Locks down the environment/sms_provider gating in Settings.validate_runtime.

A live deployment must be able to start (real database, real users) while
OTP delivery deliberately stays in dev mode (no SMS charges yet). These two
concerns used to be one flag; this file protects the split.
"""
import pytest
from app.config import Settings


def base(**overrides):
    return Settings(database_url='postgresql+psycopg://x', ops_token='t', otp_secret='s', **overrides)


def test_development_boots_by_default():
    base(environment='development').validate_runtime()


def test_live_boots_with_dev_sms_and_disabled_payments():
    base(environment='live').validate_runtime()


def test_unknown_environment_is_rejected():
    with pytest.raises(RuntimeError):
        base(environment='production').validate_runtime()


def test_live_requires_a_real_otp_secret():
    with pytest.raises(RuntimeError):
        Settings(database_url='postgresql+psycopg://x', ops_token='t',
                 environment='live').validate_runtime()


def test_live_requires_an_ops_token():
    with pytest.raises(RuntimeError):
        Settings(database_url='postgresql+psycopg://x', otp_secret='s',
                 environment='live').validate_runtime()


def test_real_sms_provider_is_rejected_until_implemented():
    with pytest.raises(RuntimeError):
        base(environment='live', sms_provider='twilio').validate_runtime()


def test_real_payment_provider_is_rejected_until_implemented():
    with pytest.raises(RuntimeError):
        base(environment='live', payment_provider='mpesa').validate_runtime()


def test_non_postgres_database_is_rejected():
    with pytest.raises(RuntimeError):
        Settings(database_url='sqlite:///x', ops_token='t', otp_secret='s',
                 environment='development').validate_runtime()
