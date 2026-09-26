from __future__ import annotations

from datetime import date
import re
from decimal import Decimal
from typing import Annotated, Literal, Optional
from pydantic import BaseModel, BeforeValidator, ConfigDict, Field, field_validator, model_validator
from .i18n import M

# Tanzania's regions, spelled as the app lists them. A region typed in any
# capitalization is stored this way, so "dar es salaam" never shows to buyers.
TANZANIA_REGIONS = ('Arusha', 'Dar es Salaam', 'Dodoma', 'Geita', 'Iringa', 'Kagera', 'Katavi', 'Kigoma',
    'Kilimanjaro', 'Lindi', 'Manyara', 'Mara', 'Mbeya', 'Morogoro', 'Mtwara', 'Mwanza', 'Njombe',
    'Pemba North', 'Pemba South', 'Pwani', 'Rukwa', 'Ruvuma', 'Shinyanga', 'Simiyu', 'Singida', 'Songwe',
    'Tabora', 'Tanga', 'Zanzibar North', 'Zanzibar South & Central', 'Zanzibar West')
_REGIONS_BY_KEY = {name.casefold(): name for name in TANZANIA_REGIONS}
_DAR = re.compile(r'\bdar\s+es\s+salaam\b', re.I)


def canonical_region(value):
    """Trim and collapse spaces; a known region gets its proper spelling, and
    "Dar es Salaam" is also fixed inside a longer place ("Mbezi, dar es salaam")."""
    if not isinstance(value, str):
        return value
    text = ' '.join(value.split())
    return _REGIONS_BY_KEY.get(text.casefold()) or _DAR.sub('Dar es Salaam', text)


Region = Annotated[str, BeforeValidator(canonical_region)]

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


def _guessable(pin):
    # Same digit (0000) or a run up or down (1234, 987654).
    steps = {int(b) - int(a) for a, b in zip(pin, pin[1:])}
    return len(set(pin)) == 1 or steps in ({1}, {-1})


class PinInput(Input):
    pin: str = Field(pattern=r'^\d{4,6}$')

    @field_validator('pin')
    @classmethod
    def not_guessable(cls, value):
        if _guessable(value):
            raise ValueError(M('err.pin_too_easy'))
        return value


class PinSignIn(Input):
    phone: str = Field(pattern=r'^\+255[67]\d{8}$')
    pin: str = Field(pattern=r'^\d{4,6}$')


class Profile(Input):
    name: str = Field(min_length=2, max_length=100)
    region: Region = Field(min_length=2, max_length=80)
    language: Literal['en', 'sw'] = 'en'
    roles: list[Literal['buyer', 'supplier']] = Field(min_length=1, max_length=2)
    buyer_type: Optional[Literal['personal', 'restaurant', 'butchery', 'hotel', 'retailer', 'caterer', 'other']] = None

    @model_validator(mode='after')
    def buyer_details(self):
        if 'buyer' in self.roles and not self.buyer_type:
            raise ValueError(M('err.choose_buyer_type'))
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
            raise ValueError(M('err.choose_buyer_type'))
        if self.role == 'supplier' and (not self.legal_name or not self.internal_pickup_address):
            raise ValueError(M('err.complete_supplier_pickup_details'))
        return self


class AddressInput(Input):
    label: str = Field(min_length=1, max_length=60)
    recipient_name: str = Field(min_length=2, max_length=100)
    phone: str = Field(pattern=r'^\+\d{9,15}$')
    region: Region = Field(min_length=2, max_length=80)
    district_area: str = Field(min_length=2, max_length=100)
    address_text: str = Field(min_length=3, max_length=500)
    coordinates: Optional[str] = Field(default=None, max_length=80)


class FarmLocationInput(Input):
    """A supplier moving their farm pin or pickup directions from Account."""
    farm_latitude: Annotated[Decimal, Field(ge=-90, le=90, max_digits=9, decimal_places=6)]
    farm_longitude: Annotated[Decimal, Field(ge=-180, le=180, max_digits=9, decimal_places=6)]
    farm_map_url: str = Field(default='', max_length=500)
    internal_pickup_address: str = Field(min_length=3, max_length=500)

    @field_validator('farm_map_url')
    @classmethod
    def google_maps_link(cls, value):
        if value and not GOOGLE_MAPS_LINK.match(value):
            raise ValueError(M('err.paste_google_maps_link_farm'))
        return value


