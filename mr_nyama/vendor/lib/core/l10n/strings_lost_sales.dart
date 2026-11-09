part of 'strings.dart';

/// Lost sale entries (MN036) and ending a phone's access. Same rules as
/// `Strings`: Swahili first, `_t(sw, en)`.
extension LostSalesStrings on Strings {
  String get lostSalesTitle => _t('Mauzo yaliyopotea', 'Lost sales');
  String get lostSalesCaption => _t('Mauzo ya simu iliyopotea kabla ya kutuma',
      'Sales from a phone lost before it sent');
  String get lostSaleNew => _t('Ingiza mauzo', 'Enter a sale');
  String get lostSalesNone =>
      _t('Hakuna ombi la mauzo yaliyopotea.', 'No lost sale requests.');
  String get lostSaleHelp => _t(
      'Kwa mauzo ambayo simu ilipotea kabla ya kuyatuma. Mtu mwingine wa fedha au mmiliki ataamua. Bei ni ya siku hiyo; haiandikwi.',
      'For sales a phone lost before sending. Another finance person or the owner decides. The price is that day\'s; nobody types it.');
  String get lostSaleDate => _t('Tarehe ya mauzo', 'Date of the sale');
  String get lostSaleChooseDate => _t('Chagua tarehe', 'Choose a date');
  String get lostSaleProducts => _t('Bidhaa', 'Products');
  String get lostSaleOnlyPriced => _t(
      'Zinaonekana tu bidhaa zilizokuwa na bei na kwenye menyu siku hiyo.',
      'Only products with a price and on the menu that day are shown.');
  String get lostSaleNoProducts => _t(
      'Hakuna bidhaa yenye bei kwenye menyu ya siku hiyo.',
      'No product had a price on that day\'s menu.');
  String get lostSalePayment => _t('Malipo', 'Payment');
  String get lostSaleCustomer => _t('Mteja wa mkopo', 'Credit customer');
  String get lostSaleNoCustomers => _t(
      'Kituo hiki hakina mteja wa mkopo.', 'This station has no credit customer.');
  String get lostSaleReason =>
      _t('Nini kilitokea, na kinajulikanaje', 'What happened, and how it is known');
  String get lostSaleReasonShort =>
      _t('Andika angalau herufi 10.', 'Write at least 10 characters.');
  String get lostSaleNeedsProduct =>
      _t('Chagua angalau bidhaa moja.', 'Choose at least one product.');
  String get lostSaleSummary => _t('Muhtasari', 'Summary');
  String get lostSaleTotal => _t('Jumla', 'Total');
  String get lostSaleSend => _t('Tuma ombi', 'Send request');
  String get lostSaleSent => _t('Ombi limetumwa.', 'Request sent.');
  String get lostSaleNoDecider => _t(
      'Hakuna mtu mwingine wa fedha wala mmiliki mwingine wa kuamua. Ombi litasubiri hadi awepo; unaweza kuliondoa.',
      'There is no other finance person or owner to decide. The request waits until there is one; you can withdraw it.');
  String lostSaleStatus(String status) => switch (status) {
        'approved' => _t('Imekubaliwa', 'Approved'),
        'rejected' => _t('Imekataliwa', 'Refused'),
        'withdrawn' => _t('Imeondolewa', 'Withdrawn'),
        _ => _t('Inasubiri uamuzi', 'Waiting for a decision'),
      };
  String lostSaleAskedBy(String name) =>
      _t('Ameomba: $name', 'Asked by: $name');
  String lostSaleDecidedBy(String name) =>
      _t('Ameamua: $name', 'Decided by: $name');
  String get lostSaleOtherDecides =>
      _t('Mtu mwingine ataamua', 'Someone else will decide');
  String get lostSaleWithdraw => _t('Ondoa ombi', 'Withdraw request');
  String get lostSaleWithdrawBody =>
      _t('Ombi litaondolewa. Hakuna mauzo yanayoingizwa.',
          'The request is withdrawn. No sale is entered.');
  String get lostSaleWithdrawYes => _t('Ndiyo, ondoa', 'Yes, withdraw');
  String get lostSaleWithdrawn => _t('Ombi limeondolewa.', 'Request withdrawn.');
  String get lostSaleApprove => _t('Kubali', 'Approve');
  String get lostSaleReject => _t('Kataa', 'Refuse');
  String get lostSaleDecisionReason =>
      _t('Sababu ya uamuzi', 'Reason for the decision');
  String get lostSaleDecided => _t('Uamuzi umehifadhiwa.', 'Decision saved.');
  String get lostSaleApproveNote => _t(
      'Mauzo yataingia kwa tarehe hiyo na kusubiri uthibitisho wa kawaida. Stoo haisogei hadi yathibitishwe.',
      'The sale goes on that date and waits for normal verification. Stock does not move until then.');
  String lostSaleCashWarning(String amount) => _t(
      'Yakithibitishwa, taslimu $amount itaongezwa kwenye fedha anazotakiwa kukabidhi muuzaji.',
      'Once verified, $amount cash is added to what the vendor must hand over.');

  // Where the sale shows.
  String get lostEnteredByOffice =>
      _t('Imeingizwa na ofisi', 'Entered by the office');
  String lostEnteredNames(String asker, String decider) =>
      _t('Ameomba: $asker · Ameruhusu: $decider',
          'Asked by: $asker · Allowed by: $decider');

  // Ending a phone's access.
  String get endPhoneAccess =>
      _t('Maliza kuingia kwenye simu', 'End phone sign-in');
  String get endPhoneHelp => _t(
      'Akaunti inabaki hai, kwa hiyo simu mpya inaweza kuingia. Kuingia kwa kidole na kufungua bila mtandao kwenye simu zote za muuzaji huisha pia.',
      'The account stays active, so a new phone can sign in. Fingerprint sign-in and offline unlock on all the vendor\'s phones end too.');
  String get endPhoneConfirm => _t(
      'Atahitaji kuingia tena. Kumbukumbu zisizotumwa zinabaki kwenye simu hiyo.',
      'They will need to sign in again. Unsent records stay on that phone.');
  String get endPhoneYes => _t('Ndiyo, maliza', 'Yes, end it');
  String get endPhoneDone =>
      _t('Kuingia kwenye simu kumemalizwa.', 'Phone sign-in ended.');
}
