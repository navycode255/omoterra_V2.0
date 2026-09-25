from __future__ import annotations

from datetime import date
import re
from decimal import Decimal
from typing import Annotated, Literal, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

Category = Literal['broilers', 'local_chicken', 'layers', 'goats', 'cattle', 'chicken_meat', 'beef', 'goat_meat', 'eggs']
Unit = Literal['bird', 'animal', 'kg', 'tray']
Money = Annotated[Decimal, Field(gt=0, max_digits=14, decimal_places=2)]
Quantity = Annotated[Decimal, Field(gt=0, max_digits=14, decimal_places=3)]
GOOGLE_DOMAIN = r'google\.(?:com|[a-z]{2})(?:\.[a-z]{2})?'
GOOGLE_MAPS_LINK = re.compile(rf'^https://(?:(?:www\.)?{GOOGLE_DOMAIN}/maps|maps\.{GOOGLE_DOMAIN}|maps\.app\.goo\.gl|goo\.gl/maps)(?:[/?#]|$)', re.I)
UNITS = {'broilers': 'bird', 'local_chicken': 'bird', 'layers': 'bird', 'goats': 'animal', 'cattle': 'animal', 'chicken_meat': 'kg', 'beef': 'kg', 'goat_meat': 'kg', 'eggs': 'tray'}


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
    buyer_type: Optional[Literal['personal', 'restaurant', 'butchery', 'hotel', 'retailer', 'caterer', 'other']] = None

    @model_validator(mode='after')
    def buyer_details(self):
        if 'buyer' in self.roles and not self.buyer_type:
            raise ValueError('Choose a buyer type')
        self.roles = sorted(set(self.roles))
        return self


class RoleRegistration(Input):
    role: Literal['buyer', 'supplier']
    buyer_type: Optional[Literal['personal', 'restaurant', 'butchery', 'hotel', 'retailer', 'caterer', 'other']] = None
    legal_name: Optional[str] = Field(default=None, min_length=2, max_length=150)
    internal_pickup_address: Optional[str] = Field(default=None, min_length=3, max_length=500)

    @model_validator(mode='after')
    def required_role_details(self):
        if self.role == 'buyer' and not self.buyer_type:
            raise ValueError('Choose a buyer type')
        if self.role == 'supplier' and (not self.legal_name or not self.internal_pickup_address):
            raise ValueError('Complete your supplier and pickup details')
        return self


class AddressInput(Input):
    label: str = Field(min_length=1, max_length=60)
    recipient_name: str = Field(min_length=2, max_length=100)
    phone: str = Field(pattern=r'^\+\d{9,15}$')
    region: str = Field(min_length=2, max_length=80)
    district_area: str = Field(min_length=2, max_length=100)
    address_text: str = Field(min_length=3, max_length=500)
    coordinates: Optional[str] = Field(default=None, max_length=80)


class SupplierInput(Input):
    legal_name: str = Field(min_length=2, max_length=150)
    internal_pickup_address: str = Field(min_length=3, max_length=500)