class SupplierInput(Input):
    legal_name: str = Field(min_length=2, max_length=150)
    internal_pickup_address: str = Field(min_length=3, max_length=500)


class ListingInput(Input):
    category: Category
    unit_type: Unit
    specs: dict
    region: Region = Field(min_length=2, max_length=80)
    photos: list[str] = Field(default_factory=list, max_length=8)
    video: Optional[str] = Field(default=None, max_length=80)
    farmer_asking_price_per_unit: Money
    quantity_total: Quantity

    @model_validator(mode='after')
    def category_specs(self):
        if self.unit_type != UNITS[self.category]:
            raise ValueError(M('err.unit_does_not_match_category'))
        if self.unit_type not in ('kg',) and self.quantity_total % 1:
            raise ValueError(M('err.birds_animals_trays_require_whole'))
        fields = {
            'bird': {'avg_weight_kg', 'breed_type', 'age_weeks', 'live_or_dressed', 'ready_date'},
            'animal': {'weight_range', 'breed', 'sex', 'approx_age', 'ready_date'},
            'kg': {'cut_type', 'chilled_or_frozen', 'slaughter_date'},
            'tray': {'tray_size', 'egg_size', 'ready_date'},
        }[self.unit_type]
        if set(self.specs) != fields or any(not str(v).strip() for v in self.specs.values()):
            raise ValueError(M('err.required_spec_fields', fields=', '.join(sorted(fields))))
        for key, value in self.specs.items():
            if not isinstance(value, (str, int, float)) or len(str(value)) > 100:
                raise ValueError(M('err.stock_specifications_must_short_text'))
            if not key.endswith('date') and re.search(r'(?:\+?255|0)[\s-]*[67](?:[\s-]*\d){8}|@|https?://|www\.', str(value), re.I):
                raise ValueError(M('err.do_not_put_contact_details'))
        if re.search(r'\d|@|https?://|www\.', self.region, re.I):
            raise ValueError(M('err.use_general_region_name_without'))
        if self.unit_type == 'bird':
            try:
                if Decimal(str(self.specs['avg_weight_kg'])) <= 0 or Decimal(str(self.specs['age_weeks'])) < 0:
                    raise ValueError(M('err.weight_must_positive_age_must'))
            except ArithmeticError:
                raise ValueError(M('err.enter_numeric_average_weight_age'))
        # Only the ops-reviewed listing can publish these values.
        if self.unit_type == 'bird' and self.specs['live_or_dressed'] not in ['live', 'dressed']:
            raise ValueError(M('err.choose_live_dressed'))
        if self.unit_type == 'kg' and self.specs['chilled_or_frozen'] not in ['chilled', 'frozen']:
            raise ValueError(M('err.choose_chilled_frozen'))
        if self.unit_type == 'tray':
            try:
                if int(self.specs['tray_size']) not in (30, 24, 12):
                    raise ValueError(M('err.choose_tray_size_12_24'))
            except (TypeError, ValueError):
                raise ValueError(M('err.choose_tray_size_12_24'))
            if self.specs['egg_size'] not in ['small', 'medium', 'large']:
                raise ValueError(M('err.choose_egg_size'))
        date.fromisoformat(str(self.specs['slaughter_date' if self.unit_type == 'kg' else 'ready_date']))
        if any(not re.fullmatch(r'/media/[a-f0-9-]{36}', photo) for photo in self.photos):
            raise ValueError(M('err.use_photos_uploaded_through_omoterra'))
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
            raise ValueError(M('err.choose_today_future_delivery_date'))
        return value


