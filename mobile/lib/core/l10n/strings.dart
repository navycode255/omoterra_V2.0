import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/session.dart';

/// Application copy in English and Swahili. Swahili is a first-class language
/// here, not a fallback: buyers and suppliers choose it during setup and the
/// choice is stored on their account.
class Strings {
  final String _code;
  const Strings(this._code);

  bool get isSwahili => _code == 'sw';
  String _t(String en, String sw) => isSwahili ? sw : en;

  // Onboarding ------------------------------------------------------------
  String get splashTagline => _t('Fresh supply. Reliable sourcing.',
      'Bidhaa mpya. Ununuzi wa kuaminika.');
  String get welcomeTitle => _t('Welcome to Omoterra', 'Karibu Omoterra');
  String get welcomeBody => _t(
      'Fresh livestock and farm produce. Direct from trusted suppliers.',
      'Mifugo na mazao mapya. Moja kwa moja kutoka kwa wasambazaji wanaoaminika.');
  String get getStarted => _t('Get Started', 'Anza Sasa');
  String get haveAccount =>
      _t('I already have an account', 'Tayari nina akaunti');
  String get phoneTitle => _t('Enter your\nphone number', 'Weka namba\nyako ya simu');
  String get phoneBody => _t("We'll send you a verification code",
      'Tutakutumia msimbo wa uthibitisho');
  String get phoneLabel => _t('Phone number', 'Namba ya simu');
  String get continueLabel => _t('Continue', 'Endelea');
  String get terms => _t('By continuing you agree to our\nTerms and Privacy Policy',
      'Kwa kuendelea unakubali\nMasharti na Sera ya Faragha');
  String get otpTitle => _t('Enter OTP', 'Thibitisha Namba Yako');
  String otpBody(String phone) => _t(
      "We've sent a 6-digit code to\n$phone",
      'Tumetuma msimbo wa tarakimu 6 kwenda\n$phone');
  String resendIn(String time) =>
      _t('Resend code in $time', 'Tuma tena baada ya $time');
  String get resendNow => _t('Resend code', 'Tuma tena');
  String get verify => _t('Verify', 'Thibitisha');
  String get roleTitle =>
      _t('How will you use Omoterra?', 'Utatumiaje Omoterra?');
  String get roleBody => _t('You can select one or both. You can add another role later.',
      'Unaweza kuchagua moja au zote mbili. Unaweza kuongeza nyingine baadaye.');
  String get buySupply => _t('Buy Supply', 'Nunua Bidhaa');
  String get buySupplyBody => _t('For homes, restaurants, butcheries and businesses.',
      'Kwa matumizi ya nyumbani, migahawa, bucha na biashara.');
  String get sellSupply => _t('Sell Supply', 'Uuze Bidhaa');
  String get sellSupplyBody => _t(
      'For farmers and suppliers.', 'Kwa wakulima na wasambazaji.');
  String get buyerTypeTitle =>
      _t('What best describes you?', 'Unanunua kwa ajili ya?');
  String get buyerTypeBody => _t('This helps us serve you better.',
      'Hii inatusaidia kukuhudumia vizuri.');
  String get profileTitle => _t('Your details', 'Taarifa zako');
  String get fullName => _t('Full name', 'Jina kamili');
  String get region => _t('Region / Area', 'Eneo / Mkoa');
  String get language => _t('Language', 'Lugha');
  String get finishSetup => _t('Finish Setup', 'Maliza Usajili');

