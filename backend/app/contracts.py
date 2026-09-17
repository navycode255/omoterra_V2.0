from datetime import date
import re
from decimal import Decimal
from typing import Annotated, Literal
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

Category = Literal['broilers', 'local_chicken', 'goats', 'cattle', 'chicken_meat', 'beef', 'goat_meat']
Unit = Literal['bird', 'animal', 'kg']
Money = Annotated[Decimal, Field(gt=0, max_digits=14, decimal_places=2)]
Quantity = Annotated[Decimal, Field(gt=0, max_digits=14, decimal_places=3)]
UNITS = {'broilers': 'bird', 'local_chicken': 'bird', 'goats': 'animal', 'cattle': 'animal', 'chicken_meat': 'kg', 'beef': 'kg', 'goat_meat': 'kg'}


class Input(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)


class Phone(Input):
    phone: str = Field(pattern=r'^\+255[67]\d{8}$')


class Verify(Input):
    challenge_id: str
    code: str = Field(pattern=r'^\d{4,8}$')


class Profile(Input):
    name: str = Field(min_length=2, max_length=100)
    region: str = Field(min_length=2, max_length=80)
    language: Literal['en', 'sw'] = 'en'
    roles: list[Literal['buyer', 'supplier']] = Field(min_length=1, max_length=2)
    buyer_type: Literal['personal', 'restaurant', 'butchery', 'hotel', 'retailer', 'caterer', 'other'] | None = None

    @model_validator(mode='after')
    def buyer_details(self):
        if 'buyer' in self.roles and not self.buyer_type:
            raise ValueError('Choose a buyer type')
        self.roles = sorted(set(self.roles))
        return self


class AddressInput(Input):
    label: str = Field(min_length=1, max_length=60)
    recipient_name: str = Field(min_length=2, max_length=100)
    phone: str = Field(pattern=r'^\+\d{9,15}$')
    region: str = Field(min_length=2, max_length=80)
    district_area: str = Field(min_length=2, max_length=100)
    address_text: str = Field(min_length=3, max_length=500)
    coordinates: str | None = Field(default=None, max_length=80)


class SupplierInput(Input):
    legal_name: str = Field(min_length=2, max_length=150)
    internal_pickup_address: str = Field(min_length=3, max_length=500)


class ListingInput(Input):
    category: Category
    unit_type: Unit
    specs: dict
    region: str = Field(min_length=2, max_length=80)
    photos: list[str] = Field(default_factory=list, max_length=8)
    farmer_asking_price_per_unit: Money
    quantity_total: Quantity

    @model_validator(mode='after')
    def category_specs(self):
        if self.unit_type != UNITS[self.category]:
            raise ValueError('Unit does not match category')
        if self.unit_type != 'kg' and self.quantity_total % 1:
            raise ValueError('Birds and animals require whole quantities')
        fields = {
            'bird': {'avg_weight_kg', 'breed_type', 'age_weeks', 'live_or_dressed', 'ready_date'},
            'animal': {'weight_range', 'breed', 'sex', 'approx_age', 'ready_date'},
            'kg': {'cut_type', 'chilled_or_frozen', 'slaughter_date'},
        }[self.unit_type]
        if set(self.specs) != fields or any(not str(v).strip() for v in self.specs.values()):
            raise ValueError(f'Required specification fields: {", ".join(sorted(fields))}')
        for key, value in self.specs.items():
            if not isinstance(value, (str, int, float)) or len(str(value)) > 100:
                raise ValueError('Stock specifications must be short text or numbers')
            if not key.endswith('date') and re.search(r'(?:\+?255|0)[\s-]*[67](?:[\s-]*\d){8}|@|https?://|www\.', str(value), re.I):
                raise ValueError('Do not put contact details in public stock specifications')
        if re.search(r'\d|@|https?://|www\.', self.region, re.I):
            raise ValueError('Use a general region name, without contact details or an exact address')
        if self.unit_type == 'bird':
            try:
                if Decimal(str(self.specs['avg_weight_kg'])) <= 0 or Decimal(str(self.specs['age_weeks'])) < 0:
                    raise ValueError('Weight must be positive and age must not be negative')
            except ArithmeticError:
                raise ValueError('Enter numeric average weight and age')
        # Only the ops-reviewed listing can publish these values.
        if self.unit_type == 'bird' and self.specs['live_or_dressed'] not in ['live', 'dressed']:
            raise ValueError('Choose live or dressed')
        if self.unit_type == 'kg' and self.specs['chilled_or_frozen'] not in ['chilled', 'frozen']:
            raise ValueError('Choose chilled or frozen')
        date.fromisoformat(str(self.specs['slaughter_date' if self.unit_type == 'kg' else 'ready_date']))
        if any(not re.fullmatch(r'/media/[a-f0-9-]{36}', photo) for photo in self.photos):
            raise ValueError('Use photos uploaded through Omoterra')
        return self


