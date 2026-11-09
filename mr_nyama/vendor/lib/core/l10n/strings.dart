import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/office_assets.dart' show AssetError;
import '../api/office_catalogue.dart';
import '../api/vendor_repository.dart';

part 'strings_owner.dart';
part 'strings_progress.dart';
part 'strings_bonus.dart';
part 'strings_offline.dart';
part 'strings_history.dart';
part 'strings_finance.dart';
part 'strings_removal.dart';
part 'strings_fingerprint.dart';
part 'strings_sign_in.dart';
part 'strings_pin.dart';
part 'strings_notifications.dart';
part 'strings_approvals.dart';
part 'strings_stock_measures.dart';
part 'strings_closing_cases.dart';
part 'strings_handovers.dart';
part 'strings_auto_verify.dart';
part 'strings_sale_cancel.dart';
part 'strings_lost_sales.dart';
part 'strings_entry_checks.dart';
part 'strings_setup.dart';
part 'strings_unsent.dart';
part 'strings_blind_count.dart';
part 'strings_station_duty.dart';
part 'strings_lead.dart';
part 'strings_supply.dart';
part 'strings_finance_workspace.dart';
part 'strings_contacts.dart';
part 'strings_assets.dart';

// REVIEW BEFORE RELEASE: a Swahili-speaking team member must review this copy
// with vendors. Wording follows the approved Mr. Nyama designs.

/// Application copy. Swahili is the default; English exists as a setting.
/// Every user-visible string in `lib/app`, `lib/features` and `lib/shared`
/// lives here; test/l10n_guard_test.dart fails when a literal slips back into
/// a screen.
class Strings {
  final String code;

  /// Units the business added (MN016), by code, for [unitName].
  final Map<String, OfficeUnit> addedUnits;
  const Strings(this.code, {this.addedUnits = const {}});

  bool get isSwahili => code != 'en';
  String _t(String sw, String en) => isSwahili ? sw : en;

  String get productEditTitle => _t('Hariri bidhaa', 'Edit product');
  String get productInformation =>
      _t('Maelezo ya bidhaa', 'Product information');
  String get productPhoto => _t('Picha ya bidhaa', 'Product photo');
  String get productPhotoHint =>
      _t('Gusa kubadilisha picha', 'Tap to change photo');
  String get productActions =>
      _t('Chaguo zaidi za bidhaa', 'More product actions');
  String get productAvailabilitySection => _t('Upatikanaji', 'Availability');
  String get productActiveHint =>
      _t('Inaruhusu mauzo mapya', 'Allows new sales');
  String get productAvailableHint =>
      _t('Huonekana kwenye menyu yao', 'Shown in their menu');
  String get productPricesSection => _t('Bei', 'Prices');
  String get productProductionSection =>
      _t('Uzalishaji na stoo', 'Production and stock');
  String get productMadeFrom => _t('Hutengenezwa kutoka', 'Made from');
  String get productReasonRequired =>
      _t('Sababu ya mabadiliko (inahitajika)', 'Reason for changes (required)');
  String get productManagementSection =>
      _t('Usimamizi wa bidhaa', 'Product management');
  String get productDisable => _t('Zima bidhaa', 'Turn off product');
  String productDisableTitle(String name) =>
      _t('Zima $name?', 'Turn off $name?');
  String get productDisableBody => _t(
      'Bidhaa haitapatikana kwa mauzo mapya. Historia ya mauzo na stoo itahifadhiwa. Hifadhi mabadiliko ili kuthibitisha.',
      'New sales will stop; sales and stock history will remain. Save changes to apply.');
  String get productDisableHint => _t(
      'Mauzo mapya yatasimama, historia itabaki',
      'Stops new sales; keeps history');
  String get productInactiveHint => _t('Bidhaa imezimwa', 'Product is off');
  String get productApplyDraft => _t('Tumia', 'Apply');
  String get productNoChanges => _t('Hakuna mabadiliko', 'No changes');
  String productPreviousPrice(String price) =>
      _t('Iliyokuwa: $price', 'Previously: $price');
  String productDefaultStations(int n) => _t(
      'Vituo $n vinatumia bei ya kawaida', '$n stations use the default price');
  String get productPartialSave => _t(
      'Maelezo yamehifadhiwa; bei haijathibitishwa. Jaribu kuhifadhi tena.',
      'Details saved; the price is not confirmed. Try saving again.');

  String get lockOwnerAccount => _t('Akaunti ya mmiliki', 'Owner account');
  String get lockTooMany => _t('Majaribio mengi mno', 'Too many attempts');
  String lockRetryIn(String time) =>
      _t('Jaribu tena baada ya $time', 'Try again in $time');
  String get lockPinUnavailable => _t('PIN haitumiki wakati akaunti imefungwa.',
      'PIN unavailable during lockout');
  String get lockAccountPin => _t('Ingiza PIN ya akaunti', 'Enter account PIN');
  String get lockPinHelp => _t(
      'Ingiza PIN yako ya tarakimu 4 kufungua programu.',
      'Enter your 4-digit PIN to unlock the app.');
  String get lockSecurity => _t('Fungua ili kuendelea.', 'Unlock to continue.');
  String get lockFailedTitle => _t('Haikuweza kufunguka', "Couldn’t unlock");
  String get lockBiometricHelp => _t('Tumia alama ya kidole au uso kuendelea.',
      'Use your fingerprint or face to continue.');

  String get biometricTitle =>
      _t('Kufungua kwa alama za mwili', 'Biometric app lock');
  String get biometricReason => _t('Thibitisha utambulisho wako ili kuendelea.',
      'Confirm it is you to continue.');
  String get biometricLocked => _t('Imefungwa', 'Locked');
  String get biometricUnlock =>
      _t('Fungua kwa biometrics', 'Unlock with biometrics');
  String get biometricUsePin => _t('Tumia PIN', 'Use PIN');
  String get biometricFailed =>
      _t('Jaribu tena au tumia PIN.', 'Try again or use your PIN.');
  String get biometricUnavailable => _t(
      'Weka alama ya kidole au uso kwenye mipangilio ya simu kwanza.',
      'Set up fingerprint or face unlock in your phone settings first.');
  String get biometricOn => _t('Imewashwa', 'On');
  String get biometricOff => _t('Imezimwa', 'Off');

  String get filterSales => _t('Chuja mauzo', 'Filter sales');
  String get resetFilters => _t('Weka upya', 'Reset');
  String get allRecords => _t('Zote', 'All');
  String get unsyncedOnly =>
      _t('Onyesha yasiyosawazishwa tu', 'Show unsynced only');
  String get showVoided => _t('Onyesha zilizobatilishwa', 'Show voided sales');
  String get applyFilters => _t('Tumia vichujio', 'Apply filters');
  String get todayLabel => _t('Leo', 'Today');
  String get yesterdayLabel => _t('Jana', 'Yesterday');
  String get thisWeek => _t('Wiki hii', 'This week');
  String get thisMonth => _t('Mwezi huu', 'This month');
  String get customDate => _t('Tarehe maalum', 'Custom date');
  String get filterPeriod => _t('Muda', 'Period');
  String get useDate => _t('Tumia tarehe', 'Use date');
  String get transactions => _t('Miamala', 'Transactions');
  String get historyPending => _t(
      'Baadhi ya mauzo hayajasawazishwa. Yatatumwa ukipata mtandao.',
      'Some sales are not synced. They will be sent when connected.');
  String get voidLockedTitle =>
      _t('Huwezi kubatilisha mauzo haya', 'You cannot void this sale');
  String get okay => _t('Sawa', 'OK');
  String get additionalNoteRequired =>
      _t('Maelezo ya ziada (lazima)', 'Additional notes (required)');
  String get additionalNoteOptional =>
      _t('Maelezo ya ziada (hiari)', 'Additional notes (optional)');
  String get voidNoteHint =>
      _t('Andika sababu ya kubatilisha...', 'Enter a reason for voiding...');
  String get receiveGoodsAction => _t('Pokea bidhaa', 'Receive goods');
  String get saveWorkflow => _t('Hifadhi', 'Save');
  String get differenceReasonRequired =>
      _t('Sababu ya tofauti (lazima)', 'Reason for difference (required)');
  String get noteRequired => _t('Maelezo (lazima)', 'Notes (required)');
  String get noteHint => _t('Andika maelezo...', 'Enter notes...');
  String get differenceLabel => _t('Tofauti', 'Difference');
  String get filterGoods => _t('Chuja bidhaa', 'Filter goods');
  String get newDeliveriesHere => _t(
      'Bidhaa mpya zitaonekana hapa zitakapowasili.',
      'New goods will appear here when they arrive.');
  String get continueCounting => _t('Endelea kuhesabu', 'Continue counting');
  String get notYetCounted => _t('Bado', 'Not yet');
  String get countedLabel => _t('Imehesabiwa', 'Counted');
  String get countEntryHint =>
      _t('Ingiza kiasi ulichohesabu', 'Enter the quantity counted');
  String get expectedRemaining =>
      _t('Baki inayotarajiwa', 'Expected remaining');
  String get countReasonSales =>
      _t('Pungua wakati wa mauzo', 'Reduced during sales');
  String get countReasonDamaged =>
      _t('Zimeharibika (ripoti kando)', 'Damaged (report separately)');
  String get countReasonOther => _t('Sababu nyingine', 'Other reason');
  String get clearCartBody => _t('Hii itaondoa bidhaa zote kwenye kikapu.',
      'This removes all goods from the cart.');
  String get emptyCartTitle => _t('Kikapu ni tupu', 'Your cart is empty');
  String get emptyCartBody =>
      _t('Ongeza bidhaa kuanza mauzo.', 'Add goods to start a sale.');
  String get paymentInstructions => _t(
      'Chagua njia ya malipo na kisha hifadhi mauzo.',
      'Choose a payment method, then save the sale.');
  String get saveErrorTitle => _t('Imeshindikana kuhifadhi', 'Could not save');
  String get saleRetryBody => _t('Mauzo yako hayajapotea. Jaribu tena.',
      'Your sale has not been lost. Try again.');
  String get undoWorkflow => _t('Rudisha', 'Undo');
  String countedProgress(int count, int total) =>
      _t('$count kati ya $total zimehesabiwa', '$count of $total counted');
  String cartLineRemoved(String name) =>
      _t('$name limefutwa.', '$name removed.');

  // Kikapu reference, 22 October 2026.
  String get removeLine => _t('Futa', 'Remove');
  String removeLineFor(String name) => _t('Futa $name', 'Remove $name');
  String get clearAllTitle => _t('Futa bidhaa zote?', 'Remove all goods?');
  String get mpesaNotSet => _t('Haijawekwa na ofisi', 'Not set by the office');
  String get saleSavedTitle => _t('Mauzo yamehifadhiwa', 'Sale saved');
  String get saleSentToOffice => _t('Yametumwa ofisini', 'Sent to the office');
  String get saleSyncedTitle => _t('Imesawazishwa', 'Synced');
  String get saleSyncedBody =>
      _t('Mauzo yako yapo kwenye mfumo.', 'Your sale is in the system.');
  String get saleSavedOnPhoneTitle =>
      _t('Mauzo yamehifadhiwa kwenye simu', 'Sale saved on the phone');
  String get saleSendsWhenOnline =>
      _t('Yatatumwa ukipata mtandao.', 'It will be sent when connected.');
  String get saleWaitingNetwork =>
      _t('Inasubiri mtandao', 'Waiting for network');
  String get saleSafeOnPhone => _t(
      'Mauzo yako yamehifadhiwa salama kwenye simu.',
      'Your sale is saved safely on the phone.');
  String get saleSaveFailedBody => _t(
      'Mauzo yako hayajapotea.\nJaribu tena. Ikiwa tatizo litaendelea, wasiliana na ofisi.',
      'Your sale has not been lost. Try again. If the problem continues, contact the office.');

  String deliveryProducts(int n) =>
      _t('bidhaa', n == 1 ? 'product' : 'products');

  String get filterCount => _t('Chuja hesabu', 'Filter counts');
  String get withDifference => _t('Zenye tofauti', 'With differences');

  String get printReceipt => _t('Printi risiti', 'Print receipt');
  String get printFailed => _t(
      'Imeshindikana kufungua kichapishi. Jaribu tena.',
      'Could not open printing. Try again.');

  String get vendorExpenseApprovalNote => _t(
      'Rekodi gharama ulizolipa kwa fedha ulizokusanya. Ofisi itaidhinisha; kiasi unachodaiwa hakipungui kabla ya idhini.',
      'Record expenses paid from money you collected. Office approval is required before reducing your cash due.');
  String get expenseCategoriesLoading => _t(
      'Inapakua aina za gharama kutoka ofisini. Unaweza kutumia Mengineyo sasa.',
      'Downloading expense categories from the office. You can use Others now.');
  String get expenseCategoriesRefreshFailed => _t(
      'Aina za gharama hazijasasishwa. Unaweza kutumia zilizohifadhiwa au Mengineyo; unganisha mtandao na ujaribu tena.',
      'Expense categories could not be refreshed. You can use saved categories or Others; connect and retry.');
  String get vendorExpenseCategoriesMissing => _t(
      'Unganisha mtandao kupakua aina za gharama. Zisipopatikana, mwambie mmiliki aziweke kwenye Mipangilio ya fedha.',
      'Connect to download expense categories. If none are available, ask the owner to configure Money settings.');
  // Pieces cut at the station (stock.cut_from).
  String get cutSection =>
      _t('Kukatwa kutoka bidhaa nyingine', 'Cut from another product');
  String get cutHelp => _t(
      'Kwa vipande kama Nusu kuku, Paja au Kidali: kituo kilichopokea kuku mzima kinaviuza kwa kukata. Kipande kikiuzwa, kilichobaki kinabaki kwenye stoo kama kilivyo (paja likiuzwa, kidali kinabaki).',
      'For pieces such as Nusu kuku, Paja or Kidali: a station that received whole birds sells them by cutting. What is not sold stays in stock as it is (a Paja sold leaves a Kidali).');
  String get cutNone =>
      _t('Haikatwi kutoka bidhaa nyingine', 'Not cut from another product');
  String cutRule(String product, int count) => _t(
      'Hukatwa kutoka $product · $count kwa kila $product',
      'Cut from $product · $count from each');
  String get cutSource => _t('Hukatwa kutoka', 'Cut from');
  String get cutCount => _t('Idadi kutoka kimoja', 'How many from one');
  String get cutOnSale => _t('kwa kukata', 'by cutting');
  String get stockCutPieces => _t(
      'Vipande vilivyokatwa (vimo kwenye hesabu ya bidhaa nzima)',
      'Cut pieces (counted in the whole product)');
  String get cutSaveFailed => _t(
      'Imeshindikana kuhifadhi. Mmiliki pekee ndiye anaweza kubadilisha hili.',
      'Could not save. Only the owner can change this.');
  String get vendorExpenseCategoriesNotSet => _t(
      'Mmiliki bado hajaweka aina za gharama. Mwambie aziweke kwenye Mipangilio ya fedha, kisha jaribu tena.',
      'The owner has not set expense categories yet. Ask them to add them in Money settings, then try again.');
  String get vendorExpenseOffline => _t(
      'Unaona rekodi zilizohifadhiwa kwenye simu. Vuta chini kusasisha majibu ya ofisi ukipata mtandao.',
      'Showing records saved on the phone. Pull to refresh office decisions when connected.');
  String get vendorExpenseSaved => _t(
      'Gharama imehifadhiwa kwenye simu. Inasubiri kutumwa na kuidhinishwa na ofisi.',
      'Expense saved on the phone, awaiting sending and office approval.');
  String vendorExpenseState(String state) => switch (state) {
        'approved' => _t('Imeidhinishwa na ofisi', 'Approved by office'),
        'rejected' => _t('Inahitaji ukaguzi wa ofisi', 'Needs office review'),
        'reversed' => _t('Imebatilishwa na ofisi', 'Reversed by office'),
        'pending' => _t('Imetumwa; inasubiri idhini ya ofisi',
            'Sent; awaiting office approval'),
        _ => _t('Imehifadhiwa kwenye simu; inasubiri kutumwa',
            'Saved on phone; awaiting sending'),
      };
  String get receiveHelpTitle =>
      _t('Jinsi ya kupokea bidhaa', 'How to receive goods');
  String get receivePurchaseHelp => _t(
      'Bidhaa zilizonunuliwa: ofisi au msimamizi aandike mzigo unaotarajiwa kwa kituo chako. Ukiona mzigo hapa, ufungue, hesabu vilivyofika na uguse Pokea bidhaa.',
      'Supplier purchases: office or your supervisor records the expected delivery for your station. Open the delivery here, count what arrived and choose Receive goods.');
  String get receiveTransferHelp => _t(
      'Kutoka jikoni au stoo yenu: msimamizi aandike uhamisho wa bidhaa zilizopo kwenda kituo chako. Thibitisha kiasi kilichofika hapa; usirekodi tena kama manunuzi mapya.',
      'From your kitchen/store: your supervisor records a transfer of existing stock to your station. Confirm what arrived here; do not record it again as a new purchase.');
  String get receiveMissingHelp => _t(
      'Mzigo haupo? Mwambie ofisi au msimamizi auweke kwa kituo chako. Kisha vuta chini kusasisha. Kuhesabu kupitia Funga Siku hakuongezi stoo.',
      'Delivery missing? Ask office or your supervisor to record it for your station, then pull to refresh. Closing counts do not add stock.');

  String get officeNewDelivery =>
      _t('Ongeza mzigo unaotarajiwa', 'Add an expected delivery');
  String get officeDeliveryKind => _t('Chanzo cha bidhaa', 'Goods source');
  String get officePurchase =>
      _t('Manunuzi kutoka kwa msambazaji', 'Purchase from supplier');
  String get officeTransfer =>
      _t('Uhamisho kutoka jikoni au stoo', 'Transfer from kitchen or store');
  String get officeAgreementReference =>
      _t('Rejea ya makubaliano au agizo', 'Agreement or order reference');
  String get officeTitleTransfer =>
      _t('Umiliki unahamia lini?', 'When does ownership transfer?');
  String get officeTitleAtReceipt =>
      _t('Baada ya kuthibitisha kupokea', 'At accepted receipt');
  String get officeTitleLater =>
      _t('Baadaye, kulingana na makubaliano', 'Later, under the agreement');
  String get officeSourceLocation =>
      _t('Jikoni au stoo inayotuma', 'Sending kitchen or store');
  String get officePurchaseUnitPrice => _t('Bei ya kununua kwa kipimo (hiari)',
      'Purchase price per unit (optional)');
  String get officeKgReceiptHelp => _t(
      'Inabaki kg. Kuandaa vipande kunahitaji rekodi ya ubadilishaji; hakuna makadirio ya kiotomatiki.',
      'Remains in kg. Preparing pieces requires a conversion record; no automatic estimate.');
  String get officePrepared =>
      _t('Vimeandaliwa na timu yetu', 'Prepared by our team');
  String get officePreparedBy => _t(
      'Viliandaliwa wapi na nani?', 'Where and by whom were these prepared?');
  String get officePreparedDeclaration => _t(
      'Bidhaa hizi na malighafi zake hazijarekodiwa kwenye stoo ya biashara.',
      'These goods and their ingredients have not been recorded in business stock.');
  String get officePreparedHelp => _t(
      'Weka bidhaa zilizokamilika na tarehe zilipofikishwa. Muuzaji atathibitisha idadi. Gharama za maandalizi zitabaki zikisubiri.',
      'Enter the finished goods and delivery date. The vendor confirms quantities. Preparation costs remain pending.');
  String get officePreparedConfirm => _t(
      'Hii itarekodi mzigo wa bidhaa tulizoandaa. Stoo itaongezwa baada ya muuzaji kuthibitisha. Haitarekodi matumizi ya malighafi wala gharama za uzalishaji.',
      'This records a delivery of our prepared goods. Stock is added after vendor confirmation. It does not record ingredient usage or production costs.');