  // Buyer -----------------------------------------------------------------
  String greeting(String name) =>
      _t('Good morning,\n$name', 'Habari za asubuhi,\n$name');
  String get whatToday =>
      _t('What do you need today?', 'Unahitaji nini leo?');
  String get buySupplyCard => _t('Buy Supply', 'Nunua Bidhaa');
  String get buySupplyCardBody => _t('Browse available livestock and meat',
      'Angalia mifugo na nyama zilizopo');
  String get requestSupply => _t('Request Supply', 'Omba Bidhaa');
  String get requestSupplyBody =>
      _t('Tell us what you need.', 'Tuambie unachohitaji.');
  String get startBusiness => _t('Start a Business', 'Anzisha Biashara');
  String get startBusinessBody =>
      _t('Get expert guidance', 'Pata mwongozo wa kitaalam');
  String get myOrders => _t('My Orders', 'Maagizo Yangu');
  String get myOrdersBody =>
      _t('Track your purchases', 'Fuatilia manunuzi yako');
  String get availableToday => _t('Available Today', 'Zilizopo Leo');
  String get viewAll => _t('View all', 'Angalia zote');
  String get explore => _t('Explore', 'Tafuta');
  String get searchHint => _t('Search livestock, meat or produce…',
      'Tafuta mifugo, nyama au mazao…');
  String get all => _t('All', 'Zote');
  String get available => _t('available', 'zinapatikana');
  String get readyToday => _t('Ready today', 'Tayari leo');
  String get buyNow => _t('Buy Now', 'Nunua Sasa');
  String get needMore =>
      _t('Need more? Request Supply', 'Unahitaji zaidi? Omba Bidhaa');
  String get omoterraApproved =>
      _t('Omoterra Approved', 'Imethibitishwa na Omoterra');
  String completedSupplies(int n) =>
      _t('$n completed supplies', 'mauzo $n yaliyokamilika');
  String get specifications => _t('Specifications', 'Maelezo');
  String get checkout => _t('Checkout', 'Malipo');
  String get deliveryAddress => _t('Delivery Address', 'Mahali pa Kufikisha');
  String get change => _t('Change', 'Badilisha');
  String get preferredDate =>
      _t('Preferred Delivery Date', 'Tarehe Unayopendelea');
  String get paymentMethod => _t('Payment Method', 'Njia ya Malipo');
  String get payNow => _t('Pay Now (Mobile Money)', 'Lipa Sasa (Mobile Money)');
  String get payNowSoon => _t('Coming soon', 'Inakuja hivi karibuni');
  String get payOnDelivery => _t('Pay on Delivery', 'Lipa Unapopokea');
  String get payOnDeliveryBody =>
      _t('Pay when you receive', 'Lipa unapopokea bidhaa');
  String get orderTotal => _t('Order Total', 'Jumla ya Agizo');
  String get confirmOrder => _t('Confirm Order', 'Thibitisha Agizo');
  String get orderConfirmed => _t('Order confirmed!', 'Agizo limethibitishwa!');
  String get orderConfirmedBody => _t(
      'Your order has been received and is being processed.',
      'Agizo lako limepokelewa na linashughulikiwa.');
  String get orderNumber => _t('Order Number', 'Namba ya Agizo');
  String get trackOrder => _t('Track Order', 'Fuatilia Agizo');
  String get backHome => _t('Back to Home', 'Rudi Mwanzo');
  String get active => _t('Active', 'Yanaendelea');
  String get past => _t('Past', 'Yaliyopita');
  String get orderDetails => _t('Order Details', 'Maelezo ya Agizo');
  String get deliveryDate => _t('Delivery Date', 'Tarehe ya Kufikisha');
  String get orderItems => _t('Order Items', 'Bidhaa Zilizoagizwa');
  String get paymentDetails => _t('Payment Details', 'Maelezo ya Malipo');
  String get activityTimeline => _t('Activity Timeline', 'Ratiba ya Matukio');

  // Order status ----------------------------------------------------------
  String get confirmed => _t('Confirmed', 'Imethibitishwa');
  String get preparing => _t('Preparing', 'Inaandaliwa');
  String get onTheWay => _t('On the way', 'Njiani');
  String get delivered => _t('Delivered', 'Imefikishwa');
  String get cancelled => _t('Cancelled', 'Imeghairiwa');

  // Request supply --------------------------------------------------------
  String get product => _t('Product', 'Bidhaa');
  String get quantity => _t('Quantity', 'Kiasi');
  String get preferredWeight =>
      _t('Preferred Weight', 'Uzito Unaopendelea');
  String get optional => _t('optional', 'si lazima');
  String get neededBy => _t('Needed By', 'Inahitajika Ifikapo');
  String get deliveryArea => _t('Delivery Area', 'Eneo la Kufikisha');
  String get notes => _t('Additional Notes', 'Maelezo ya Ziada');
  String get submitRequest => _t('Submit Request', 'Tuma Ombi');
  String get sourcingTitle =>
      _t("We're sourcing this for you.", 'Tunakutafutia hii.');
  String get referenceNumber => _t('Reference Number', 'Namba ya Kumbukumbu');
  String get sourcingBody => _t(
      'Our team will find the best suppliers and get back to you soon.',
      'Timu yetu itatafuta wasambazaji bora na kukujibu hivi karibuni.');
  String get viewRequest => _t('View Request', 'Angalia Ombi');
  String get submitted => _t('Submitted', 'Imetumwa');
  String get sourcing => _t('Sourcing', 'Inatafutwa');
  String get supplyFound => _t('Supply Found', 'Bidhaa Imepatikana');

  // Business --------------------------------------------------------------
  String get startBusinessTitle => _t('Start a Business', 'Anzisha Biashara');
  String get startBusinessIntro => _t(
      'Turn your plan into a profitable food business with Omoterra.',
      'Geuza mpango wako kuwa biashara ya chakula yenye faida na Omoterra.');
  String get whatYouNeed => _t("What you'll need", 'Utakachohitaji');
  String get howOmoterraHelps =>
      _t('How Omoterra helps', 'Omoterra inavyosaidia');
  String get requestSetupPlan =>
      _t('Request a Setup Plan', 'Omba Mpango wa Kuanzisha');
  String get setupPlanRequest =>
      _t('Setup Plan Request', 'Ombi la Mpango wa Kuanzisha');
  String get locationArea => _t('Location / Area', 'Eneo');
  String get budgetRange => _t('Budget Range', 'Kiasi cha Bajeti');
  String get hasPremises =>
      _t('Do you already have premises?', 'Je, tayari una eneo la biashara?');
  String get wantsStock =>
      _t('Do you need initial stock?', 'Je, unahitaji bidhaa za kuanzia?');
  String get whenStart =>
      _t('When would you like to start?', 'Ungependa kuanza lini?');
  String get sendRequest => _t('Send Request', 'Tuma Ombi');
  String get yes => _t('Yes', 'Ndiyo');
  String get no => _t('No', 'Hapana');