class Reserve(Input):
    listing_id: str
    quantity: Quantity


class Checkout(Input):
    reservation_id: str
    delivery_address_id: str
    preferred_delivery_date: date
    payment_method: Literal['pay_now', 'pay_on_delivery']

    @field_validator('preferred_delivery_date')
    @classmethod
    def future_delivery(cls, value):
        if value < date.today():
            raise ValueError('Choose today or a future delivery date')
        return value


class StockUpdate(Input):
    quantity_total: Annotated[Decimal, Field(ge=0, max_digits=14, decimal_places=3)] | None = None
    action: Literal['update', 'pause', 'confirm']


class Approval(Input):
    buyer_price_per_unit: Money
    supplier_payout_price_per_unit: Annotated[Decimal, Field(ge=0, max_digits=14, decimal_places=2)] | None = None
    public_alias: str = Field(pattern=r'^[A-Za-z][A-Za-z -]{2,49}$')


class SourcingInput(Input):
    category: Category
    unit_type: Unit
    quantity: Quantity
    weight_or_size_requirement: str = Field(default='', max_length=100)
    live_dressed_or_cut: str = Field(default='', max_length=100)
    needed_by_date: date
    delivery_area: str = Field(min_length=2, max_length=150)
    notes: str = Field(default='', max_length=1000)
    reference_photo: str | None = None

    @model_validator(mode='after')
    def valid_request(self):
        if UNITS[self.category] != self.unit_type or (self.unit_type != 'kg' and self.quantity % 1):
            raise ValueError('Invalid category unit or quantity')
        if self.needed_by_date < date.today():
            raise ValueError('Needed-by date must not be in the past')
        if self.reference_photo and not re.fullmatch(r'/media/[a-f0-9-]{36}', self.reference_photo):
            raise ValueError('Use a photo uploaded through Omoterra')
        return self


class BusinessInput(Input):
    business_type: Literal['chicken_shop', 'butchery', 'fish_shop', 'meat_delivery', 'egg_reseller', 'local_chicken_business', 'goat_meat_business', 'restaurant_grill']
    area: str = Field(min_length=2, max_length=150)
    budget_range: str = Field(min_length=1, max_length=80)
    has_premises: bool
    wants_stock: bool
    target_start_date: str = Field(min_length=2, max_length=100)


class Progress(Input):
    expected_collection_date: date | None = None
    internal_status: Literal['supply_confirmed', 'pickup_scheduled', 'collected', 'quality_checked', 'in_transit', 'delivered', 'completed', 'cancelled', 'payment_failed']
    actual_quantity: Annotated[Decimal, Field(ge=0, max_digits=14, decimal_places=3)] | None = None
    rejected_quantity: Annotated[Decimal, Field(ge=0, max_digits=14, decimal_places=3)] | None = None
    actual_weight: Annotated[Decimal, Field(ge=0, max_digits=14, decimal_places=3)] | None = None
    collection_notes: str = Field(default='', max_length=1000)


class Reconcile(Input):
    amount: Money
    payment_reference: str = Field(min_length=3, max_length=150)


class SourceProgress(Input):
    status: Literal['submitted', 'sourcing', 'supply_found', 'confirmed', 'cancelled']
    quantity_secured: Annotated[Decimal, Field(ge=0, max_digits=14, decimal_places=3)]
    admin_notes: str = Field(default='', max_length=1000)


class Convert(Checkout):
    pass


class ListingReview(Input):
    status: Literal['paused', 'rejected']


class BusinessProgress(Input):
    status: Literal['new', 'contacted', 'interested', 'setup_in_progress', 'converted', 'closed']
    internal_notes: str = Field(default='', max_length=2000)


class StockCorrection(Input):
    counted_on_hand: Annotated[Decimal, Field(ge=0, max_digits=14, decimal_places=3)]
    reason: str = Field(min_length=5, max_length=500)


class StockAddition(Input):
    quantity: Quantity
    reason: str = Field(min_length=5, max_length=500)


class SaleInput(Input):
    quantity: Quantity
    sold_on: date
    unit_price: Money | None = None
    note: str = Field(default='', max_length=500)

    @field_validator('sold_on')
    @classmethod
    def no_future_sale(cls, value):
        if value > date.today():
            raise ValueError('A sale date cannot be in the future')
        return value