  /// Names the field a refused delivery save needs; [min] 0 means "choose one".
  String officeFieldNeeded(String field, int min) => min > 0
      ? _t('Jaza "$field" (angalau herufi $min).',
          'Fill in "$field" (at least $min characters).')
      : _t('Chagua "$field".', 'Choose "$field".');
  String get officePreparedDeclarationNeeded => _t(
      'Weka alama kuthibitisha kuwa bidhaa hizi hazijarekodiwa kwenye stoo.',
      'Tick to confirm these goods are not yet recorded in stock.');
  String get officeDeliveryLineInvalid => _t(
      'Angalia bidhaa: kila mstari uwe na idadi sahihi, na stoo ya kutosha kwa uhamisho.',
      'Check the products: each line needs a valid quantity, and enough stock for a transfer.');
  String get actualReceiptDate =>
      _t('Tarehe na saa vilipopokelewa', 'Actual receipt date and time');
  String get officeNoTransferStock => _t(
      'Hakuna bidhaa zinazomilikiwa hapa za kuhamisha. Hakikisha mapokezi au uzalishaji umerekodiwa.',
      'No owned stock is available here to transfer. Check that receipts or production have been recorded.');
  String get officeTransferConfirm => _t(
      'Bidhaa zitaondoka kwenye stoo inayotuma na kubaki safarini. Muuzaji lazima athibitishe vilivyofika kabla ya kuongezwa kituoni.',
      'Stock will leave the source location and remain in transit. The vendor must confirm arrival before it is added at the destination.');
  String get officePurchaseConfirm => _t(
      'Hii itaweka mzigo kwenye orodha ya muuzaji. Stoo itaongezwa tu baada ya muuzaji kuthibitisha vilivyofika.',
      'This adds a delivery to the vendor list. Stock is added only after the vendor confirms what arrived.');
  String get officeDeliveryRetry => _t(
      'Jaribu tena kwa ombi hili hili ili kuepuka kurudia mzigo.',
      'Retry this same request to avoid duplicating the delivery.');
  String get officeHandoverDate => _t('Tarehe ya kukabidhi', 'Handover date');
  String get officeChooseProduct => _t('Chagua bidhaa', 'Choose product');
  String get officePickSourceFirst => _t(
      'Chagua chanzo cha bidhaa kwanza, kisha ongeza bidhaa unazokabidhi.',
      'Choose the goods source first, then add the products you are handing over.');
  String officeDeliveryLine(int n) => _t('Bidhaa $n', 'Item $n');
  String get officeDeliveryProducts =>
      _t('Bidhaa za mzigo', 'Products in this delivery');
  String get officeNoDeliveryProducts => _t(
      'Bado hujaongeza bidhaa. Gusa "Ongeza bidhaa" kuchagua.',
      'No products yet. Tap "Add products" to choose.');
  String get officeChooseSourceFirst => _t(
      'Chagua jikoni au stoo inayotuma kwanza.',
      'Choose the sending kitchen or store first.');
  String officeAvailableHere(String quantity) =>
      _t('Zipo hapa: $quantity', 'Here: $quantity');
  String get officeNoTransferSources => _t(
      'Hakuna jikoni au stoo nyingine yenye bidhaa za kuhamisha. Kwa bidhaa mlizoandaa ambazo hazijarekodiwa, chagua "Vimeandaliwa na timu yetu".',
      'No other kitchen or store has stock to transfer. For your prepared goods that have not been recorded, choose "Prepared by our team".');
  String get officeNoneHere =>
      _t('Hazipo kwenye stoo hii', 'None at this location');
  String get officeAlreadyAdded => _t('Imeshaongezwa', 'Already added');

  // Brand.
  String get brand => 'Mr. Nyama';
  String get tagline => 'MOTO WAKE HAUZIMI!!';

  // Main destinations.
  String get home => _t('Nyumbani', 'Home');
  String get sales => _t('Mauzo', 'Sales');
  String get products => _t('Bidhaa', 'Products');

  // Secondary destinations.
  String get newSaleHint => _t('Ongeza mauzo mapya', 'Record a new sale');
  String get marketHint => _t('Tazama bidhaa', 'View products');
  String get receiveHint => _t('Ingiza bidhaa stock', 'Receive stock');
  String get damagedHint => _t('Rekodi bidhaa mbovu', 'Record damaged goods');
  String get closeDayHint =>
      _t('Maliza na hifadhi hesabu za siku', 'Save the closing count');
  String get allStations => _t('Vituo vyote', 'All stations');
  String get myStation => _t('Kituo changu', 'My station');
  String get filter => _t('Chuja', 'Filter');
  String get dateLabel => _t('Tarehe', 'Date');
  String get unitsLabel => _t('Vipande', 'Units');
  String get kindsLabel => _t('Aina', 'Products');
  String get receive => _t('Pokea Bidhaa', 'Receive goods');
  String get damaged => _t('Vimeharibika', 'Damaged');
  String get history => _t('Historia', 'History');
  String get closeDay => _t('Funga Siku', 'Close the day');
  String get profile => _t('Wasifu', 'Profile');

  // Common actions.
  String get back => _t('Rudi', 'Back');
  String get cancel => _t('Ghairi', 'Cancel');
  String get confirm => _t('Thibitisha', 'Confirm');
  String get retry => _t('Jaribu tena', 'Try again');
  String get decrease => _t('Punguza', 'Decrease');
  String get increase => _t('Ongeza', 'Increase');
  String get remove => _t('Ondoa', 'Remove');
  String get backspace => _t('Futa', 'Delete');
  String get add => _t('Ongeza kwenye mauzo', 'Add to sale');

  // Amounts and quantities.
  String get currency => 'TSh';
  String itemsCount(int n) => _t('Bidhaa $n', '$n items');
  String quantityOf(String name, int n) => '$name × $n';
  String get remainingLabel => _t('Imesalia', 'Left');
  String remaining(String n) => '$remainingLabel: $n';
  String get outOfStock => _t('Imeisha', 'Sold out');
  String get viewCart => _t('Angalia kikapu', 'View cart');

  // Payment methods.
  String get cash => _t('Taslimu', 'Cash');
  String get mpesa => _t('M-Pesa ya Mr. Nyama', 'Mr. Nyama M-Pesa');

  // Sync — one honest line, never a network error message.
  String get syncSent => _t('Imetumwa ofisini', 'Sent to the office');
  String get syncWaiting => _t('Inasubiri kusawazisha', 'Waiting to sync');
  String get syncUnknown => _t(
      'Hali ya usawazishaji haijathibitishwa', 'Sync status not yet confirmed');
  String syncOutstanding(int count) => _t(
      'Kumbukumbu $count hazijakamilisha usawazishaji',
      '$count records have not completed sync');
  String syncReviewCount(int count) =>
      _t('Kumbukumbu $count zinahitaji ukaguzi', '$count records need review');
  String get syncSending => _t('Inatuma…', 'Sending…');
  String get savedOnPhone => _t('Imehifadhiwa kwenye simu', 'Saved on phone');

  // Sign-in.
  String get phoneLabel => _t('Namba ya simu', 'Phone number');
  String get continueLabel => _t('Endelea', 'Continue');
  String get phoneHelp => _t(
      'Tafadhali tumia namba yako ya simu ya muuzaji wa Mr. Nyama.',
      'Use your Mr. Nyama vendor phone number.');
  String get phoneInvalid => _t('Namba si sahihi', 'Not a valid number');
  String get countryCode => '+255';
  String get forgotPin => _t('Umesahau PIN?', 'Forgot PIN?');
  String welcomeBack(String name) =>
      _t('Karibu tena, $name', 'Welcome back, $name');
  String get activationTitle =>
      _t('Weka namba ya uthibitisho', 'Enter your activation code');
  String get activationHelp =>
      _t('Namba uliyopewa na msimamizi.', 'The code your supervisor gave you.');
  String get createPin => _t('Chagua PIN mpya', 'Choose a new PIN');
  String get confirmPin => _t('Rudia PIN yako', 'Enter the PIN again');
  String get currentPin => _t('Ingiza PIN ya sasa', 'Enter your current PIN');
  String get pinMismatch =>
      _t('PIN hazilingani. Anza upya.', "The PINs don't match. Start again.");
  String get pinWeak => _t('Chagua PIN isiyo rahisi kukisia.',
      'Choose a PIN that is harder to guess.');
  String get pinChanged => _t('PIN imebadilishwa', 'PIN changed');
  String get forgotPinTitle => _t('Umesahau PIN?', 'Forgot your PIN?');
  String get forgotPinBody => _t(
      'Mwombe msimamizi wako namba mpya ya uthibitisho, kisha uchague PIN mpya.',
      'Ask your supervisor for a new code, then choose a new PIN.');
  String get haveCode => _t('Nina namba ya uthibitisho', 'I have a code');
  String get suspendedTitle => _t('Akaunti imesimamishwa', 'Account suspended');
  String get suspendedBody =>
      _t('Wasiliana na msimamizi wako.', 'Contact your supervisor.');
  String get startOver => _t('Rudi mwanzo', 'Start again');

  // Sign-in failures: calm, specific, never technical.
  String get errNotConfigured => _t(
      'Huduma ya kuingia bado haipatikani.', 'Sign-in is not available yet.');
  String get errService => _t(
      'Huduma ina tatizo kwa sasa. Intaneti yako iko sawa; jaribu tena baadaye.',
      'The service has a problem right now. Your internet is fine; try again later.');
  String get errOffline => _t(
      'Hakuna intaneti. Unganisha simu kisha ujaribu tena.',
      'No internet. Connect and try again.');
  String get errUnknownPhone => _t('Namba hii haijasajiliwa kama muuzaji.',
      'This number is not registered as a vendor.');

  /// "PIN si sahihi." and, when the server says, the tries left; the PIN
  /// pad shows the second sentence in grey under the first.
  String errWrongPin(int? left) =>
      left == null ? pinWrong : '$pinWrong ${pinTriesLeft(left)}';
  String errLocked(DateTime? until) => until == null
      ? _t('Umekosea mara nyingi. Subiri kidogo kisha ujaribu.',
          'Too many attempts. Wait, then try again.')
      : _t('Umekosea mara nyingi. Jaribu tena saa ${hhmm(until)}.',
          'Too many attempts. Try again at ${hhmm(until)}.');
  String get errInvalidCode =>
      _t('Namba ya uthibitisho si sahihi.', 'That code is not valid.');
  String get errExpired => _t('Muda wa kuingia umeisha. Ingiza PIN tena.',
      'Your session ended. Enter your PIN again.');

  String failure(AuthFailure f) => switch (f.kind) {
        AuthFailureKind.notConfigured => errNotConfigured,
        AuthFailureKind.offline => f.serviceProblem ? errService : errOffline,
        AuthFailureKind.unknownPhone => errUnknownPhone,
        AuthFailureKind.wrongPin => errWrongPin(f.attemptsLeft),
        AuthFailureKind.locked => errLocked(f.retryAfter),
        AuthFailureKind.invalidCode => errInvalidCode,
        AuthFailureKind.weakPin => pinWeak,
        AuthFailureKind.suspended => suspendedTitle,
        AuthFailureKind.sessionExpired => errExpired,
      };

  // Dashboard.
  String get referenceTodaySales => _t('Mauzo leo', "Today's sales");
  String get mpesaShort => 'M-Pesa';
  String get tzs => 'TZS';
  String transactionCount(int n) => _t('Miamala $n', '$n transactions');
  String get recordSale => _t('Rekodi mauzo', 'Record sale');
  String get referenceReceive => _t('Pokea bidhaa', 'Receive goods');
  String get referenceDamaged => _t('Vimeharibika', 'Damaged');
  String get referenceCloseDay => _t('Funga siku', 'Close the day');
  String get referenceRecentSales => _t('Mauzo ya karibuni', 'Recent sales');
  String get referenceNoSales => _t('Hakuna mauzo bado', 'No sales yet');
  String get myStock => _t('Stoo yangu', 'My stock');
  String get stockQuantity => _t('Idadi', 'Quantity');
  String get unknownQuantity => _t('Idadi haijulikani', 'Quantity unknown');
  String stockUnit(String name) {
    final n = name.toLowerCase();
    if (n.contains('mishkaki')) return _t('mishkaki', 'skewers');
    if (n.contains('kidali') || n.contains('paja')) {
      return _t('robo', 'quarters');
    }
    if (n.contains('nusu')) return _t('nusu', 'halves');
    if (n.contains('kuku mzima')) return _t('kuku', 'chickens');
    if (n.contains('firigisi') || n.contains('shingo') || n.contains('ndizi')) {
      return _t('vipande', 'pieces');
    }
    return '';
  }

  String get welcome => _t('Karibu tena', 'Welcome back');
  String get todaySales => _t('Mauzo ya Leo', "Today's sales");
  String salesCount(int n) => _t('$n mauzo', n == 1 ? '1 sale' : '$n sales');
  String get market => _t('Sokoni', 'Stock');
  String get recentSales => _t('Mauzo ya hivi karibuni', 'Recent sales');
  String get seeAll => _t('Ona yote', 'See all');
  String get noSalesToday => _t('Hakuna mauzo leo bado', 'No sales yet today');
  String get offlineDashboard => _t(
      'Hakuna intaneti. Takwimu za leo zitaonekana ukiunganishwa.',
      "Offline. Today's figures appear once you are connected.");
  String paymentName(bool mpesa) => mpesa ? this.mpesa : cash;

  /// Cash, M-Pesa or credit (MN018); a credit sale names its customer.
  String paymentMethodName(String method, {String? customer}) =>
      switch (method) {
        'mpesa' => mpesa,
        'credit' => customer == null ? credit : creditSaleTo(customer),
        _ => cash,
      };

  // Yesterday's Funga Siku the next morning (owner decision 26 October 2026).
  String get closeYesterdayFirst =>
      _t('Funga siku ya jana kwanza', 'Close yesterday first');
  String closeYesterdayBody(String date) => _t(
      'Siku ya $date haikufungwa. Hesabu bidhaa zilizopo sasa kabla ya mauzo au mzigo wa leo; ofisi itaona imechelewa.',
      '$date was not closed. Count what is here now, before today\'s first sale or delivery; the office will see it was late.');
  String get closeYesterdayAction =>
      _t('Funga siku ya jana', 'Close yesterday');
  String yesterdayMissed(String date) => _t(
      'Siku ya $date haikufungwa, na kazi ya leo imeshaanza. Msimamizi atafungua kesi ya siku hii.',
      '$date was not closed and today\'s work has begun. A supervisor will open a case for this day.');
  String get yesterdayNotClosed =>
      _t('Siku ya jana haijafungwa', "Yesterday isn't closed");
  String yesterdayCloseCaption(String date) => _t(
      '$date · Funga kabla ya mauzo ya leo',
      "$date · Close it before today's sales");
  String yesterdayMissedCaption(String date) => _t(
      '$date · Msimamizi atafungua kesi ya siku hii',
      '$date · A supervisor will open a case for this day');
  String closeDayFor(String date) =>
      _t('Funga siku ya $date', 'Close the day of $date');

  // Credit customers (MN018, owner decisions 25 October 2026).
  String get credit => _t('Mkopo', 'Credit');
  String get creditCaption =>
      _t('Mteja wa mkopo atalipa baadaye', 'A credit customer pays later');
  String creditSaleTo(String name) => _t('Mkopo · $name', 'Credit · $name');
  String get creditCustomers => _t('Wateja wa mkopo', 'Credit customers');
  String get creditChooseCustomer => _t('Chagua mteja', 'Choose the customer');
  String get creditNoCustomers => _t(
      'Hakuna wateja wa mkopo kituoni. Ofisi ndiyo inawasajili.',
      'No credit customers at this station. The office registers them.');
  String creditOwes(String amount) => _t('Anadaiwa $amount', 'Owes $amount');
  String creditLimitOf(String amount) => _t('Kikomo $amount', 'Limit $amount');
  String get creditNoneOwed => _t('Hakuna deni', 'Nothing owed');
  String get creditNoLimit =>
      _t('Ofisi haijaweka kikomo: hawezi kukopa', 'No limit set: no credit');
  String get creditSuspended =>
      _t('Amesimamishwa: hawezi kukopa', 'Suspended: no credit');
  String creditOverLimit(String name, String after, String limit) => _t(
      '$name atadaiwa $after, zaidi ya kikomo cha $limit. Mauzo yatahifadhiwa na ofisi itakagua.',
      '$name will owe $after, over the $limit limit. The sale is saved and the office will review it.');
  String get creditCustomerRequired =>
      _t('Chagua mteja wa mkopo.', 'Choose the credit customer.');
  String get creditRecordRepayment => _t('Pokea malipo', 'Record a repayment');
  String get creditRepaymentAmount => _t('Kiasi alicholipa', 'Amount paid');
  String get creditRepaymentHow => _t('Amelipaje?', 'How did they pay?');
  String get creditRepaymentCashNote => _t(
      'Taslimu itaongezwa kwenye fedha unazokabidhi ofisini.',
      'Cash is added to the money you hand over.');
  String get creditRepaymentSaved =>
      _t('Malipo yamehifadhiwa kwenye simu.', 'Repayment saved on the phone.');
  String creditRepaymentTooMuch(String owed) => _t(
      'Kiasi kisizidi anachodaiwa ($owed).', 'No more than they owe ($owed).');
  String creditUnsent(int n) => _t('Rekodi $n bado hazijatumwa ofisini',
      '$n records not sent to the office yet');
  String get creditTotalOwed => _t('Jumla wanayodaiwa', 'Total owed');
  String creditLastSale(String date) =>
      _t('Mkopo wa mwisho: $date', 'Last credit: $date');

  // Credit customers in the office.
  String get creditAddCustomer => _t('Sajili mteja', 'Register a customer');
  String get creditCustomerName => _t('Jina la mteja', 'Customer name');
  String get creditCustomerPhone => _t('Simu (si lazima)', 'Phone (optional)');
  String get creditCustomerNote => _t('Maelezo (si lazima)', 'Note (optional)');
  String get creditLimit => _t('Kikomo cha mkopo', 'Credit limit');
  String get creditLimitNotSet => _t('Hakijawekwa', 'Not set');
  String get creditLimitHelp => _t(
      'Bila kikomo mteja hawezi kukopa. Deni lililopo linabaki.',
      'Without a limit the customer cannot take credit. What is owed stays owed.');
  String get creditRemoveLimit => _t('Ondoa kikomo', 'Remove the limit');
  String get creditLimitOwnerOnly => _t(
      'Mmiliki pekee ndiye anaweka kikomo.', 'Only the owner sets the limit.');
  String get creditStatus => _t('Hali', 'Status');
  String get creditActive => _t('Anaruhusiwa', 'Allowed');
  String get creditSuspend => _t('Simamisha mkopo', 'Suspend credit');
  String get creditReactivate => _t('Ruhusu tena', 'Allow again');
  String get creditOwed => _t('Anadaiwa', 'Owes');
  String get creditSold => _t('Mauzo ya mkopo', 'Credit sales');
  String get creditRepaid => _t('Amelipa', 'Repaid');
  String get creditWrittenOff => _t('Deni lililofutwa', 'Written off');
  String get creditOfficeRepayment =>
      _t('Rekodi malipo ofisini', 'Record a repayment at the office');
  String get creditReverse => _t('Batilisha', 'Reverse');
  String get creditReverseTitle =>
      _t('Batilisha malipo haya', 'Reverse this repayment');
  String get creditReversed => _t('Imebatilishwa', 'Reversed');
  String get creditWriteOff => _t('Futa deni (hasara)', 'Write off (loss)');
  String get creditWriteOffHelp => _t(
      'Biashara inabeba hasara hii; muuzaji hadaiwi.',
      'The business carries this loss; the vendor is not charged.');
  String get creditWriteOffAmount =>
      _t('Kiasi cha kufuta', 'Amount to write off');
  String get creditHistory => _t('Historia', 'History');
  String get creditNoHistory => _t('Hakuna kumbukumbu bado', 'Nothing yet');
  String creditEntry(String kind) => switch (kind) {
        'sale' => _t('Mauzo ya mkopo', 'Credit sale'),
        'repayment' => _t('Malipo', 'Repayment'),
        'reversal' => _t('Marekebisho ya malipo', 'Repayment reversed'),
        'write_off' => _t('Deni limefutwa', 'Written off'),
        _ => kind,
      };
  String creditBy(String name) => _t('Na $name', 'By $name');
  String creditCashRepaid(String amount) => _t(
      'Malipo ya mkopo (taslimu): $amount', 'Credit repaid in cash: $amount');
  String creditSalesNotCash(String amount) => _t(
      'Mauzo ya mkopo: $amount (si fedha taslimu)',
      'Credit sales: $amount (not cash)');
  String get creditSaved => _t('Imehifadhiwa ofisini.', 'Saved on the server.');

  // Catalogue and cart.
  String get all => _t('Zote', 'All');
  String category(String code) => switch (code) {
        'kuku' => 'Kuku',
        'vyakula' => _t('Vyakula', 'Food'),
        _ => _t('Mengine', 'Other'),
      };
  String get noPrice => _t('Bei haijawekwa', 'No price set');
  String get catalogOffline => _t(
      'Bidhaa zitaonekana simu ikiunganishwa na ofisi.',
      'Products appear once the phone is connected to the office.');
  String get catalogNothingReceived => _t(
      'Kituo hakina bidhaa za kuuza. Bidhaa zitaonekana ukishapokea mzigo.',
      'The station has nothing to sell. Products appear once a delivery is received.');
  String get cart => _t('Kikapu', 'Cart');
  String get clearCart => _t('Futa zote', 'Clear all');
  String get clearCartConfirm =>
      _t('Futa bidhaa zote kwenye kikapu?', 'Remove everything from the cart?');
  String get clearYes => _t('Ndiyo, futa', 'Yes, clear');
  String get addMore => _t('Ongeza bidhaa', 'Add products');
  String get total => _t('Jumla', 'Total');
  String get howPaid => _t('Aina ya malipo', 'How the customer paid');
  String get cashCaption =>
      _t('Nimepokea pesa kutoka kwa mteja', 'I received the money');
  String mpesaCaption(String number) =>
      _t('Mteja amelipia $number', 'Customer paid $number');
  String get mpesaMissing => _t('Namba ya malipo haijawekwa na ofisi',
      'The office has not set the payment number');
  String get handOverAfterPay => _t('Toa bidhaa baada ya kupokea pesa.',
      'Hand over the goods only after you have the money.');
  String get saveSale => _t('Hifadhi mauzo', 'Save sale');
  String get choosePayment =>
      _t('Chagua aina ya malipo', 'Choose how the customer paid');
  String lowStock(String name) => _t(
      'Huna $name wa kutosha kwenye rekodi.', 'Records show not enough $name.');
  String get lowStockNote => _t('Mauzo yatahifadhiwa; ofisi itakagua idadi.',
      'The sale is still saved; the office will check the count.');
  String get saveFailed => _t('Mauzo hayakuhifadhiwa. Jaribu tena.',
      'The sale was not saved. Try again.');
  String get saveNotDone =>
      _t('Haikuhifadhiwa. Jaribu tena.', 'Not saved. Try again.');
  String get moreActions => _t('Zaidi', 'More');
  String quantityFor(String name) => _t('Idadi ya $name', 'Quantity of $name');
  String get setQuantity => _t('Weka idadi', 'Set quantity');
  String added(String name) => _t('$name imeongezwa', '$name added');