  // Supplier --------------------------------------------------------------
  String get availableStat => _t('Available', 'Zilizopo');
  String get reservedStat => _t('Reserved', 'Zimehifadhiwa');
  String get soldStat => _t('Sold', 'Zilizouzwa');
  String get expectedPayment => _t('Expected Payment', 'Malipo Yanayotarajiwa');
  String get addStock => _t('Add Stock', 'Ongeza Bidhaa');
  String get yourStock => _t('Your Stock', 'Bidhaa Zako');
  String get myStock => _t('My Stock', 'Bidhaa Zangu');
  String get selectCategory => _t('Select category', 'Chagua aina ya bidhaa');
  String get stockDetails => _t('Stock Details', 'Taarifa za Bidhaa');
  String get priceAndLocation => _t('Price & Location', 'Bei na Eneo');
  String get addPhotos => _t('Add Photos', 'Ongeza Picha');
  String get previewSubmit => _t('Preview & Submit', 'Kagua na Tuma');
  String get averageWeight => _t('Average Weight (kg)', 'Uzito wa Wastani (kg)');
  String get ageWeeks => _t('Age (weeks)', 'Umri (wiki)');
  String get breedType => _t('Type / Breed', 'Aina / Kizazi');
  String get condition => _t('Condition', 'Hali');
  String get live => _t('Live', 'Hai');
  String get dressed => _t('Dressed', 'Iliyochinjwa');
  String get readyDate => _t('Ready Date', 'Tarehe ya Kuwa Tayari');
  String get askingPrice =>
      _t('Asking price (TZS per unit)', 'Bei unayoomba (TZS kwa kila kimoja)');
  String get generalArea => _t('General area', 'Eneo kwa ujumla');
  String get pickupAddress => _t('Pickup address (for Omoterra only)',
      'Mahali pa kuchukua (kwa Omoterra pekee)');
  String get pickupNote => _t(
      'Your exact location is shared privately with Omoterra, never with buyers.',
      'Eneo lako kamili linashirikiwa na Omoterra pekee, si kwa wanunuzi.');
  String get photoNote => _t(
      'Clear photos help Omoterra review your stock faster.',
      'Picha zenye ubora husaidia Omoterra kukagua haraka.');
  String get next => _t('Next', 'Endelea');
  String get submitForReview => _t('Submit for Review', 'Tuma kwa Ukaguzi');
  String get pending => _t('Pending', 'Inasubiri');
  String get paused => _t('Paused', 'Imesimamishwa');
  String get needsConfirmation =>
      _t('Needs confirmation', 'Inahitaji uthibitisho');
  String get confirmStock => _t('Confirm your stock', 'Thibitisha bidhaa zako');
  String confirmStockBody(String qty, String unit) => _t(
      'Are $qty $unit still available?', 'Je, $qty $unit bado zipo?');
  String confirmQty(String qty) => _t('Confirm $qty', 'Thibitisha $qty');
  String get updateQuantity => _t('Update quantity', 'Badilisha kiasi');
  String get payouts => _t('Payouts', 'Malipo');
  String get paid => _t('Paid', 'Yamelipwa');

  // Account ---------------------------------------------------------------
  String get account => _t('Account', 'Akaunti');
  String get home => _t('Home', 'Mwanzo');
  String get orders => _t('Orders', 'Maagizo');
  String get stock => _t('Stock', 'Bidhaa');
  String get savedAddresses => _t('Saved addresses', 'Anwani zilizohifadhiwa');
  String get support => _t('Support', 'Msaada');
  String get termsPrivacy => _t('Terms & Privacy', 'Masharti na Faragha');
  String get logout => _t('Log out', 'Toka');

  // Shared ----------------------------------------------------------------
  String get retry => _t('Try again', 'Jaribu tena');
  String get cancel => _t('Cancel', 'Ghairi');
  String get save => _t('Save', 'Hifadhi');
  String get noOrdersTitle => _t('No orders yet.', 'Bado hakuna maagizo.');
  String get noOrdersBody => _t(
      "Browse today's available supply or request what you need.",
      'Angalia bidhaa zilizopo leo au omba unachohitaji.');
  String get noStockTitle =>
      _t('No stock listed yet.', 'Bado hujaweka bidhaa.');
  String get noStockBody => _t(
      'Add your available livestock and Omoterra will review it before it goes live.',
      'Ongeza mifugo yako na Omoterra itakagua kabla haijaonekana kwa wanunuzi.');
}

/// Watches the signed-in account's language so switching it in Account
/// immediately re-renders every screen.
final stringsProvider = Provider<Strings>((ref) =>
    Strings(ref.watch(sessionProvider).valueOrNull?.language ?? 'en'));

extension StringsContext on WidgetRef {
  Strings get s => watch(stringsProvider);
}
