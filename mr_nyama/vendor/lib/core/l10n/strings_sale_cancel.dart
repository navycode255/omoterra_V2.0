part of 'strings.dart';

/// Sale cancellations (MN034): a wrong sale the vendor can no longer void is
/// cancelled by the office, asked by one person and decided by another. Same
/// rules as `Strings`: Swahili first, `_t(sw, en)`.
extension SaleCancelStrings on Strings {
  String get cancelAsk => _t('Omba kubatilisha', 'Ask to cancel');
  String get cancelWaiting =>
      _t('Ombi la kubatilisha linasubiri', 'Cancellation request waiting');
  String get cancelAskTitle =>
      _t('Omba kubatilisha mauzo', 'Ask to cancel a sale');
  String get cancelReasonLabel =>
      _t('Sababu ya kubatilisha', 'Why it should be cancelled');
  String get cancelSend => _t('Tuma ombi', 'Send request');
  String get cancelSent => _t('Ombi limetumwa.', 'Request sent.');
  String get cancelAskHelp => _t(
      'Mtu mwingine wa fedha au mmiliki ataamua. Mauzo hayabadiliki hadi aamue.',
      'Another finance person or the owner decides. The sale does not change until then.');
  String get cancelSectionTitle =>
      _t('Maombi ya kubatilisha', 'Cancellation requests');
  String get cancelOtherWillDecide =>
      _t('Mtu mwingine ataamua', 'Someone else will decide');
  String get cancelNoDecider => _t(
      'Hakuna mtu mwingine wa fedha wala mmiliki mwingine wa kuamua. Ombi litasubiri hadi awepo; unaweza kuliondoa.',
      'There is no other finance person or owner to decide. The request waits until there is one; you can withdraw it.');
  String get cancelWithdraw => _t('Ondoa ombi', 'Withdraw request');
  String get cancelWithdrawBody => _t(
      'Ombi litaondolewa. Mauzo hayabadiliki na yanaweza kuthibitishwa.',
      'The request is withdrawn. The sale does not change and can be verified.');
  String get cancelWithdrawYes => _t('Ndiyo, ondoa', 'Yes, withdraw');
  String get cancelWithdrawn => _t('Ombi limeondolewa.', 'Request withdrawn.');
  String get cancelWarning => _t('Mauzo yatabatilishwa; historia itabaki.',
      'The sale will be cancelled; the history stays.');
  String get cancelDecisionWarning =>
      _t('Mauzo yatabatilishwa; historia itabaki.',
          'The sale will be cancelled; the history stays.');
  String get cancelApprove => _t('Kubali', 'Approve');
  String get cancelReject => _t('Kataa', 'Refuse');
  String get cancelDecisionReason =>
      _t('Sababu ya uamuzi', 'Reason for the decision');
  String get cancelDecided => _t('Uamuzi umehifadhiwa.', 'Decision saved.');
  String cancelRequestedBy(String name) =>
      _t('Ameomba: $name', 'Asked by: $name');

  // The vendor's phone.
  String get statusCancelledByOffice =>
      _t('Yamebatilishwa na ofisi', 'Cancelled by the office');
}