  // Sale saved.
  String get saleSaved => _t('MAUZO YAMEHIFADHIWA!', 'SALE SAVED!');
  String itemsAt(int n, DateTime t) => _t('Bidhaa $n · ${hhmm(t)} · ${date(t)}',
      '$n items · ${hhmm(t)} · ${date(t)}');
  String get recordAnother => _t('Rekodi Mauzo Mengine', 'Record another sale');
  String get backHome => _t('Rudi Nyumbani', 'Back home');

  // History.
  String get historyTitle => _t('Historia ya mauzo', 'Sales history');
  String get yesterday => _t('Jana', 'Yesterday');
  static const _weekdays = [
    'Jumatatu', 'Jumanne', 'Jumatano', 'Alhamisi', 'Ijumaa', //
    'Jumamosi', 'Jumapili',
  ];
  static const _weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String dayChip(DateTime day, int daysAgo) => switch (daysAgo) {
        0 => _t('Leo', 'Today'),
        1 => yesterday,
        _ =>
          '${(isSwahili ? _weekdays : _weekdaysEn)[day.weekday - 1]} ${day.day}',
      };
  String get dayTotal => _t('Jumla ya mauzo', 'Total sales');
  String get recordedHere => _t(
      'Mauzo yaliyorekodiwa kwenye simu hii', 'Sales recorded on this phone');
  String get noSalesDay => _t('Hakuna mauzo siku hii', 'No sales this day');
  String moreProducts(int n) => '+$n';
  String get statusVoided => _t('Yamebatilishwa', 'Voided');
  String get statusVoidPending =>
      _t('Yamebatilishwa · inasubiri ofisi', 'Voided · waiting for the office');
  String get statusVerified => _t('Imethibitishwa', 'Verified');

  // Short forms for the compact history rows.
  String get statusWaitingShort => _t('Inasubiri', 'Waiting');
  String get statusSentShort => _t('Imetumwa', 'Sent');

  // Sale details and voids.
  String get saleDetails => _t('Maelezo ya mauzo', 'Sale details');
  String get reference => _t('Kumbukumbu', 'Reference');
  String get recordedAt => _t('Muda', 'Time');
  String get paymentLabel => _t('Malipo', 'Payment');
  String get verification => _t('Uthibitisho', 'Verification');
  String get unverified => _t('Haijathibitishwa', 'Not verified yet');
  String get verifiedByOffice =>
      _t('Imethibitishwa na ofisi', 'Verified by the office');
  String qtyTimesPrice(int qty, String price) => '$qty × $price';
  String get voidAction => _t('Batilisha mauzo haya', 'Void this sale');
  String get voidReasonTitle => _t('Sababu ya kubatilisha', 'Reason');
  String voidReason(String code) => switch (code) {
        'wrong_quantity' => _t('Idadi si sahihi', 'Wrong quantity'),
        'wrong_product' => _t('Bidhaa si sahihi', 'Wrong product'),
        'customer_cancelled' => _t('Mteja ameghairi, bidhaa zimerudi',
            'Customer cancelled, goods returned'),
        'duplicate' => _t('Yamerekodiwa mara mbili', 'Recorded twice'),
        _ => _t('Sababu nyingine', 'Other reason'),
      };
  String get continueAction => _t('Endelea', 'Continue');
  String get voidConfirmTitle => _t('Batilisha mauzo haya?', 'Void this sale?');
  String get voidConfirmBody => _t(
      'Mauzo yatawekewa alama kuwa yamebatilishwa. Hayatafutwa kabisa; ofisi itaona sababu.',
      'The sale is marked void, not deleted, and the office sees the reason.');
  String get voidYes => _t('Ndiyo, batilisha', 'Yes, void');
  String voidedAt(DateTime t, String reason) => _t(
      'Yamebatilishwa saa ${hhmm(t)} · $reason',
      'Voided at ${hhmm(t)} · $reason');
  String get voidWaiting => _t(
      'Ombi la kubatilisha linasubiri kutumwa ofisini.',
      'The void is waiting to be sent to the office.');
  String voidRejected(String? reason) => reason == 'already_verified'
      ? _t(
          'Mauzo yamethibitishwa, kwa hiyo hayawezi kubatilishwa kwenye simu. Mwambie msimamizi wako.',
          'The sale is verified, so it cannot be voided on the phone. Tell your supervisor.')
      : _t('Ofisi haikukubali kubatilisha mauzo haya.',
          'The office did not accept this void.');
  String get verifiedLocked => _t(
      'Mauzo yaliyothibitishwa hubadilishwa na ofisi tu.',
      'Only the office can change a verified sale.');
  String get notTodayLocked => _t(
      'Mauzo ya siku zilizopita hayawezi kubatilishwa kwenye simu.',
      "Earlier days' sales cannot be voided on the phone.");
  String get voidDone => _t('Mauzo yamebatilishwa', 'Sale voided');
  String get voidFailed => _t('Mauzo hayakubatilishwa. Jaribu tena.',
      'The sale was not voided. Try again.');

  // Receiving.
  String get pendingTab => _t('Zinazosubiri', 'Waiting');
  String get receivedTab => _t('Zilizopokelewa', 'Received');
  String get noReceived =>
      _t('Bado hujapokea mzigo wowote', 'Nothing received yet');
  String fromTo(String from, String to) => '$from → $to';
  String kindsAndUnits(int kinds, int units) =>
      _t('Aina $kinds · Vipande $units', '$kinds products · $units units');
  String get statusAwaitingReceipt =>
      _t('Inasubiri kupokelewa', 'Waiting to be received');
  String get statusAcceptedByOffice =>
      _t('Imepokelewa ofisini', 'Received by the office');
  String get statusNeedsReview => _t('Inahitaji ukaguzi', 'Needs review');
  String get statusRefused => _t('Imekataliwa', 'Refused');
  String get statusOtherStation => _t('Kituo kingine', 'Another station');
  String get deliveryDetails => _t('Maelezo ya mzigo', 'Delivery');
  String get statusLabel => _t('Hali', 'Status');
  String get sentFrom => _t('Kutoka', 'From');
  String get dispatchedOn => _t('Ilitumwa', 'Dispatched');
  String dispatchedCount(int n) => _t('Zimetumwa: $n', 'Dispatched: $n');
  String get receivedLabel => _t('Umepokea', 'Received');
  String receivedCount(int n) => '$receivedLabel: $n';
  String get receivedAll => _t('Nimepokea', 'Received all');
  String get differentCount => _t('Idadi tofauti', 'Different count');
  String get confirmReceipt => _t('Thibitisha upokeaji', 'Confirm receipt');
  String get confirmAllTitle => _t('Umepokea bidhaa zote kama zilivyotumwa?',
      'Did everything arrive as dispatched?');
  String get confirmCountTitle =>
      _t('Thibitisha hesabu yako?', 'Confirm your count?');
  String get confirmReceiptBody => _t(
      'Hesabu yako itatumwa ofisini. Bidhaa zitaongezwa kwenye hesabu yako baada ya kutumwa ofisini.',
      'Your count goes to the office. Stock is added once it has been sent to the office.');
  String get yesConfirm => _t('Ndiyo, thibitisha', 'Yes, confirm');
  String get discrepancyTitle =>
      _t('Sababu ya tofauti', 'Reason for the difference');
  String get chooseReason => _t('Chagua sababu', 'Choose a reason');
  String discrepancy(String code) => switch (code) {
        'short' => _t('Hazikufika (zimepungua)', 'Did not arrive (short)'),
        'damaged' => _t('Zimeharibika', 'Damaged'),
        'wrong_product' => _t('Bidhaa si sahihi', 'Wrong product'),
        _ => _t('Sababu nyingine', 'Other reason'),
      };
  String get enterCount => _t('Weka idadi uliyopokea', 'Enter the count');
  String get wrongStationNote => _t(
      'Mzigo huu si wa kituo chako. Huwezi kuupokea.',
      'This delivery is for another station. You cannot receive it.');
  String get conflictNote => _t(
      'Orodha ya mzigo ilibadilika baada ya kuhesabu. Ofisi itakagua; hesabu yako haijabadilishwa.',
      'The delivery list changed after your count. The office will review; your count is unchanged.');
  String get refusedNote => _t(
      'Ofisi haikukubali hesabu hii.', 'The office did not accept this count.');
  String get stockAfterAcceptance => _t(
      'Bidhaa zitaongezwa kwenye hesabu yako baada ya kutumwa ofisini.',
      'Stock is added once your count has been sent to the office.');
  String get acceptedNote => _t('Hesabu yako imepokelewa ofisini.',
      'Your count has been received by the office.');
  String receiptBlock(String code) => switch (code) {
        'missingReason' => _t('Chagua sababu kwa kila tofauti.',
            'Choose a reason for each difference.'),
        'aboveDispatched' => _t('Huwezi kupokea zaidi ya zilizotumwa.',
            'You cannot receive more than was dispatched.'),
        'nothingReceived' =>
          _t('Hesabu haina bidhaa yoyote.', 'The count has no goods in it.'),
        'wrongStation' => wrongStationNote,
        'manifestChanged' => _t('Orodha ya mzigo imebadilika. Fungua tena.',
            'The delivery list changed. Open it again.'),
        'alreadyReceived' => _t(
            'Mzigo huu umeshapokelewa.', 'This delivery was already received.'),
        _ => _t('Hesabu si sahihi.', 'The count is not valid.'),
      };
  String get receiptSaved => _t('Upokeaji umehifadhiwa', 'Receipt saved');
  String receivedOf(int got, int sent) =>
      _t('Umepokea $got kati ya $sent', 'Received $got of $sent');
  String get backToList => _t('Rudi kwenye orodha', 'Back to the list');

  // Damage reports.
  String get reportDamage =>
      _t('Ripoti bidhaa iliyoharibika', 'Report damaged goods');
  String get chooseProduct => _t('Chagua bidhaa', 'Choose the product');
  String get damagedQuantity =>
      _t('Idadi iliyoharibika', 'How many are damaged');
  String get damageReasonTitle => _t('Sababu', 'Reason');
  String damageReason(String code) => switch (code) {
        'spoiled' => _t('Imeharibika', 'Spoiled'),
        'burnt' => _t('Imeungua', 'Burnt'),
        'spilled' => _t('Imemwagika', 'Spilled'),
        _ => _t('Sababu nyingine', 'Other reason'),
      };
  String get noteOptional => _t('Maelezo (si lazima)', 'Note (optional)');
  String get reviewReport => _t('Kagua ripoti', 'Check the report');
  String get submitReport => _t('Hifadhi ripoti', 'Save report');
  String get reportSaved => _t('Ripoti imehifadhiwa.', 'Report saved.');
  String get reportNotLoss => _t(
      'Ofisi itakagua ripoti hii kabla ya kuihesabu kama hasara.',
      'The office checks this report before counting it as a loss.');
  String get similarTitle => _t('Ripoti kama hii imehifadhiwa sasa hivi',
      'A report like this was just saved');
  String get similarBody =>
      _t('Hifadhi ripoti nyingine?', 'Save another report?');
  String get saveAnother => _t('Ndiyo, hifadhi', 'Yes, save');
  String get anotherReport => _t('Ripoti nyingine', 'Another report');
  String get enterDamaged =>
      _t('Weka idadi iliyoharibika.', 'Enter how many are damaged.');
  String get noDamageReports =>
      _t('Hakuna ripoti za uharibifu', 'No damage reports');
  String damageStatus(bool sent, String review) => switch (review) {
        'verified' => _t('Imethibitishwa na ofisi', 'Verified by the office'),
        'rejected' =>
          _t('Haikukubaliwa na ofisi', 'Not accepted by the office'),
        _ => sent
            ? _t('Inasubiri ofisi', 'Waiting for the office')
            : _t('Inasubiri kutumwa', 'Waiting to be sent'),
      };

  // Funga Siku.
  String get countTitle => _t('Hesabu bidhaa zilizobaki', 'Count what is left');
  String recordedLabel(int n) => _t('Rekodi: $n', 'Records: $n');
  String get notCounted => '—';
  String get countAllFirst =>
      _t('Hesabu bidhaa zote kwanza.', 'Count every product first.');
  String get reviewCount => _t('Hakiki hesabu', 'Check the count');
  String get saveAndClose =>
      _t('Hifadhi na funga siku', 'Save and close the day');
  String get closeConfirmTitle =>
      _t('Funga siku kwa hesabu hii?', 'Close the day with this count?');
  String get closeConfirmBody => _t(
      'Hesabu haiwezi kubadilishwa kwenye simu baada ya kuhifadhiwa. Marekebisho hufanywa na ofisi.',
      'The count cannot be changed on the phone once saved. The office makes corrections.');
  String get closeYes => _t('Ndiyo, funga siku', 'Yes, close the day');
  String get skip => _t('Ruka', 'Skip');
  String get dayClosedLead => _t('SIKU', 'DAY');
  String get dayClosedTail => _t('IMEFUNGWA!', 'CLOSED!');
  String get finalCountSaved => _t('Hesabu ya mwisho imehifadhiwa kwenye simu.',
      'The final count is saved on the phone.');
  String get countSavedOnPhone =>
      _t('Hesabu imehifadhiwa kwenye simu.', 'Count saved on the phone.');
  String get waitingToSend => _t('Inasubiri kutumwa.', 'Waiting to be sent.');
  String get sentToOffice => _t('Imetumwa ofisini.', 'Sent to the office.');
  String get awaitingOfficeCheck => _t(
      'Inasubiri uthibitisho wa ofisi.', 'Waiting for the office to confirm.');
  String get confirmedByOffice =>
      _t('Imethibitishwa na ofisi.', 'Confirmed by the office.');
  String get closingOnlyCount => _t(
      'Funga Siku hurekodi hesabu tu. Mauzo, pesa na bidhaa hukaguliwa na ofisi kando.',
      'Funga Siku records the count only. Sales, money and stock are checked by the office separately.');
  String get correctionsByOffice => _t(
      'Marekebisho ya hesabu hufanywa na ofisi.',
      'Count corrections are made by the office.');
  String get todayCountSaved =>
      _t('Hesabu ya leo imehifadhiwa', "Today's count is saved");

  // Sync.
  String get syncTitle => _t('Usawazishaji', 'Sync');
  String get syncAttention => _t('Inahitaji ukaguzi', 'Needs review');
  String get syncNow => _t('Sawazisha sasa', 'Sync now');
  String queuedCount(int n) =>
      _t('Kumbukumbu $n zinasubiri kutumwa', '$n records waiting to be sent');
  String get allSent =>
      _t('Kumbukumbu zote zimetumwa ofisini', 'Everything has been sent');
  String get needsReviewTitle => _t('Zinahitaji ukaguzi', 'Need review');
  String lastAttempt(DateTime t) =>
      _t('Jaribio la mwisho: ${hhmm(t)}', 'Last attempt: ${hhmm(t)}');
  String syncOutcome(String code) => switch (code) {
        'ok' => _t('Imefanikiwa', 'Succeeded'),
        'offline' => _t('Hakuna intaneti', 'No internet'),
        'not_configured' => _t('Huduma ya kutuma bado haipatikani',
            'Sending is not available yet'),
        'session_expired' => _t('Ingiza PIN tena', 'Enter your PIN again'),
        _ => _t('Imeshindikana', 'Did not succeed'),
      };
  String operationName(String type) => switch (type) {
        'sale' => _t('Mauzo', 'Sale'),
        'sale_void' => _t('Kubatilisha mauzo', 'Sale void'),
        'receipt' => _t('Upokeaji wa mzigo', 'Delivery receipt'),
        'damage_report' => _t('Ripoti ya uharibifu', 'Damage report'),
        'closing_count' => _t('Hesabu ya Funga Siku', 'Closing count'),
        'expense' => moneyExpenses,
        _ => type,
      };

  /// One calm sentence per known server reason; the office sees details.
  ///
  /// Only a `conflict` promises an office review; a `rejected` record is not
  /// counted and the vendor is told to speak to the supervisor.
  String operationProblem(String type, String? reason, {String? status}) {
    // Not the vendor's mistake: the station's count exists and the day is
    // closed, so nothing waits for the office.
    if (reason == 'station_counted') {
      return '$closingStationCounted '
          '${_t('Siku yako imefungwa.', 'Your day is closed.')}';
    }
    // The office reviewed it and refused it for good: nothing waits.
    if (reason == 'office_rejected') {
      return _t('Ofisi imekagua na kuikataa kumbukumbu hii. Haihesabiwi.',
          'The office reviewed this record and refused it. It does not count.');
    }
    return switch (reason) {
          'already_verified' => _t(
              'Mauzo yalishathibitishwa kabla ombi halijafika.',
              'The sale was verified before this arrived.'),
          'future_date' => _t(
              'Tarehe ya mauzo iko mbele ya leo. Ofisi itakagua kumbukumbu hii.',
              'The sale date is in the future. The office will review this record.'),
          'manifest_changed' => _t(
              'Orodha ya mzigo ilibadilika kabla hesabu haijafika.',
              'The delivery list changed before your count arrived.'),
          'already_closed' => _t(
              'Hesabu ya leo tayari ilitumwa kutoka simu nyingine.',
              "Today's count was already sent from another phone."),
          'day_moved_on' => _t(
              'Kazi ya leo ilikuwa imeshaanza kituoni, kwa hiyo siku ya jana haiwezi kuhesabiwa tena.',
              "Today's work had already begun at the station, so yesterday can no longer be counted."),
          'unknown_customer' => _t('Mteja huyu hayupo kwenye orodha ya kituo.',
              'This customer is not on the station list.'),
          'unknown_item' => _t('Kitu hiki hakipo kwenye orodha ya ofisi.',
              'This item is not on the office list.'),
          'item_required' =>
            _t('Andika kilichonunuliwa.', 'Write what was bought.'),
          'unknown_category' => _t(
              'Aina hii ya gharama haipo kwenye mipangilio ya ofisi.',
              'This expense category is not configured by office.'),
          'not_assigned' => _t(
              'Ofisi inahitaji kuthibitisha kituo chako kwa tarehe hii.',
              'Office must confirm your station assignment for this date.'),
          'wrong_station' => _t('Si ya kituo chako.', 'Not for your station.'),
          _ => _t('Ofisi haikukubali kumbukumbu hii.',
              'The office did not accept this record.'),
        } +
        (status == 'conflict'
            ? _t(' Imehifadhiwa kwenye simu; ofisi itakagua.',
                ' It is kept on the phone; the office will review it.')
            : _t(' Haihesabiwi. Mwambie msimamizi wako.',
                ' It does not count. Tell your supervisor.'));
  }

  String get statusSaleRefused => _t('Haikukubaliwa', 'Not accepted');
  String logoutUnsent(int n) => _t(
      'Kumbukumbu $n bado hazijatumwa. Zitabaki kwenye simu na kutumwa ukiingia tena.',
      '$n records are not sent yet. They stay on the phone and are sent when you sign in again.');
  String get closingConflict =>
      _t('Inahitaji ukaguzi wa ofisi.', 'Needs the office to review.');

  /// Another vendor at the same kituo already sent today's count; the
  /// station's count exists and this vendor's day is closed.
  String get closingStationCounted => _t(
      'Kituo kimeshahesabiwa leo na muuzaji mwenzako.',
      "Another vendor at this station already counted today's stock.");

  // Language (a setting; Swahili by default).
  String get language => _t('Lugha', 'Language');

  /// Each language is named in itself, whatever the app's language.
  String languageName(String code) => switch (code) {
        'en' => 'English',
        _ => 'Kiswahili',
      };

