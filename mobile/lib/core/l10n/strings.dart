import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/session.dart';

// REVIEW BEFORE RELEASE: the Swahili copy in this file is a first draft
// (partly machine-assisted). A Swahili-speaking team member must review all of
// it before release, farming and livestock terms especially, and check it
// reads naturally for Tanzanian farmers and buyers.

/// Application copy in English and Swahili. Swahili is a first-class language
/// here, not a fallback: buyers and suppliers choose it during setup and the
/// choice is stored on their account.
///
/// Every user-visible string in `lib/features` and `lib/shared` lives here;
/// test/l10n_guard_test.dart fails when a literal slips back into a screen.
class Strings {
  final String _code;
  const Strings(this._code);

  /// The language code sent to the API as `Accept-Language`.
  String get code => isSwahili ? 'sw' : 'en';
  bool get isSwahili => _code == 'sw';
  String _t(String en, String sw) => isSwahili ? sw : en;

  /// Readable name for a value the API sends as a code (a category, status,
  /// unit, weekday…). Unknown codes fall back to Title Case English.
  String label(String value) {
    final pair = _labels[value];
    if (pair != null) return _t(pair.$1, pair.$2);
    return value
        .split('_')
        .map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }

  /// A record status. `live` means visible to buyers here, not a live animal.
  String status(String value) =>
      value == 'live' ? _t('Live', 'Inaonekana sokoni') : label(value);

  /// A unit of sale (`bird`, `animal`, `tray`, `kg`), plural unless [qty] is 1.
  String unit(String unit, [num? qty]) {
    final one = qty == 1;
    return switch (unit) {
      'bird' || 'birds' => _t(one ? 'bird' : 'birds', 'kuku'),
      'animal' ||
      'animals' =>
        _t(one ? 'animal' : 'animals', one ? 'mnyama' : 'wanyama'),
      'tray' || 'trays' => _t(one ? 'tray' : 'trays', 'trei'),
      'kg' => 'kg',
      _ => unit,
    };
  }

  // Onboarding ------------------------------------------------------------
  String get splashHeadline =>
      _t('Farm supply\nmade simple.', 'Bidhaa za shambani\nkwa urahisi.');
  String get splashTagline => _t(
      'Fresh supply. Better business.\nA stronger tomorrow.',
      'Bidhaa bora. Biashara bora.\nKesho yenye nguvu zaidi.');
  String get welcomeTitle => _t('Welcome to Omoterra', 'Karibu Omoterra');
  String get welcomeBody => _t(
      'Fresh livestock and farm produce. Direct from trusted suppliers.',
      'Mifugo na mazao mapya. Moja kwa moja kutoka kwa wasambazaji wanaoaminika.');
  String get getStarted => _t('Get Started', 'Anza Sasa');

  /// Reassures returning users that the single button covers them too.
  String get signInHint => _t('New or returning — just use your phone number.',
      'Mgeni au unarudi — tumia namba yako ya simu.');
  String get phoneTitle =>
      _t('Enter your\nphone number', 'Weka namba\nyako ya simu');
  String get phoneBody => _t("We'll send you a verification code",
      'Tutakutumia msimbo wa uthibitisho');
  String get phoneLabel => _t('Phone number', 'Namba ya simu');
  String get phoneHint => '712 *** ***';
  String get leadingZero => _t('Drop the leading 0 — +255 already covers it.',
      'Ondoa 0 ya mwanzo — +255 tayari inaihusisha.');
  String get phoneTooShort => _t('Enter all 9 digits of your number.',
      'Weka tarakimu zote 9 za namba yako.');
  String get continueLabel => _t('Continue', 'Endelea');
  String get terms => _t(
      'By continuing you agree to our\nTerms and Privacy Policy',
      'Kwa kuendelea unakubali\nMasharti na Sera ya Faragha');
  String get otpTitle => _t('Enter OTP', 'Thibitisha Namba Yako');
  String otpBody(String phone) => _t("We've sent a 6-digit code to\n$phone",
      'Tumetuma msimbo wa tarakimu 6 kwenda\n$phone');
  String resendIn(String time) =>
      _t('Resend code in $time', 'Tuma tena baada ya $time');
  String get resendNow => _t('Resend code', 'Tuma tena');
  String get verify => _t('Verify', 'Thibitisha');
  String get roleTitle =>
      _t('How will you use Omoterra?', 'Utatumiaje Omoterra?');
  String get roleBody => _t(
      'You can select one or both. You can add another role later.',
      'Unaweza kuchagua moja au zote mbili. Unaweza kuongeza nyingine baadaye.');
  String get buySupply => _t('Buy Supply', 'Nunua Bidhaa');
  String get buySupplyBody => _t(
      'For homes, restaurants, butcheries and businesses.',
      'Kwa matumizi ya nyumbani, migahawa, bucha na biashara.');
  String get sellSupply => _t('Sell Supply', 'Uuze Bidhaa');
  String get sellSupplyBody =>
      _t('For farmers and suppliers.', 'Kwa wakulima na wasambazaji.');
  String get buyerTypeTitle =>
      _t('What best describes you?', 'Unanunua kwa ajili ya?');
  String get buyerTypeBody => _t(
      'This helps us serve you better.', 'Hii inatusaidia kukuhudumia vizuri.');
  String get profileTitle => _t('Your details', 'Taarifa zako');
  String get fullName => _t('Full name', 'Jina kamili');
  String get region => _t('Region / Area', 'Eneo / Mkoa');
  String get language => _t('Language', 'Lugha');
  String get finishSetup => _t('Finish Setup', 'Maliza Usajili');

  // Buyer -----------------------------------------------------------------
  String greeting(String name) =>
      _t('Good morning,\n$name', 'Habari za asubuhi,\n$name');
  String get whatToday => _t('What do you need today?', 'Unahitaji nini leo?');
  String get buySupplyCard => _t('Buy Supply', 'Nunua Bidhaa');
  String get buySupplyCardBody => _t(
      'Browse available livestock and meat from trusted suppliers.',
      'Angalia mifugo na nyama zilizopo kutoka kwa wasambazaji waaminifu.');
  String get exploreNow => _t('Explore Now', 'Tazama Sasa');
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
  String get searchHint => _t(
      'Search livestock, meat or produce…', 'Tafuta mifugo, nyama au mazao…');
  String get all => _t('All', 'Zote');
  String get available => _t('available', 'zinapatikana');
  String get readyToday => _t('Ready today', 'Tayari leo');
  String get buyNow => _t('Buy Now', 'Nunua Sasa');
  String get needMore =>
      _t('Need more? Request Supply', 'Unahitaji zaidi? Omba Bidhaa');
  String get noSupplyTitle =>
      _t('No supply available right now', 'Hakuna bidhaa zilizopo kwa sasa');
  String noSupplyFor(String search) => _t("No stock for '$search' right now",
      "Hakuna bidhaa za '$search' kwa sasa");
  String get noSupplyBody => _t(
      'Tell Omoterra what you need and we’ll help source it.',
      'Iambie Omoterra unachohitaji na tutakusaidia kukipata.');
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
  String get preferredWeight => _t('Preferred Weight', 'Uzito Unaopendelea');
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
  String get averageWeight =>
      _t('Average Weight (kg)', 'Uzito wa Wastani (kg)');
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
  String confirmStockBody(String qty, String unit) =>
      _t('Are $qty $unit still available?', 'Je, $qty $unit bado zipo?');
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
  String get retrying => _t('Trying again…', 'Inajaribu tena…');
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

  // Common widgets --------------------------------------------------------
  String get pleaseWait => _t('Please wait…', 'Tafadhali subiri…');
  String get close => _t('Close', 'Funga');
  String get ok => _t('OK', 'Sawa');
  String get submit => _t('Submit', 'Tuma');
  String get goBack => _t('Go back', 'Rudi nyuma');
  String get back => _t('Back', 'Rudi');
  String get done => _t('Done', 'Imekamilika');
  String get edit => _t('Edit', 'Hariri');
  String get remove => _t('Remove', 'Ondoa');
  String get delete => _t('Delete', 'Futa');
  String get confirm => _t('Confirm', 'Thibitisha');
  String get notNow => _t('Not now', 'Si sasa');
  String get loadingContent => _t('Loading content', 'Inapakia maudhui');
  String enterField(String field) =>
      _t('Enter ${field.toLowerCase()}', 'Weka ${field.toLowerCase()}');
  String get photoOffline => _t('Photo shows when you’re back online',
      'Picha itaonekana ukirudi mtandaoni');
  String get inStock => _t('In stock', 'Ipo');
  String nAvailable(String n) => _t('$n available', '$n zinapatikana');
  String get anyDate => _t('Any date', 'Tarehe yoyote');
  String get clearDate => _t('Clear date', 'Futa tarehe');
  String get chooseDate => _t('Choose a date', 'Chagua tarehe');
  String get noneYet => _t('None yet', 'Bado hakuna');