class StockUpdate(Input):
    quantity_total: Optional[Annotated[Decimal, Field(ge=0, max_digits=14, decimal_places=3)]] = None
    action: Literal['update', 'pause', 'confirm', 'resubmit']


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
    delivery_region: Region = Field(default='', max_length=80)
    delivery_notes: str = Field(default='', max_length=500)
    requirement_type: Literal['one_time', 'recurring'] = 'one_time'
    recurrence_frequency: Literal['', 'weekly', 'monthly'] = ''
    preferred_weekdays: list[Literal['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']] = Field(default_factory=list, max_length=7)

    @model_validator(mode='after')
    def valid_request(self):
        if UNITS[self.category] != self.unit_type or (self.unit_type != 'kg' and self.quantity % 1):
            raise ValueError(M('err.invalid_category_unit_quantity'))
        if self.needed_by_date < date.today():
            raise ValueError(M('err.needed_by_date_must_not'))
        if self.reference_photo and not re.fullmatch(r'/media/[a-f0-9-]{36}', self.reference_photo):
            raise ValueError(M('err.use_photo_uploaded_through_omoterra'))
        if self.minimum_weight_kg and self.maximum_weight_kg and self.minimum_weight_kg > self.maximum_weight_kg:
            raise ValueError(M('err.minimum_weight_cannot_exceed_maximum'))
        if self.requirement_type == 'recurring' and not self.recurrence_frequency:
            raise ValueError(M('err.choose_recurrence_frequency'))
        if self.requirement_type == 'recurring' and not self.preferred_weekdays:
            raise ValueError(M('err.choose_least_one_preferred_delivery'))
        if self.requirement_type == 'one_time' and (self.recurrence_frequency or self.preferred_weekdays):
            raise ValueError(M('err.recurrence_settings_require_recurring_requirement'))
        return self


class OperatorRequirementInput(SourcingInput):
    buyer_profile_id: Optional[str] = None
    buyer: Optional['OperatorBuyerInput'] = None
    internal_notes: str = Field(default='', max_length=1000)


class MobileAdminStart(Input):
    passphrase: str = Field(min_length=1, max_length=200)
    phone: str = Field(pattern=r'^\+255[67]\d{8}$')


class AdminBuyerRegistration(Input):
    """A buyer registered by an operator: the app account plus the same
    CRM record the dashboard keeps."""
    phone: str = Field(pattern=r'^\+255[67]\d{8}$')
    name: str = Field(min_length=2, max_length=100)
    business_name: str = Field(min_length=2, max_length=150)
    buyer_type: Literal['personal', 'restaurant', 'butchery', 'hotel', 'retailer', 'caterer', 'other']
    region: Region = Field(min_length=2, max_length=80)
    area: str = Field(default='', max_length=100)
    preferences: dict = Field(default_factory=dict)
    last_known_buying_price: Optional[Annotated[Decimal, Field(gt=0, max_digits=14, decimal_places=2)]] = None
    minimum_order: Optional[Quantity] = None
    payment_terms: str = Field(default='', max_length=100)
    internal_notes: str = Field(default='', max_length=2000)


class OperatorBuyerInput(Input):
    business_name: str = Field(min_length=2, max_length=150)
    buyer_type: Literal['personal', 'restaurant', 'butchery', 'hotel', 'retailer', 'caterer', 'other'] = 'other'
    contact_person: str = Field(default='', max_length=100)
    phone: str = Field(default='', max_length=20)
    region: Region = Field(default='', max_length=80)
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
    region: Region = Field(min_length=2, max_length=80)
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
            raise ValueError(M('err.paste_google_maps_link_farm'))
        return value

    @model_validator(mode='after')
    def farm_pin_complete(self):
        if (self.farm_latitude is None) != (self.farm_longitude is None):
            raise ValueError(M('err.farm_location_needs_both_latitude'))
        return self

    @field_validator('region')
    @classmethod
    def public_region_only(cls, value):
        if re.search(r'\d|@|https?://|www\.', value, re.I):
            raise ValueError(M('err.enter_general_region_name_not'))
        return value

    @field_validator('alternate_phone')
    @classmethod
    def valid_alternate_phone(cls, value):
        if value and not re.fullmatch(r'\+255[67]\d{8}', value):
            raise ValueError(M('err.enter_alternate_tanzanian_mobile_number'))
        return value

    @field_validator('categories')
    @classmethod
    def unique_categories(cls, value):
        if len(set(value)) != len(value):
            raise ValueError(M('err.choose_each_supply_category_only'))
        return value

    @model_validator(mode='after')
    def valid_production_profile(self):
        if self.primary_category not in self.categories:
            raise ValueError(M('err.main_supply_category_must_selected'))
        if set(self.production_profile) - set(self.categories):
            raise ValueError(M('err.production_details_must_match_selected'))
        for category, details in self.production_profile.items():
            if not isinstance(details, dict):
                raise ValueError(M('err.enter_production_capacity_by_category'))
            try:
                capacity = Decimal(str(details.get('capacity', '')))
            except Exception as exc:
                raise ValueError(M('err.enter_valid_production_capacity')) from exc
            if not capacity.is_finite() or capacity < 0:
                raise ValueError(M('err.enter_valid_non_negative_production'))
            if details.get('unit') != UNITS[category]:
                raise ValueError(M('err.choose_correct_unit_each_category'))
            if len(str(details.get('frequency', ''))) > 80:
                raise ValueError(M('err.production_frequency_too_long'))
        return self