  // Profile.
  String get station => _t('Kituo', 'Station');
  String get phone => _t('Simu', 'Phone');
  String get syncInfo => _t('Usawazishaji', 'Sync');
  String get changePin => _t('Badilisha PIN', 'Change PIN');
  String get recordDetails => _t('Maelezo zaidi', 'More details');
  String get help => _t('Msaada', 'Help');
  String get helpBody => _t(
      'Kwa msaada wowote, wasiliana na msimamizi wako wa kituo.',
      'For any help, contact your station supervisor.');
  String get close => _t('Funga', 'Close');
  String get accountBusiness => _t('Biashara', 'Business');
  String get accountSettings => _t('Mipangilio', 'Settings');
  String get changeProfilePhoto =>
      _t('Badilisha picha ya akaunti', 'Change profile photo');
  String get damagePhoto => _t(
      'Ongeza picha ya uharibifu (si lazima)', 'Add a damage photo (optional)');
  String get damagePhotoUnavailable =>
      _t('Picha haipatikani kwa sasa.', 'Photo is not available right now.');
  String get accountLanguageCaption =>
      _t('Badili lugha ya programu', 'Change app language');
  String get accountVendorCaption => _t(
      'Ingia kama muuzaji kwenye simu hii', 'Sign in a vendor on this device');
  String get accountPaymentsCaption =>
      _t('Simamia malipo ya wauzaji', 'Manage vendor payments');
  String get accountBooksCaption =>
      _t('Akaunti na ripoti', 'Accounts and reports');
  String get accountExpensesCaption =>
      _t('Fuatilia matumizi', 'Track spending');
  String get accountSignOutBody => _t(
      'Utahitaji kuingia tena ili kutumia akaunti hii.',
      'You will need to sign in again to use this account.');
  String get accountSignOutFailed => _t(
      'Imeshindikana kutoka. Jaribu tena.', 'Could not sign out. Try again.');
  String get logout => _t('Toka kwenye akaunti', 'Sign out');
  String get logoutConfirm => _t('Toka kwenye akaunti?', 'Sign out?');
  String get logoutBody => _t(
      'Utahitaji namba yako ya simu na PIN kuingia tena.',
      'You will need your phone number and PIN to sign in again.');
  String get logoutYes => _t('Ndiyo, toka', 'Yes, sign out');
  String get stay => _t('Hapana', 'No');

