part of 'strings.dart';

/// Setting a station up: opening stock (#10) and kitchens and stores (#13).
/// Same rules as `Strings`: Swahili first, `_t(sw, en)`.
extension SetupStrings on Strings {
  // Opening stock
  String get openingTitle => _t('Stoo ya mwanzo', 'Opening stock');
  String get openingCaption => _t(
      'Bidhaa zilizopo siku ya kuanza kutumia mfumo.',
      'Stock on hand on the day the system starts.');
  String get openingDate => _t('Tarehe ya mwanzo', 'Opening date');
  String get openingDateCaption => _t(
      'Tarehe ya kuanza kwa salio hili la stoo.',
      'Effective date for these opening balances.');
  String get openingStatus => _t('Hali', 'Status');
  String get openingStatusNotStarted =>
      _t('Bado haijaanza', 'Not started');
  String get openingStatusPending => _t('Inasubiri idhini', 'Pending approval');
  String get openingStatusClosed => _t('Imefungwa', 'Closed');
  String get openingStatusMixed =>
      _t('Maingizo yana hali tofauti', 'Entries have different statuses');
  String get openingProducts => _t('Bidhaa', 'Products');
  String get openingQuantityTotal => _t('Jumla ya idadi', 'Total quantity');
  String get openingTotalValue => _t('Jumla ya thamani', 'Total value');
  String get openingEmptyInstruction => _t(
      'Rekodi stoo iliyopo mfumo unapoanza.',
      'Record the stock available when the system starts.');
  String get openingApprovalRequired => _t(
      'Maingizo yanahitaji idhini kabla ya kuathiri salio la stoo.',
      'Entries require approval before affecting stock balances.');
  String get openingDateUnset => _t('Haijawekwa', 'Not set');
  String get openingSetDate => _t('Weka tarehe ya mwanzo', 'Set the opening date');
  String get openingDateOwnerOnly => _t(
      'Mmiliki lazima aweke tarehe ya mwanzo kwanza. Bila tarehe, stoo ya mwanzo haiandikwi.',
      'The owner must set the opening date first. Without a date, no opening stock can be entered.');
  String get openingDateSet => _t('Tarehe imewekwa.', 'Opening date set.');
  String get openingClose => _t('Funga stoo ya mwanzo', 'Close opening stock');
  String get openingCloseBody => _t(
      'Baada ya kufunga, hakuna stoo ya mwanzo inayoongezwa tena. Marekebisho ya baadaye ni marekebisho yenye tarehe.',
      'After closing, no more opening stock can be added. Later corrections are dated adjustments.');
  String get openingCloseYes => _t('Ndiyo, funga', 'Yes, close');
  String get openingClosedNote => _t(
      'Stoo ya mwanzo imefungwa. Marekebisho ya baadaye ni marekebisho yenye tarehe.',
      'Opening stock is closed. Later corrections are dated adjustments.');
  String get openingClosedToast => _t('Stoo ya mwanzo imefungwa.', 'Opening stock closed.');
  String get openingCountNote => _t(
      'Funga Siku haiongezi stoo. Stoo ya mwanzo iliyoidhinishwa ndiyo inaongeza.',
      'Funga Siku never adds stock. An approved opening entry does.');
  String get openingAdd => _t('Ongeza stoo ya mwanzo', 'Add opening stock');
  String get openingWarnOwner => _t(
      'Mhasibu aandike, wewe uidhinishe.',
      'The accountant enters it, you approve it.');
  String get openingWarnOwnerBody => _t(
      'Hakuna anayeidhinisha alichoandika mwenyewe. Ukiandika wewe, hakuna mwingine anayeweza kuidhinisha isipokuwa kuna mmiliki wa pili.',
      'Nobody approves their own entry. If you enter it, no one else can approve it unless there is a second owner.');
  String get openingNone => _t('Hakuna stoo ya mwanzo bado.', 'No opening stock yet.');
  String get openingDraft => _t('Inasubiri uamuzi', 'Waiting for a decision');
  String get openingApproved => _t('Imeidhinishwa', 'Approved');
  String get openingRejected => _t('Imekataliwa', 'Rejected');
  String get openingCostUnknown => _t('Gharama haijulikani', 'Cost unknown');
  String openingEnteredBy(String name) => _t('Aliyeandika: $name', 'Entered by: $name');
  String openingLine(String product, int qty) => '$product × $qty';
  String openingCostEach(String amount) => _t('$amount kwa kila moja', '$amount each');
  String get openingReference => _t('Kumbukumbu', 'Reference');
  String get openingOwnDraftOwner => _t(
      'Huwezi kuidhinisha uliyoandika mwenyewe; mmiliki mwingine anahitajika. Unaweza kuikataa.',
      'You cannot approve what you entered; another owner is needed. You can reject it.');
  String get openingOwnDraftFinance => _t(
      'Mmiliki ndiye anayeidhinisha. Ukikosea, unaweza kuikataa.',
      'The owner approves. If you made a mistake, you can reject it.');
  String get openingClosedRejectOnly => _t(
      'Imefungwa: haiwezi kuidhinishwa tena, inaweza kukataliwa tu.',
      'Closed: it can no longer be approved, only rejected.');
  String get openingOldDate => _t(
      'Hii ni ya tarehe nyingine ya mwanzo, haiwezi kuidhinishwa. Ikatae na uandike upya.',
      'This is for a different opening date and cannot be approved. Reject it and enter it again.');
  String openingCloseDrafts(int n) => _t(
      'Rasimu ambazo bado zinasubiri uamuzi: $n. Baada ya kufunga haziwezi kuidhinishwa, zinaweza kukataliwa tu.',
      'Drafts still waiting for a decision: $n. After closing they cannot be approved, only rejected.');
  String get openingOwnerDecides => _t('Mmiliki ataamua', 'The owner decides');
  String get openingApprove => _t('Idhinisha', 'Approve');
  String get openingReject => _t('Kataa', 'Reject');
  String get openingRejectTitle => _t('Kataa stoo ya mwanzo', 'Reject opening stock');
  String get openingApproveTitle => _t('Idhinisha stoo ya mwanzo', 'Approve opening stock');
  String get openingDecisionReason => _t('Sababu', 'Reason');
  String get openingLocation => _t('Mahali pa stoo', 'Stock location');
  String get openingProduct => _t('Bidhaa', 'Product');
  String get openingQuantity => _t('Idadi', 'Quantity');
  String get openingUnitCost => _t('Gharama kwa moja (hiari)', 'Unit cost (optional)');
  String get openingUnitCostHint => _t(
      'Acha wazi kama haijulikani. Wazi si sifuri.',
      'Leave blank if unknown. Blank is not zero.');
  String get openingRefRequired => _t('Kumbukumbu (karatasi ya hesabu)', 'Reference (count sheet)');
  String get openingRefInvalid => _t('Andika kumbukumbu (angalau herufi 3).', 'Write a reference (at least 3 characters).');
  String get openingChooseLocation => _t('Chagua mahali pa stoo.', 'Choose a stock location.');
  String get openingChooseProduct => _t('Chagua bidhaa.', 'Choose a product.');
  String get openingCostInvalid => _t('Gharama ni namba nzima.', 'The cost is a whole number.');
  String get openingSave => _t('Hifadhi', 'Save');
  String get openingSaved => _t('Imehifadhiwa, inasubiri idhini.', 'Saved, waiting for approval.');
  String get openingNoLocations => _t('Hakuna mahali pa stoo.', 'No stock locations.');
  String get openingDecided => _t('Uamuzi umehifadhiwa.', 'Decision saved.');