class SupplierContactInput(Input):
    """What a supplier may change without a new review: how Omoterra reaches
    them and where stock is collected."""
    alternate_phone: str = Field(default='', max_length=20)
    preferred_contact_method: Literal['phone', 'whatsapp', 'sms'] = 'phone'
    internal_pickup_address: str = Field(min_length=3, max_length=500)
    pickup_instructions: str = Field(default='', max_length=1000)

    @field_validator('alternate_phone')
    @classmethod
    def valid_alternate_phone(cls, value):
        if value and not re.fullmatch(r'\+255[67]\d{8}', value):
            raise ValueError(M('err.enter_alternate_tanzanian_mobile_number'))
        return value


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
            raise ValueError(M('err.select_every_current_planned_supply'))
        if any(batch.asking_price_per_unit is None for batch in batches):
            raise ValueError(M('err.add_agreed_asking_price_every'))
        return self


class SupplierOnboardingInput(SupplierProfileInput):
    name: str = Field(min_length=2, max_length=100)
    current_batch: Optional['SupplierBatchInput'] = None
    future_batches: list['SupplierBatchInput'] = Field(default_factory=list, max_length=10)

    @model_validator(mode='after')
    def batch_categories_selected(self):
        batches = ([self.current_batch] if self.current_batch else []) + self.future_batches
        if any(batch.category not in self.categories for batch in batches):
            raise ValueError(M('err.select_every_current_planned_supply'))
        if any(batch.asking_price_per_unit is None for batch in batches):
            raise ValueError(M('err.add_agreed_asking_price_every'))
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
    region: Region = Field(min_length=2, max_length=80)
    private_pickup_location: str = Field(default='', max_length=500)
    photos: list[str] = Field(default_factory=list, max_length=8)

    @model_validator(mode='after')
    def valid_batch(self):
        if self.expected_ready_date < date.today():
            raise ValueError(M('err.expected_ready_date_must_today'))
        if (self.expected_ready_date - date.today()).days > 365 * 5:
            raise ValueError(M('err.expected_ready_date_too_far'))
        if self.expected_min_weight_kg and self.expected_max_weight_kg and self.expected_min_weight_kg > self.expected_max_weight_kg:
            raise ValueError(M('err.minimum_weight_cannot_exceed_maximum'))
        if self.category not in ('chicken_meat', 'beef', 'goat_meat') and self.initial_quantity % 1:
            raise ValueError(M('err.birds_animals_trays_require_whole'))
        if self.category in ('chicken_meat', 'beef', 'goat_meat') and self.form not in ('chilled', 'frozen', 'dressed'):
            raise ValueError(M('err.choose_valid_meat_form'))
        if self.category in ('broilers', 'local_chicken', 'goats', 'cattle') and self.form != 'live':
            raise ValueError(M('err.live_stock_batches_must_use'))
        if re.search(r'\d|@|https?://|www\.', self.region, re.I):
            raise ValueError(M('err.enter_general_region_not_private'))
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
            raise ValueError(M('err.provide_new_allocation_quantity_cancel'))
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
    # changes_requested: under review, back to the supplier with [note].
    # live: resume stock Omoterra paused.
    status: Literal['paused', 'rejected', 'changes_requested', 'live']
    note: str = Field(default='', max_length=1000)

    @model_validator(mode='after')
    def changes_need_a_note(self):
        if self.status == 'changes_requested' and len(self.note.strip()) < 5:
            raise ValueError(M('err.tell_supplier_what_change'))
        return self


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
            raise ValueError(M('err.sale_date_cannot_future'))
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


class VideoUploadStart(Input):
    size: int = Field(gt=0)


class VideoUploadParts(Input):
    numbers: list[int] = Field(min_length=1, max_length=100)


class UploadedPart(Input):
    number: int = Field(ge=1, le=10000)
    etag: str = Field(min_length=1, max_length=200)


class VideoUploadComplete(Input):
    parts: list[UploadedPart] = Field(min_length=1, max_length=10000)


class VideoUploadConfirm(Input):
    upload_id: str = Field(min_length=36, max_length=36)
