from dataclasses import dataclass
from decimal import Decimal
from typing import Protocol


@dataclass(frozen=True)
class ProviderConfirmation:
    transaction_id: str
    order_id: str
    amount: Decimal
    status: str


class PaymentProvider(Protocol):
    def initiate(self, order_id: str, amount: Decimal, idempotency_key: str) -> str: ...
    def verify_callback(self, body: bytes, signature: str) -> ProviderConfirmation: ...


class DisabledPaymentProvider:
    def initiate(self, order_id, amount, idempotency_key):
        raise RuntimeError('No payment provider is connected')

    def verify_callback(self, body, signature):
        raise RuntimeError('No payment provider is connected')


class MockPaymentProvider:
    """Explicit test double, never selected by a production application."""
    def initiate(self, order_id, amount, idempotency_key):
        return f'dev-{idempotency_key}'

    def verify_callback(self, body, signature):
        import json
        if signature != 'development-only':
            raise ValueError('Invalid development signature')
        data = json.loads(body)
        return ProviderConfirmation(data['transaction_id'], data['order_id'], Decimal(data['amount']), data['status'])