  // Kitchens and stores
  String get kitchensTitle => _t('Majiko na stoo', 'Kitchens and stores');
  String get kitchensCaption => _t(
      'Majiko ya maandalizi na stoo za kupokelea.',
      'Preparation kitchens and receiving stores.');
  String get kitchensNone => _t('Hakuna jiko wala stoo bado.', 'No kitchens or stores yet.');
  String get kitchensAdd => _t('Ongeza', 'Add');
  String get kitchensAddTitle => _t('Ongeza jiko au stoo', 'Add a kitchen or store');
  String get kitchenKindKitchen => _t('Jiko', 'Kitchen');
  String get kitchenKindReceiving => _t('Stoo ya kupokelea', 'Receiving store');
  String get kitchenKindStation => _t('Kituo', 'Station');
  String get kitchenKindCustody => _t('Mkononi mwa muuzaji', 'With a vendor');
  String get kitchenKindTransit => _t('Njiani', 'In transit');
  String get kitchenKindOther => _t('Mahali pa stoo', 'Stock location');
  String get kitchenAllHeld => _t('Tayari yupo kwenye majiko yote.', 'Already at every kitchen.');
  String get kitchenKind => _t('Aina', 'Kind');
  String get kitchenName => _t('Jina', 'Name');
  String get kitchenCode => _t('Msimbo (herufi kubwa na namba)', 'Code (capitals and digits)');
  String get kitchenCodeInvalid => _t(
      'Msimbo: herufi kubwa, namba au -, kuanzia 2 hadi 30.',
      'Code: capitals, digits or -, 2 to 30 characters.');
  String get kitchenSaved => _t('Imeongezwa.', 'Added.');
  String get kitchenPick => _t('Jiko', 'Kitchen');
  String get kitchenRequired => _t('Chagua jiko.', 'Choose a kitchen.');
  String get kitchenNoneToPick => _t(
      'Hakuna jiko. Ongeza jiko kwanza kwenye Majiko na stoo.',
      'There is no kitchen. Add one first under Kitchens and stores.');
  String kitchenOfPerson(String name) => _t('Jiko: $name', 'Kitchen: $name');
  String get kitchenSecond => _t(
      'Kuongeza jiko la pili: chagua kazi ya Jikoni tena.',
      'To add a second kitchen, add the Kitchen role again.');
}