class ListingInput(Input):
    category: Category
    unit_type: Unit
    specs: dict
    region: str = Field(min_length=2, max_length=80)
    photos: list[str] = Field(default_factory=list, max_length=8)
    video: Optional[str] = Field(default=None, max_length=80)
    farmer_asking_price_per_unit: Money
    quantity_total: Quantity

    @model_validator(mode='after')
    def category_specs(self):
        if self.unit_type != UNITS[self.category]:
            raise ValueError('Unit does not match category')
        if self.unit_type not in ('kg',) and self.quantity_total % 1:
            raise ValueError('Birds, animals and trays require whole quantities')
        fields = {
            'bird': {'avg_weight_kg', 'breed_type', 'age_weeks', 'live_or_dressed', 'ready_date'},
            'animal': {'weight_range', 'breed', 'sex', 'approx_age', 'ready_date'},
            'kg': {'cut_type', 'chilled_or_frozen', 'slaughter_date'},
            'tray': {'tray_size', 'egg_size', 'ready_date'},
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
        if self.unit_type == 'tray':
            try:
                if int(self.specs['tray_size']) not in (30, 24, 12):
                    raise ValueError('Choose a tray size of 12, 24 or 30 eggs')
            except (TypeError, ValueError):
                raise ValueError('Choose a tray size of 12, 24 or 30 eggs')
            if self.specs['egg_size'] not in ['small', 'medium', 'large']:
                raise ValueError('Choose an egg size')
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
    # 'pay_now' is reserved for a mobile-money provider. Until one is connected
    # checkout rejects it (422) and /config advertises only 'pay_on_delivery';
    # the app shows Pay Now greyed out as "coming soon".
    payment_method: Literal['pay_now', 'pay_on_delivery']

    @field_validator('preferred_delivery_date')
    @classmethod
    def future_delivery(cls, value):
        if value < date.today():
            raise ValueError('Choose today or a future delivery date')
        return value


class StockUpdate(Input):
    quantity_total: Optional[Annotated[Decimal, Field(ge=0, max_digits=14, decimal_places=3)]] = None
    action: Literal['update', 'pause', 'confirm']


class Approval(Input):
    buyer_price_per_unit: Money
    supplier_asking_price_per_unit: Optional[Money] = None
    supplier_payout_price_per_unit: Optional[Annotated[Decimal, Field(ge=0, max_digits=14, decimal_places=2)]] = None
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
    reference_photo: Optional[str] = None
    minimum_weight_kg: Optional[Annotated[Decimal, Field(gt=0, max_digits=8, decimal_places=3)]] = None
    maximum_weight_kg: Optional[Annotated[Decimal, Field(gt=0, max_digits=8, decimal_places=3)]] = None
    product_subtype: str = Field(default='', max_length=100)
    delivery_region: str = Field(default='', max_length=80)
    delivery_notes: str = Field(default='', max_length=500)
    requirement_type: Literal['one_time', 'recurring'] = 'one_time'
    recurrence_frequency: Literal['', 'weekly', 'monthly'] = ''
    preferred_weekdays: list[Literal['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']] = Field(default_factory=list, max_length=7)

    @model_validator(mode='after')
    def valid_request(self):
        if UNITS[self.category] != self.unit_type or (self.unit_type != 'kg' and self.quantity % 1):
            raise ValueError('Invalid category unit or quantity')
        if self.needed_by_date < date.today():
            raise ValueError('Needed-by date must not be in the past')
        if self.reference_photo and not re.fullmatch(r'/media/[a-f0-9-]{36}', self.reference_photo):
            raise ValueError('Use a photo uploaded through Omoterra')
        if self.minimum_weight_kg and self.maximum_weight_kg and self.minimum_weight_kg > self.maximum_weight_kg:
            raise ValueError('Minimum weight cannot exceed maximum weight')
        if self.requirement_type == 'recurring' and not self.recurrence_frequency:
            raise ValueError('Choose a recurrence frequency')
        if self.requirement_type == 'recurring' and not self.preferred_weekdays:
            raise ValueError('Choose at least one preferred delivery day')
        if self.requirement_type == 'one_time' and (self.recurrence_frequency or self.preferred_weekdays):
            raise ValueError('Recurrence settings require a recurring requirement')
        return self


class OperatorRequirementInput(SourcingInput):
    buyer_profile_id: Optional[str] = None
    buyer: Optional['OperatorBuyerInput'] = None
    internal_notes: str = Field(default='', max_length=1000)


class OperatorBuyerInput(Input):
    business_name: str = Field(min_length=2, max_length=150)
    buyer_type: Literal['personal', 'restaurant', 'butchery', 'hotel', 'retailer', 'caterer', 'other'] = 'other'
    contact_person: str = Field(default='', max_length=100)
    phone: str = Field(default='', max_length=20)
    region: str = Field(default='', max_length=80)
    area: str = Field(default='', max_length=100)
    internal_notes: str = Field(default='', max_length=2000)


class BuyerProfileInput(OperatorBuyerInput):
    user_id: Optional[str] = None
    preferences: dict = Field(default_factory=dict)
    last_known_buying_price: Optional[Annotated[Decimal, Field(gt=0, max_digits=14, decimal_places=2)]] = None
    minimum_order: Optional[Quantity] = None
    payment_terms: str = Field(default='', max_length=100)


class SupplierProfileInput(Input):
    public_alias: str = Field(min_length=2, max_length=120)
    legal_name: str = Field(min_length=2, max_length=150)
    alternate_phone: str = Field(default='', max_length=20)
    region: str = Field(min_length=2, max_length=80)
    district: str = Field(min_length=2, max_length=100)
    general_area: str = Field(default='', max_length=120)
    categories: list[Category] = Field(min_length=1, max_length=9)
    primary_category: Category
    production_profile: dict = Field(default_factory=dict)
    evidence_photos: list[str] = Field(default_factory=list, max_length=8)
    production_frequency: str = Field(default='', max_length=120)
    internal_pickup_address: str = Field(min_length=3, max_length=500)
    pickup_instructions: str = Field(default='', max_length=1000)
    omoterra_pickup: bool = False
    supplier_transport: bool = False
    supply_forms: list[Literal['live', 'dressed', 'chilled', 'frozen']] = Field(default_factory=list)
    preferred_contact_method: Literal['phone', 'whatsapp', 'sms'] = 'phone'
    operating_notes: str = Field(default='', max_length=1000)
    farm_latitude: Optional[Annotated[Decimal, Field(ge=-90, le=90, max_digits=9, decimal_places=6)]] = None
    farm_longitude: Optional[Annotated[Decimal, Field(ge=-180, le=180, max_digits=9, decimal_places=6)]] = None
    farm_map_url: str = Field(default='', max_length=500)

    @field_validator('farm_map_url')
    @classmethod
    def google_maps_link(cls, value):
        if value and not GOOGLE_MAPS_LINK.match(value):
            raise ValueError('Paste a Google Maps link for the farm location')
        return value

    @model_validator(mode='after')
    def farm_pin_complete(self):
        if (self.farm_latitude is None) != (self.farm_longitude is None):
            raise ValueError('The farm location needs both latitude and longitude')
        return self

    @field_validator('region')
    @classmethod
    def public_region_only(cls, value):
        if re.search(r'\d|@|https?://|www\.', value, re.I):
            raise ValueError('Enter a general region name, not a phone number or exact address')
        return value

    @field_validator('alternate_phone')
    @classmethod
    def valid_alternate_phone(cls, value):
        if value and not re.fullmatch(r'\+255[67]\d{8}', value):
            raise ValueError('Enter an alternate Tanzanian mobile number or leave it blank')
        return value

    @field_validator('categories')
    @classmethod
    def unique_categories(cls, value):
        if len(set(value)) != len(value):
            raise ValueError('Choose each supply category only once')
        return value

    @model_validator(mode='after')
    def valid_production_profile(self):
        if self.primary_category not in self.categories:
            raise ValueError('Your main supply category must be selected')
        if set(self.production_profile) - set(self.categories):
            raise ValueError('Production details must match selected categories')
        for category, details in self.production_profile.items():
            if not isinstance(details, dict):
                raise ValueError('Enter production capacity by category')
            try:
                capacity = Decimal(str(details.get('capacity', '')))
            except Exception as exc:
                raise ValueError('Enter a valid production capacity') from exc
            if not capacity.is_finite() or capacity < 0:
                raise ValueError('Enter a valid non-negative production capacity')
            if details.get('unit') != UNITS[category]:
                raise ValueError('Choose the correct unit for each category')
            if len(str(details.get('frequency', ''))) > 80:
                raise ValueError('Production frequency is too long')
        return self


class SupplierStatusInput(Input):
    status: Literal['under_review', 'approved', 'rejected', 'suspended']
    notes: str = Field(default='', max_length=2000)


class SupplierVideoInput(Input):
    youtube_url: str = Field(min_length=11, max_length=300)
    title: str = Field(default='', max_length=120)


class SupplierVerificationInput(Input):
    checks: dict[str, bool]
    notes: str = Field(default='', max_length=2000)

class OperatorSupplierInput(SupplierProfileInput):
    phone: str = Field(pattern=r'^\+255[67]\d{8}$')
    name: str = Field(min_length=2, max_length=100)
    internal_notes: str = Field(default='', max_length=2000)
    verification: dict = Field(default_factory=dict)
    current_batch: Optional['SupplierBatchInput'] = None
    future_batches: list['SupplierBatchInput'] = Field(default_factory=list, max_length=10)

    @model_validator(mode='after')
    def batch_categories_selected(self):
        batches = ([self.current_batch] if self.current_batch else []) + self.future_batches
        if any(batch.category not in self.categories for batch in batches):
            raise ValueError('Select every current and planned supply category above')
        if any(batch.asking_price_per_unit is None for batch in batches):
            raise ValueError('Add the agreed asking price for every current and planned batch')
        return self


class SupplierOnboardingInput(SupplierProfileInput):
    name: str = Field(min_length=2, max_length=100)
    current_batch: Optional['SupplierBatchInput'] = None
    future_batches: list['SupplierBatchInput'] = Field(default_factory=list, max_length=10)

    @model_validator(mode='after')
    def batch_categories_selected(self):
        batches = ([self.current_batch] if self.current_batch else []) + self.future_batches
        if any(batch.category not in self.categories for batch in batches):
            raise ValueError('Select every current and planned supply category above')
        if any(batch.asking_price_per_unit is None for batch in batches):
            raise ValueError('Add the agreed asking price for every current and planned batch')
        return self


class SupplierBatchInput(Input):
    category: Category
    subtype: str = Field(default='', max_length=100)
    initial_quantity: Quantity
    current_age: Optional[Annotated[Decimal, Field(ge=0, max_digits=8, decimal_places=3)]] = None
    age_unit: Literal['days', 'weeks', 'months'] = 'weeks'
    expected_ready_date: date
    expected_min_weight_kg: Optional[Annotated[Decimal, Field(gt=0, max_digits=8, decimal_places=3)]] = None
    expected_max_weight_kg: Optional[Annotated[Decimal, Field(gt=0, max_digits=8, decimal_places=3)]] = None
    form: Literal['live', 'dressed', 'chilled', 'frozen'] = 'live'
    asking_price_per_unit: Optional[Money] = None
    region: str = Field(min_length=2, max_length=80)
    private_pickup_location: str = Field(default='', max_length=500)
    photos: list[str] = Field(default_factory=list, max_length=8)

    @model_validator(mode='after')
    def valid_batch(self):
        if self.expected_ready_date < date.today():
            raise ValueError('Expected ready date must be today or later')
        if (self.expected_ready_date - date.today()).days > 365 * 5:
            raise ValueError('Expected ready date is too far in the future')
        if self.expected_min_weight_kg and self.expected_max_weight_kg and self.expected_min_weight_kg > self.expected_max_weight_kg:
            raise ValueError('Minimum weight cannot exceed maximum weight')
        if self.category not in ('chicken_meat', 'beef', 'goat_meat') and self.initial_quantity % 1:
            raise ValueError('Birds, animals and trays require whole quantities')
        if self.category in ('chicken_meat', 'beef', 'goat_meat') and self.form not in ('chilled', 'frozen', 'dressed'):
            raise ValueError('Choose a valid meat form')
        if self.category in ('broilers', 'local_chicken', 'goats', 'cattle') and self.form != 'live':
            raise ValueError('Live stock batches must use the live form')
        if re.search(r'\d|@|https?://|www\.', self.region, re.I):
            raise ValueError('Enter a general region, not a private pickup address')
        return self


class BatchExternalSaleInput(Input):
    quantity: Quantity
    notes: str = Field(default='', max_length=500)


class SupplyOfferInput(Input):
    batch_id: str
    offered_quantity: Quantity
    expected_ready_date: Optional[date] = None
    expected_min_weight_kg: Optional[Annotated[Decimal, Field(gt=0, max_digits=8, decimal_places=3)]] = None
    expected_max_weight_kg: Optional[Annotated[Decimal, Field(gt=0, max_digits=8, decimal_places=3)]] = None
    asking_price_per_unit: Optional[Money] = None
    supplier_notes: str = Field(default='', max_length=500)


class AllocationInput(Input):
    supply_offer_id: Optional[str] = None
    supplier_batch_id: str
    allocated_quantity: Quantity


class AllocationPlanInput(Input):
    allocations: list[AllocationInput] = Field(min_length=1, max_length=50)


class OfferReview(Input):
    status: Literal['accepted', 'partially_accepted', 'rejected']
    accepted_quantity: Optional[Quantity] = None
    notes: str = Field(default='', max_length=1000)


class AllocationUpdate(Input):
    allocated_quantity: Optional[Quantity] = None
    status: Optional[Literal['cancelled']] = None

    @model_validator(mode='after')
    def has_change(self):
        if self.allocated_quantity is None and self.status is None:
            raise ValueError('Provide a new allocation quantity or cancel the allocation')
        return self


class DemandOrderCreate(Input):
    delivery_address_id: Optional[str] = None
    payment_method: Literal['pay_on_delivery'] = 'pay_on_delivery'


class RequirementProgress(Input):
    status: Literal['confirmed', 'fulfilling', 'completed', 'cancelled']
    internal_notes: str = Field(default='', max_length=1000)


class BatchVerificationInput(Input):
    verified_quantity: Quantity
    sampled_average_weight_kg: Optional[Annotated[Decimal, Field(gt=0, max_digits=8, decimal_places=3)]] = None
    rejected_quantity: Annotated[Decimal, Field(ge=0, max_digits=14, decimal_places=3)] = Decimal('0')
    readiness_confirmed: bool = False
    location_confirmed: bool = False
    notes: str = Field(default='', max_length=1000)
    photos: list[str] = Field(default_factory=list, max_length=8)
    buyer_price_per_unit: Money
    supplier_asking_price_per_unit: Optional[Money] = None
    supplier_payout_price_per_unit: Optional[Annotated[Decimal, Field(ge=0, max_digits=14, decimal_places=2)]] = None


class BusinessInput(Input):
    business_type: Literal['chicken_shop', 'butchery', 'fish_shop', 'meat_delivery', 'egg_reseller', 'local_chicken_business', 'goat_meat_business', 'restaurant_grill']
    area: str = Field(min_length=2, max_length=150)
    budget_range: str = Field(min_length=1, max_length=80)
    has_premises: bool
    wants_stock: bool
    target_start_date: str = Field(min_length=2, max_length=100)


class CollectionResult(Input):
    order_item_id: str
    actual_quantity: Annotated[Decimal, Field(ge=0, max_digits=14, decimal_places=3)]
    rejected_quantity: Annotated[Decimal, Field(ge=0, max_digits=14, decimal_places=3)]


class Progress(Input):
    expected_collection_date: Optional[date] = None
    internal_status: Literal['supply_confirmed', 'pickup_scheduled', 'collected', 'quality_checked', 'in_transit', 'delivered', 'completed', 'cancelled', 'payment_failed']
    actual_quantity: Optional[Annotated[Decimal, Field(ge=0, max_digits=14, decimal_places=3)]] = None
    rejected_quantity: Optional[Annotated[Decimal, Field(ge=0, max_digits=14, decimal_places=3)]] = None
    actual_weight: Optional[Annotated[Decimal, Field(ge=0, max_digits=14, decimal_places=3)]] = None
    collection_results: Optional[list[CollectionResult]] = None
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


class StockMediaInput(Input):
    photos: list[str] = Field(default_factory=list, max_length=8)
    video: Optional[str] = Field(default=None, max_length=80)


class StockCorrection(Input):
    counted_on_hand: Annotated[Decimal, Field(ge=0, max_digits=14, decimal_places=3)]
    reason: str = Field(min_length=5, max_length=500)


class StockAddition(Input):
    quantity: Quantity
    reason: str = Field(min_length=5, max_length=500)


class SaleInput(Input):
    quantity: Quantity
    sold_on: date
    unit_price: Optional[Money] = None
    note: str = Field(default='', max_length=500)

    @field_validator('sold_on')
    @classmethod
    def no_future_sale(cls, value):
        if value > date.today():
            raise ValueError('A sale date cannot be in the future')
        return value


class SaleReversalInput(Input):
    reason: str = Field(min_length=5, max_length=500)


class NotificationsRead(Input):
    ids: list[str] = Field(default_factory=list, max_length=200)
    all: bool = False


class DeviceInput(Input):
    token: str = Field(min_length=20, max_length=4096)
    platform: Literal['android', 'ios', 'web'] = 'android'


class OperatorInput(Input):
    phone: str = Field(pattern=r'^\+255[67]\d{8}$')
    name: str = Field(min_length=2, max_length=100)
    role: Literal['admin', 'staff'] = 'staff'


class OperatorUpdate(Input):
    name: Optional[str] = Field(default=None, min_length=2, max_length=100)
    role: Optional[Literal['admin', 'staff']] = None
    active: Optional[bool] = None


class SetupStart(Input):
    passphrase: str = Field(min_length=1, max_length=200)


class SetupPhone(Input):
    setup_token: str = Field(min_length=20, max_length=200)
    phone: str = Field(pattern=r'^\+255[67]\d{8}$')


class SetupAdmin(SetupPhone):
    name: str = Field(min_length=2, max_length=100)


class SetupVerify(Input):
    setup_token: str = Field(min_length=20, max_length=200)
    challenge_id: str
    code: str = Field(pattern=r'^\d{4,8}$')


class RatingInput(Input):
    stars: int = Field(ge=1, le=5)
    comment: str = Field(default='', max_length=500)


class RatingVisibility(Input):
    hidden: bool