  static const _monthsEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  static const _monthsSw = [
    'Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', //
    'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  /// A date as people read it: 27 Sep 2026 / 27 Sep 2026.
  String date(DateTime d) =>
      '${d.day} ${(isSwahili ? _monthsSw : _monthsEn)[d.month - 1]} ${d.year}';

  /// A date without the year: 27 Sep.
  String dayMonth(DateTime d) =>
      '${d.day} ${(isSwahili ? _monthsSw : _monthsEn)[d.month - 1]}';

  // Errors ----------------------------------------------------------------
  String get errDelayTitle =>
      _t('Omoterra is having a short delay', 'Omoterra imechelewa kidogo');
  String get errDelayBody => _t(
      'We couldn’t load this just now. Please try again shortly.',
      'Hatukuweza kupakia hii sasa hivi. Tafadhali jaribu tena baada ya muda mfupi.');
  String get errSignInTitle =>
      _t('Please sign in again', 'Tafadhali ingia tena');
  String get errSignInBody => _t(
      'Your sign-in has expired. Sign in to continue.',
      'Muda wa kuingia kwako umeisha. Ingia tena ili kuendelea.');
  String get errStaffSignInBody => _t(
      'Your staff sign-in has expired. Sign in again.',
      'Muda wa kuingia kwako kama mfanyakazi umeisha. Ingia tena.');
  String get errNotFoundTitle =>
      _t('We couldn’t find this just now', 'Hatukuweza kupata hii sasa hivi');
  String get errNotFoundBody => _t(
      'Refresh and try again. If the problem continues, try again later.',
      'Onyesha upya na ujaribu tena. Tatizo likiendelea, jaribu tena baadaye.');
  String get errGoneTitle =>
      _t('This is no longer available', 'Hii haipatikani tena');
  String get errGoneBody => _t('Choose another option and try again.',
      'Chagua chaguo lingine na ujaribu tena.');
  String get errFailedTitle =>
      _t('We couldn’t complete that', 'Hatukuweza kukamilisha hilo');
  String get errFailedBody => _t(
      'Please check your connection and try again. If the problem continues, try again later.',
      'Tafadhali angalia mtandao wako na ujaribu tena. Tatizo likiendelea, jaribu tena baadaye.');
  String get errCheckTitle =>
      _t('Please check this information', 'Tafadhali kagua taarifa hizi');
  String get errLoadTitle =>
      _t('We couldn’t load this just now', 'Hatukuweza kupakia hii sasa hivi');
  String get errLoadBody => _t(
      'Check your internet connection, then try again.',
      'Angalia mtandao wako wa intaneti, kisha ujaribu tena.');
  String get errOfflineTitle =>
      _t('We couldn’t reach Omoterra', 'Hatukuweza kufikia Omoterra');
  String get errOfflineBody => _t(
      'Check your connection and retry. Your action is not confirmed.',
      'Angalia mtandao wako na ujaribu tena. Kitendo chako hakijathibitishwa.');
  String get errVideoPaused => _t(
      'The connection dropped, so the upload is paused. Tap Resume when you are back online — finished parts are kept.',
      'Mtandao ulikatika, kwa hiyo upakiaji umesimama. Gusa Endelea ukirudi mtandaoni — sehemu zilizokamilika zimehifadhiwa.');

  // Supplier home ---------------------------------------------------------
  String get supplierHeroTitle =>
      _t('Grow Beyond\nthe Farm', 'Kua Zaidi ya\nShamba');
  String get supplierHeroBody => _t(
      'Reach more buyers.\nBuild a stronger business.',
      'Fikia wanunuzi wengi.\nJenga biashara imara.');
  String get completeSupplierRegistration =>
      _t('Complete supplier registration', 'Kamilisha usajili wa msambazaji');
  String get completeSupplierRegistrationBody => _t(
      'Add your farm, products and pickup details',
      'Ongeza shamba lako, bidhaa na taarifa za mahali pa kuchukua');
  String get completeSupplierProductsBody => _t(
      'Add your products, production and pickup details',
      'Ongeza bidhaa zako, uzalishaji na taarifa za mahali pa kuchukua');
  String get batchAwaitingReview => _t(
      'Batch awaiting Omoterra review', 'Kundi linasubiri ukaguzi wa Omoterra');
  String productionRecorded(String status) =>
      _t('Production recorded · $status', 'Uzalishaji umerekodiwa · $status');
  String get marketDemand => _t('Market Demand', 'Mahitaji ya Soko');
  String get sales => _t('Sales', 'Mauzo');
  String get quickStats => _t('Quick Stats', 'Takwimu kwa Ufupi');
  String get statsAfterApproval => _t('Stats available after approval.',
      'Takwimu zitaonekana baada ya kuidhinishwa.');
  String get newBatch => _t('New batch', 'Kundi jipya');
  String weightRange(String min, String max) =>
      _t('$min–$max kg', '$min–$max kg');
  String get pendingReview => _t('Pending review', 'Inasubiri ukaguzi');
  String get noLiveListingsYet =>
      _t('No live listings yet', 'Bado hakuna bidhaa sokoni');
  String get batchDetails => _t('Batch details', 'Maelezo ya kundi');
  String get viewStock => _t('View Stock', 'Angalia Bidhaa');
  String get addFirstBatch => _t('Add your first batch to see your stock here.',
      'Ongeza kundi lako la kwanza ili kuona bidhaa zako hapa.');
  String get kilograms => _t('Kilograms', 'Kilogramu');
  String get totalStock => _t('Total Stock', 'Jumla ya Bidhaa');
  String get buyerRatings => _t('Buyer Ratings', 'Tathmini za Wanunuzi');
  String get statusUnderReviewTitle =>
      _t('Registration under review', 'Usajili unakaguliwa');
  String get statusUnderReviewBody => _t(
      'We’ll let you know when your supplier account is ready.',
      'Tutakujulisha akaunti yako ya msambazaji ikiwa tayari.');
  String get statusSuspendedTitle =>
      _t('Supplier account paused', 'Akaunti ya msambazaji imesimamishwa');
  String get statusSuspendedBody => _t(
      'Contact Omoterra for help with your account.',
      'Wasiliana na Omoterra kupata msaada kuhusu akaunti yako.');
  String get statusRejectedTitle =>
      _t('Registration needs an update', 'Usajili unahitaji marekebisho');
  String get statusRejectedBody => _t(
      'Please contact Omoterra to find out what to update.',
      'Tafadhali wasiliana na Omoterra kujua cha kurekebisha.');
  String get statusNewTitle => _t('Supplier registration not finished',
      'Usajili wa msambazaji haujakamilika');
  String get statusNewBody => _t('Complete your supplier details to continue.',
      'Kamilisha taarifa zako za msambazaji ili kuendelea.');
  String get statusOtherTitle =>
      _t('Supplier account status', 'Hali ya akaunti ya msambazaji');
  String get statusOtherBody => _t(
      'Contact Omoterra if you need help with your account.',
      'Wasiliana na Omoterra ukihitaji msaada kuhusu akaunti yako.');

  /// An API date (2026-09-27…) as people read it; other text is kept.
  String dateText(Object? value) {
    final parsed = DateTime.tryParse('$value');
    return parsed == null ? '${value ?? ''}' : date(parsed.toLocal());
  }

  // Payouts and supplier orders -------------------------------------------
  String get yourPayouts => _t('Your payouts', 'Malipo yako');
  String get payoutDetails => _t('Payout details', 'Maelezo ya malipo');
  String askingPriceTimes(String qty) =>
      _t('Asking price × $qty', 'Bei uliyoomba × $qty');
  String commissionTimes(String qty) =>
      _t('Commission × $qty', 'Kamisheni × $qty');
  String get yourPayout => _t('Your payout', 'Malipo yako');
  String paymentReference(String ref) =>
      _t('Payment reference: $ref', 'Namba ya malipo: $ref');
  String get noPayoutsTitle => _t('No payouts yet', 'Bado hakuna malipo');
  String get noPayoutsBody => _t(
      'Settlements appear here after your supply is delivered.',
      'Malipo yataonekana hapa baada ya bidhaa zako kufikishwa.');
  String get noReservationsTitle =>
      _t('No reservations yet', 'Bado hakuna oda zilizohifadhiwa');
  String get noReservationsBody => _t(
      'When buyers reserve your approved stock, collection details will appear here.',
      'Wanunuzi wakihifadhi bidhaa zako zilizoidhinishwa, taarifa za uchukuaji zitaonekana hapa.');
  String get ordersAndReservations =>
      _t('Orders & reservations', 'Maagizo na uhifadhi');
  String get collectionDetails =>
      _t('Collection details', 'Taarifa za uchukuaji');
  String reservationNo(String id) => _t('Reservation #$id', 'Uhifadhi #$id');
  String get collectionTbc =>
      _t('Collection to be confirmed', 'Uchukuaji utathibitishwa');
  String collectionExpected(String date) =>
      _t('Collection expected $date', 'Uchukuaji unatarajiwa $date');
  String settlement(String amount) =>
      _t('Settlement $amount', 'Malipo $amount');
  String collectionTopic(String id) => _t('collection #$id', 'uchukuaji #$id');

  // Stock list ------------------------------------------------------------
  String availableReserved(String available, String reserved) => _t(
      '$available available · $reserved reserved',
      '$available zinapatikana · $reserved zimehifadhiwa');
  String get stockActions => _t('Stock actions', 'Vitendo vya bidhaa');
  String get viewDetails => _t('View details', 'Angalia maelezo');
  String get correctStockCount =>
      _t('Correct stock count', 'Sahihisha idadi ya bidhaa');
  String get addStockReceived =>
      _t('Add stock received', 'Ongeza bidhaa zilizopokelewa');
  String get myStockTitle => _t('My stock', 'Bidhaa zangu');
  String get batch => _t('Batch', 'Kundi');
  String get allStock => _t('All stock', 'Bidhaa zote');
  String get availableListings =>
      _t('Available listings', 'Bidhaa zilizopo sokoni');
  String confirmedListings(int n) => _t(
      'Confirmed $n listing${n == 1 ? '' : 's'}. Buyers can order them for the next 48 hours.',
      'Umethibitisha bidhaa $n. Wanunuzi wanaweza kuziagiza kwa saa 48 zijazo.');
  String listingsNeedConfirming(int n) => _t(
      '$n listing${n == 1 ? ' needs' : 's need'} confirming',
      'Bidhaa $n zinahitaji kuthibitishwa');
  String get confirmDueBody => _t(
      'Buyers only see stock you have confirmed in the last 48 hours. If it is all still available, confirm it in one tap.',
      'Wanunuzi huona tu bidhaa ulizothibitisha ndani ya saa 48 zilizopita. Kama zote bado zipo, thibitisha kwa mguso mmoja.');
  String get everythingStillAvailable =>
      _t('Everything is still available', 'Zote bado zipo');
  String get somethingChanged => _t(
      'Something changed? Open that stock to correct the count or pause it.',
      'Kuna kilichobadilika? Fungua bidhaa hiyo kusahihisha idadi au kuisimamisha.');

  // Stock detail ----------------------------------------------------------
  String get pauseListing => _t('Pause listing', 'Simamisha bidhaa');
  String stillAvailableQ(String qty) =>
      _t('Are $qty still available?', 'Je, $qty bado zipo?');
  String get pauseListingBody => _t(
      'Buyers will no longer be able to reserve this stock. Existing confirmed orders remain reserved.',
      'Wanunuzi hawataweza tena kuhifadhi bidhaa hizi. Maagizo yaliyokwisha kuthibitishwa yatabaki yamehifadhiwa.');
  String get countIsDifferent =>
      _t('The count is different', 'Idadi ni tofauti');
  String get stockDetailsTitle => _t('Stock details', 'Maelezo ya bidhaa');
  String get refreshStock => _t('Refresh stock', 'Onyesha upya bidhaa');
  String get manageYourStock => _t('Manage your stock', 'Simamia bidhaa zako');
  String get photosAndVideo => _t('Photos & video', 'Picha na video');
  String get stockHistory => _t('Stock history', 'Historia ya bidhaa');
  String get stockInformation => _t('Stock information', 'Taarifa za bidhaa');
  String get recordedTotal => _t('Recorded total', 'Jumla iliyorekodiwa');
  String get askingPriceShort => _t('Asking price', 'Bei uliyoomba');
  String get regionLabel => _t('Region', 'Mkoa');
  String get confirmAvailability =>
      _t('Confirm availability', 'Thibitisha upatikanaji');
  String weeksCount(String n) =>
      _t('$n ${n == '1' ? 'week' : 'weeks'}', 'wiki $n');
  String get avgWeight => _t('Avg. weight', 'Uzito wa wastani');
  String get weight => _t('Weight', 'Uzito');
  String get breed => _t('Breed', 'Aina');
  String get form => _t('Form', 'Hali');
  String get age => _t('Age', 'Umri');
  String get readyDateShort => _t('Ready date', 'Tarehe ya kuwa tayari');
  String get recordASale => _t('Record a sale', 'Rekodi mauzo');
  String get recordingSales => _t('Recording sales', 'Kurekodi mauzo');
  String get recordingSalesBody => _t(
      'Omoterra deliveries are recorded automatically. Use Record a sale only for goods you sold elsewhere, so your stock count stays right.',
      'Mauzo ya Omoterra hurekodiwa yenyewe. Tumia Rekodi mauzo kwa bidhaa ulizouza mahali pengine tu, ili idadi ya bidhaa zako ibaki sahihi.');
  String get omoterraAskedChanges =>
      _t('Omoterra asked for changes', 'Omoterra imeomba marekebisho');
  String get updatePhotosVideo =>
      _t('Update photos & video', 'Badilisha picha na video');
  String get sendBackForReview =>
      _t('Send back for review', 'Rudisha kwa ukaguzi');
  String get sentBackForReview => _t('Sent back to Omoterra for review.',
      'Imerudishwa kwa Omoterra kwa ukaguzi.');

  // Inventory -------------------------------------------------------------
  String get balancesAppearHere => _t('Your stock balances will appear here.',
      'Salio la bidhaa zako litaonekana hapa.');
  String get addToThisStock =>
      _t('Add to this stock', 'Ongeza kwenye bidhaa hii');
  String get fixRecordingMistake =>
      _t('Fix a recording mistake', 'Sahihisha kosa la kurekodi');
  String get receivedMoreQ => _t(
      'Received more of the same stock?', 'Umepokea zaidi ya bidhaa hii hii?');
  String get correctionBody => _t(
      'Enter the actual stock still on hand, including reserved stock. This corrects your balance; it does not record a sale or change your sold history.',
      'Weka idadi halisi ya bidhaa ulizonazo, pamoja na zilizohifadhiwa. Hii inasahihisha salio lako; hairekodi mauzo wala kubadilisha historia ya mauzo.');
  String get additionBody => _t(
      'Use this for newly received stock with the same specifications. For a different batch or product, add a new listing.',
      'Tumia hii kwa bidhaa mpya zilizopokelewa zenye sifa zilezile. Kwa kundi au bidhaa tofauti, ongeza bidhaa mpya.');
  String actualOnHand(String unit) =>
      _t('Actual stock on hand ($unit)', 'Bidhaa halisi zilizopo ($unit)');
  String quantityReceived(String unit) =>
      _t('Quantity received ($unit)', 'Kiasi kilichopokelewa ($unit)');
  String get whyCountWrong =>
      _t('Why was the count incorrect?', 'Kwa nini idadi haikuwa sahihi?');
  String get stockReceivedNote => _t('Stock received / batch note',
      'Maelezo ya bidhaa zilizopokelewa / kundi');
  String get saveCorrection =>
      _t('Save correction to history', 'Hifadhi marekebisho kwenye historia');
  String get addStockSaveHistory =>
      _t('Add stock & save history', 'Ongeza bidhaa na uhifadhi historia');
  String get countCorrected => _t('Count corrected. Sold history is unchanged.',
      'Idadi imesahihishwa. Historia ya mauzo haijabadilika.');
  String get stockAddedRecorded => _t('Stock added and recorded in history.',
      'Bidhaa zimeongezwa na kurekodiwa kwenye historia.');
  String get soldOutsideNote => _t(
      'For goods sold outside Omoterra. Omoterra orders record their sales automatically when delivered—do not enter them again here.',
      'Kwa bidhaa zilizouzwa nje ya Omoterra. Maagizo ya Omoterra hurekodi mauzo yenyewe yanapofikishwa—usiyaingize tena hapa.');
  String quantitySold(String unit) =>
      _t('Quantity sold ($unit)', 'Kiasi kilichouzwa ($unit)');
  String get dateSold => _t('Date sold', 'Tarehe ya kuuza');
  String salePricePer(String unit) => _t('Sale price per $unit (TZS, optional)',
      'Bei ya kuuza kwa kila $unit (TZS, si lazima)');
  String get saleNoteOptional =>
      _t('Sale note (optional)', 'Maelezo ya mauzo (si lazima)');
  String get recordSaleDeduct =>
      _t('Record sale & deduct stock', 'Rekodi mauzo na upunguze bidhaa');
  String get confirmThisSale =>
      _t('Confirm this sale', 'Thibitisha mauzo haya');
  String get confirmSaleCopy => _t(
      'This records goods already sold outside Omoterra and deducts only available stock. It does not collect a payment.',
      'Hii inarekodi bidhaa zilizokwisha kuuzwa nje ya Omoterra na inapunguza bidhaa zilizopo tu. Haikusanyi malipo.');
  String movement(String kind) => switch (kind) {
        'opening_balance' => _t('Opening stock balance', 'Salio la kuanzia'),
        'sale_reversed' => _t('Sale reversed · stock returned',
            'Mauzo yamebatilishwa · bidhaa zimerudishwa'),
        'correction' => _t('Stock count corrected', 'Idadi imesahihishwa'),
        'stock_added' => _t('Stock received', 'Bidhaa zimepokelewa'),
        'sale_external' =>
          _t('Sold outside Omoterra', 'Imeuzwa nje ya Omoterra'),
        'sale_omoterra' =>
          _t('Sold through Omoterra', 'Imeuzwa kupitia Omoterra'),
        'hold_created' => _t('Stock reserved', 'Bidhaa zimehifadhiwa'),
        'hold_confirmed' =>
          _t('Reservation confirmed', 'Uhifadhi umethibitishwa'),
        'hold_released' =>
          _t('Reserved stock released', 'Bidhaa zilizohifadhiwa zimeachiliwa'),
        'hold_expired' => _t('Reservation expired', 'Muda wa uhifadhi umeisha'),
        'hold_cancelled' => _t('Reservation cancelled', 'Uhifadhi umeghairiwa'),
        'availability_confirmed' =>
          _t('Availability confirmed', 'Upatikanaji umethibitishwa'),
        'listing_paused' => _t('Listing paused', 'Bidhaa imesimamishwa'),
        _ => label(kind),
      };
  String get movementRecordTitle =>
      _t('A record of every movement', 'Kumbukumbu ya kila mabadiliko');
  String get movementRecordBody => _t(
      'Sales, count corrections, incoming stock and reservations stay separate. Your history is never overwritten.',
      'Mauzo, marekebisho ya idadi, bidhaa zinazoingia na uhifadhi vinakaa tofauti. Historia yako haifutwi kamwe.');
  String historyFilter(String f) => switch (f) {
        'all' => _t('All', 'Zote'),
        'sales' => _t('Sales', 'Mauzo'),
        'corrections' => _t('Corrections', 'Marekebisho'),
        'reservations' => _t('Reservations', 'Uhifadhi'),
        _ => label(f),
      };
  String get noMovementsTitle =>
      _t('No movements here yet', 'Bado hakuna mabadiliko hapa');
  String get noMovementsBody => _t(
      'Matching stock movements will appear here as you use this stock record.',
      'Mabadiliko ya bidhaa yataonekana hapa unapotumia kumbukumbu hii.');
  String balanceAfter(String available, String reserved, String sold) => _t(
      'Balance after: $available available · $reserved reserved · $sold sold',
      'Salio baadaye: $available zipo · $reserved zimehifadhiwa · $sold zimeuzwa');
  String get knowWhatSold => _t('Know what has sold.', 'Jua kilichouzwa.');
  String get salesIntro => _t('Review completed sales and transaction history.',
      'Kagua mauzo yaliyokamilika na historia ya miamala.');
  String get allSales => _t('All sales', 'Mauzo yote');
  String get elsewhere => _t('Elsewhere', 'Kwingineko');
  String get noSalesTitle =>
      _t('No sales recorded yet', 'Bado hakuna mauzo yaliyorekodiwa');
  String get noSalesBody => _t(
      'Record a sale from a stock detail page. Omoterra deliveries will appear automatically.',
      'Rekodi mauzo kutoka ukurasa wa maelezo ya bidhaa. Mauzo ya Omoterra yataonekana yenyewe.');
  String get viewMyStock => _t('View my stock', 'Angalia bidhaa zangu');
  String get omoterraDelivery =>
      _t('Omoterra delivery', 'Imefikishwa na Omoterra');
  String get soldElsewhere => _t('Sold elsewhere', 'Imeuzwa kwingineko');
  String saleNo(String id) => _t('Sale #$id', 'Mauzo #$id');
  String get recordedUnitPrice =>
      _t('Recorded unit price', 'Bei ya kimoja iliyorekodiwa');
  String get saleValue => _t('Sale value', 'Thamani ya mauzo');
  String get recordedAtDelivery => _t(
      'Recorded automatically at delivery. Settlement is shown under Payouts.',
      'Imerekodiwa yenyewe wakati wa kufikisha. Malipo yanaonekana chini ya Malipo.');
  String get deductedWhenRecorded => _t(
      'Stock was deducted when this sale was recorded. This is a sales record, not an Omoterra payment.',
      'Bidhaa zilipunguzwa mauzo haya yaliporekodiwa. Hii ni kumbukumbu ya mauzo, si malipo ya Omoterra.');
  String get reverseSaleTitle =>
      _t('Reverse an incorrect sale', 'Batilisha mauzo yasiyo sahihi');
  String get reverseSaleBody => _t(
      'Use this only when this sale was recorded by mistake. The stock will be returned, and the original sale and reversal will both stay in history.',
      'Tumia hii tu kama mauzo haya yalirekodiwa kimakosa. Bidhaa zitarudishwa, na mauzo ya awali pamoja na ubatilishaji vitabaki kwenye historia.');
  String get reasonForReversal =>
      _t('Reason for reversal', 'Sababu ya kubatilisha');
  String get reverseSaleButton =>
      _t('Reverse sale & return stock', 'Batilisha mauzo na urudishe bidhaa');
  String get saleRecordedByMistake => _t(
      'This sale was recorded by mistake', 'Mauzo haya yalirekodiwa kimakosa');
  String get viewStockHistory =>
      _t('View stock history', 'Angalia historia ya bidhaa');

  // Add stock -------------------------------------------------------------
  String get stockSubmitted => _t(
      'Stock submitted — Omoterra will review it before it appears to buyers.',
      'Bidhaa zimetumwa — Omoterra itazikagua kabla hazijaonekana kwa wanunuzi.');
  String get addProductionStock =>
      _t('Add Production / Stock', 'Ongeza Uzalishaji / Bidhaa');
  String get firstPickupDetails =>
      _t('First, your pickup details', 'Kwanza, taarifa za mahali pa kuchukua');
  String get pickupDetailsPrivate => _t(
      'These details are for Omoterra operations only. Buyers never see your legal name or pickup address.',
      'Taarifa hizi ni kwa shughuli za Omoterra pekee. Wanunuzi hawaoni jina lako rasmi wala mahali pa kuchukua.');
  String get legalName => _t('Legal name', 'Jina rasmi');
  String get internalPickupAddress =>
      _t('Internal pickup address', 'Mahali pa kuchukua (ndani)');
  String get saveAndAddStock =>
      _t('Save & add stock', 'Hifadhi na uongeze bidhaa');
  String get registerLivestockIntro => _t(
      'Register livestock that is still growing or ready now. Tell us when this batch will be ready.',
      'Sajili mifugo ambayo bado inakua au iko tayari sasa. Tuambie kundi hili litakuwa tayari lini.');
  String quantityIn(String unit) => _t('Quantity ($unit)', 'Kiasi ($unit)');
  String get expectedReadyDate =>
      _t('Expected ready date', 'Tarehe inayotarajiwa kuwa tayari');
  String nEggs(String n) => _t('$n eggs', 'Mayai $n');
  String askingPricePer(String unit) => _t('Your asking price per $unit (TZS)',
      'Bei unayoomba kwa kila $unit (TZS)');
  String get generalRegion => _t('General region', 'Mkoa kwa ujumla');
  String get priceReviewNote => _t(
      'Omoterra reviews your asking price before the stock becomes available to buyers.',
      'Omoterra hukagua bei unayoomba kabla bidhaa hazijapatikana kwa wanunuzi.');
  String get category => _t('Category', 'Aina');
  String get submitForReviewLower =>
      _t('Submit for review', 'Tuma kwa ukaguzi');

  // Supplier reviews ------------------------------------------------------
  String ratingSummary(String average, int count) => _t(
      '$average of 5 from $count buyer ratings',
      '$average kati ya 5 kutoka tathmini $count za wanunuzi');
  String get noRatingsYetDelivery => _t(
      'No ratings yet. Buyers rate orders after delivery.',
      'Bado hakuna tathmini. Wanunuzi hutathmini maagizo baada ya kufikishwa.');
  String ratingsSoFar(int count, int needed) => _t(
      '$count rating${count == 1 ? '' : 's'} so far; your average shows after $needed more',
      'Tathmini $count hadi sasa; wastani wako utaonekana baada ya $needed zaidi');
  String get aboutRatingsBody => _t(
      'Buyers rate an order after it is delivered. They see your average once you have 3 ratings, together with your deliveries and how much of your supply passed Omoterra’s quality check.\n\n'
          'Buyers never see comments, and you never see who wrote them.',
      'Wanunuzi hutathmini agizo baada ya kufikishwa. Wanaona wastani wako ukishapata tathmini 3, pamoja na idadi ya ulizofikisha na kiasi cha bidhaa zako kilichopita ukaguzi wa ubora wa Omoterra.\n\n'
          'Wanunuzi hawaoni maoni, na wewe huoni aliyeyaandika.');
  String get buyerRatingsTitle => _t('Buyer ratings', 'Tathmini za wanunuzi');
  String get aboutYourRatings =>
      _t('About your ratings', 'Kuhusu tathmini zako');
  String get whatBuyersSaid => _t('What buyers said', 'Wanunuzi walisema nini');
  String get noRatingsYet => _t('No ratings yet', 'Bado hakuna tathmini');
  String get noRatingsYetBody => _t(
      'After Omoterra delivers your supply, buyers can rate the order.',
      'Omoterra ikishafikisha bidhaa zako, wanunuzi wanaweza kutathmini agizo.');

  // Stock media -----------------------------------------------------------
  String get removeThisPhoto => _t('Remove this photo', 'Ondoa picha hii');
  String get photoUploadFailed => _t(
      'We could not upload this photo. Check gallery permission and your connection, then retry.',
      'Hatukuweza kupakia picha hii. Angalia ruhusa ya picha na mtandao wako, kisha ujaribu tena.');
  String get mediaSavedForReview => _t(
      'Saved — Omoterra will review the new photos and video before buyers see this stock again.',
      'Imehifadhiwa — Omoterra itakagua picha na video mpya kabla wanunuzi hawajaona bidhaa hii tena.');
  String get mediaSaved =>
      _t('Photos and video saved.', 'Picha na video zimehifadhiwa.');
  String get showSupplyClearly => _t(
      'Show the supply clearly. Avoid people, phone numbers and signs.',
      'Onyesha bidhaa waziwazi. Epuka watu, namba za simu na mabango.');
  String get noPhotosYet => _t('No photos yet', 'Bado hakuna picha');
  String photoCount(int n) =>
      _t('$n ${n == 1 ? 'photo' : 'photos'}', 'Picha $n');
  String get addPhoto => _t('Add photo', 'Ongeza picha');
  String get addAnotherPhoto =>
      _t('Add another photo', 'Ongeza picha nyingine');
  String get video => _t('Video', 'Video');
  String get optionalBadge => _t('Optional', 'Si lazima');
  String get addShortClip =>
      _t('Add a short clip of the supply.', 'Ongeza video fupi ya bidhaa.');
  String get savingSendsBack => _t(
      'Saving sends this stock back to Omoterra review. Buyers won’t see it until it is approved again.',
      'Kuhifadhi kunarudisha bidhaa hii kwa ukaguzi wa Omoterra. Wanunuzi hawataiona hadi iidhinishwe tena.');
  String get saving => _t('Saving…', 'Inahifadhi…');
  String get saveChanges => _t('Save changes', 'Hifadhi mabadiliko');

  // Market demand ---------------------------------------------------------
  String get dateTbc => _t('Date to be confirmed', 'Tarehe itathibitishwa');
  String repeats(String frequency) =>
      _t('Repeats $frequency', 'Inajirudia ${frequency.toLowerCase()}');
  String neededByDate(String date) =>
      _t('Needed by $date', 'Inahitajika kufikia $date');
  String get recurringSuffix => _t(' · recurring', ' · inajirudia');
  String get locationTbc =>
      _t('Location to be confirmed', 'Eneo litathibitishwa');
  String get weightTbc => _t('Weight to be confirmed', 'Uzito utathibitishwa');
  String get searchDemand => _t('Search demand', 'Tafuta mahitaji');
  String get searchProductOrLocation =>
      _t('Search product or location', 'Tafuta bidhaa au eneo');
  String get cows => _t('Cows', "Ng'ombe");
  String get noDemandTitle =>
      _t('No demand here yet', 'Bado hakuna mahitaji hapa');
  String get noDemandBody => _t(
      'Try another category or location. You can still register your stock while we find suitable demand.',
      'Jaribu aina au eneo jingine. Bado unaweza kusajili bidhaa zako tunapotafuta mahitaji yanayofaa.');
  String matchedOf(String total) =>
      _t(' / $total matched', ' / $total zimepatikana');
  String matchedSemantics(String matched, String total) =>
      _t('$matched of $total matched', '$matched kati ya $total zimepatikana');
  String get backToDemand => _t('Back to demand', 'Rudi kwenye mahitaji');
  String get recurring => _t('Recurring', 'Inajirudia');
  String get recurringDemand =>
      _t('Recurring demand', 'Mahitaji yanayojirudia');
  String get oneTimeDemand => _t('One-time demand', 'Mahitaji ya mara moja');
  String currentCycle(String date) => _t('Current cycle · needed by $date',
      'Mzunguko wa sasa · inahitajika kufikia $date');
  String get readyDateRange => _t(
      'Choose a ready date between today and the demand deadline.',
      'Chagua tarehe ya kuwa tayari kati ya leo na mwisho wa mahitaji.');
  String get supplyThisDemand =>
      _t('Supply This Demand', 'Toa Bidhaa kwa Mahitaji Haya');
  String get aboutOffers => _t('About offers', 'Kuhusu ofa');
  String get aboutOffersBody => _t(
      'Omoterra reviews every offer before anything is agreed. Your stock is reserved only after Omoterra confirms it.',
      'Omoterra hukagua kila ofa kabla ya makubaliano yoyote. Bidhaa zako huhifadhiwa tu baada ya Omoterra kuthibitisha.');
  String offerCycleNote(String date) => _t(
      'This demand repeats. Your offer covers the current cycle only (needed by $date); later cycles are offered separately.',
      'Mahitaji haya yanajirudia. Ofa yako inahusu mzunguko wa sasa tu (inahitajika kufikia $date); mizunguko ijayo hutolewa ofa kando.');
  String get noBatchInTime => _t(
      'No batch ready in time', 'Hakuna kundi litakalokuwa tayari kwa wakati');
  String get registerBatchFirst => _t(
      'Register a production batch first', 'Sajili kundi la uzalishaji kwanza');
  String noneReadyBy(String category, String date) => _t(
      'None of your $category batches has stock ready by $date.',
      'Hakuna kundi lako la $category lenye bidhaa tayari kufikia $date.');
  String get offersFromStock => _t('Offers must come from your recorded stock.',
      'Ofa lazima zitoke kwenye bidhaa ulizorekodi.');
  String get registerProductionBatch =>
      _t('Register production batch', 'Sajili kundi la uzalishaji');
  String get offerReceived =>
      _t('Supply offer received', 'Ofa yako imepokelewa');
  String get offerReceivedBody => _t(
      'Omoterra will review your offer and contact you before any stock is reserved.',
      'Omoterra itakagua ofa yako na kuwasiliana nawe kabla bidhaa yoyote haijahifadhiwa.');
  String get demandFullyMatched =>
      _t('Demand fully matched', 'Mahitaji yamekamilika');
  String get demandFullyMatchedBody => _t(
      'Explore other demand to find your next opportunity.',
      'Angalia mahitaji mengine kupata fursa yako inayofuata.');
  String get productionBatch => _t('Production batch', 'Kundi la uzalishaji');
  String batchNo(String id) => _t('Batch #$id', 'Kundi #$id');
  String get quantityToSupply => _t('Quantity to supply', 'Kiasi cha kutoa');
  String get enterQuantity => _t('Enter a quantity', 'Weka kiasi');
  String onlyStillNeeded(String qty) =>
      _t('Only $qty still needed', 'Zinahitajika $qty tu');
  String batchHasAvailable(String qty) => _t(
      'This batch has $qty available', 'Kundi hili lina $qty zinazopatikana');
  String get expectedReady => _t('Expected ready', 'Tarehe ya kuwa tayari');
  String get averageWeightLabel => _t('Average weight', 'Uzito wa wastani');
  String get enterValidWeight =>
      _t('Enter a valid weight', 'Weka uzito sahihi');
  String get askingPriceOptional =>
      _t('Asking price (optional)', 'Bei unayoomba (si lazima)');
  String tzsPer(String unit) => _t('TZS per $unit', 'TZS kwa kila $unit');
  String get unitWord => _t('unit', 'kimoja');
  String get enterValidPrice => _t('Enter a valid price', 'Weka bei sahihi');
  String get submitOffer => _t('Submit offer', 'Tuma ofa');

  // Production batches ----------------------------------------------------
  String get registerBatchTitle => _t('Register Batch', 'Sajili Kundi');
  String stepOf(int step, int steps) =>
      _t('$step of $steps', '$step kati ya $steps');
  String get batchStepRaising => _t('What you’re raising', 'Unachofuga');
  String get batchStepReady =>
      _t('Ready date & price', 'Tarehe ya kuwa tayari na bei');
  String get batchStepPickup => _t('Pickup & photos', 'Uchukuaji na picha');
  String get enterNumberAboveZero =>
      _t('Enter a number above 0', 'Weka namba kubwa kuliko 0');
  String get fieldRequired =>
      _t('This field is required', 'Sehemu hii ni lazima');
  String countedIn(String units) =>
      _t('Counted in $units', 'Huhesabiwa kwa $units');
  String get breedTypeOptional =>
      _t('Breed / type (optional)', 'Aina / kizazi (si lazima)');
  String get breedHint =>
      _t('e.g. Ross 308, Kuroiler, Boer', 'mfano Ross 308, Kuroiler, Boer');
  String get batchQuantity => _t('Batch quantity', 'Idadi ya kundi');
  String get useWholeNumber => _t('Use a whole number', 'Tumia namba kamili');
  String get ageOptional => _t('Age (optional)', 'Umri (si lazima)');
  String get enterZeroOrMore => _t('Enter 0 or more', 'Weka 0 au zaidi');
  String get ageIn => _t('Age in', 'Umri kwa');
  String get suppliedAs => _t('Supplied as', 'Inauzwa ikiwa');
  String get weightRangeKg => _t('Weight range (kg)', 'Kiwango cha uzito (kg)');
  String get min => _t('Min', 'Chini');
  String get max => _t('Max', 'Juu');
  String get maxAtLeastMin =>
      _t('Max must be at least Min', 'Juu lazima iwe angalau sawa na Chini');
  String get pickupLocation => _t('Pickup location', 'Mahali pa kuchukua');
  String get pickupHint => _t('Village, landmarks, directions for collection',
      'Kijiji, alama za eneo, maelekezo ya kufika kuchukua');
  String get onlyOmoterraSeesPickup => _t(
      'Only Omoterra sees the pickup location.',
      'Omoterra pekee ndiyo huona mahali pa kuchukua.');
  String get batchPhotos => _t('Batch photos', 'Picha za kundi');
  String get batchPhotosHint => _t('Optional · helps Omoterra review faster',
      'Si lazima · husaidia Omoterra kukagua haraka');
  String get batchRegistered => _t('Batch registered for Omoterra review.',
      'Kundi limesajiliwa kwa ukaguzi wa Omoterra.');
  String get registerBatch => _t('Register batch', 'Sajili kundi');
  String nextStep(String title) => _t('Next: $title', 'Ifuatayo: $title');
  String get batchesOfferedNote => _t(
      'Registered batches can be offered to buyer demand once Omoterra reviews them.',
      'Makundi yaliyosajiliwa yanaweza kutolewa kwa mahitaji ya wanunuzi baada ya Omoterra kuyakagua.');
  String get pickupDetailsFirst =>
      _t('Your pickup details first', 'Kwanza taarifa za mahali pa kuchukua');
  String get privatePickupAddress =>
      _t('Private pickup address', 'Mahali binafsi pa kuchukua');
  String get saveAndContinue => _t('Save and continue', 'Hifadhi na uendelee');
  String get noBatches => _t('No production batches registered.',
      'Hakuna makundi ya uzalishaji yaliyosajiliwa.');
  String get growing => _t('Growing', 'Yanakua');
  String get ready => _t('Ready', 'Tayari');
  String get completed => _t('Completed', 'Yamekamilika');
  String batchAgeReady(String age, String unit, String date) =>
      _t('Age $age $unit · Ready $date', 'Umri $age $unit · Tayari $date');
  String expectedWeight(String min, String max) =>
      _t('Expected weight $min–$max kg', 'Uzito unaotarajiwa $min–$max kg');
  String reservedAvailableToCommit(String reserved, String available) => _t(
      '$reserved reserved · $available available to commit',
      '$reserved zimehifadhiwa · $available zinaweza kutolewa');
  String externallySold(String n) =>
      _t('$n externally sold', '$n zimeuzwa nje');
  String get recordExternalSale =>
      _t('Record external sale', 'Rekodi mauzo ya nje');
  String get quantitySoldOutside =>
      _t('Quantity sold outside Omoterra', 'Kiasi kilichouzwa nje ya Omoterra');
  String get noteOptional => _t('Note (optional)', 'Maelezo (si lazima)');
  String get confirmExternalSale =>
      _t('Confirm external sale', 'Thibitisha mauzo ya nje');
  String get awaitingReview =>
      _t('Awaiting Omoterra review', 'Inasubiri ukaguzi wa Omoterra');

  // Role registration -----------------------------------------------------
  String get unknownRole => _t('Unknown role', 'Jukumu lisilojulikana');
  String get registerAsBuyer =>
      _t('Register as a buyer', 'Jisajili kama mnunuzi');
  String get completeBuyerRegistration =>
      _t('Complete buyer registration', 'Kamilisha usajili wa mnunuzi');
  String get chooseBuyerProfile => _t(
      'Choose the buyer profile that fits how you purchase.',
      'Chagua aina ya mnunuzi inayoendana na jinsi unavyonunua.');
  String get buyerType => _t('Buyer type', 'Aina ya mnunuzi');
  String get completeRegistration =>
      _t('Complete registration', 'Kamilisha usajili');
  String get enterTzMobile => _t(
      'Enter a Tanzanian mobile number, e.g. 0712 345 678',
      'Weka namba ya simu ya Tanzania, mfano 0712 345 678');
  String get stepSupplierIdentity =>
      _t('Supplier identity', 'Utambulisho wa msambazaji');
  String get stepWhatYouSupply => _t('What you supply', 'Unachosambaza');
  String get stepPickupOperations =>
      _t('Pickup & operations', 'Uchukuaji na shughuli');
  String get stepCurrentProduction =>
      _t('Current production', 'Uzalishaji wa sasa');
  String get stepPhotos => _t('Photos', 'Picha');
  String get stepReview => _t('Review', 'Kagua');
  String get productCategory => _t('Product category', 'Aina ya bidhaa');
  String currentQuantityIn(String unit) =>
      _t('Current quantity ($unit)', 'Idadi ya sasa ($unit)');
  String get currentAgeOptional =>
      _t('Current age (optional)', 'Umri wa sasa (si lazima)');
  String get ageUnit => _t('Age unit', 'Kipimo cha umri');
  String get expectedMinWeight =>
      _t('Expected minimum weight (kg)', 'Uzito wa chini unaotarajiwa (kg)');
  String get expectedMaxWeight =>
      _t('Expected maximum weight (kg)', 'Uzito wa juu unaotarajiwa (kg)');
  String get expectedReadyCollectionDate => _t(
      'Expected ready / collection date',
      'Tarehe ya kuwa tayari / kuchukuliwa');
  String get supplyForm => _t('Supply form', 'Hali ya bidhaa');
  String askingPricePerTzs(String unit) =>
      _t('Asking price per $unit (TZS)', 'Bei unayoomba kwa kila $unit (TZS)');
  String get farmSupplierName =>
      _t('Farm / supplier name', 'Jina la shamba / msambazaji');
  String get legalFullName => _t('Legal / full name', 'Jina rasmi / kamili');
  String get suppliersMobile =>
      _t("Supplier's mobile number", 'Namba ya simu ya msambazaji');
  String get primaryPhone => _t('Primary phone', 'Simu kuu');
  String get alternatePhoneOptional =>
      _t('Alternate phone (optional)', 'Simu mbadala (si lazima)');
  String get district => _t('District', 'Wilaya');
  String get generalAreaOptional =>
      _t('General area (optional)', 'Eneo kwa ujumla (si lazima)');
  String get chooseProductsYouSupply => _t(
      'Choose the products you normally supply.',
      'Chagua bidhaa unazosambaza kwa kawaida.');
  String get mainCategory => _t('Main category', 'Aina kuu');
  String typicalCapacity(String category) => _t(
      '$category typical capacity (optional)',
      'Uwezo wa kawaida wa $category (si lazima)');
  String perCycle(String unit) => _t('$unit / cycle', '$unit / mzunguko');
  String get usualCycle => _t('Usual production cycle (optional)',
      'Mzunguko wa kawaida wa uzalishaji (si lazima)');
  String get cycleHint => _t('e.g. every 6 weeks', 'mfano kila wiki 6');
  String get pickupDirectionsPrivate => _t(
      'Pickup directions / landmarks (private)',
      'Maelekezo / alama za mahali pa kuchukua (siri)');
  String get pickupInstructionsOptional =>
      _t('Pickup instructions (optional)', 'Maelekezo ya kuchukua (si lazima)');
  String get omoterraCanCollect => _t('Omoterra can collect from this location',
      'Omoterra inaweza kuchukua kutoka eneo hili');
  String get supplierCanTransport => _t(
      'Supplier can arrange transport', 'Msambazaji anaweza kupanga usafiri');
  String get preferredContact =>
      _t('Preferred contact', 'Njia ya mawasiliano unayopendelea');
  String get operatingNotesOptional => _t(
      'Operating schedule or notes (optional)',
      'Ratiba ya kazi au maelezo (si lazima)');
  String get haveProductionQ => _t(
      'Do you have livestock or stock currently in production?',
      'Je, una mifugo au bidhaa zinazozalishwa sasa hivi?');
  String get yesAddCurrentBatch =>
      _t('Yes, add the current batch', 'Ndiyo, ongeza kundi la sasa');
  String get noCurrentBatch => _t('No current batch', 'Hakuna kundi la sasa');
  String get nextPlannedProduction =>
      _t('Next planned production', 'Uzalishaji unaofuata uliopangwa');
  String get addPlannedBatch =>
      _t('Add a planned batch too', 'Ongeza pia kundi lililopangwa');
  String get addFarmPhotosIntro => _t(
      'Add farm and location photos for Omoterra staff to review.',
      'Ongeza picha za shamba na eneo ili wafanyakazi wa Omoterra wazikague.');
  String get farmLocationPhotos =>
      _t('Farm / location photos', 'Picha za shamba / eneo');
  String get privateStaffNotes => _t('Private staff notes (optional)',
      'Maelezo ya siri ya mfanyakazi (si lazima)');
  String get farmSupplier => _t('Farm / supplier', 'Shamba / msambazaji');
  String get contact => _t('Contact', 'Mawasiliano');
  String get location => _t('Location', 'Eneo');
  String get supplyCategories => _t('Supply categories', 'Aina za bidhaa');
  String get typicalCycle => _t('Typical cycle', 'Mzunguko wa kawaida');
  String get notProvided => _t('Not provided', 'Haijatolewa');
  String get farmLocation => _t('Farm location', 'Eneo la shamba');
  String get pickup => _t('Pickup', 'Uchukuaji');
  String get omoterraCollection =>
      _t('Omoterra collection', 'Uchukuaji wa Omoterra');
  String get notAvailable => _t('Not available', 'Haipatikani');
  String quantityReady(String qty, String unit, String date) =>
      _t('$qty $unit · ready $date', '$qty $unit · tayari $date');
  String get registrationReviewNote => _t(
      'Registration will be reviewed by Omoterra before supply is shown to buyers.',
      'Usajili utakaguliwa na Omoterra kabla bidhaa hazijaonyeshwa kwa wanunuzi.');
  String get chooseOneCategory => _t('Choose at least one supply category.',
      'Chagua angalau aina moja ya bidhaa.');
  String get capacityNotNegative => _t(
      'Production capacity cannot be negative.',
      'Uwezo wa uzalishaji hauwezi kuwa hasi.');
  String get addFarmLocation => _t(
      'Add the farm location: paste a Google Maps link or pick it on the map.',
      'Ongeza eneo la shamba: bandika kiungo cha Google Maps au lichague kwenye ramani.');
  String get chooseOneForm => _t('Choose at least one supply form.',
      'Chagua angalau hali moja ya bidhaa.');
  String get quantityAboveZeroEach => _t(
      'Enter a quantity greater than zero for each batch.',
      'Weka kiasi kikubwa kuliko sifuri kwa kila kundi.');
  String get maxWeightAtLeastMin => _t(
      'Expected maximum weight must be at least the minimum.',
      'Uzito wa juu unaotarajiwa lazima uwe angalau sawa na wa chini.');
  String get chooseReadyDate => _t('Choose an expected ready date.',
      'Chagua tarehe inayotarajiwa kuwa tayari.');
  String get priceAboveZero => _t('Enter an asking price greater than zero.',
      'Weka bei unayoomba iliyo kubwa kuliko sifuri.');
  String stepNOf(int step, int steps) =>
      _t('Step $step of $steps', 'Hatua $step kati ya $steps');
  String get submitting => _t('Submitting…', 'Inatuma…');
  String get submitRegistration => _t('Submit registration', 'Tuma usajili');

  // Account ---------------------------------------------------------------
  String get switchRoleFailed => _t('Could not switch role. Please try again.',
      'Imeshindikana kubadilisha jukumu. Tafadhali jaribu tena.');
  String get retryLoadingAccount =>
      _t('Retry loading account', 'Jaribu tena kupakia akaunti');
  String get yourAccount => _t('Your account', 'Akaunti yako');
  String get yourCapabilities => _t('Your capabilities', 'Majukumu yako');
  String get deliveryLocation => _t('Delivery location', 'Mahali pa kupokea');
  String get profileAndLanguage => _t('Profile & language', 'Wasifu na lugha');
  String get omoterraStaff => _t('Omoterra staff', 'Wafanyakazi wa Omoterra');
  String get yourName => _t('Your name', 'Jina lako');
  String get saveProfile => _t('Save profile', 'Hifadhi wasifu');
  String get deleteMyAccount => _t('Delete my account', 'Futa akaunti yangu');
  String get deleteMyAccountBody => _t(
      'Permanently removes your account and personal details.',
      'Inaondoa kabisa akaunti yako na taarifa zako binafsi.');
  String get deliveryAddressTitle =>
      _t('Delivery address', 'Anwani ya kupokea');
  String get addressLabel => _t('Address label', 'Jina la anwani');
  String get recipientName => _t('Recipient name', 'Jina la mpokeaji');
  String get deliveryPhone =>
      _t('Delivery phone (+255…)', 'Simu ya mpokeaji (+255…)');
  String get districtArea => _t('District / area', 'Wilaya / eneo');
  String get deliveryDirections =>
      _t('Delivery directions', 'Maelekezo ya kufikisha');
  String get saveAddress => _t('Save address', 'Hifadhi anwani');
  String get defaultLabel => _t('Default', 'Chaguo-msingi');
  String get makeDefault => _t('Make default', 'Fanya chaguo-msingi');
  String get addAddress => _t('Add address', 'Ongeza anwani');
  String get termsOfService => _t('Terms of service', 'Masharti ya huduma');
  String get privacyNotice => _t('Privacy notice', 'Taarifa ya faragha');
  String get myAccountTopic => _t('my account', 'akaunti yangu');
  String get openSourceLicenses =>
      _t('Open-source licenses', 'Leseni za programu huria');
  String get supportIntro => _t(
      'For help with supply, payment or delivery, contact the Omoterra team. Keep your order reference ready.',
      'Kwa msaada kuhusu bidhaa, malipo au ufikishaji, wasiliana na timu ya Omoterra. Kuwa na namba ya agizo lako tayari.');
  String get supportFallback => _t(
      'Use the Omoterra contact provided with your supply arrangement.',
      'Tumia mawasiliano ya Omoterra uliyopewa pamoja na makubaliano yako ya bidhaa.');
  String contactForTerms(bool terms) => _t(
      'Please contact Omoterra for the current ${terms ? 'terms of service' : 'privacy notice'} before placing an order.',
      'Tafadhali wasiliana na Omoterra upate ${terms ? 'masharti ya huduma' : 'taarifa ya faragha'} ya sasa kabla ya kuagiza.');

  // Delete account --------------------------------------------------------
  String get deleteAccount => _t('Delete account', 'Futa akaunti');
  String get deletePermanently => _t('This permanently deletes your account',
      'Hii inafuta akaunti yako kabisa');
  String get deletePointPersonal => _t(
      'Your name, phone number and saved addresses are removed.',
      'Jina lako, namba ya simu na anwani zilizohifadhiwa zinaondolewa.');
  String get deletePointSupplier => _t(
      'A supplier profile, farm location, photos and video are removed and your stock is taken down.',
      'Wasifu wa msambazaji, eneo la shamba, picha na video zinaondolewa na bidhaa zako zinaondolewa sokoni.');
  String get deletePointRecords => _t(
      'Past orders and payouts stay on record for Omoterra’s accounts, but are no longer linked to your name.',
      'Maagizo na malipo ya zamani yanabaki kwenye kumbukumbu za hesabu za Omoterra, lakini hayahusishwi tena na jina lako.');
  String get cannotBeUndone =>
      _t('This can’t be undone.', 'Hili haliwezi kutenduliwa.');
  String get deleteBlockedNote => _t(
      'If you have an order in progress, an unpaid payout, or stock reserved for a buyer, finish or settle it first — deletion is blocked until then.',
      'Kama una agizo linaloendelea, malipo ambayo hayajalipwa, au bidhaa zilizohifadhiwa kwa mnunuzi, likamilishe kwanza — kufuta kumezuiwa hadi hapo.');

  /// The word typed to confirm deleting an account.
  String get deleteWord => _t('DELETE', 'FUTA');
  String typeToConfirm(String word) =>
      _t('Type $word to confirm', 'Andika $word kuthibitisha');

  // Farm location screen --------------------------------------------------
  String get registerSupplierFirst =>
      _t('Register as a supplier first', 'Jisajili kama msambazaji kwanza');
  String get farmLocationPartOfRegistration => _t(
      'Your farm location is part of supplier registration.',
      'Eneo la shamba lako ni sehemu ya usajili wa msambazaji.');
  String get addFarmLocationFull => _t(
      'Add the farm location: use your current location, pick it on the map or paste a Google Maps link.',
      'Ongeza eneo la shamba: tumia eneo ulipo sasa, lichague kwenye ramani au bandika kiungo cha Google Maps.');
  String get farmLocationSaved =>
      _t('Farm location saved.', 'Eneo la shamba limehifadhiwa.');
  String get farmLocationIntro => _t(
      'Where Omoterra collects your supply. Only Omoterra sees this, never buyers.',
      'Mahali Omoterra inapochukua bidhaa zako. Omoterra pekee huona hapa, si wanunuzi.');
  String get pickupDirections =>
      _t('Pickup directions', 'Maelekezo ya kuchukua');
  String get pickupDirectionsHint => _t(
      'Village, landmarks, how to reach the farm',
      'Kijiji, alama za eneo, jinsi ya kufika shambani');
  String get addDirections =>
      _t('Add directions for collection', 'Ongeza maelekezo ya kuchukua');
  String get movingPinNote => _t(
      'Moving the pin asks Omoterra to re-check the location. Your supplier approval stays.',
      'Kuhamisha alama kunaiomba Omoterra ikague eneo upya. Idhini yako ya msambazaji inabaki.');
  String get saveFarmLocation =>
      _t('Save farm location', 'Hifadhi eneo la shamba');

  // Notifications inbox ---------------------------------------------------
  String get notifications => _t('Notifications', 'Arifa');
  String get markAllRead => _t('Mark all read', 'Weka zote kama zimesomwa');
  String get noNotificationsTitle =>
      _t('No notifications yet', 'Bado hakuna arifa');
  String get noNotificationsBody => _t(
      'Updates about your orders, stock and payouts will appear here.',
      'Taarifa kuhusu maagizo, bidhaa na malipo yako zitaonekana hapa.');
  String get justNow => _t('Just now', 'Sasa hivi');
  String minutesAgo(int n) => _t('$n min ago', 'dakika $n zilizopita');
  String hoursAgo(int n) => _t('$n h ago', 'saa $n zilizopita');
  String notificationsUnread(int n) =>
      _t('Notifications, $n unread', 'Arifa, $n hazijasomwa');

  // Staff (admin) ---------------------------------------------------------
  String get enterYourCode => _t('Enter your code', 'Weka msimbo wako');
  String get staffSignIn => _t('Staff sign-in', 'Kuingia kwa wafanyakazi');
  String sentCodeTo(String phone) =>
      _t('We sent a code to $phone.', 'Tumetuma msimbo kwenda $phone.');
  String get staffSignInIntro => _t(
      'For Omoterra staff registering buyers and suppliers.',
      'Kwa wafanyakazi wa Omoterra wanaosajili wanunuzi na wasambazaji.');
  String get staffPassphrase =>
      _t('Staff passphrase', 'Nenosiri la wafanyakazi');
  String get showPassphrase => _t('Show passphrase', 'Onyesha nenosiri');
  String get hidePassphrase => _t('Hide passphrase', 'Ficha nenosiri');
  String get enterStaffPassphrase =>
      _t('Enter the staff passphrase', 'Weka nenosiri la wafanyakazi');
  String get staffPhone =>
      _t('Your staff phone number', 'Namba yako ya simu ya kazi');
  String get enterTzMobileShort =>
      _t('Enter a Tanzanian mobile number', 'Weka namba ya simu ya Tanzania');
  String get codeLabel => _t('Code', 'Msimbo');
  String get enterSmsCode => _t('Enter the code from the text message',
      'Weka msimbo kutoka kwenye ujumbe mfupi');
  String developmentCode(String code) =>
      _t('Development code: $code', 'Msimbo wa majaribio: $code');
  String get useDifferentNumber =>
      _t('Use a different number', 'Tumia namba nyingine');
  String get signIn => _t('Sign in', 'Ingia');
  String get sendCode => _t('Send code', 'Tuma msimbo');
  String get staffSignInOff => _t(
      'Staff sign-in isn’t switched on yet. An Omoterra admin must set the staff passphrase on the API and restart it.',
      'Kuingia kwa wafanyakazi bado hakujawashwa. Msimamizi wa Omoterra lazima aweke nenosiri la wafanyakazi kwenye API na kuiwasha upya.');
  String get signOut => _t('Sign out', 'Toka');
  String hello(String name) => _t('Hello, $name', 'Habari, $name');
  String get staffWord => _t('staff', 'mfanyakazi');
  String get registerSomeone =>
      _t('Register someone on Omoterra.', 'Sajili mtu kwenye Omoterra.');
  String myRegistrations(int? n) => _t(
      'My registrations${n == null ? '' : ' ($n)'}',
      'Usajili wangu${n == null ? '' : ' ($n)'}');
  String get nobodyRegistered =>
      _t('Nobody registered yet.', 'Bado hujasajili mtu yeyote.');
  String get nobodyRegisteredBody => _t(
      'Buyers and suppliers you register appear here.',
      'Wanunuzi na wasambazaji unaowasajili wataonekana hapa.');
  String get register => _t('Register', 'Sajili');
  String roleRegistered(String role) => _t(
      '$role registered. They can sign in with their own phone number.',
      '$role amesajiliwa. Anaweza kuingia kwa namba yake ya simu.');

  // Staff: register buyer -------------------------------------------------
  String get whoTheyAre => _t('Who they are', 'Wao ni nani');
  String get whereTheyAre => _t('Where they are', 'Wako wapi');
  String get howTheyBuy => _t('How they buy', 'Wanavyonunua');
  String get businessName => _t('Business name', 'Jina la biashara');
  String get businessNameHint =>
      _t('e.g. Asha Grill House', 'mfano Asha Grill House');
  String get enterBusinessName =>
      _t('Enter the business name', 'Weka jina la biashara');
  String get contactPerson => _t('Contact person', 'Mtu wa kuwasiliana naye');
  String get enterTheirName => _t('Enter their name', 'Weka jina lake');
  String get theirMobile => _t('Their mobile number', 'Namba yake ya simu');
  String get area => _t('Area', 'Eneo');
  String get areaOptional => _t('Area (optional)', 'Eneo (si lazima)');
  String get townOrDistrict => _t('Town or district', 'Mji au wilaya');
  String get pickupOrDelivery =>
      _t('Pickup or delivery', 'Kuchukua au kuletewa');
  String get noPreference => _t('No preference', 'Hakuna upendeleo');
  String get delivery => _t('Delivery', 'Kuletewa');
  String get theyCollect => _t('They collect', 'Wanachukua wenyewe');
  String get either => _t('Either', 'Vyovyote');
  String get productsTheyBuy => _t('Products they buy', 'Bidhaa wanazonunua');
  String get liveOrDressed => _t('Live or dressed', 'Hai au iliyochinjwa');
  String get typicalQuantityOptional => _t(
      'Typical quantity per order (optional)',
      'Kiasi cha kawaida kwa agizo (si lazima)');
  String get minWeight => _t('Min weight', 'Uzito wa chini');
  String get maxWeight => _t('Max weight', 'Uzito wa juu');
  String get howOftenTheyBuy => _t('How often they buy', 'Wanunua mara ngapi');
  String get notKnown => _t('Not known', 'Haijulikani');
  String get everyTwoWeeks => _t('Every two weeks', 'Kila wiki mbili');
  String get occasionally => _t('Occasionally', 'Mara kwa mara');
  String get preferredDays => _t('Preferred days', 'Siku wanazopendelea');
  String get lastBuyingPrice => _t('Last known buying price (optional)',
      'Bei ya mwisho waliyonunulia (si lazima)');
  String get tzsPerUnit => _t('TZS / unit', 'TZS / kimoja');
  String get minimumOrderOptional =>
      _t('Minimum order (optional)', 'Agizo la chini (si lazima)');
  String get paymentTermsOptional =>
      _t('Payment terms (optional)', 'Masharti ya malipo (si lazima)');
  String get paymentTermsHint =>
      _t('e.g. cash on delivery', 'mfano pesa taslimu wakati wa kupokea');
  String get registerBuyerTitle => _t('Register buyer', 'Sajili mnunuzi');
  String get registering => _t('Registering…', 'Inasajili…');
  String get finishRegistration => _t('Finish registration', 'Maliza usajili');

  // Farm location widget --------------------------------------------------
  String get pasteMapsLinkError => _t(
      'Paste the link from Google Maps (Share → Copy link), or pick the farm on the map.',
      'Bandika kiungo kutoka Google Maps (Shiriki → Nakili kiungo), au chagua shamba kwenye ramani.');
  String get linkNoLocation => _t(
      'We couldn’t read a location from this link. Drop a pin in Google Maps and share that, or pick the farm on the map.',
      'Hatukuweza kusoma eneo kutoka kiungo hiki. Weka alama kwenye Google Maps na uishiriki, au chagua shamba kwenye ramani.');
  String get linkOpenFailed => _t(
      'We couldn’t open this link. Check your connection, or pick the farm on the map.',
      'Hatukuweza kufungua kiungo hiki. Angalia mtandao wako, au chagua shamba kwenye ramani.');
  String get farmOnMap =>
      _t('Farm location on the map', 'Eneo la shamba kwenye ramani');
  String get farmOnMapBody => _t(
      'So Omoterra can find the exact farm. Only Omoterra staff see this.',
      'Ili Omoterra ipate shamba hasa. Wafanyakazi wa Omoterra pekee ndio huona hii.');
  String get pasteMapsLink =>
      _t('Paste Google Maps link', 'Bandika kiungo cha Google Maps');
  String get useThisLink => _t('Use this link', 'Tumia kiungo hiki');
  String get or => _t('or', 'au');
  String get pickOnMap => _t('Pick on map', 'Chagua kwenye ramani');
  String get changeOnMap => _t('Change on map', 'Badilisha kwenye ramani');
  String get turnOnLocation => _t('Turn on location on your phone, then retry.',
      'Washa huduma ya eneo kwenye simu yako, kisha ujaribu tena.');
  String get allowLocation => _t(
      'Allow location access to use where you are now, or move the map to the farm.',
      'Ruhusu ufikiaji wa eneo kutumia ulipo sasa, au sogeza ramani hadi shambani.');
  String get locationFailed => _t(
      'We couldn’t get your location. Move the map to the farm instead.',
      'Hatukuweza kupata eneo lako. Badala yake sogeza ramani hadi shambani.');
  String get pickFarmLocation =>
      _t('Pick farm location', 'Chagua eneo la shamba');
  String get moveMapHint => _t(
      'Move the map until the pin sits on the farm, then confirm.',
      'Sogeza ramani hadi alama ikae juu ya shamba, kisha thibitisha.');
  String get useCurrentLocation =>
      _t('Use my current location', 'Tumia eneo nilipo sasa');
  String get confirmFarmLocation =>
      _t('Confirm farm location', 'Thibitisha eneo la shamba');

  // Stock video -----------------------------------------------------------
  String get recordVideo => _t('Record a video', 'Rekodi video');
  String get chooseFromGallery =>
      _t('Choose from gallery', 'Chagua kutoka kwenye picha');
  String get videoTooBig => _t(
      'Choose a video smaller than 60 MB — a clip under a minute is enough.',
      'Chagua video iliyo chini ya MB 60 — video fupi ya chini ya dakika moja inatosha.');
  String get videoUploadFailed => _t(
      'We could not upload this video. Check camera or gallery permission and your connection, then retry.',
      'Hatukuweza kupakia video hii. Angalia ruhusa ya kamera au picha na mtandao wako, kisha ujaribu tena.');
  String get videoOptional => _t('Video (optional)', 'Video (si lazima)');
  String get videoHint => _t(
      'A short clip of the animals or produce. Keep faces, phone numbers and signs out of it.',
      'Video fupi ya mifugo au mazao. Usionyeshe nyuso, namba za simu wala mabango.');
  String get removeVideo => _t('Remove video', 'Ondoa video');
  String uploadingVideo(int percent) =>
      _t('Uploading video… $percent%', 'Inapakia video… $percent%');
  String uploadPausedAt(int percent) =>
      _t('Upload paused at $percent%', 'Upakiaji umesimama kwenye $percent%');
  String get resumeUpload => _t('Resume upload', 'Endelea kupakia');
  String get chooseAnotherVideo =>
      _t('Choose another video', 'Chagua video nyingine');
  String get addVideo => _t('Add video', 'Ongeza video');
  String get replaceVideo => _t('Replace video', 'Badilisha video');
  String get watchVideo => _t('Watch video', 'Tazama video');
  String get videoGone =>
      _t('This video is no longer available.', 'Video hii haipatikani tena.');
  String get videoCantPlay => _t(
      'This video can’t play right now. Check your connection and retry.',
      'Video hii haiwezi kucheza sasa hivi. Angalia mtandao wako na ujaribu tena.');

  // Photos ----------------------------------------------------------------
  String get photoTooBig => _t(
      'Choose a photo smaller than 8 MB.', 'Chagua picha iliyo chini ya MB 8.');
  String removeThisQ(bool video) => _t(
      'Remove this ${video ? 'video' : 'photo'}?',
      'Ondoa ${video ? 'video' : 'picha'} hii?');
  String removeBody(bool video) => _t(
      'The ${video ? 'video' : 'photo'} will be deleted from Omoterra. You can’t undo this.',
      '${video ? 'Video' : 'Picha'} itafutwa kutoka Omoterra. Huwezi kutendua hili.');
  String removeWhat(bool video) => _t('Remove ${video ? 'video' : 'photo'}',
      'Ondoa ${video ? 'video' : 'picha'}');
  String get photoPickerHint => _t(
      'Use clear photos of the supply. Keep people, contact details and signs out of the image.',
      'Tumia picha zilizo wazi za bidhaa. Usionyeshe watu, mawasiliano wala mabango kwenye picha.');
  String photosSwipe(int n) =>
      _t('$n photo(s) · swipe to view', 'Picha $n · telezesha kuona');
  String get removeLastPhoto =>
      _t('Remove last photo', 'Ondoa picha ya mwisho');

  // Support contact -------------------------------------------------------
  String get couldNotOpenApp => _t(
      'Could not open that app. Try the other option.',
      'Imeshindikana kufungua programu hiyo. Jaribu chaguo lingine.');
  String supportMessage(String topic) => _t(
      'Hello Omoterra, I need help with $topic.',
      'Habari Omoterra, ninahitaji msaada kuhusu $topic.');
  String get needHelp => _t('Need help?', 'Unahitaji msaada?');
  String get talkToTeam => _t('Talk to the Omoterra team about this.',
      'Zungumza na timu ya Omoterra kuhusu hili.');
  String get call => _t('Call', 'Piga simu');

  // Ratings ---------------------------------------------------------------
  String get newSupplier => _t('New supplier', 'Msambazaji mpya');
  String get newLabel => _t('New', 'Mpya');
  String get awaiting => _t('Awaiting', 'Inasubiri');
  String nRatings(int n) => _t('$n ratings', 'tathmini $n');
  String get deliveries => _t('Deliveries', 'Zilizofikishwa');
  String get quality => _t('Quality', 'Ubora');
  String get ratingThanks => _t('Thank you. Your rating helps other buyers.',
      'Asante. Tathmini yako inasaidia wanunuzi wengine.');
  String starLabel(int stars) => switch (stars) {
        1 => _t('Poor', 'Mbaya'),
        2 => _t('Fair', 'Wastani'),
        3 => _t('Good', 'Nzuri'),
        4 => _t('Very good', 'Nzuri sana'),
        5 => _t('Excellent', 'Bora kabisa'),
        _ => '',
      };
  String get yourRating => _t('Your rating', 'Tathmini yako');
  String get howWasOrder => _t('How was this order?', 'Agizo hili lilikuwaje?');
  String get ratingPrivacy => _t(
      'Your rating builds the supplier’s reputation. Suppliers never see who rated them.',
      'Tathmini yako hujenga sifa ya msambazaji. Wasambazaji hawaoni nani aliyewatathmini.');
  String nStars(int n) => _t('$n star${n == 1 ? '' : 's'}', 'nyota $n');
  String get ratingCommentHint => _t(
      'What went well, or what could be better? (optional)',
      'Nini kilienda vizuri, au nini kingeboreshwa? (si lazima)');
  String get submitRating => _t('Submit rating', 'Tuma tathmini');
  String get updateRating => _t('Update rating', 'Badilisha tathmini');

  // Artwork descriptions (screen readers) ---------------------------------
  String illustration(String kind) => _t(
      '${kind.replaceAll('_', ' ')} illustration',
      'Mchoro wa ${label(kind).toLowerCase()}');
  String get farmSceneLabel => _t(
      'Chicken, goats and cattle from farms, coordinated by Omoterra',
      "Kuku, mbuzi na ng'ombe kutoka mashambani, kwa uratibu wa Omoterra");

  // Checkout, explore filters, listing ------------------------------------
  String get chooseDeliveryAddress =>
      _t('Choose a delivery address.', 'Chagua anwani ya kupokea.');
  String get pricePerUnit => _t('Price per unit', 'Bei kwa kimoja');
  String get estimatedTotal => _t('Estimated total', 'Jumla inayokadiriwa');
  String get reservationExpired => _t(
      'Reservation expired. Return to the listing to reserve again.',
      'Muda wa uhifadhi umeisha. Rudi kwenye bidhaa uhifadhi tena.');
  String stockHeldFor(String time) =>
      _t('Your stock is held for $time', 'Bidhaa zako zimehifadhiwa kwa $time');
  String get addDeliveryAddress =>
      _t('Add delivery address', 'Ongeza anwani ya kupokea');
  String get preferredDelivery =>
      _t('Preferred delivery', 'Tarehe unayopendelea kupokea');
  String get filterSupply => _t('Filter supply', 'Chuja bidhaa');
  String get maxPricePerUnit =>
      _t('Maximum price per unit', 'Bei ya juu kwa kimoja');
  String get readyBy => _t('Ready by', 'Tayari kufikia');
  String get minWeightKg => _t('Minimum weight (kg)', 'Uzito wa chini (kg)');
  String get maxWeightKg => _t('Maximum weight (kg)', 'Uzito wa juu (kg)');
  String get anyCondition => _t('Any condition', 'Hali yoyote');
  String get applyFilters => _t('Apply filters', 'Tumia vichujio');
  String get reservationExpiredReselect => _t(
      'Your reservation expired. Select your quantity again.',
      'Muda wa uhifadhi wako umeisha. Chagua kiasi tena.');
  String get supplyPartner =>
      _t('Omoterra supply partner', 'Mshirika wa bidhaa wa Omoterra');
  String get reservedFor15 => _t(
      'Stock reserved for 15 minutes.', 'Bidhaa zimehifadhiwa kwa dakika 15.');

  // Buyer orders ----------------------------------------------------------
  String requestNo(String id) => _t('Request #$id', 'Ombi #$id');
  String orderNo(String id) => _t('Order #$id', 'Agizo #$id');
  String get refreshOrder => _t('Refresh order', 'Onyesha upya agizo');
  String get supplyOnItsWay =>
      _t('Your supply, on its way', 'Bidhaa zako, ziko njiani');
  String get orderSummary => _t('Order summary', 'Muhtasari wa agizo');
  String get total => _t('Total', 'Jumla');
  String get deliveryHeader => _t('Delivery', 'Ufikishaji');
  String preferredDateIs(String date) =>
      _t('Preferred date: $date', 'Tarehe unayopendelea: $date');
  String get payment => _t('Payment', 'Malipo');
  String get method => _t('Method', 'Njia');
  String get statusWord => _t('Status', 'Hali');
  String orderTopic(String id) => _t('order #$id', 'agizo #$id');
  String get cancelOrderQ => _t('Cancel this order?', 'Ghairi agizo hili?');
  String get cancelOrderBody => _t(
      'Your reserved stock will be released. This is available before collection starts.',
      'Bidhaa ulizohifadhi zitaachiliwa. Hili linawezekana kabla uchukuaji haujaanza.');
  String get cancelOrder => _t('Cancel order', 'Ghairi agizo');
  String get activity => _t('Activity', 'Matukio');

  // Request supply form ---------------------------------------------------
  String get requestUpdated =>
      _t('Your request was updated.', 'Ombi lako limesasishwa.');
  String get enterNumberAboveZeroWord =>
      _t('Enter a number above zero', 'Weka namba kubwa kuliko sifuri');
  String get requestSupplyTitle => _t('Request Supply', 'Omba Bidhaa');
  String get updateYourRequest =>
      _t('Update your request.', 'Sasisha ombi lako.');
  String get addReferencePhoto => _t(
      'Add a reference photo (optional)', 'Ongeza picha ya mfano (si lazima)');
  String get changeReferencePhoto =>
      _t('Change reference photo', 'Badilisha picha ya mfano');
  String get referencePhotoHint => _t('Helps suppliers understand your needs.',
      'Inasaidia wasambazaji kuelewa mahitaji yako.');
  String get subtypeOptional =>
      _t('Subtype / breed (optional)', 'Aina ndogo / kizazi (si lazima)');
  String get subtypeHint =>
      _t('e.g. Cobb, Ross, Local', 'mfano Cobb, Ross, Kienyeji');
  String get sizeNotesOptional => _t('Weight or size notes (optional)',
      'Maelezo ya uzito au ukubwa (si lazima)');
  String get sizeNotesHint => _t('e.g. dressed weight, preferred size',
      'mfano uzito baada ya kuchinjwa, ukubwa unaopendelea');
  String get neededByLabel => _t('Needed by', 'Inahitajika kufikia');
  String get deliveryRegion => _t('Delivery region', 'Mkoa wa kufikisha');
  String get deliveryAreaLabel => _t('Delivery area', 'Eneo la kufikisha');
  String get enterArea => _t('Enter the area', 'Weka eneo');
  String get deliveryInstructionsOptional => _t(
      'Delivery instructions (optional)', 'Maelekezo ya kufikisha (si lazima)');
  String get deliveryInstructionsHint => _t(
      'e.g. specific market, meeting point, contact person',
      'mfano soko fulani, mahali pa kukutana, mtu wa kuwasiliana naye');
  String get requirementType => _t('Requirement type', 'Aina ya hitaji');
  String get repeat => _t('Repeat', 'Rudia');
  String get preferredDeliveryDays =>
      _t('Preferred delivery days', 'Siku za kufikisha unazopendelea');
  String get additionalNotesOptional =>
      _t('Additional notes (optional)', 'Maelezo ya ziada (si lazima)');
  String get additionalNotesHint => _t(
      'Any other details to help us find the right supply',
      'Maelezo mengine yoyote ya kutusaidia kupata bidhaa sahihi');
  String get chooseOneDeliveryDay => _t('Choose at least one delivery day.',
      'Chagua angalau siku moja ya kufikisha.');
  String get nextDeliveryDetails =>
      _t('Next: Delivery Details', 'Ifuatayo: Taarifa za Kufikisha');
  String get submitRequestLower => _t('Submit request', 'Tuma ombi');

  // Request detail --------------------------------------------------------
  String requestStep(String status) => switch (status) {
        'open' => _t('Request received', 'Ombi limepokelewa'),
        'partially_matched' => _t('Matching supply', 'Tunatafuta bidhaa'),
        'fully_matched' => _t('Supply secured', 'Bidhaa zimepatikana'),
        'confirmed' => _t('Confirmed', 'Imethibitishwa'),
        'fulfilling' => _t('Preparing & delivery', 'Maandalizi na ufikishaji'),
        'completed' => _t('Delivered', 'Imefikishwa'),
        _ => label(status),
      };
  String get supplyRequest => _t('Supply request', 'Ombi la bidhaa');
  String get requestDetails => _t('Request details', 'Maelezo ya ombi');
  String get editRequest => _t('Edit request', 'Hariri ombi');
  String get supplyWord => _t('Supply', 'Bidhaa');
  String get secured => _t('Secured', 'Zimepatikana');
  String get remaining => _t('Remaining', 'Zilizobaki');
  String get trackYourOrder => _t('Track your order', 'Fuatilia agizo lako');
  String get weAreOnIt => _t('We’re on it.', 'Tunalishughulikia.');
  String get whatHappensNext => _t('What happens next', 'Nini kinafuata');
  String get whatHappensNextBody => _t(
      'Omoterra will contact you once suitable supply is available and delivery is confirmed.',
      'Omoterra itawasiliana nawe bidhaa zinazofaa zikipatikana na ufikishaji ukithibitishwa.');
  String get requestCancelled => _t(
      'This request was cancelled. Contact Omoterra if you still need supply.',
      'Ombi hili limeghairiwa. Wasiliana na Omoterra kama bado unahitaji bidhaa.');
  String get supplyProgress =>
      _t('Supply progress', 'Maendeleo ya upatikanaji');
  String securedOf(String secured, String total) =>
      _t('$secured of $total secured', '$secured kati ya $total zimepatikana');
  String nRemaining(String n) => _t('$n remaining', '$n zimebaki');

  // Start a business ------------------------------------------------------
  /// Title, what you need and how Omoterra helps, for a business [type].
  (String, String, String) business(String type) => switch (type) {
        'chicken_shop' => (
            _t('Chicken Shop', 'Duka la Kuku'),
            _t('A suitable selling space, safe handling and cold storage.',
                'Eneo linalofaa la kuuzia, utunzaji salama na hifadhi ya baridi.'),
            _t('We help you source chicken stock and coordinate supply.',
                'Tunakusaidia kupata kuku na kuratibu upatikanaji.')
          ),
        'butchery' => (
            _t('Butchery', 'Bucha'),
            _t('Suitable premises, hygienic preparation space and refrigeration.',
                'Jengo linalofaa, eneo safi la maandalizi na jokofu.'),
            _t('We help you find meat supply for your opening stock.',
                'Tunakusaidia kupata nyama kwa bidhaa zako za kuanzia.')
          ),
        'fish_shop' => (
            _t('Fish Shop', 'Duka la Samaki'),
            _t('Cold storage, hygienic display and a suitable location.',
                'Hifadhi ya baridi, maonyesho safi na eneo linalofaa.'),
            _t('Our team can discuss your plan. Fish supply is subject to availability.',
                'Timu yetu inaweza kujadili mpango wako. Upatikanaji wa samaki unategemea kilichopo.')
          ),
        'meat_delivery' => (
            _t('Chicken / Meat Delivery', 'Usambazaji wa Kuku / Nyama'),
            _t('Safe insulated transport and a clear delivery area.',
                'Usafiri salama wenye kuhifadhi baridi na eneo la kufikisha lililo wazi.'),
            _t('We help source your starting supply and coordinate collection.',
                'Tunakusaidia kupata bidhaa za kuanzia na kuratibu uchukuaji.')
          ),
        'egg_reseller' => (
            _t('Egg Reseller', 'Muuzaji wa Mayai'),
            _t('Safe dry storage, protective trays and local customers.',
                'Hifadhi kavu na salama, trei za kukinga na wateja wa karibu.'),
            _t('Our team can discuss sourcing options for your plan.',
                'Timu yetu inaweza kujadili njia za kupata bidhaa kwa mpango wako.')
          ),
        'local_chicken_business' => (
            _t('Local Chicken Business', 'Biashara ya Kuku wa Kienyeji'),
            _t('Appropriate holding space and a clear target market.',
                'Eneo linalofaa la kuwaweka na soko lengwa lililo wazi.'),
            _t('We help source available local chicken.',
                'Tunakusaidia kupata kuku wa kienyeji waliopo.')
          ),
        'goat_meat_business' => (
            _t('Goat Meat Business', 'Biashara ya Nyama ya Mbuzi'),
            _t('Hygienic premises, storage and a handling plan.',
                'Jengo safi, hifadhi na mpango wa utunzaji.'),
            _t('We help coordinate goat or goat meat supply.',
                'Tunakusaidia kuratibu upatikanaji wa mbuzi au nyama ya mbuzi.')
          ),
        'restaurant_grill' => (
            _t('Small Restaurant / Grill', 'Mgahawa Mdogo / Nyama Choma'),
            _t('Suitable premises, food preparation equipment and storage.',
                'Jengo linalofaa, vifaa vya kuandaa chakula na hifadhi.'),
            _t('We help source the livestock and meat your menu needs.',
                'Tunakusaidia kupata mifugo na nyama unazohitaji kwa menyu yako.')
          ),
        _ => (label(type), '', ''),
      };
  String get planIntro => _t(
      'Tell us a little about your plan. We’ll use your account details to get in touch.',
      'Tuambie kidogo kuhusu mpango wako. Tutatumia taarifa za akaunti yako kuwasiliana nawe.');
  String get budgetRangeTzs =>
      _t('Budget range (TZS)', 'Kiasi cha bajeti (TZS)');
  String get havePremisesQ =>
      _t('Do you have premises?', 'Je, una eneo la biashara?');
  String get needStartingStockQ =>
      _t('Do you need starting stock?', 'Je, unahitaji bidhaa za kuanzia?');
  String get requestASetupPlan =>
      _t('Request a setup plan', 'Omba mpango wa kuanzisha');
  String referenceNo(String id) => _t('Reference #$id', 'Kumbukumbu #$id');
  String get teamWillReview => _t(
      'The Omoterra team will review your requirements and follow up with suitable supply.',
      'Timu ya Omoterra itakagua mahitaji yako na kukurudia na bidhaa zinazofaa.');
  String get viewRequestLower => _t('View request', 'Angalia ombi');
  String get preparingInTransit =>
      _t('Preparing / in transit', 'Inaandaliwa / njiani');

  // Sign-in details -------------------------------------------------------
  /// The language screen shows both languages at once, whichever is chosen.
  String get chooseLanguageEn => 'Choose your language';
  String get chooseLanguageSw => 'Chagua lugha yako';

  /// Each language is named in itself on the language screen.
  static const languageNames = {'en': 'English', 'sw': 'Kiswahili'};
  String get chooseBuyOrSell => _t('Choose Buy Supply or Sell Supply.',
      'Chagua Nunua Bidhaa au Uuze Bidhaa.');
  String get hideKeyboard => _t('Hide keyboard', 'Ficha kibodi');
  String get showKeyboard => _t('Show keyboard', 'Onyesha kibodi');
  String get verificationCode =>
      _t('Verification code', 'Msimbo wa uthibitisho');
  String get empty => _t('empty', 'tupu');

  // App shell -------------------------------------------------------------
  String get requestReceived => _t('Request received', 'Ombi limepokelewa');
  String get requestReceivedBody => _t(
      'Your request has been received. An Omoterra team member will contact you.',
      'Ombi lako limepokelewa. Mfanyakazi wa Omoterra atawasiliana nawe.');
  String get pageUnavailable => _t('Page unavailable', 'Ukurasa haupatikani');
  String get returnHome => _t('Return to your home to continue.',
      'Rudi ukurasa wako wa mwanzo ili kuendelea.');
  String get signInAgain => _t('Sign in again', 'Ingia tena');
  String get demand => _t('Demand', 'Mahitaji');
  String get browseAndBuy =>
      _t('Browse and buy supply', 'Angalia na ununue bidhaa');
  String get manageAndSell =>
      _t('Manage and sell your supply', 'Simamia na uuze bidhaa zako');
  String get registerAsBuyerShort =>
      _t('Register as buyer', 'Jisajili kama mnunuzi');
  String get registerAsSupplier =>
      _t('Register as supplier', 'Jisajili kama msambazaji');
  String get completeBuyerDetails => _t(
      'Complete buyer details to add this role',
      'Kamilisha taarifa za mnunuzi kuongeza jukumu hili');
  String get completeSupplierDetails => _t(
      'Complete supplier details to add this role',
      'Kamilisha taarifa za msambazaji kuongeza jukumu hili');
  String get chooseAccountType =>
      _t('Choose account type', 'Chagua aina ya akaunti');
  String get switchRolesFailed => _t(
      'We couldn’t switch roles just now. Please try again.',
      'Hatukuweza kubadilisha jukumu sasa hivi. Tafadhali jaribu tena.');
  String get view => _t('View', 'Angalia');

  /// A Tanzanian region as it is shown; the API keeps the English value.
  String regionName(String value) => isSwahili
      ? const {
            'Pemba North': 'Kaskazini Pemba',
            'Pemba South': 'Kusini Pemba',
            'Zanzibar North': 'Kaskazini Unguja',
            'Zanzibar South & Central': 'Kusini Unguja',
            'Zanzibar West': 'Mjini Magharibi',
          }[value] ??
          value
      : value;
}

const _labels = <String, (String, String)>{
  // Categories
  'broilers': ('Broilers', 'Kuku wa nyama'),
  'local_chicken': ('Local Chicken', 'Kuku wa kienyeji'),
  'layers': ('Layers', 'Kuku wa mayai'),
  'goats': ('Goats', 'Mbuzi'),
  'cattle': ('Cattle', "Ng'ombe"),
  'chicken_meat': ('Chicken Meat', 'Nyama ya kuku'),
  'beef': ('Beef', "Nyama ya ng'ombe"),
  'goat_meat': ('Goat Meat', 'Nyama ya mbuzi'),
  'eggs': ('Eggs', 'Mayai'),
  // Units
  'bird': ('Bird', 'Kuku'),
  'birds': ('Birds', 'Kuku'),
  'animal': ('Animal', 'Mnyama'),
  'animals': ('Animals', 'Wanyama'),
  'tray': ('Tray', 'Trei'),
  'trays': ('Trays', 'Trei'),
  'kg': ('Kg', 'Kg'),
  // Forms
  'live': ('Live', 'Hai'),
  'dressed': ('Dressed', 'Iliyochinjwa'),
  'chilled': ('Chilled', 'Iliyopozwa'),
  'frozen': ('Frozen', 'Iliyogandishwa'),
  // Stock specifications
  'avg_weight_kg': ('Average Weight (kg)', 'Uzito wa Wastani (kg)'),
  'age_weeks': ('Age (weeks)', 'Umri (wiki)'),
  'breed_type': ('Breed Type', 'Aina / Kizazi'),
  'live_or_dressed': ('Live Or Dressed', 'Hai au Iliyochinjwa'),
  'ready_date': ('Ready Date', 'Tarehe ya Kuwa Tayari'),
  'weight_range': ('Weight Range', 'Kiwango cha Uzito'),
  'weight_kg': ('Weight (kg)', 'Uzito (kg)'),
  'breed': ('Breed', 'Aina'),
  'sex': ('Sex', 'Jinsia'),
  'approx_age': ('Approx Age', 'Umri wa Kukadiria'),
  'tray_size': ('Tray Size', 'Ukubwa wa Trei'),
  'egg_size': ('Egg Size', 'Ukubwa wa Yai'),
  'cut_type': ('Cut Type', 'Aina ya Kipande'),
  'chilled_or_frozen': ('Chilled Or Frozen', 'Iliyopozwa au Iliyogandishwa'),
  'slaughter_date': ('Slaughter Date', 'Tarehe ya Kuchinja'),
  'male': ('Male', 'Dume'),
  'female': ('Female', 'Jike'),
  'mixed': ('Mixed', 'Mchanganyiko'),
  'small': ('Small', 'Ndogo'),
  'medium': ('Medium', 'Wastani'),
  'large': ('Large', 'Kubwa'),
  // Statuses
  'new': ('New', 'Mpya'),
  'pending': ('Pending', 'Inasubiri'),
  'pending_review': ('Pending Review', 'Inasubiri ukaguzi'),
  'under_review': ('Under Review', 'Inakaguliwa'),
  'approved': ('Approved', 'Imeidhinishwa'),
  'rejected': ('Rejected', 'Imekataliwa'),
  'suspended': ('Suspended', 'Imesimamishwa kwa muda'),
  'changes_requested': ('Changes Requested', 'Marekebisho yanahitajika'),
  'active': ('Active', 'Inaendelea'),
  'paused': ('Paused', 'Imesimamishwa'),
  'growing': ('Growing', 'Inakua'),
  'ready': ('Ready', 'Tayari'),
  'open': ('Open', 'Wazi'),
  'closed': ('Closed', 'Imefungwa'),
  'expired': ('Expired', 'Muda umeisha'),
  'withdrawn': ('Withdrawn', 'Imeondolewa'),
  'sold_out': ('Sold Out', 'Imeisha'),
  'reserved': ('Reserved', 'Imehifadhiwa'),
  'partially_reserved': ('Partially Reserved', 'Imehifadhiwa kwa sehemu'),
  'fully_reserved': ('Fully Reserved', 'Imehifadhiwa yote'),
  'released': ('Released', 'Imeachiliwa'),
  'reversed': ('Reversed', 'Imebatilishwa'),
  'needs_confirmation': ('Needs Confirmation', 'Inahitaji uthibitisho'),
  'location_confirmed': ('Location Confirmed', 'Eneo limethibitishwa'),
  'submitted': ('Submitted', 'Imetumwa'),
  'sourcing': ('Sourcing', 'Inatafutwa'),
  'supply_found': ('Supply Found', 'Bidhaa imepatikana'),
  'partially_matched': ('Partially Matched', 'Imepatikana kwa sehemu'),
  'fully_matched': ('Fully Matched', 'Imepatikana yote'),
  'accepted': ('Accepted', 'Imekubaliwa'),
  'partially_accepted': ('Partially Accepted', 'Imekubaliwa kwa sehemu'),
  'confirmed': ('Confirmed', 'Imethibitishwa'),
  'preparing': ('Preparing', 'Inaandaliwa'),
  'fulfilling': ('Fulfilling', 'Inashughulikiwa'),
  'on_the_way': ('On The Way', 'Njiani'),
  'in_transit': ('In Transit', 'Njiani'),
  'supply_confirmed': ('Supply Confirmed', 'Bidhaa imethibitishwa'),
  'supplier_confirmed': ('Supplier Confirmed', 'Msambazaji amethibitisha'),
  'pickup_scheduled': ('Pickup Scheduled', 'Uchukuaji umepangwa'),
  'collected': ('Collected', 'Imechukuliwa'),
  'quality_checked': ('Quality Checked', 'Ubora umekaguliwa'),
  'delivered': ('Delivered', 'Imefikishwa'),
  'completed': ('Completed', 'Imekamilika'),
  'cancelled': ('Cancelled', 'Imeghairiwa'),
  'failed': ('Failed', 'Imeshindikana'),
  'payment_failed': ('Payment Failed', 'Malipo yameshindikana'),
  'paid': ('Paid', 'Imelipwa'),
  'unpaid': ('Unpaid', 'Haijalipwa'),
  'external_sale': ('External Sale', 'Mauzo nje ya Omoterra'),
  'contacted': ('Contacted', 'Amewasiliana'),
  'interested': ('Interested', 'Ana nia'),
  'setup_in_progress': ('Setup In Progress', 'Uanzishaji unaendelea'),
  'converted': ('Converted', 'Amejiunga'),
  // Payment methods
  'pay_now': ('Pay Now', 'Lipa sasa'),
  'pay_on_delivery': ('Pay On Delivery', 'Lipa unapopokea'),
  'mobile_money': ('Mobile Money', 'Mobile Money'),
  // Repeats
  'one_time': ('One Time', 'Mara moja'),
  'recurring': ('Recurring', 'Inajirudia'),
  'daily': ('Daily', 'Kila siku'),
  'weekly': ('Weekly', 'Kila wiki'),
  'monthly': ('Monthly', 'Kila mwezi'),
  'monday': ('Monday', 'Jumatatu'),
  'tuesday': ('Tuesday', 'Jumanne'),
  'wednesday': ('Wednesday', 'Jumatano'),
  'thursday': ('Thursday', 'Alhamisi'),
  'friday': ('Friday', 'Ijumaa'),
  'saturday': ('Saturday', 'Jumamosi'),
  'sunday': ('Sunday', 'Jumapili'),
  // Age units
  'days': ('Days', 'Siku'),
  'weeks': ('Weeks', 'Wiki'),
  'months': ('Months', 'Miezi'),
  // Buyer and business types
  'personal': ('Personal', 'Binafsi'),
  'restaurant': ('Restaurant', 'Mgahawa'),
  'butchery': ('Butchery', 'Bucha'),
  'hotel': ('Hotel', 'Hoteli'),
  'retailer': ('Retailer', 'Muuzaji wa rejareja'),
  'caterer': ('Caterer', 'Mhudumu wa chakula'),
  'other': ('Other', 'Nyingine'),
  'chicken_shop': ('Chicken Shop', 'Duka la kuku'),
  'fish_shop': ('Fish Shop', 'Duka la samaki'),
  'meat_delivery': ('Meat Delivery', 'Usambazaji wa nyama'),
  'egg_reseller': ('Egg Reseller', 'Muuzaji wa mayai'),
  'local_chicken_business': (
    'Local Chicken Business',
    'Biashara ya kuku wa kienyeji'
  ),
  'goat_meat_business': ('Goat Meat Business', 'Biashara ya nyama ya mbuzi'),
  'restaurant_grill': ('Restaurant Grill', 'Mgahawa wa nyama choma'),
  // Languages and account pages
  'en': ('English', 'Kiingereza'),
  'sw': ('Kiswahili', 'Kiswahili'),
  'support': ('Support', 'Msaada'),
  'terms': ('Terms', 'Masharti'),
  'privacy': ('Privacy', 'Faragha'),
  // Start-business timing and yes/no answers
  'yes': ('Yes', 'Ndiyo'),
  'no': ('No', 'Hapana'),
  'within_2_weeks': ('Within 2 Weeks', 'Ndani ya wiki 2'),
  'within_1_month': ('Within 1 Month', 'Ndani ya mwezi 1'),
  'within_3_months': ('Within 3 Months', 'Ndani ya miezi 3'),
  'still_planning': ('Still Planning', 'Bado ninapanga'),
  // Roles and contact methods
  'buyer': ('Buyer', 'Mnunuzi'),
  'supplier': ('Supplier', 'Msambazaji'),
  'admin': ('Admin', 'Msimamizi'),
  'staff': ('Staff', 'Mfanyakazi'),
  'phone': ('Phone', 'Simu'),
  'whatsapp': ('WhatsApp', 'WhatsApp'),
  'sms': ('SMS', 'SMS'),
};

/// Watches the signed-in account's language so switching it in Account
/// immediately re-renders every screen.
final stringsProvider = Provider<Strings>((ref) => Strings(
    ref.watch(sessionProvider).valueOrNull?.language ??
        ref.watch(selectedLanguageProvider)));

extension StringsContext on WidgetRef {
  Strings get s => watch(stringsProvider);
}

extension StringsOf on BuildContext {
  /// The app's copy for widgets without a [WidgetRef]. It rebuilds the
  /// caller when the language changes (the app's locale follows it). Outside
  /// a ProviderScope, as in some widget tests, it follows the locale alone.
  Strings get s {
    final locale = Localizations.maybeLocaleOf(this);
    if (getElementForInheritedWidgetOfExactType<UncontrolledProviderScope>() ==
        null) {
      return Strings(locale?.languageCode ?? 'en');
    }
    return ProviderScope.containerOf(this, listen: false).read(stringsProvider);
  }
}