  // Dates and times.
  static const _months = [
    'Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', //
    'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  static const _monthsEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  String date(DateTime d) =>
      '${d.day} ${(isSwahili ? _months : _monthsEn)[d.month - 1]} ${d.year}';
  String today(DateTime d) => _t('Leo, ${date(d)}', 'Today, ${date(d)}');
  String monthShort(int month) => (isSwahili ? _months : _monthsEn)[month - 1];

  // Date and time sheets (the app's own, never the platform pickers).
  static const _monthNames = [
    'Januari', 'Februari', 'Machi', 'Aprili', 'Mei', 'Juni', //
    'Julai', 'Agosti', 'Septemba', 'Oktoba', 'Novemba', 'Desemba',
  ];
  static const _monthNamesEn = [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// Weekday initials for the date sheet, Monday first.
  List<String> get weekdayInitials => isSwahili
      ? const ['Jt', 'Jn', 'Jtn', 'Alh', 'Ij', 'Jm', 'Jp']
      : const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
  String monthYear(DateTime d) =>
      '${(isSwahili ? _monthNames : _monthNamesEn)[d.month - 1]} ${d.year}';
  String get previousMonth => _t('Mwezi uliopita', 'Previous month');
  String get nextMonth => _t('Mwezi ujao', 'Next month');
  String get useThisDate => _t('Tumia tarehe hii', 'Use this date');
  String get chooseDateRange => _t('Chagua kipindi', 'Choose a period');
  String get dateRangeHint => _t('Gusa siku ya kwanza, kisha ya mwisho.',
      'Tap the first day, then the last.');
  String get useThisPeriod => _t('Tumia kipindi hiki', 'Use this period');
  String get chooseTime => _t('Chagua muda', 'Choose a time');
  String get hourLabel => _t('Saa', 'Hour');
  String get minuteLabel => _t('Dakika', 'Minutes');
  String get useThisTime => _t('Tumia muda huu', 'Use this time');

  // PIN.
  String get enterPin => _t('Ingiza PIN yako', 'Enter your PIN');
  String pinDigits(int filled, int length) =>
      _t('Tarakimu $filled kati ya $length', '$filled of $length digits');

  // States.
  String get loading => _t('Inapakia', 'Loading');
  String get selectPlaceholder => _t('Chagua', 'Choose');
  String get nothingToChoose =>
      _t('Hakuna cha kuchagua bado.', 'Nothing to choose yet.');
  String get noInternetTitle => _t('Hakuna intaneti', 'No internet connection');
  String get noInternetBody => _t(
      'Unganisha intaneti, kisha vuta chini kuonyesha upya.',
      'Connect to the internet, then pull down to refresh.');
  String get errorTitle => _t('Imeshindikana', 'Something went wrong');
  String get errorBody =>
      _t('Jaribu tena baada ya muda mfupi.', 'Try again in a moment.');
  String get noProducts => _t('Hakuna bidhaa bado', 'No products yet');
  String get noSales => _t('Hakuna mauzo bado', 'No sales yet');
  String get noDeliveries =>
      _t('Hakuna bidhaa zinazosubiri', 'No deliveries waiting');
  String get noDamage => _t('Hakuna bidhaa za kuripoti', 'Nothing to report');
  String get noCount => _t('Hakuna bidhaa za kuhesabu', 'Nothing to count');
  String get notConnected => _t('Itaonekana hapa simu ikiunganishwa na ofisi.',
      'This appears once the phone is connected to the office.');
  String get profileEmpty =>
      _t('Maelezo yako yataonekana hapa.', 'Your details will appear here.');

  String get manageProducts => _t('Bidhaa na bei', 'Products and prices');
  String get productName => _t('Jina la bidhaa', 'Product name');
  String get productCategory => _t('Kundi la bidhaa', 'Category');
  String get productUnit => _t('Kipimo', 'Unit');
  String unitName(String unit) => switch (unit) {
        'bird' => _t('Kuku', 'Bird'),
        'piece' => _t('Kipande', 'Piece'),
        'portion' => _t('Sehemu', 'Portion'),
        'tray' => _t('Trei', 'Tray'),
        'kg' => _t('Kilogramu', 'Kilogram'),
        // An added unit; before its name loads, its code reads as words.
        _ => addedUnits[unit]?.name ??
            unit
                .replaceAll('_', ' ')
                .replaceFirstMapped(RegExp('^.'), (m) => m[0]!.toUpperCase())
      };
  String get uploadPhoto => _t('Chagua picha', 'Choose photo');
  String get removePhoto => _t('Ondoa picha', 'Remove photo');
  String get photoHelp => _t('JPEG, PNG au WebP. Ukubwa usizidi MB 5.',
      'JPEG, PNG or WebP, up to 5 MB.');
  String get photoFailed => _t(
      'Picha haikupakiwa. Chagua picha nyingine au jaribu tena.',
      'Photo was not uploaded. Choose another image or try again.');
  String get productAvailable =>
      _t('Inaonekana kwa wauzaji', 'Visible to vendors');
  String get productActive => _t('Bidhaa inatumika', 'Product is active');
  String get changeReason => _t('Sababu ya mabadiliko', 'Reason for change');
  String get detailsInvalid => _t('Jaza maelezo na sababu (angalau herufi 3).',
      'Complete the details and a reason (at least 3 characters).');
  String get saveChanges => _t('Hifadhi mabadiliko', 'Save changes');
  String get changesSaved =>
      _t('Mabadiliko yamehifadhiwa ofisini.', 'Changes saved on the server.');
  String get defaultPrice => _t('Bei ya kawaida', 'Default price');
  String get stationPrices => _t('Bei kwa kila kituo', 'Prices by station');
  String get priceAmount => _t('Bei (TSh)', 'Price (TSh)');
  String get priceInvalid => _t(
      'Weka bei kamili kati ya TSh 1 na 100,000,000 pamoja na sababu.',
      'Enter a whole price from TSh 1 to 100,000,000 and a reason.');
  String get noPriceSet => _t('Bei haijawekwa', 'No price set');
  String get defaultPriceUsed =>
      _t('Inatumia bei ya kawaida', 'Uses default price');
  String get stationPriceUsed => _t('Bei maalumu ya kituo', 'Station override');
  String get priceHelp => _t(
      'Bei mpya itatumika wauzaji wakisasisha bidhaa. Mauzo ya awali yanabaki na bei iliyorekodiwa.',
      'New prices apply when vendors refresh their catalogue. Earlier sales retain their recorded prices.');
  String get workStations => _t('Vituo vya kazi', 'Work stations');
  String get workStationsHelp => _t(
      'Chagua vituo vya mfanyakazi. Ondoa cha zamani na uchague kipya ili kumhamisha.',
      'Select work stations. Deselect the old station and select a new one to transfer.');
  String get assignmentFailed => _t(
      'Mabadiliko hayakuhifadhiwa. Hakikisha kituo kinatumika na hakina msimamizi mwingine.',
      'Changes were not saved. Check the station is active and has no other supervisor.');
  String get productSaveFailed => _t('Mabadiliko hayakuhifadhiwa. Jaribu tena.',
      'Changes were not saved. Try again.');
  String get noOfficeProducts => _t('Hakuna bidhaa bado.', 'No products yet.');

  // Owner references approved 22 October 2026.
  String get ownerSummary => _t('Muhtasari', 'Overview');
  String get ownerToday => _t('Leo', 'Today');
  String get ownerAccount => _t('Akaunti', 'Account');
  String get ownerReports => _t('Ripoti', 'Reports');
  String get managementSetup => _t('Maandalizi', 'Setup');
  String get managementKitchen => _t('Jikoni', 'Kitchen');
  String get managementAdministration => _t('Utawala', 'Administration');
  String get managementAllHaveVendors =>
      _t('Vyote vina wauzaji', 'All have vendors');
  String get managementPendingReview =>
      _t('Zinazosubiri ukaguzi', 'Pending review');
  String get managementPendingCaption => _t(
      'Kumbukumbu za simu zinazosubiri ukaguzi wa ofisi',
      'Phone records waiting for office review');
  String managementPendingCount(int n) => _t('Zinasubiri $n', '$n pending');
  String moneyHoursSummary(int hours) => _t('Saa $hours', '$hours hours');
  String get managementNoStations => _t('Hakuna vituo', 'No stations');
  String get moneyExpenseCategories =>
      _t('Aina za gharama', 'Expense categories');
  String moneyCategoryCount(int n) => _t('Aina $n', '$n categories');
  String get moneySettingsSecurity => _t('Usalama', 'Security');

  String get ownerManagement => _t('Usimamizi', 'Management');
  String get ownerNotifications => _t('Arifa', 'Notifications');
  String get ownerSalesToday => _t('Mauzo leo', 'Sales today');
  String get ownerGrossProfit => _t('Faida ghafi', 'Gross profit');
  String get ownerSupervisorFunds => _t('Kwa msimamizi', 'With supervisor');
  String get ownerComparedYesterday => _t('kuliko jana', 'vs yesterday');
  String get ownerComparedDayBefore =>
      _t('kuliko siku iliyotangulia', 'vs the day before');
  String get ownerSalesYesterday => _t('Mauzo jana', 'Sales yesterday');
  String ownerSalesOn(DateTime d) =>
      _t('Mauzo ya ${dayMonth(d)}', 'Sales on ${dayMonth(d)}');
  String get ownerChooseDay => _t('Chagua siku', 'Choose a day');
  String dayMonth(DateTime d) =>
      '${d.day} ${(isSwahili ? _months : _monthsEn)[d.month - 1]}';
  String get ownerStationsOpen => _t('Vituo vilivyofunguliwa', 'Stations open');
  String ownerMoneyDifferences(String count) => _t(
      count == '1'
          ? 'Kituo 1 kina tofauti za fedha'
          : 'Vituo $count vina tofauti za fedha',
      count == '1'
          ? '1 station has money differences'
          : '$count stations have money differences');
  String get ownerNoSalesYet => _t('Hakuna mauzo bado', 'No sales yet');
  String get ownerNoStationsOpen =>
      _t('Hakuna kituo kilichofunguliwa', 'No station has opened yet');
  String get ownerNoMoneyDifferences =>
      _t('Hakuna tofauti za fedha', 'No money differences');
  String get ownerMoneyDifferencesUnknown =>
      _t('Tofauti za fedha —', 'Money differences —');
  String ownerOpenStationsCount(int? open, int? total) => _t(
      '${open ?? '—'} / ${total ?? '—'} vimefunguliwa',
      '${open ?? '—'} / ${total ?? '—'} open');
  String get ownerReportsCaption =>
      _t('Mauzo, faida na zaidi', 'Sales, profits and more');
  String get ownerBonusesCaption =>
      _t('Zilizopatikana na makadirio', 'Earned and estimated');
  String get ownerPerformanceCaption =>
      _t('Alama na nyota', 'Scores and stars');
  String get ownerManagementCaption =>
      _t('Wafanyakazi, mipangilio na zana', 'Staff, settings and tools');
  String ownerUnassigned(int count) =>
      _t('Hawajapangiwa: $count', 'Unassigned: $count');
  String ownerUnpriced(int count) =>
      _t('Hazina bei: $count', 'Without a price: $count');
  String get ownerCurrency => 'TZS';
  String get ownerPriceColumn => _t('Bei (TZS)', 'Price (TZS)');
  String get ownerSetPrice => _t('Weka bei', 'Set price');
  String get ownerAssignStation => _t('Panga kituo', 'Assign station');
  String get ownerVendorActive => _t('Hai', 'Active');
  String get ownerVendorUnassigned => _t('hajapangiwa', 'unassigned');
  String get ownerAddVendorHint =>
      _t('Gusa + kuongeza muuzaji', 'Tap + to add a vendor');
  String get ownerAddStaffHint =>
      _t('Gusa + kusajili mfanyakazi', 'Tap + to register a staff member');
  String ownerStaffTotal(int? count) =>
      _t('Jumla: ${count ?? '—'}', 'Total: ${count ?? '—'}');
  String get ownerStationsCaption =>
      _t('Maeneo ya biashara', 'Business locations');
  String get ownerProductsCaption => _t('Menyu na bei', 'Menu and prices');
  String get ownerStaffCaption =>
      _t('Majukumu na ruhusa', 'Roles and permissions');
  String get ownerVendorsCaption => _t('Wanaouza vituoni', 'Station sellers');
  String get ownerAccountCaption =>
      _t('Wasifu na usalama', 'Profile and security');
  String ownerMissingVendors(int? n) =>
      _t('${n ?? '—'} bila muuzaji', '${n ?? '—'} without a vendor');
  String ownerMissingPrices(int? n) =>
      _t('${n ?? '—'} bila bei', '${n ?? '—'} without a price');
  String ownerStaffCount(int? n) => _t(
      '${n ?? '—'} ${n == 1 ? 'mfanyakazi' : 'wafanyakazi'}',
      '${n ?? '—'} staff');
  String ownerVendorCount(int? n) => _t(
      '${n ?? '—'} ${n == 1 ? 'muuzaji' : 'wauzaji'}', '${n ?? '—'} vendors');
  String ownerStationsWithoutVendor(int? n) =>
      _t('Bila muuzaji: ${n ?? '—'}', 'Without a vendor: ${n ?? '—'}');
  String get ownerAssignVendor => _t('Panga muuzaji', 'Assign vendor');
  String get ownerAddStationHint =>
      _t('Gusa + kuongeza kituo', 'Tap + to add a station');
  String get stationUnset => _t('Haijawekwa', 'Not set');
  String get stationAdd => _t('Ongeza', 'Add');
  String get stationAssignPerson => _t('Panga mtu kituoni', 'Assign a person');
  String get stationVendorRole => _t('Muuzaji', 'Vendor');
  String get stationVendorHint => _t('Anauza kituoni', 'Sells at this station');
  String get stationStaffHint => _t('Anasimamia kituo', 'Manages this station');
  String get stationRelationship =>
      _t('Uhusiano na kituo', 'Station relationship');
  String get stationRemovePerson =>
      _t('Ondoa kwenye kituo', 'Remove from station');
  String get stationRemoveCaption => _t(
      'Haitafuta akaunti au historia ya mauzo.',
      'The account and sales history will remain.');
  String stationRemoveTitle(String name, String station) =>
      _t('Ondoa $name kwenye $station?', 'Remove $name from $station?');
  String get stationRemoveBody => _t(
      'Atatolewa kwenye kituo hiki tu. Akaunti yake na historia ya mauzo itabaki salama.',
      'Only this station assignment will end. The account and sales history will remain safe.');
  String get personBasics => _t('Maelezo ya msingi', 'Basic information');
  String get personDuty => _t('Jukumu', 'Role');
  String get personStarted => _t('Alianza', 'Started');
  String get personFullProfile => _t('Wasifu kamili', 'Full profile');
  String get personMoreActions => _t('Chaguo zaidi', 'More options');
  String get stationPendingTitle =>
      _t('Zinazosubiri kupokelewa', 'Awaiting receipt');
  String get stationExpectedLoads =>
      _t('Mizigo inayotarajiwa', 'Expected deliveries');
  String get stationExpectedCaption =>
      _t('Orodha ya mizigo kutoka Omoterra', 'Delivery lists from Omoterra');
  String get stationStockSummary =>
      _t('Hesabu na marejesho', 'Counts and returns');
  String get stationInformation =>
      _t('Maelezo ya kituo', 'Station information');
  String get stationArea => _t('Eneo', 'Area');
  String get stationAddress => _t('Anwani', 'Address');
  String get stationEdit => _t('Hariri maelezo', 'Edit information');
  String get stationPeople => _t('Watu wa kituo', 'Station people');
  String get stationAssignStaff => _t('Panga mfanyakazi', 'Assign staff');
  String get stationRemoveVendor =>
      _t('Ondoa muuzaji kituoni', 'Unassign vendor');
  String get stationStock => _t('Stoo ya kituo', 'Station stock');
  String get stationNoStock =>
      _t('Hakuna bidhaa kwenye stoo ya kituo.', 'No stock at this station.');
  String get stationDeliveries => _t('Bidhaa zilizotumwa', 'Sent stock');
  String get stationNoDeliveries =>
      _t('Hakuna orodha ya bidhaa zilizotumwa.', 'No deliveries recorded.');
  String get stationEditDelivery => _t('Badili orodha', 'Change delivery list');
  String get stationCancelDelivery => _t('Ghairi utumaji', 'Cancel delivery');
  String get stationDeliveryLocked => _t(
      'Orodha iliyopokelewa au kughairiwa haiwezi kubadilishwa.',
      'Received or cancelled deliveries cannot be rewritten.');
  String get stationOwnedDelivery => _t(
      'Bidhaa za biashara: ghairi orodha iliyo wazi ili kurudisha stoo kwenye chanzo kabla ya kutuma upya.',
      'Business-owned stock: cancel an open delivery to return stock to its source before sending again.');
  String get stationQuantity => _t('Idadi iliyotumwa', 'Sent quantity');
  String get stationAccepted => _t('Zilizopokelewa', 'Accepted');
  String get stationUnitCost =>
      _t('Gharama kwa kipimo (TZS)', 'Unit cost (TZS)');
  String get stationNoVendor =>
      _t('Hakuna muuzaji aliyepangwa.', 'No vendor assigned.');
  String get stationNoAvailablePeople =>
      _t('Hakuna mtu mwingine wa kuchagua.', 'No other people available.');
  String get stationNoPeople =>
      _t('Hakuna mtu aliyepangwa hapa.', 'Nobody assigned here.');
  String get stationAssignmentReason =>
      _t('Sababu ya upangaji au uhamisho', 'Assignment or transfer reason');
  String get stationChoosePerson => _t('Chagua mtu', 'Choose a person');
  String get stationStockNote => _t(
      'Stoo inaonyesha bidhaa zilizopokelewa. Bidhaa zinazotarajiwa ziko kwenye orodha za utumaji.',
      'Stock shows accepted goods. Expected goods are listed under deliveries.');
  String stationDeliveryStatus(String status) => switch (status) {
        'open' => _t('Inasubiri kupokelewa', 'Awaiting receipt'),
        'received' => _t('Imepokelewa', 'Received'),
        'cancelled' => _t('Imeghairiwa', 'Cancelled'),
        _ => status,
      };
  String get ownerAddProduct => _t('Ongeza bidhaa', 'Add product');
  String get newProductInvalid => _t(
      'Andika jina la bidhaa (angalau herufi 2) na uchague kundi.',
      'Enter the product name (at least 2 characters) and choose a category.');
  String get ownerDataUnavailable => _t(
      'Takwimu hizi bado hazipatikani kutoka ofisini.',
      'These figures are not available from the server yet.');
  String get ownerReportsUnavailable => _t(
      'Ripoti za faida na upatanisho wa fedha bado hazijaunganishwa.',
      'Profit and money reconciliation reports are not connected yet.');

  // Owner money report: income and expenses per station.
  String get reportMoneyTitle =>
      _t('Mapato na matumizi', 'Income and expenses');
  String get reportPeriodDay => _t('Leo', 'Today');
  String get reportPeriodChosenDay => _t('Siku', 'Day');
  String get reportPeriodChosenWeek => _t('Wiki', 'Week');
  String get reportPeriodChosenMonth => _t('Mwezi', 'Month');
  String get reportPeriodWeek => _t('Wiki hii', 'This week');
  String get reportPeriodMonth => _t('Mwezi huu', 'This month');
  String get reportAllStations => _t('Vituo vyote', 'All stations');
  String get reportIncome => _t('Mapato', 'Income');
  String get reportExpenses => _t('Matumizi', 'Expenses');
  String get reportBalance => _t('Baki', 'Balance');
  String get reportBalanceNote => _t(
      'Baki ni mapato kutoa matumizi. Si faida: gharama ya bidhaa haimo.',
      'Balance is income minus expenses. It is not profit: stock cost is not in it.');
  String reportVerified(String amount) =>
      _t('Yaliyothibitishwa: $amount', 'Verified: $amount');
  String reportPending(String amount) => _t(
      'Matumizi yanayosubiri idhini: $amount',
      'Expenses awaiting approval: $amount');
  String get reportTopExpenses => _t('Matumizi makubwa', 'Largest expenses');
  String get reportByStation => _t('Kila kituo', 'Each station');
  String get reportNoExpenses =>
      _t('Hakuna matumizi katika kipindi hiki.', 'No expenses in this period.');
  String get reportNoStations => _t('Hakuna vituo bado.', 'No stations yet.');
  String ownerProductPortion(String name, String unit) {
    final n = name.toLowerCase();
    if (n.contains('mishkaki')) return _t('Mshikaki mmoja', 'One skewer');
    if (n.contains('maini')) return _t('Sehemu moja', 'One portion');
    if (n.contains('firigisi')) return _t('Vipande viwili', 'Two pieces');
    if (n.contains('nusu')) return _t('Nusu ya kuku', 'Half a chicken');
    if (n.contains('kidali') || n.contains('paja')) {
      return _t('Robo kuku', 'Quarter chicken');
    }
    if (n.contains('mzima')) return _t('Kuku mmoja', 'One chicken');
    if (n.contains('ndizi') || n.contains('shingo')) {
      return _t('Kipande kimoja', 'One piece');
    }
    return unitName(unit);
  }

  // Office (staff mode).
  String get officeSignIn => _t('Ingia ofisini', 'Office sign-in');
  String get vendorSignIn => _t('Ingia kama muuzaji', 'Vendor sign-in');
  String get officeForgotBody => _t(
      'Omba mmiliki au meneja wa shughuli akupe namba ya kubadili PIN '
          '(Ofisi → Wafanyakazi → jina lako). Mmiliki hupata namba hiyo kwenye seva.',
      'Ask the owner or operations manager for a PIN reset code '
          '(Office → Staff → your name). The owner gets it on the server.');
  String get office => _t('Ofisi', 'Office');
  String get officeSignInHelp => _t('Kwa mmiliki, mameneja na wasimamizi.',
      'For the owner, managers and supervisors.');
  String get officeNothing => _t(
      'Kazi za ofisi kwa akaunti yako bado hazipo kwenye simu.',
      'Office tasks for your account are not on the phone yet.');
  String get vendors => _t('Wauzaji', 'Vendors');
  String get staffMembers => _t('Wafanyakazi', 'Staff');
  String get stations => _t('Vituo', 'Stations');
  String get addVendor => _t('Sajili muuzaji', 'Register a vendor');
  String get addStaff => _t('Sajili mfanyakazi', 'Register staff');
  String get addStation => _t('Ongeza kituo', 'Add a station');
  String get fullName => _t('Jina kamili', 'Full name');
  String get nameRequired => _t('Andika jina kamili', 'Enter the full name');
  String get stationName => _t('Jina la kituo', 'Station name');
  String get stationCode => _t('Namba ya kituo', 'Station code');
  String get stationCodeHint => 'KA01';
  String get stationCodeInvalid => _t('Herufi kubwa na namba, mfano KA01',
      'Capital letters and digits, for example KA01');
  String get noStation => _t('Hana kituo', 'No station');
  String get chooseStation => _t('Chagua kituo', 'Choose a station');

  /// How many vendors a station has; several may share one station.
  String stationVendorCount(int n) => switch (n) {
        0 => _t('Bila muuzaji', 'No vendor'),
        1 => _t('Muuzaji 1', '1 vendor'),
        _ => _t('Wauzaji $n', '$n vendors'),
      };
  String get role => _t('Kazi', 'Role');
  String roleName(String role, {bool lead = false}) => switch (role) {
        'supervisor' when lead => leadRole,
        'supervisor' => _t('Msimamizi', 'Supervisor'),
        'finance' => _t('Meneja wa fedha', 'Finance manager'),
        'operations_admin' => _t('Meneja wa shughuli', 'Operations manager'),
        'business_owner' => _t('Mmiliki', 'Owner'),
        'kitchen_staff' => _t('Jikoni', 'Kitchen'),
        _ => role,
      };
  String roleHint(String role) => switch (role) {
        'kitchen_staff' =>
          _t('Anarekodi maandalizi ya bidhaa', 'Records food preparation'),
        'supervisor' => _t('Anasimamia kituo na wauzaji wake',
            'Oversees a station and its vendors'),
        'finance' => _t('Anahakiki mauzo na fedha', 'Checks sales and money'),
        'operations_admin' => _t('Anasajili watu, vituo na bidhaa',
            'Registers people, stations and products'),
        _ => '',
      };
  String get register => _t('Sajili', 'Register');
  String get statusPending => _t('Hajaanza', 'Not started');
  String get statusActive => _t('Anatumia', 'Active');
  String get statusSuspended => _t('Amesimamishwa', 'Suspended');
  String get newCode => _t('Toa namba ya kuingia', 'Give a sign-in code');
  String get resetPinCode =>
      _t('Toa namba ya kubadili PIN', 'Give a PIN reset code');
  String get changeStation => _t('Badilisha kituo', 'Change station');
  String get paySaveRefused => _t(
      'Haijahifadhiwa. Hakikisha mkataba, tarehe na salio la kipindi, kisha jaribu tena.',
      'Not saved. Check the contract, dates and period balance, then retry.');
  String get payRetrySame => _t(
      'Hatujathibitisha jibu la seva. Jaribu tena kwa ombi hili hili.',
      'The server response is unconfirmed. Retry this same request.');
  String get payLoadFailed =>
      _t('Imeshindikana kupakia. Jaribu tena.', 'Could not load. Try again.');
  String get payStationUnknown =>
      _t('Kituo hakijarekodiwa', 'Station not recorded');
  String get payServerUpdate => _t(
      'Seva bado haijawezeshwa kwa malipo ya wauzaji.',
      'Vendor payments have not been enabled on this server yet.');
  String get payDailyRate => _t('TZS kwa siku iliyofanywa (0 kama haitumiki)',
      'TZS per day worked (0 if unused)');
  String get payCommissionPercent => _t(
      'Asilimia ya mauzo yaliyothibitishwa (0 kama haitumiki)',
      'Percentage of verified sales (0 if unused)');
  String get payWeekday => _t('Siku ya malipo kwa wiki', 'Weekly pay day');
  String payWeekdayName(int day) => _t(
      [
        'Jumatatu',
        'Jumanne',
        'Jumatano',
        'Alhamisi',
        'Ijumaa',
        'Jumamosi',
        'Jumapili'
      ][day],
      [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ][day]);
  String get payMonthday =>
      _t('Tarehe ya malipo kwa mwezi (1–31)', 'Monthly pay date (1–31)');
  String get payAgreedTerms => _t('Masharti mliyokubaliana', 'Agreed terms');
  String get payActualPaymentHelp => _t(
      'Rekodi pesa ambazo tayari umemlipa muuzaji. App haitumi pesa.',
      'Record money already paid to the vendor. The app does not send money.');
  String get payPeriodFrom => _t('Malipo ya kuanzia', 'Period from');
  String get payPeriodTo => _t('Malipo hadi', 'Period to');
  String get payMethod => _t('Njia ya malipo', 'Payment method');
  String get payPaidAt =>
      _t('Tarehe na saa ya kulipa', 'Actual payment date and time');
  String get payOtherMethod => _t('Njia nyingine', 'Other method');
  String get payReverse =>
      _t('Sahihisha rekodi ya malipo', 'Correct payment record');
  String get payReversalHelp => _t(
      'Rekodi ya awali itabaki kwenye historia. Weka sababu ya kuisahihisha. Hii hairudishi pesa kupitia M-Pesa au benki.',
      'The original record remains in history. Give a correction reason. This does not refund money through M-Pesa or a bank.');
  String get payChoosePeriod =>
      _t('Chagua kipindi cha historia', 'Choose history period');
  String get payAllTimeTotals =>
      _t('Jumla ya rekodi zote hadi leo', 'Totals across all records to date');
  String get payCorrectAttendance =>
      _t('Sahihisha mahudhurio', 'Correct attendance');
  String get payPartial => _t('Amelipwa sehemu', 'Partly paid');
  String get payNothingOwed =>
      _t('Hakuna salio la kulipwa', 'No outstanding balance');
  String get payOverpaid => _t('Malipo yanazidi stahiki; yanahitaji ukaguzi',
      'Paid exceeds earnings; review required');
  String payPercent(String value) => '$value%';
  String get paySetContractFirst => _t(
      'Mmiliki aweke mkataba unaohusu tarehe ya kazi kwanza.',
      'The owner must first set a contract covering the work date.');
  String get payMaxPeriod => _t('Chagua kipindi kisichozidi siku 366.',
      'Choose a period of at most 366 days.');
  String payMissingContracts(int n) => _t(
      'Wauzaji $n hawana mkataba. Stahiki na salio hapo juu ni za mikataba iliyowekwa.',
      '$n vendors have no contract. Earnings and balance above cover configured contracts.');
  String get paySalesStations => _t('Vituo vya mauzo', 'Sales stations');
  String get payDueNow =>
      _t('Stahiki zilizofikia tarehe ya kulipa', 'Earnings due for payment');
  String get vendorPayTitle => _t('Malipo ya wauzaji', 'Vendor payments');
  String get payDaily => _t('Kila siku', 'Daily');
  String get payWeekly => _t('Kila wiki', 'Weekly');
  String get payMonthly => _t('Kila mwezi', 'Monthly');
  String get payContractMissing => _t('Hana mkataba', 'No contract');
  String get payNotCalculated => _t('Bado haijahesabiwa', 'Not calculated');
  String payAsOf(String date) => _t('Hadi $date', 'As of $date');
  String get payUnpaid => _t('Hawajalipwa', 'Outstanding');
  String get paySettled => _t('Wamelipwa', 'Settled');
  String get payNoMatches =>
      _t('Hakuna wauzaji kwenye chaguo hili.', 'No vendors in this selection.');
  String get payEarned => _t('Walichostahili', 'Earned');
  String get payPaid => _t('Iliyolipwa', 'Paid');
  String get payBalance => _t('Deni letu kwa wauzaji', 'Owed to vendors');
  String get payNextDue => _t('Tarehe ya malipo', 'Payment due');
  String get payRecordPayment =>
      _t('Rekodi malipo yaliyofanyika', 'Record a payment made');
  String get payAttendanceAndSales =>
      _t('Mahudhurio na mauzo', 'Attendance and sales');
  String get payRecordAttendance =>
      _t('Rekodi mahudhurio', 'Record attendance');
  String get payNoAttendance => _t(
      'Hakuna mahudhurio yaliyorekodiwa katika kipindi hiki.',
      'No attendance recorded in this period.');
  String get payAttendance => _t('Mahudhurio', 'Attendance');
  String get payAttendanceUnknown => _t('Hayajarekodiwa', 'Not recorded');
  String get payPresent => _t('Amefanya kazi', 'Worked');
  String get payAbsent => _t('Hakufanya kazi', 'Did not work');
  String get payReportedSales => _t('Mauzo yaliyoripotiwa', 'Reported sales');
  String get payVerifiedSales =>
      _t('Mauzo yaliyothibitishwa', 'Verified sales');
  String get payContracts => _t('Mikataba', 'Contracts');
  String get paySetContract => _t('Weka mkataba', 'Set contract');
  String get payFrequency => _t('Ratiba ya malipo', 'Payment schedule');
  String get payEffectiveFrom => _t('Unaanza', 'Effective from');
  String get payHistory => _t('Historia ya malipo', 'Payment history');
  String get payNoPayments => _t(
      'Hakuna malipo yaliyorekodiwa katika kipindi hiki.',
      'No payments recorded in this period.');
  String get payReversed =>
      _t('Malipo yamerejeshwa kwenye hesabu', 'Payment reversed');
  String get copyFailed =>
      _t('Imeshindikana kunakili. Jaribu tena.', 'Could not copy. Try again.');
  String get codeOneUse => _t('Inatumika mara moja tu.', 'For one use only.');
  String codeExpiry(int hours) =>
      _t('Inaisha baada ya saa $hours.', 'Expires after $hours hours.');
  String get codeNotShownAgain =>
      _t('Haitaonekana tena.', 'It will not be shown again.');
  String get codeTitle => _t('Namba ya kuingia', 'Sign-in code');
  String codeFor(String name) =>
      _t('Mpe $name namba hii', 'Give $name this code');
  String codeValid(int hours) => _t(
      'Inatumika mara moja tu, ndani ya saa $hours. Haitaonekana tena.',
      'Works once, within $hours hours. It will not be shown again.');
  String get codeHowVendor => _t(
      'Afungue app, aweke namba yake ya simu, kisha namba hii na PIN yake mpya.',
      'They open the app, enter their phone number, then this code and a new PIN.');
  String get codeHowStaff => _t(
      'Afungue app, afungue menyu ya nukta tatu, aguse "Ingia ofisini", aweke simu yake, kisha namba hii.',
      'They open the app, open the three-dot menu, tap "Office sign-in", enter their phone, then this code.');
  String get done => _t('Nimemaliza', 'Done');
  String get copyCode => _t('Nakili namba', 'Copy code');
  String get codeCopied => _t('Namba imenakiliwa.', 'Code copied.');
  String get duplicatePhone =>
      _t('Namba hii tayari imesajiliwa', 'This number is already registered');
  String get duplicateStation =>
      _t('Namba ya kituo tayari ipo', 'This station code is already used');
  String get notAllowed => _t(
      'Akaunti yako hairuhusiwi kufanya hili', 'Your account may not do this');
  String get noVendors => _t('Hakuna wauzaji bado', 'No vendors yet');
  String get noStaff => _t('Hakuna wafanyakazi bado', 'No staff yet');
  String get noStations => _t('Hakuna vituo bado', 'No stations yet');
  String get officeReason =>
      _t('Imesajiliwa kwenye app ya ofisi', 'Registered in the office app');

  // Office: one person (vendor or staff) and the owner's corrections.
  String get vendorNumber => _t('Namba ya muuzaji', 'Vendor number');
  String get staffNumber => _t('Namba ya mfanyakazi', 'Staff number');
  String get statusLeft => _t('Ameondoka', 'Left');
  String statusWithReason(String status, String reason) => '$status: $reason';
  String get signInState => _t('Kuingia', 'Sign-in');
  String get signInDone =>
      _t('Ameingia kwa PIN yake', 'Signed in with their own PIN');
  String get signInWaiting =>
      _t('Anasubiri namba ya kuingia', 'Waiting for a sign-in code');
  String get personLeftNote => _t(
      'Ameondoka kazini. Rekodi zake zinabaki kwa kumbukumbu. Kama ilikuwa makosa, "Rudisha kazini".',
      'They have left. Their records stay for history. If it was a mistake, use "Bring back".');
  String get personNotFound =>
      _t('Mtu huyu hapatikani tena.', 'This person can no longer be found.');
  String get editPerson => _t('Badilisha jina au simu', 'Edit name or phone');
  String get phoneChangeWarning => _t(
      'Ukibadilisha simu, ataondolewa kwenye app mara moja na atahitaji namba mpya ya kuingia.',
      'Changing the phone signs them out at once; they need a new sign-in code.');
  String get phoneChangeTitle =>
      _t('Badilisha namba ya simu?', 'Change the phone number?');
  String get phoneChangeYes => _t('Ndiyo, badilisha', 'Yes, change');
  String get nothingChanged =>
      _t('Hakuna kilichobadilika.', 'Nothing has changed.');
  String get reasonInvalid => _t('Andika sababu (angalau herufi 3).',
      'Write a reason (at least 3 characters).');
  String get offerCodeTitle =>
      _t('Toa namba mpya ya kuingia sasa?', 'Give a new sign-in code now?');
  String get offerCodeBody => _t(
      'Simu mpya inahitaji namba ya kuingia kabla ya kutumia app.',
      'The new phone needs a sign-in code before the app can be used.');
  String get offerCodeYes => _t('Ndiyo, toa namba', 'Yes, give a code');
  String get later => _t('Baadaye', 'Later');
  String get suspendAccount => _t('Simamisha akaunti', 'Suspend account');
  String get suspendBody => _t(
      'Ataondolewa kwenye app mara moja na hataweza kuingia hadi arudishwe.',
      'They are signed out at once and cannot sign in until reinstated.');
  String get reinstateAccount => _t('Rudisha akaunti', 'Reinstate account');
  String get reinstateBody =>
      _t('Ataweza kuingia tena kwa PIN yake.', 'They can sign in again.');
  String get markLeft => _t('Ameondoka kazini', 'Mark as left');
  String get leaveBody => _t(
      'Akaunti inafungwa na namba yake ya simu inaachiwa. Historia yake inabaki. Ikiwa ni makosa, unaweza kumrudisha kazini.',
      'The account closes and the phone number is freed. History stays. If it was a mistake, you can bring them back.');
  String leaveConfirmTitle(String name) =>
      _t('Thibitisha $name ameondoka?', 'Confirm $name has left?');
  String get leaveConfirmBody => _t(
      'Ataondoka kwenye kazi zote na hataweza kuingia. Unaweza kumrudisha kazini baadaye ikiwa ni makosa.',
      'They leave every post and cannot sign in. You can bring them back later if it was a mistake.');
  String get leaveYes => _t('Ndiyo, ameondoka', 'Yes, they left');
  String get grantRole => _t('Ongeza kazi', 'Add a role');
  String revokeRole(String role) =>
      _t('Ondoa kazi: $role', 'Remove role: $role');
  String get revokeRoleBody => _t('Hatakuwa na ruhusa za kazi hii tena.',
      'They lose the permissions of this role.');
  String get noRoleToGrant => _t('Hakuna kazi nyingine unayoweza kumpa.',
      'There is no other role you can give.');
  String serverRefused(String detail) {
    final translated = switch (detail) {
      'A voided sale is not verified.' => _t(
          'Mauzo yaliyobatilishwa hayawezi kuthibitishwa.',
          'A voided sale cannot be verified.'),
      'Sales or damage reports are waiting' => _t(
          'Kuna mauzo au ripoti za uharibifu zinazosubiri.',
          'Sales or damage reports are still waiting.'),
      'The last business owner cannot leave.' => _t(
          'Mmiliki wa mwisho wa biashara hawezi kuondoka.',
          'The last business owner cannot leave.'),
      'There is no work.' => _t('Hakuna kazi ya kupimia.', 'There is no work.'),
      _ => null,
    };
    if (translated != null) return translated;
    if (RegExp(r'^The station held only \d+ of .+\.$').hasMatch(detail)) {
      return _t('Kiasi kilichopo kituoni hakitoshi kwa ombi hili.',
          'The station does not have enough stock for this request.');
    }
    final trimmed = detail.trim();
    if (trimmed.isNotEmpty &&
        !trimmed.contains('_') &&
        trimmed.contains(' ') &&
        RegExp(r'^[A-Za-z0-9 ,.;:/\\-]+$').hasMatch(trimmed)) {
      return trimmed;
    }
    return _t(
        'Ombi halijakubaliwa. Kagua maelezo kisha ujaribu tena. Ikiendelea, wasiliana na ofisi.',
        'The request was not accepted. Check the details and try again. If it continues, contact the office.');
  }

  // Office: product categories.
  String get newCategory => _t('Kundi jipya', 'New category');
  String get newCategoryEntry => _t('+ Kundi jipya', '+ New category');
  String get categoryName => _t('Jina la kundi', 'Category name');
  String get categoryCode => _t('Namba ya kundi', 'Category code');
  String get categoryCodeHint => _t('mfano: vinywaji', 'for example: drinks');
  String get categoryCodeInvalid => _t(
      'Herufi ndogo, namba au _ ; ianze na herufi (2 hadi 32).',
      'Lowercase letters, digits or _ ; starts with a letter (2 to 32).');
  String get duplicateCategory =>
      _t('Kundi hili tayari lipo', 'This category already exists');
  String get addCategory => _t('Ongeza kundi', 'Add category');
  String get newUnit => _t('Kipimo kipya', 'New unit');
  String get newUnitEntry => _t('+ Kipimo kipya', '+ New unit');
  String get unitNameLabel => _t('Jina la kipimo', 'Unit name');
  String get unitNameHint => _t('mfano: Bakuli', 'for example: Bowl');
  String get unitCounting => _t('Kinavyohesabiwa', 'How it is counted');
  String get unitWhole =>
      _t('Namba kamili tu (kama kipande)', 'Whole numbers only (like piece)');
  String get unitDecimal =>
      _t('Desimali zinaruhusiwa (kama kg)', 'Decimals allowed (like kg)');
  String get unitCountingFixed => _t(
      'Hili halibadiliki baada ya kuongeza kipimo.',
      'This cannot change once the unit is added.');
  String get duplicateUnit =>
      _t('Kipimo hiki tayari kipo', 'This unit already exists');
  String get addUnit => _t('Ongeza kipimo', 'Add unit');

  // Office: verification of sales, damage and closing counts.
  String get moreRows => _t('Zaidi', 'More');
  String get problems => _t('Matatizo', 'Problems');
  String get verifyQueueEmpty => _t('Hakuna kinachosubiri uthibitisho',
      'Nothing is waiting for verification');
  String get verifyNothingWaiting =>
      _t('Hakuna kinachosubiri', 'Nothing waiting');
  String verifySalesCount(int n, String amount) =>
      _t('Mauzo $n · $amount', '$n sales · $amount');
  String verifyDamageCount(int n) =>
      _t('Vimeharibika: $n', 'Damage reports: $n');
  String verifyClosingCount(int n) =>
      _t('Funga Siku: $n', 'Closing counts: $n');
  String verifyProblemCount(int n) => _t('Matatizo: $n', 'Problems: $n');
  String verifyOldest(String date) => _t('Tangu $date', 'Since $date');
  String get notYourRole => _t('Kazi hii hufanywa na msimamizi au mmiliki.',
      'A supervisor or the owner does this.');

  // Sales.
  String get noUnverifiedSales => _t('Hakuna mauzo yanayosubiri uthibitisho',
      'No sales waiting for verification');
  String get selectAll => _t('Chagua zote', 'Select all');
  String get clearAll => _t('Ondoa zote', 'Clear all');
  String selectSale(String time, String amount) =>
      _t('Chagua mauzo ya $time, $amount', 'Select the $time sale, $amount');
  String get showSaleLines => _t('Onyesha bidhaa', 'Show products');
  String get voidedNotVerified =>
      _t('Yamebatilishwa · hayathibitishwi', 'Voided · not verified');
  String verifySelection(int n, String amount) =>
      _t('Umechagua mauzo $n · $amount', 'Selected: $n sales · $amount');
  String get verifyNoneSelected =>
      _t('Chagua mauzo ya kuthibitisha.', 'Select the sales to verify.');
  String get verifyAction => _t('Thibitisha', 'Verify');
  String verifyConfirmTitle(int n, String amount) => _t(
      'Thibitisha mauzo $n ya jumla ya $amount?',
      'Verify $n sales totalling $amount?');
  String get verifyConfirmBody => _t(
      'Mauzo yaliyothibitishwa hayawezi kubatilishwa na muuzaji. Ofisi itarekodi kuwa wewe umeyathibitisha.',
      'Verified sales can no longer be voided by the vendor. The server records that you verified them.');
  String salesVerified(int n) => _t(
      'Mauzo $n yamethibitishwa na ofisi.', '$n sales verified on the server.');
  String get verifyBatchNotDone => _t(
      'Hakuna mauzo ya kundi hili yaliyothibitishwa.',
      'None of the sales in this batch were verified.');
  String verifyEarlierDone(int n) => _t(
      'Mauzo $n ya makundi ya awali yamethibitishwa.',
      '$n sales in earlier batches were verified.');

  // Damage reports.
  String get noDamageWaiting => _t(
      'Hakuna ripoti za uharibifu zinazosubiri', 'No damage reports waiting');
  String get damageDecisionHelp => _t(
      'Kukubali ripoti kunaondoa bidhaa kwenye stock kama hasara iliyothibitishwa. Kukataa kunaiacha stock ilivyo.',
      'Accepting a report removes the goods from stock as a verified loss. Rejecting leaves stock as it is.');
  String get damageWaitingDecision =>
      _t('Inasubiri uamuzi wa ofisi', 'Waiting for an office decision');
  String reasonText(String reason) => _t('Sababu: $reason', 'Reason: $reason');
  String noteText(String note) => _t('Maelezo: $note', 'Note: $note');
  String get damageApprove => _t('Kubali hasara', 'Accept as loss');
  String get damageReject => _t('Kataa', 'Reject');
  String get damageApproveTitle => _t('Kubali kama hasara', 'Accept as a loss');
  String get damageRejectTitle => _t('Kataa ripoti', 'Reject the report');
  String damageApproveBody(String quantity, String product) => _t(
      'Ukikubali, $product ($quantity) itaondolewa kwenye stock kama hasara iliyothibitishwa.',
      'Accepting removes $product ($quantity) from stock as a verified loss.');
  String get damageRejectBody => _t(
      'Ukikataa, ripoti haitahesabiwa kama hasara na stock haitabadilika.',
      'Rejecting means it is not counted as a loss and stock does not change.');
  String get decisionReason =>
      _t('Sababu ya uamuzi', 'Reason for the decision');
  String get decisionReasonInvalid => _t('Andika sababu ya herufi 3 hadi 500.',
      'Write a reason of 3 to 500 characters.');
  String get decisionSaved =>
      _t('Uamuzi umehifadhiwa ofisini.', 'Decision saved on the server.');

  // Phone records waiting for office review (MN014).
  String get syncConflicts => _t('Kumbukumbu za simu', 'Phone records');
  String get syncConflictsCaption =>
      _t('Zinazosubiri ukaguzi wa ofisi', 'Waiting for office review');
  String? syncConflictsCount(int? n) =>
      n == null || n == 0 ? null : _t('$n zinasubiri', '$n waiting');
  String get syncConflictGone => _t('Kumbukumbu hii haisubiri ukaguzi tena.',
      'This record is no longer waiting for review.');
  String get syncConflictsEmpty =>
      _t('Hakuna kumbukumbu za simu bado', 'No phone records yet');

  /// Why the server kept the record, for the office.
  String conflictReason(String reason) => switch (reason) {
        'future_date' => _t('Tarehe ya mauzo iko mbele ya leo.',
            'The sale date is in the future.'),
        'product_not_on_station_menu' => _t(
            'Bidhaa haikuwa kwenye menyu ya kituo wakati mauzo yaliporekodiwa.',
            'The item was not on the station menu when the sale was recorded.'),
        'not_assigned' => _t('Muuzaji hakuwa na kituo siku hii.',
            'The vendor had no station on this day.'),
        'wrong_station' => _t(
            'Kituo kilichoko kwenye simu si kituo cha muuzaji.',
            "The phone's station is not the vendor's station."),
        'station_counted' => _t(
            'Kituo kilishahesabiwa siku hii na muuzaji mwingine.',
            'Another vendor already counted this station on this day.'),
        'already_closed' => _t('Hesabu ya siku hii ilishatumwa.',
            "This day's count was already sent."),
        'day_moved_on' => _t(
            'Hesabu ya siku iliyopita ilifika baada ya kazi ya leo kuanza.',
            "Yesterday's count arrived after today's work had begun."),
        'manifest_changed' => _t(
            'Orodha ya mzigo ilibadilika kabla hesabu haijafika.',
            'The delivery list changed before the count arrived.'),
        'refused' => _t('Kanuni ya biashara ilikataa kumbukumbu hii.',
            'A business rule refused this record.'),
        _ => _t('Seva haikukubali kumbukumbu hii ($reason).',
            'The server did not accept this record ($reason).'),
      };
  String conflictRecordedAt(String when) =>
      _t('Ilirekodiwa: $when', 'Recorded: $when');
  String conflictPhoneStation(String name) =>
      _t('Kituo kwenye simu: $name', "Phone's station: $name");
  String conflictVendorStation(String name) =>
      _t('Kituo cha sasa: $name', 'Station now: $name');
  String get conflictPastDay =>
      _t('Weka kituo kwa tarehe hii', 'Set the station for this date');
  String conflictPastDayBody(String vendor, String station, String day) => _t(
      '$vendor atahesabiwa kuwa alikuwa $station tarehe $day. Kituo chake cha sasa hakibadiliki.',
      '$vendor will be recorded at $station on $day. Their current station does not change.');
  String get conflictPastDayNoStation => _t(
      'Muuzaji hana kituo. Mweke kwenye kituo kwanza.',
      'The vendor has no station. Assign one first.');
  String get conflictPastDayDone => _t(
      'Kituo kimewekwa. Sasa jaribu tena.', 'Station recorded. Now try again.');
  String get conflictRetry => _t('Jaribu tena', 'Try again');
  String get conflictRetryBody => _t(
      'Seva itaipokea kama ilivyorekodiwa kwenye simu: muda, bidhaa na bei zake.',
      'The server takes it as recorded on the phone: its time, products and prices.');
  String get conflictReject => _t('Kataa', 'Refuse');
  String get conflictRejectBody => _t(
      'Kumbukumbu hii haitahesabiwa. Uamuzi huu ni wa mwisho.',
      'This record will not count. This decision is final.');
  String get conflictAccepted => _t(
      'Imepokelewa. Simu ya muuzaji itaonyesha imetumwa ikisawazisha.',
      "Accepted. The vendor's phone shows it as sent on its next sync.");
  String conflictStillWaiting(String reason) =>
      _t('Bado inasubiri: $reason', 'Still waiting: $reason');
  String get conflictRejected =>
      _t('Imekataliwa. Haitahesabiwa.', 'Refused. It does not count.');
  String get conflictHistory => _t('Maamuzi ya awali', 'Earlier decisions');
  String conflictReviewLine(String action, String by, String when) => _t(
      '${action == 'reject' ? 'Kataa' : 'Jaribu tena'} · $by · $when',
      '${action == 'reject' ? 'Refuse' : 'Try again'} · $by · $when');

  // Closing counts.
  String get noClosingsWaiting => _t(
      'Hakuna hesabu za Funga Siku zinazosubiri', 'No closing counts waiting');
  String get closingConfirmHelp => _t(
      'Kuthibitisha kunakubali hesabu ya bidhaa tu. Pesa hukaguliwa kando.',
      'Confirming accepts the stock count only. Money is checked separately.');
  String get closingVendorCounted =>
      _t('Muuzaji alihesabu', 'The vendor counted');
  String get closingExpected => _t('Inatarajiwa', 'Expected');
  String get closingCounted => _t('Imehesabiwa', 'Counted');
  String get closingDifference => _t('Tofauti', 'Difference');
  String get closingBlocked =>
      _t('Huwezi kuthibitisha bado:', 'You cannot confirm yet:');
  String closingBlockedSales(int n) =>
      _t('mauzo $n hayajathibitishwa', '$n sales not verified');
  String closingBlockedDamage(int n) => n == 1
      ? _t('ripoti 1 ya uharibifu inasubiri', '1 damage report waiting')
      : _t('ripoti $n za uharibifu zinasubiri', '$n damage reports waiting');
  String get confirmCount => _t('Thibitisha hesabu', 'Confirm the count');

  // Problems and resolution history.
  String get noOpenProblems =>
      _t('Hakuna matatizo yaliyo wazi', 'No open problems');
  String problemOpenTab(int count) =>
      _t('Yaliyo wazi ($count)', 'Open ($count)');
  String get problemResolvedTab => _t('Yaliyotatuliwa', 'Resolved');
  String problemOpenCount(int count) => _t('$count wazi', '$count open');
  String get problemDetails => _t('Maelezo ya tatizo', 'Problem details');
  String get problemVendor => _t('Muuzaji', 'Vendor');
  String get problemProduct => _t('Bidhaa', 'Product');
  String get problemType => _t('Aina', 'Type');
  String get problemHistory => _t('Historia', 'History');
  String get problemOpened => _t('Tatizo limefunguliwa', 'Problem opened');
  String get problemResolvedHistory =>
      _t('Tatizo limetatuliwa', 'Problem resolved');
  String get problemNoteRequired =>
      _t('Andika maelezo (lazima)', 'Enter note (required)');
  String get problemNoteHelp => _t(
      'Eleza kwa kifupi hatua uliyochukua, kwa mfano kurekodi mauzo yaliyochelewa.',
      'Briefly explain what you did, for example recording the late entry.');
  String get problemAutoResolveTitle => _t('Hujitatua yenyewe', 'Auto-resolve');
  String get problemAutoResolveCost => _t(
      'Tatizo hili litafungwa kiotomatiki ukiweka gharama ya kawaida ya bidhaa.',
      'This problem will close automatically when you set the product\'s standard cost.');
  String get problemSetStandardCost =>
      _t('Weka gharama ya kawaida', 'Set standard cost');
  String get problemNotResolved => _t('Bado halijatatuliwa', 'Still open');
  String get problemNoResolved =>
      _t('Hakuna matatizo yaliyotatuliwa', 'No resolved problems');
  String problemCountProducts(int count) =>
      _t('Bei ya makubaliano haipo · $count', 'Agreed price missing · $count');
  String get problemCancel => _t('Ghairi', 'Cancel');
  String get problemsHelp => _t(
      'Hapa unaona matatizo yaliyo wazi na kuyatatua. Thamani kubwa inakwenda kwa anayeidhinisha.',
      'Open problems are shown and resolved here. A larger value goes to its approver.');
  String problemKind(String kind) => switch (kind) {
        'damage_reported' => _t('Ripoti ya uharibifu', 'Damage reported'),
        'stock_difference' => _t('Tofauti ya stock', 'Stock difference'),
        'missing_agreed_price' =>
          _t('Bei ya makubaliano haipo', 'Agreed price missing'),
        'receipt_mismatch' => _t('Upokeaji haulingani', 'Receipt mismatch'),
        'receipt_override' => _t('Upokeaji wa msimamizi', 'Supervisor receipt'),
        'emergency_receipt' => _t('Upokeaji wa dharura', 'Emergency receipt'),
        'price_mismatch' => _t('Bei hailingani', 'Price mismatch'),
        'late_entry' => _t('Mauzo yaliyochelewa', 'Late entry'),
        'oversold' => _t('Imeuzwa zaidi ya stock', 'Sold beyond stock'),
        'clock_skew' => _t('Saa ya simu si sahihi', 'Phone clock is wrong'),
        'production_variance' =>
          _t('Tofauti ya uzalishaji', 'Production variance'),
        'credit_over_limit' =>
          _t('Mkopo umezidi kikomo', 'Credit over the limit'),
        'credit_not_allowed' => _t('Mkopo bila ruhusa', 'Credit not allowed'),
        'stale_sync' => _t('Simu haijatuma rekodi', 'Phone not syncing'),
        'handover_unconfirmed' =>
          _t('Fedha haijathibitishwa', 'Handover not confirmed'),
        'unauthorized_adjustment' =>
          _t('Jaribio lisiloruhusiwa', 'Attempt not allowed'),
        'cash_limit_exceeded' =>
          _t('Pesa mkononi zimezidi kikomo', 'Cash on hand over the limit'),
        'closing_missed' => _t('Siku haikufungwa', 'Day not closed'),
        'offline_authorisation' =>
          _t('Rekodi ya nje ya mtandao inasubiri', 'Offline record held'),
        'late_after_verification' =>
          _t('Rekodi baada ya uthibitisho', 'Entry after verification'),
        'possible_duplicate_entry' => _t('Huenda mauzo yameingizwa mara mbili',
            'Sale possibly entered twice'),
        _ => kind,
      };
  String severityName(String severity) => switch (severity) {
        'info' => _t('Maelezo', 'Information'),
        'critical' => _t('Hatari', 'Critical'),
        _ => _t('Tahadhari', 'Warning'),
      };
  String openedAt(String when) => _t('Lilifunguliwa $when', 'Opened $when');

  // Office: station money (handovers, expenses, the owner's settings).
  String get money => _t('Fedha', 'Money');
  String get moneyCaption =>
      _t('Makabidhiano na gharama', 'Handovers and expenses');
  String get moneySettings => _t('Mipangilio ya fedha', 'Money settings');
  String get moneySettingsCaption => _t('Aina za gharama na muda wa kukabidhi',
      'Expense categories and handover time');
  String get moneyHandovers => _t('Makabidhiano', 'Handovers');
  String get moneyExpenses => _t('Gharama', 'Expenses');
  String get moneyChooseDate => _t('Chagua tarehe', 'Choose a date');
  String moneyDayText(String date) => _t('Siku: $date', 'Day: $date');
  String get moneyCashDueHelp => _t(
      'Deni = mauzo ya taslimu yaliyothibitishwa − gharama za muuzaji zilizokubaliwa. '
          'Mauzo ambayo bado hayajathibitishwa hayamo kwenye deni.',
      'Cash due = verified cash sales − approved vendor expenses. '
          'Sales not yet verified are not in the cash due.');
  String get moneyNoDays =>
      _t('Hakuna fedha za wauzaji siku hii', 'No vendor cash for this day');
  String get moneyNoDayForVendor => _t(
      'Ofisi haina hesabu ya fedha ya muuzaji huyu siku hii.',
      'The server has no cash figures for this vendor on this day.');
  String moneyCashDue(String amount) => _t('Deni: $amount', 'Due: $amount');
  String moneyHandedOver(String amount) =>
      _t('Amekabidhi: $amount', 'Handed over: $amount');
  String moneyRemaining(String amount) =>
      _t('Imebaki: $amount', 'Remaining: $amount');
  String moneyUnverified(String amount) =>
      _t('$amount bado haijathibitishwa', '$amount not yet verified');
  String moneyVerifiedCash(String amount) => _t(
      'Mauzo ya taslimu yaliyothibitishwa: $amount',
      'Verified cash sales: $amount');
  String moneyApprovedVendorExpenses(String amount) => _t(
      'Gharama za muuzaji zilizokubaliwa: $amount',
      'Approved vendor expenses: $amount');
  String moneyPendingVendorExpenses(String amount) => _t(
      'Gharama za muuzaji zinazosubiri uamuzi: $amount',
      'Vendor expenses waiting for a decision: $amount');
  String moneyConfirmedCash(String amount) =>
      _t('Imethibitishwa: $amount', 'Confirmed: $amount');
  String moneyLastReceived(String when) =>
      _t('Alikabidhi mara ya mwisho: $when', 'Last handed over: $when');
  String get moneyNothingDue => _t('Hakuna deni', 'Nothing due');
  String get moneyNotHanded => _t('Hajakabidhi', 'Not handed over');
  String moneyShort(String amount) => _t('Pungufu $amount', 'Short $amount');
  String get moneyFull => _t('Kamili', 'Full');
  String moneyOver(String amount) => _t('Ziada $amount', 'Over $amount');
  String get moneyLate => _t('Amechelewa', 'Late');

  // Handovers.
  String get moneyReceiveCash => _t('Pokea fedha', 'Receive cash');
  String get moneyAmount => _t('Kiasi (TSh)', 'Amount (TSh)');
  String get moneyAmountInvalid =>
      _t('Andika kiasi kikubwa kuliko sifuri.', 'Enter an amount above zero.');
  String moneyHandoverConfirmTitle(String amount, String vendor) => vendor
          .isEmpty
      ? _t('Pokea $amount?', 'Receive $amount?')
      : _t(
          'Pokea $amount kutoka kwa $vendor?', 'Receive $amount from $vendor?');
  String moneyHandoverConfirmBody(String date) => _t(
      'Itarekodiwa kwa siku ya $date. Mtu mwingine ataithibitisha baadaye.',
      'It is recorded for $date. Someone else confirms it later.');
  String get moneyHandoverSaved => _t(
      'Makabidhiano yamehifadhiwa ofisini.', 'Handover saved on the server.');
  String get moneyNoHandovers =>
      _t('Hakuna makabidhiano bado', 'No handovers yet');
  String moneyRecordedBy(String name, String when) =>
      _t('Imerekodiwa na $name · $when', 'Recorded by $name · $when');
  String get moneyHandoverWaiting =>
      _t('Inasubiri uthibitisho wa fedha', 'Waiting for finance to confirm');
  String moneyConfirmedBy(String name) =>
      _t('Imethibitishwa na $name', 'Confirmed by $name');
  String get moneyConfirmHandover =>
      _t('Thibitisha makabidhiano', 'Confirm the handover');
  String moneyConfirmHandoverTitle(String amount, String vendor) => _t(
      'Thibitisha $amount zimepokelewa kutoka kwa $vendor?',
      'Confirm $amount was received from $vendor?');
  String get moneyConfirmHandoverBody => _t(
      'Ofisi itarekodi kuwa wewe umeyathibitisha.',
      'The server records that you confirmed it.');
  String get moneyHandoverConfirmed => _t(
      'Makabidhiano yamethibitishwa ofisini.',
      'Handover confirmed on the server.');
  String get moneyOwnRecord => _t(
      'Uliyarekodi wewe; mtu mwingine atayathibitisha.',
      'You recorded this; someone else confirms it.');
  String get moneyCorrection =>
      _t('Rekodi ya kurekebisha', 'Correcting record');
  String get moneyReversed => _t('Imerekebishwa', 'Reversed');
  String moneyCorrectsHandover(String amount) => _t(
      'Inarekebisha makabidhiano ya $amount', 'Reverses the $amount handover');
  String moneyCorrectsExpense(String category, String amount) => _t(
      'Inarekebisha gharama ya $category, $amount',
      'Reverses the $category expense of $amount');
  String moneyCorrectedBy(String name) =>
      _t('Imerekebishwa na $name', 'Reversed by $name');
  String get moneyReverse => _t('Rekebisha', 'Reverse');
  String get moneyReverseHandoverTitle =>
      _t('Rekebisha makabidhiano', 'Reverse the handover');
  String get moneyReverseExpenseTitle =>
      _t('Rekebisha gharama', 'Reverse the expense');
  String get moneyReverseWarning => _t(
      'Rekodi ya awali haifutwi. Rekodi mpya ya kurekebisha itaongezwa na kuiondoa kwenye hesabu.',
      'The original is not deleted. A new correcting record is added that takes it out of the totals.');
  String get moneyReason => _t('Sababu', 'Reason');
  String get moneyReversalSaved => _t(
      'Rekodi ya kurekebisha imehifadhiwa ofisini.',
      'Correcting record saved on the server.');
  String get moneyInvalid => _t(
      'Ofisi haikukubali maelezo haya. Angalia kisha ujaribu tena.',
      'The server did not accept these details. Check and try again.');
  String get moneyRecordGone =>
      _t('Rekodi hii haipatikani tena.', 'This record can no longer be found.');

  // Expenses.
  String get moneyAddExpense => _t('Ongeza gharama', 'Add an expense');
  String get moneyCategory => _t('Aina ya gharama', 'Expense category');
  String get moneyCategoryRequired =>
      _t('Chagua aina ya gharama.', 'Choose an expense category.');
  String get moneyCategoriesMissing => _t(
      'Mmiliki anahitaji kuweka aina za gharama kwanza.',
      'The owner must set the expense categories first.');
  String get moneyOpenSettings =>
      _t('Fungua mipangilio ya fedha', 'Open money settings');
  String moneyExpenseConfirmTitle(String category, String amount) => _t(
      'Rekodi gharama ya $category, $amount?',
      'Record a $category expense of $amount?');
  String moneyExpenseConfirmBody(String date) => _t(
      'Imelipwa na ofisi, kwa siku ya $date.',
      'Paid by the office, for $date.');
  String get moneyExpenseSaved =>
      _t('Gharama imehifadhiwa ofisini.', 'Expense saved on the server.');
  String get moneyNoExpenses =>
      _t('Hakuna gharama siku hii', 'No expenses this day');
  String get moneyVendorClaims =>
      _t('Madai ya wauzaji yanayosubiri', 'Vendor claims waiting');
  String get moneyDayExpenses => _t('Gharama za siku', "The day's expenses");
  String get moneyPaidByOffice => _t('Imelipwa na ofisi', 'Paid by the office');
  String moneyPaidByVendor(String name) =>
      _t('Imelipwa na $name', 'Paid by $name');
  String moneyDecidedBy(String name) =>
      _t('Imeamuliwa na $name', 'Decided by $name');
  String get moneyExpenseWaiting =>
      _t('Inasubiri uamuzi', 'Waiting for a decision');
  String get moneyExpenseApproved => _t('Imekubaliwa', 'Approved');
  String get moneyExpenseRejected => _t('Imekataliwa', 'Rejected');
  String get moneyApproveExpense => _t('Kubali', 'Approve');
  String get moneyRejectExpense => _t('Kataa', 'Reject');
  String get moneyApproveExpenseTitle =>
      _t('Kubali gharama', 'Approve the expense');
  String get moneyRejectExpenseTitle =>
      _t('Kataa gharama', 'Reject the expense');
  String moneyApproveExpenseBody(String amount, String vendor) => _t(
      'Ukikubali, $amount itaondolewa kwenye deni la $vendor.',
      "Approving takes $amount off $vendor's cash due.");
  String get moneyRejectExpenseBody => _t(
      'Ukikataa, deni la muuzaji halibadiliki.',
      "Rejecting leaves the vendor's cash due unchanged.");

  // Expense items (MN017) and "Mengineyo".
  String get expenseOtherLabel => _t('Mengineyo', 'Others');
  String get expenseOtherCaption =>
      _t('Andika ulichonunua', 'Write what was bought');
  String get expenseItem => _t('Kitu', 'Item');
  String get expenseWhatBought => _t('Umenunua nini?', 'What was bought?');
  String get expenseItemRequired => _t('Chagua au andika kitu kilichonunuliwa.',
      'Choose or write the item bought.');
  String expenseLabel(String category, String? item) => item == null
      ? (category == 'Mengineyo' ? expenseOtherLabel : category)
      : '${category == 'Mengineyo' ? expenseOtherLabel : category} · $item';

  // The owner's money settings.
  String get moneySectionExpenses => _t('Matumizi', 'Expenses');
  String get moneySectionCash => _t('Fedha', 'Cash');
  String get moneySectionStock => _t('Stoo', 'Stock');
  String expenseItemCount(int n) => switch (n) {
        0 => _t('Hakuna vitu', 'No items'),
        1 => _t('Kitu 1', '1 item'),
        _ => _t('Vitu $n', '$n items'),
      };
  String get expenseOtherSetting => _t(
      'Ipo kila wakati. Muuzaji anaandika alichonunua.',
      'Always there. The vendor writes what was bought.');
  String get expenseAddCategory => _t('Ongeza aina', 'Add a category');
  String get expenseAddItem => _t('Ongeza kitu', 'Add an item');
  String get expenseCategoryName => _t('Jina la aina', 'Category name');
  String get expenseItemName => _t('Jina la kitu', 'Item name');
  String get expenseItemsHelp => _t(
      'Muuzaji atachagua kimoja kati ya hivi anaporekodi gharama.',
      'The vendor chooses one of these when recording an expense.');
  String get expenseNoItems => _t(
      'Hakuna vitu bado. Bila vitu, muuzaji anachagua aina tu.',
      'No items yet. Without items the vendor picks only the category.');
  String get expenseRemoveCategory =>
      _t('Ondoa aina hii', 'Remove this category');
  String expenseRemoveCategoryConfirm(String name) => _t(
      'Ondoa $name na vitu vyake? Gharama zilizokwisha rekodiwa hazibadiliki.',
      'Remove $name and its items? Expenses already recorded stay as they are.');
  String expenseRemoveItemConfirm(String item) =>
      _t('Ondoa $item kwenye orodha?', 'Remove $item from the list?');
  String get expenseNameTaken =>
      _t('Jina hili lipo tayari.', 'This name is already there.');
  String get expenseNameReserved => _t(
      'Mengineyo ipo tayari kwa vitu visivyo na aina.',
      'Others is already there for items with no category.');
  String expenseNameLength(int most) => _t(
      'Andika jina la herufi 1 hadi $most.',
      'Write a name of 1 to $most characters.');
  String expenseReasonAddCategory(String name) =>
      _t('Imeongezwa aina: $name', 'Category added: $name');
  String expenseReasonRemoveCategory(String name) =>
      _t('Imeondolewa aina: $name', 'Category removed: $name');
  String expenseReasonAddItem(String item, String category) =>
      _t('Imeongezwa: $item ($category)', 'Added: $item ($category)');
  String expenseReasonRemoveItem(String item, String category) =>
      _t('Imeondolewa: $item ($category)', 'Removed: $item ($category)');
  String get moneyCategories => _t('Aina za gharama', 'Expense categories');
  String moneyCategoriesHelp(int most, int longest) => _t(
      'Aina 1 hadi $most, kila jina herufi 1 hadi $longest, yasijirudie.',
      '1 to $most categories, each 1 to $longest characters, no repeats.');
  String moneyCategoryRow(int n) => _t('Aina $n', 'Category $n');
  String get moneyAddCategoryRow => _t('Ongeza aina', 'Add a category');
  String get moneyCategoriesEmpty =>
      _t('Weka angalau aina moja ya gharama.', 'Add at least one category.');
  String moneyCategoriesTooMany(int most) =>
      _t('Aina zisizidi $most.', 'No more than $most categories.');
  String get moneyCategoryBlank => _t(
      'Jaza au ondoa sehemu iliyo tupu.', 'Fill in or remove the empty row.');
  String moneyCategoryTooLong(int longest) => _t(
      'Kila jina lisizidi herufi $longest.',
      'Each name has at most $longest characters.');
  String get moneyCategoryDuplicate =>
      _t('Kuna majina yanayojirudia.', 'Some names repeat.');
  String get moneySaveCategories =>
      _t('Hifadhi aina za gharama', 'Save the expense categories');
  String moneyCategoriesSummary(String names) =>
      _t('Aina mpya: $names', 'New categories: $names');
  String get moneyDeadline =>
      _t('Muda wa mwisho wa kukabidhi fedha', 'Cash handover deadline');
  String get moneyDeadlineNotSet => _t('Haujawekwa', 'Not set');
  String moneyDeadlineValue(String time) =>
      _t('Kila siku saa $time', 'Every day at $time');
  String get moneyDeadlineHelp => _t(
      'Muda ukishawekwa unaweza kubadilishwa, lakini hauwezi kuondolewa.',
      'Once set, the time can be changed but not removed.');
  String get moneyChooseDeadline => _t('Chagua muda', 'Choose a time');
  String moneySaveDeadlineTitle(String time) =>
      _t('Weka muda wa mwisho saa $time', 'Set the deadline to $time');
  String get moneySettingsSaved =>
      _t('Mipangilio imehifadhiwa ofisini.', 'Settings saved on the server.');

  // Office: station stock (stock days, returns), Phase 5C.
  String weekdayName(int weekday) => (isSwahili
      ? const [
          'Jumatatu',
          'Jumanne',
          'Jumatano',
          'Alhamisi',
          'Ijumaa',
          'Jumamosi',
          'Jumapili'
        ]
      : const [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ])[weekday - 1];
  String get menuImportTitle =>
      _t('Ingiza menyu ya Excel', 'Import Excel menu');
  String get menuImportCaption => _t('Majina, vipimo na bei za kawaida',
      'Names, measurements and default prices');
  String get menuExcelInstructions => _t(
      'Tumia .xlsx yenye safu name, unit, price (au jina, kipimo, bei). code na category ni hiari. Vipimo: bird/kuku, piece/kipande, portion/sehemu, tray/trei, kg. Bei ni TSh nzima. Bidhaa 1000, MB 5 kwa faili. Hakiki kabla ya kuhifadhi; faili haliongezi stoo.',
      'Use .xlsx columns name, unit, price. Optional: code, category. Units: bird, piece, portion, tray, kg. Whole TSh prices. Up to 1000 items and 5 MB. Review before saving; importing does not add stock.');
  String get menuDownloadTemplate =>
      _t('Pakua Excel tupu', 'Download blank Excel');
  String get menuChooseExcel =>
      _t('Chagua faili la Excel', 'Choose Excel file');
  String get menuPreviewTitle => _t('Hakiki menyu', 'Review menu');
  String get menuNewItem => _t('Bidhaa mpya', 'New item');
  String get menuUpdateItem =>
      _t('Sasisha bidhaa iliyopo', 'Update existing item');
  String get menuImportConfirm => _t('Hifadhi menyu', 'Save menu');
  String get menuFileInvalid => _t('Chagua Excel .xlsx lisilozidi MB 5.',
      'Choose an .xlsx file up to 5 MB.');
  String menuImportSaved(int created, int updated) => _t(
      'Imehifadhiwa ofisini: mpya $created, zilizosasishwa $updated.',
      'Saved on the server: $created new, $updated updated.');
  String menuRowError(int row, String error) =>
      _t('Mstari $row: $error', 'Row $row: $error');
  String get menuChooseStations =>
      _t('Chagua menyu za vituo', 'Choose station menus');
  String get stationMenuTitle => _t('Menyu ya kituo', 'Station menu');
  String get stationMenuRow =>
      _t('Bidhaa na bei za kituo', 'Products and station prices');
  String get stationPhotoAdd => _t('Weka picha', 'Add photo');
  String get stationPhotoChange => _t('Badilisha picha', 'Change photo');
  String get stationPhotoRemove => _t('Ondoa picha', 'Remove photo');
  String get stationPhotoOptions => _t('Chaguo za picha', 'Photo options');
  String get stationPhotoFailed => _t('Picha haikuhifadhiwa. Jaribu tena.',
      'The photo was not saved. Try again.');
  String get stationMenuCaption =>
      _t('Chagua bidhaa na bei za kituo', 'Choose items and station prices');
  String get menuStationInstructions => _t(
      'Chagua bidhaa zinazouzwa hapa. Bei ya kituo isipowekwa, bei ya kawaida itatumika. Uchaguzi huu hauongezi stoo.',
      'Select items sold here. A blank station price uses the default price. Selecting items does not add stock.');
  String get menuNotConfigured => _t(
      'Menyu ya kituo haijawekwa. Uchaguzi wa zamani umehifadhiwa hadi uhifadhi menyu hii.',
      'Station menu is not configured. Previous availability remains until you save this menu.');
  String get menuStationPrice => _t('Bei ya kituo', 'Station price');
  String get menuPriceFallback => _t(
      'Acha wazi au futa bei hii ili kutumia bei ya kawaida.',
      'Leave blank or clear this price to use the default.');
  String get menuSearch => _t('Tafuta bidhaa', 'Search items');
  String get menuSelectAll => _t('Chagua zote', 'Select all');
  String get menuSelectNone => _t('Ondoa zote', 'Clear all');
  String get stationMenuHeading => _t('Menyu', 'Menu');
  String menuSelectedCount(int n) => _t(
      n == 1 ? 'Bidhaa 1 imechaguliwa' : 'Bidhaa $n zimechaguliwa',
      n == 1 ? '1 item selected' : '$n items selected');
  String menuUnitPer(String unit) => _t('Kwa ${unitName(unit).toLowerCase()}',
      'Per ${unitName(unit).toLowerCase()}');
  String get menuNoPrice => _t('Hakuna bei', 'No price');
  String get menuSetPriceToSell =>
      _t('Weka bei ili uiuze', 'Set a price to sell it');
  String get menuNoChanges =>
      _t('Fanya mabadiliko ili kuhifadhi', 'Make a change to save');
  String get menuOffInCatalogue =>
      _t('Imezimwa kwenye orodha kuu', 'Off in the main catalogue');
  String get menuNoMatches =>
      _t('Hakuna bidhaa inayolingana.', 'No matching items.');
  String get menuSaveTitle => _t('Hifadhi menyu', 'Save menu');
  String menuPriceAction(String name) =>
      _t('Bei ya $name, badilisha', 'Price of $name, change');
  String get menuReload => _t('Soma menyu upya', 'Reload menu');
  String get stockChoosePeriod => _t('Chagua kipindi', 'Choose period');
  String get stockPeriodLimit =>
      _t('Chagua kipindi kisichozidi siku 62.', 'Choose up to 62 days.');
  String get stockDailyCounts => _t('Hesabu za kila siku', 'Daily counts');
  String get stockOfficeReturns =>
      _t('Zilizorudishwa kwa ofisi', 'Returned to office');
  String get stockNoRecords => _t('Hakuna rekodi za stoo', 'No stock records');
  String get stockRecordsHint => _t('Hesabu na marejesho yataonekana hapa.',
      'Counts and returns will appear here.');
  String get stockNow => _t('Kwenye stoo sasa:', 'Currently in stock:');
  String get stockNothingAvailable =>
      _t('Hakuna bidhaa kwenye stoo.', 'No goods in stock.');
  String get stockStillOpen => _t('Bado kufungwa', 'Not yet closed');
  String get stockReceivedOffice =>
      _t('Imepokelewa ofisini', 'Received at the office');
  String stockKinds(int n) => _t('$n aina', '$n types');
  String get stockTitle => _t('Stoo', 'Stock');
  String get stockCaption => _t('Hesabu ya kila siku na bidhaa zilizorudishwa',
      'Daily stock and returns');
  String get stockDays => _t('Siku za stoo', 'Stock days');
  String get stockDaysHelp => _t(
      'Kwa kila bidhaa: mwanzo + zilizopokelewa − zilizouzwa − zilizorudishwa − zilizopotea − zilizohamishwa = inayotarajiwa. Ofisi ndiyo inapiga hesabu.',
      'For each product: opening + received − sold − returned − lost − moved out = expected. The server does the arithmetic.');
  String get stockNoDays => _t('Hakuna siku za stoo katika kipindi hiki',
      'No stock days in this period');
  String get stockShowOlder =>
      _t('Onyesha siku 14 za nyuma', 'Show 14 earlier days');
  String stockRange(String from, String to) =>
      _t('Kuanzia $from hadi $to', 'From $from to $to');
  String stockStatusName(String status) => switch (status) {
        'not_tracked' => _t('Haifuatiliwi', 'Not tracked'),
        'open' => _t('Iko wazi', 'Open'),
        'reconciled' => _t('Imesawazishwa', 'Reconciled'),
        'discrepancy' => _t('Ina tofauti', 'Has a difference'),
        'needs_reconciliation' =>
          _t('Inahitaji kusawazishwa tena', 'Needs reconciling again'),
        _ => status,
      };
  String get closingBlockedPreviousDay => _t(
      'siku iliyotangulia haijasawazishwa',
      'the previous day is not reconciled');
  String stockBlockedPreviousDay(String date) => _t(
      'siku iliyotangulia ($date) haijasawazishwa',
      'the previous day ($date) is not reconciled');
  String movementName(String type) => switch (type) {
        'return' || 'stock_return' => _t('urejeshaji', 'a return'),
        'sale' => _t('mauzo', 'a sale'),
        'receipt' || 'receiving' => _t('upokeaji', 'a receipt'),
        'damage' || 'loss' => _t('hasara', 'a loss'),
        'transfer' ||
        'transfer_out' ||
        'transfer_in' =>
          _t('uhamisho', 'a transfer'),
        'adjustment' => _t('marekebisho', 'an adjustment'),
        'production' => _t('uzalishaji', 'production'),
        _ => type,
      };
  String stockReopenedBy(String what, String day, String when) => _t(
      'Imefunguliwa tena na $what ya siku $day ($when)',
      'Reopened by $what for $day ($when)');
  String get stockShowProducts => _t('Onyesha bidhaa', 'Show products');
  String get stockHideProducts => _t('Ficha bidhaa', 'Hide products');
  String get stockOpening => _t('Mwanzo', 'Opening');
  String get stockReceived => _t('Zilizopokelewa', 'Received');
  String get stockSold => _t('Zilizouzwa', 'Sold');
  String get stockReturned => _t('Zilizorudishwa', 'Returned');
  String get stockLost => _t('Zilizopotea', 'Lost');
  String get stockMovedOut => _t('Zilizohamishwa', 'Moved out');
  String get stockExpected => _t('Inayotarajiwa', 'Expected');
  String get stockCounted => _t('Iliyohesabiwa', 'Counted');
  String get stockDifference => _t('Tofauti', 'Difference');
  String get stockNotCounted => _t('Bado haijahesabiwa', 'Not counted yet');
  String get stockConfirmAgain =>
      _t('Thibitisha hesabu tena', 'Confirm the count again');
  String get stockConfirmAgainHelp => _t(
      'Siku hii ilisawazishwa, kisha rekodi ya baadaye ikaibadilisha. Thibitisha hesabu ya Funga Siku tena.',
      'This day was reconciled, then a later entry changed it. Confirm the closing count again.');
  String get stockConfirmedAgain => _t('Hesabu imethibitishwa tena na ofisi.',
      'The server confirmed the count again.');

  // Returns.
  String get returnGoods => _t('Rudisha bidhaa', 'Return goods');
  String get returnHelp => _t(
      'Bidhaa zinatoka kituoni kwenda jikoni au stoo ya kupokelea. Ofisi inakataa ukirudisha zaidi ya kilichopo kituoni.',
      'Goods leave the station for a kitchen or receiving store. The server refuses more than the station holds.');
  String get returnDestination => _t('Zinakwenda wapi', 'Destination');
  String get returnNoDestinations => _t(
      'Hakuna jiko wala stoo ya kupokelea iliyosajiliwa.',
      'No kitchen or receiving store is registered.');
  String get returnDate => _t('Tarehe ya biashara', 'Business date');
  String get returnProducts => _t('Bidhaa za kurudisha', 'Goods to return');
  String get returnNoProducts =>
      _t('Bado hujaongeza bidhaa.', 'No goods added yet.');
  String get returnReason => _t('Sababu ya kurudisha', 'Reason for the return');
  String get reviewBeforeSending =>
      _t('Kagua kabla ya kutuma', 'Review before sending');
  String returnSummary(String destination, String date) =>
      _t('Kwenda $destination, siku ya $date', 'To $destination, for $date');
  String get returnSend => _t('Tuma urejeshaji', 'Send the return');
  String get sendRetryNote => _t(
      'Hatukupata jibu la ofisi. Jaribu tena: rekodi hii haitaandikwa mara mbili.',
      'No answer from the server. Try again: this record will not be written twice.');
  String get returnSaved =>
      _t('Urejeshaji umerekodiwa ofisini', 'Return recorded on the server');
  String costText(String amount) => _t('Gharama: $amount', 'Cost: $amount');
  String get costUnknown => _t('Gharama haijulikani', 'Cost unknown');
  String get finish => _t('Maliza', 'Done');
  String get returnsHistory => _t('Zilizorudishwa', 'Returns');
  String get returnsNone => _t(
      'Hakuna bidhaa zilizorudishwa katika kipindi hiki',
      'No returns in this period');
  String returnedTo(String destination) =>
      _t('Kwenda $destination', 'To $destination');

  // Receipt mismatch: units still in transit after a short receipt.
  String get mismatchResolve => _t('Tatua tofauti', 'Resolve');
  String get mismatchHelp => _t(
      'Vipande vilivyopungua bado viko njiani. Chagua vilivyoishia; ofisi inakataa kama hakuna kilicho njiani.',
      'The missing units are still in transit. Choose how they ended; the server refuses when nothing is in transit.');
  String get mismatchOutcome => _t('Vimeishiaje', 'What happened');
  String transitResolutionName(String resolution) => switch (resolution) {
        'delivered_later' => _t('Vimefika baadaye', 'Delivered later'),
        'returned_to_central' => _t('Rudisha ghala kuu', 'Return to central'),
        'transit_loss' => _t('Vimepotea njiani', 'Lost in transit'),
        _ => resolution,
      };
  String transitResolutionCaption(String resolution) => switch (resolution) {
        'delivered_later' => _t('Vinaingia stoo ya kituo; mhasibu atakagua',
            'They go into the station stock; finance reviews it'),
        'returned_to_central' => _t('Vinarudi vilikotoka, kwa gharama ileile',
            'They go back where they came from, at the same cost'),
        'transit_loss' =>
          _t('Hasara ya stoo kwa gharama yake', 'A stock loss at its cost'),
        _ => '',
      };
  String get mismatchDestination =>
      _t('Stoo ya kupokelea (hiari)', 'Receiving store (optional)');
  String get mismatchDefaultDestination =>
      _t('Ghala kuu la kawaida', 'The usual central store');
  String mismatchResolved(String resolution) => switch (resolution) {
        'delivered_later' => _t(
            'Tatizo limetatuliwa: bidhaa zimeingia kituoni.',
            'Resolved: the goods are in the station stock.'),
        'transit_loss' => _t('Tatizo limetatuliwa: hasara imerekodiwa.',
            'Resolved: the loss is recorded.'),
        _ => _t('Tatizo limetatuliwa: bidhaa zimerudishwa ghala kuu.',
            'Resolved: the goods went back to central.'),
      };
  String abnormalLossText(String amount) =>
      _t('Hasara isiyo ya kawaida: $amount', 'Abnormal loss: $amount');
  String batchesText(String n) => _t('Awamu: $n', 'Batches: $n');

  // The owner's late-entry window.
  String get lateEntryTitle =>
      _t('Kuingiza stoo kwa kuchelewa', 'Late stock entries');
  String get lateEntryNotSet => _t(
      'Haujawekwa: kila rekodi ya nyuma inahitaji idhini',
      'Not set: every back-dated entry needs approval');
  String lateEntryValue(int hours) => _t(
      'Saa $hours baada ya siku kusawazishwa',
      '$hours hours after a day is reconciled');
  String get lateEntryHelp => _t(
      'Ndani ya muda huu, rekodi ya nyuma kwenye siku iliyosawazishwa inakubaliwa bila idhini. Usipoweka muda, kila rekodi ya nyuma kwenye siku iliyosawazishwa inahitaji idhini ya fedha au mmiliki.',
      'Within this window, a back-dated entry into a reconciled day is accepted without approval. When not set, any back-dated entry into a reconciled day needs finance or owner approval.');
  String get lateEntryHours =>
      _t('Idadi ya saa (0 hadi 720)', 'Hours (0 to 720)');
  String get lateEntryInvalid => _t('Andika namba kamili kuanzia 0 hadi 720.',
      'Enter a whole number from 0 to 720.');
  String get lateEntrySave => _t('Hifadhi muda', 'Save the window');
  String get lateEntryClear => _t('Ondoa muda', 'Remove the window');
  String lateEntrySaveTitle(int hours) =>
      _t('Weka saa $hours', 'Set $hours hours');
  String get lateEntryClearBody => _t(
      'Baada ya hapo, kila rekodi ya nyuma kwenye siku iliyosawazishwa itahitaji idhini.',
      'After this, any back-dated entry into a reconciled day needs approval.');

  // Recipes.
  String get recipes => _t('Mapishi', 'Recipes');
  String get recipesCaption =>
      _t('Mapishi na matoleo yake', 'Recipes and their versions');
  String get recipesNone => _t('Hakuna mapishi bado', 'No recipes yet');
  String get recipeNew => _t('Pishi jipya', 'New recipe');
  String get recipeName => _t('Jina la pishi', 'Recipe name');
  String get recipeProduct => _t('Bidhaa kuu', 'Main product');
  String get recipeNameInvalid => _t(
      'Jaza jina (herufi 2 hadi 120), bidhaa na sababu.',
      'Enter a name (2 to 120 characters), a product and a reason.');
  String get recipeNoVersionInForce => _t(
      'Hakuna toleo lililoidhinishwa linalotumika',
      'No approved version in force');
  String recipeInForce(int n) =>
      _t('Toleo $n linatumika', 'Version $n in force');
  String recipeVersion(int n) => _t('Toleo $n', 'Version $n');
  String recipeStatus(String status) => switch (status) {
        'approved' => _t('Imeidhinishwa', 'Approved'),
        'rejected' => _t('Imekataliwa', 'Rejected'),
        _ => _t('Rasimu, inasubiri idhini ya mmiliki',
            'Draft, waiting for the owner'),
      };
  String get recipeInForceNow => _t('Linatumika sasa', 'In force now');
  String get recipeInputs => _t('Malighafi', 'Inputs');
  String get recipeOutputs => _t('Matokeo', 'Outputs');
  String get recipePrimary => _t('Malighafi kuu', 'Primary input');
  String get recipeAddInput => _t('Ongeza malighafi', 'Add an input');
  String get recipeAddOutput => _t('Ongeza tokeo', 'Add an output');
  String get recipeMethod =>
      _t('Njia ya kugawa gharama', 'Cost allocation method');
  String methodName(String method) => switch (method) {
        'weight' => _t('Kwa uzito', 'By weight'),
        'selling_value' => _t('Kwa thamani ya kuuza', 'By selling value'),
        'fixed_shares' => _t('Kwa sehemu maalum', 'Fixed shares'),
        _ => method,
      };
  String methodHelp(String method) => switch (method) {
        'weight' => _t(
            'Gharama inagawanywa kwa uzito wa kila tokeo. Andika uzito wa kipande kimoja (kg).',
            'Cost is shared by the weight of each output. Enter the weight of one unit (kg).'),
        'selling_value' => _t(
            'Gharama inagawanywa kwa thamani ya kuuza ya kila tokeo. Andika thamani ya kipande kimoja (TSh).',
            'Cost is shared by the selling value of each output. Enter the value of one unit (TSh).'),
        _ => _t('Unaweka asilimia ya gharama kwa kila tokeo. Jumla iwe 100%.',
            'You set a percentage of the cost for each output. They must total 100%.'),
      };
  String basisLabel(String method) => switch (method) {
        'weight' => _t('Uzito wa kipande (kg)', 'Weight of one unit (kg)'),
        'selling_value' =>
          _t('Thamani ya kipande (TSh)', 'Value of one unit (TSh)'),
        _ => _t('Sehemu ya gharama (%)', 'Share of the cost (%)'),
      };
  String sharesTotal(String percent) =>
      _t('Jumla ya sehemu: $percent%', 'Shares total: $percent%');
  String get sharesMustTotal =>
      _t('Sehemu zote ziwe jumla ya 100%.', 'The shares must total 100%.');
  String get recipeWaste => _t('Upotevu unaoruhusiwa', 'Waste allowance');
  String wasteKindName(String kind) => switch (kind) {
        'percent' =>
          _t('Asilimia ya malighafi kuu', 'Percent of the primary input'),
        _ => _t('Kiasi, kwa kipimo cha malighafi kuu',
            'Quantity, in the primary input unit'),
      };
  String get wasteValue => _t('Thamani ya upotevu', 'Waste value');
  String get recipeMaxRatio => _t('Uwiano wa juu wa matokeo (1 hadi 100)',
      'Maximum output ratio (1 to 100)');
  String get recipeMaxRatioHelp => _t(
      'Ofisi inakataa uzalishaji unaozidi matokeo yanayotarajiwa mara hizi.',
      'The server refuses a run whose output exceeds the expected by more than this factor.');
  String get recipeNoYields => _t(
      'Hakuna namba iliyojazwa mapema: andika kila kiasi wewe mwenyewe.',
      'No number is prefilled: type every quantity yourself.');
  String get recipeNewVersion => _t('Toleo jipya', 'New version');
  String get recipeQuantityKg => _t('Kiasi (kg)', 'Quantity (kg)');
  String get recipeLinesInvalid => _t(
      'Kila mstari unahitaji kiasi zaidi ya sifuri.',
      'Every line needs a quantity above zero.');
  String get recipeBasisInvalid => _t(
      'Jaza thamani ya kila tokeo kwa njia uliyochagua.',
      'Fill in the value of each output for the chosen method.');
  String get recipeNumbersInvalid => _t(
      'Angalia njia, upotevu, uwiano wa juu na sababu.',
      'Check the method, waste, maximum ratio and reason.');
  String get recipeVersionSaved => _t(
      'Toleo limehifadhiwa kama rasimu. Mmiliki ataliidhinisha.',
      'Version saved as a draft. The owner approves it.');
  String get recipeApprove => _t('Idhinisha', 'Approve');
  String get recipeReject => _t('Kataa', 'Reject');
  String recipeApproveTitle(int n) =>
      _t('Idhinisha toleo $n', 'Approve version $n');
  String recipeRejectTitle(int n) => _t('Kataa toleo $n', 'Reject version $n');
  String get recipeApproveBody => _t(
      'Likiidhinishwa, uzalishaji mpya utarekodiwa kwa toleo hili kuanzia tarehe yake ya kuanza.',
      'Once approved, new runs use this version from its start date.');
  String get recipeRejectBody => _t(
      'Toleo lililokataliwa halitumiki.', 'A rejected version is never used.');
  String get recipeYourDraft => _t(
      'Wewe uliandaa toleo hili, kwa hiyo huwezi kuliidhinisha.',
      'You drafted this version, so you cannot approve it.');
  String recipeEffective(String date) =>
      _t('Linaanza $date', 'Effective $date');
  String recipeWasteText(String value) =>
      _t('Upotevu unaoruhusiwa: $value', 'Waste allowance: $value');
  String recipeRatioText(String ratio) =>
      _t('Uwiano wa juu: $ratio', 'Maximum ratio: $ratio');

  // Production runs.
  String get production => _t('Uzalishaji', 'Production');
  String get productionCaption =>
      _t('Uzalishaji wa jikoni', 'Kitchen production');
  String get productionRecord => _t('Rekodi uzalishaji', 'Record production');
  String get productionNone =>
      _t('Hakuna uzalishaji uliorekodiwa bado', 'No production recorded yet');
  String get productionKitchen => _t('Jiko', 'Kitchen');
  String get productionNoKitchens => _t(
      'Ofisi haijakuweka jikoni. Muombe meneja akuweke kwenye jiko.',
      'The office has not placed you in a kitchen. Ask a manager to assign you to one.');
  String productionKitchenNamed(String code) =>
      _t('Jiko $code', 'Kitchen $code');
  String get productionRecipe => _t('Pishi', 'Recipe');
  String get productionNoRecipes => _t(
      'Hakuna pishi lenye toleo lililoidhinishwa',
      'No recipe has an approved version');
  String get productionPickFirst => _t(
      'Chagua jiko na pishi kwanza.', 'Choose a kitchen and a recipe first.');
  String get productionQuantitiesHelp => _t(
      'Andika kiasi halisi kilichotumika na kilichopatikana.',
      'Enter the actual quantities used and produced.');
  String productionWaste(String unit) => _t('Upotevu ($unit)', 'Waste ($unit)');
  String get productionQuantitiesInvalid => _t(
      'Andika kiasi cha malighafi kuu na angalau tokeo moja.',
      'Enter the primary input and at least one output.');
  String get productionSend => _t('Tuma uzalishaji', 'Send the run');
  String get productionSaved =>
      _t('Uzalishaji umerekodiwa ofisini', 'Run recorded on the server');
  String productionInputCost(String amount) =>
      _t('Gharama ya malighafi: $amount', 'Input cost: $amount');
  String get productionCostUnknown => _t(
      'Gharama haijulikani bado: baadhi ya malighafi hazina gharama.',
      'Cost not known yet: some inputs have no cost.');
  String productionWasteText(String used, String allowed, String abnormal) =>
      _t('Upotevu $used · unaoruhusiwa $allowed · zaidi $abnormal',
          'Waste $used · allowed $allowed · above $abnormal');
  String get productionVariance => _t('Kuna tofauti: ofisi imefungua tatizo.',
      'Variance: the server opened a problem.');
  String get productionNoVariance => _t('Hakuna tofauti.', 'No variance.');
  String productionOutputText(String got, String expected) => _t(
      'Imepatikana $got · ilitarajiwa $expected',
      'Produced $got · expected $expected');
  String productionAllocated(String amount) =>
      _t('Gharama iliyogawiwa: $amount', 'Allocated cost: $amount');
  String productionAt(String when) => _t('Ilifanyika $when', 'Done $when');
  // Vendor balances, money statuses, adjustments and exports (Phase 6).
  String get balancesTab => _t('Madeni', 'Balances');
  String get balancesHelp => _t(
      'Deni = mauzo ya fedha taslimu yaliyothibitishwa − makabidhiano aliyothibitisha mhasibu ± marekebisho yaliyoidhinishwa.',
      'Owed = verified cash sales − handovers finance confirmed ± approved adjustments.');
  String get balancesNone => _t('Hakuna wauzaji wenye kumbukumbu za fedha.',
      'No vendors with money records.');
  String balanceOwed(String amount) => _t('Anadaiwa $amount', 'Owes $amount');
  String get balanceClear => _t('Hana deni', 'Owes nothing');
  String balanceCredit(String amount) =>
      _t('Ana salio $amount', 'In credit $amount');
  String balanceSince(String date, int days) => days == 0
      ? _t('Tangu $date (leo)', 'Since $date (today)')
      : _t('Tangu $date · siku $days', 'Since $date · $days days');
  String balanceUnconfirmed(String amount) => _t(
      'Makabidhiano yanayosubiri mhasibu: $amount',
      'Handovers waiting for finance: $amount');
  String balanceUnverified(String amount) => _t(
      'Mauzo ambayo bado hayajathibitishwa: $amount (hayahesabiwi)',
      'Sales not yet verified: $amount (not counted)');
  String balancePendingAdjustments(int n) => _t(
      'Marekebisho $n yanasubiri uamuzi', '$n adjustments wait for a decision');
  String balanceUnresolvedDays(int n) => _t(
      'Siku $n zina M-Pesa isiyolinganishwa', '$n days with unmatched M-Pesa');
  String moneyStatusName(String status) => switch (status) {
        'nothing_due' => _t('Hakuna cha kuleta', 'Nothing due'),
        'outstanding' => _t('Hajaleta', 'Not handed over'),
        'part_received' => _t('Ameleta sehemu', 'Part received'),
        'settled' => _t('Imekamilika', 'Settled'),
        'unresolved' => _t('M-Pesa haijalinganishwa', 'M-Pesa unmatched'),
        _ => status,
      };
  String get balanceDays => _t('Siku', 'Days');
  String balanceDayDue(String amount) =>
      _t('Alipaswa kuleta $amount', 'Due $amount');
  String balanceDayApplied(String amount) =>
      _t('Imepokelewa $amount', 'Received $amount');
  String balanceDayRemaining(String amount) =>
      _t('Imebaki $amount', 'Left $amount');
  String balanceDayAdjusted(String debits, String credits) => _t(
      'Marekebisho: +$debits / −$credits', 'Adjustments: +$debits / −$credits');
  String get adjustments => _t('Marekebisho', 'Adjustments');
  String get adjustmentNew => _t('Omba marekebisho', 'Request an adjustment');
  String get adjustmentNone => _t('Hakuna marekebisho.', 'No adjustments.');
  String adjustmentKindName(String kind) => switch (kind) {
        'stock_charge' => _t('Kudaiwa bidhaa', 'Stock charge'),
        'price_shortfall' => _t('Upungufu wa bei', 'Price shortfall'),
        'write_off' => _t('Kusamehe deni', 'Write-off'),
        'correction' => _t('Kusahihisha', 'Correction'),
        _ => kind,
      };
  String adjustmentKindCaption(String kind) => switch (kind) {
        'stock_charge' => _t('Inaongeza deni: bidhaa zilizopotea kwa muuzaji',
            'Adds to what is owed: goods lost with the vendor'),
        'price_shortfall' => _t('Inaongeza deni: aliuza chini ya bei',
            'Adds to what is owed: sold below the price'),
        'write_off' => _t('Inapunguza deni: biashara inabeba hasara',
            'Reduces what is owed: the business carries the loss'),
        _ => '',
      };
  String adjustmentEffect(bool debit, String amount) => debit
      ? _t('+$amount kwenye deni', '+$amount owed')
      : _t('−$amount kwenye deni', '−$amount owed');
  String get adjustmentKind => _t('Aina', 'Kind');
  String get adjustmentDay => _t('Siku ya deni', 'Day it belongs to');
  String get adjustmentBasis =>
      _t('Rejea ya mkataba au ushahidi', 'Contract or evidence reference');
  String get adjustmentBasisInvalid => _t('Andika rejea (herufi 3 hadi 120).',
      'Write a reference (3 to 120 characters).');
  String get adjustmentHelp => _t(
      'Mtu mwingine (mhasibu au mmiliki) ataidhinisha kabla deni halijabadilika.',
      'Someone else (finance or the owner) approves it before the balance changes.');
  String adjustmentCorrects(String kind, String amount) =>
      _t('Inasahihisha $kind ya $amount', 'Corrects the $kind of $amount');
  String get adjustmentSend => _t('Tuma ombi', 'Send request');
  String get adjustmentSaved => _t('Ombi limetumwa. Linasubiri idhini.',
      'Request sent. It waits for approval.');
  String get adjustmentPending =>
      _t('Inasubiri idhini', 'Waiting for approval');
  String adjustmentApprovedBy(String name) =>
      _t('Imeidhinishwa na $name', 'Approved by $name');
  String adjustmentRejectedBy(String name) =>
      _t('Imekataliwa na $name', 'Rejected by $name');
  String adjustmentRequestedBy(String name, String when) =>
      _t('Imeombwa na $name · $when', 'Requested by $name · $when');
  String get adjustmentApprove => _t('Idhinisha', 'Approve');
  String get adjustmentReject => _t('Kataa', 'Reject');
  String get adjustmentOwn => _t('Uliomba wewe: mtu mwingine ataamua.',
      'You asked for it: someone else decides.');
  String get adjustmentDecided => _t('Uamuzi umehifadhiwa.', 'Decision saved.');
  String get adjustmentApproveNote => _t(
      'Ukiidhinisha, deni la muuzaji linabadilika mara moja.',
      'Once approved, the vendor\'s balance changes at once.');
  String get adjustmentRejectNote => _t('Ukikataa, deni halibadiliki.',
      'If rejected, the balance does not change.');
  String get adjustmentCorrect => _t('Sahihisha', 'Correct');
  String get adjustmentCorrectNote => _t(
      'Marekebisho mapya yanakwenda upande mwingine; ya zamani yanabaki kwenye historia.',
      'A new adjustment goes the other way; the old one stays in the history.');
  String basisText(String ref) => _t('Rejea: $ref', 'Reference: $ref');
  String get moneyExport => _t('Pakua ripoti (CSV)', 'Download report (CSV)');
  String get moneyExportCaption => _t(
      'Siku, madeni, makabidhiano au marekebisho',
      'Days, balances, handovers or adjustments');
  String get moneyExportKind => _t('Ripoti', 'Report');
  String moneyExportKindName(String kind) => switch (kind) {
        'days' => _t('Siku za wauzaji', 'Vendor days'),
        'balances' => _t('Madeni ya sasa', 'Current balances'),
        'handovers' => _t('Makabidhiano', 'Handovers'),
        'adjustments' => _t('Marekebisho', 'Adjustments'),
        _ => kind,
      };
  String get moneyExportRange => _t('Kipindi', 'Period');
  String get moneyExportStation => _t('Kituo', 'Station');
  String get moneyExportSave => _t('Pakua', 'Download');
  String moneyExportSaved(int rows) =>
      _t('Faili limehifadhiwa: mistari $rows.', 'File saved: $rows rows.');
  String get productionWhen => _t('Ilifanyika lini', 'When it was done');
  String get productionNow => _t('Sasa hivi', 'Just now');
  String get productionWhenFuture =>
      _t('Muda hauwezi kuwa baadaye.', 'The time cannot be in the future.');
}

/// The phone's language. Swahili by default; `language.dart` restores and
/// keeps the owner's or vendor's choice.
final languageProvider = StateProvider<String>((ref) => 'sw');

final stringsProvider = Provider<Strings>((ref) => Strings(
    ref.watch(languageProvider),
    addedUnits: ref.watch(addedUnitsProvider)));

/// Units the business added, by code; set whenever the office loads them.
final addedUnitsProvider =
    StateProvider<Map<String, OfficeUnit>>((ref) => const {});
