part of 'strings.dart';

/// Supply requests, "Maombi ya mzigo" (team roles plan, Part 2). A request is
/// not money and not stock: the words say which stage it is truthfully. Same
/// rules as `Strings`: Swahili first, `_t(sw, en)`. REVIEW: a Swahili speaker
/// must check it.
extension SupplyStrings on Strings {
  // Seller side.
  String get supplyAsk => _t('Omba mzigo', 'Request goods');
  String get supplyTitle => _t('Maombi ya mzigo', 'Supply requests');
  String get supplyNewTitle => _t('Ombi jipya', 'New request');
  String get supplyNone => _t('Hakuna maombi bado', 'No requests yet');
  String get supplyProduct => _t('Bidhaa', 'Product');
  String get supplyChooseProduct => _t('Chagua bidhaa', 'Choose a product');
  String get supplyWrittenItem =>
      _t('Bidhaa nyingine (andika)', 'Other item (write it)');
  String get supplyItemName => _t('Jina la bidhaa', 'Item name');
  String get supplyUnit => _t('Kipimo', 'Unit');
  String get supplyQuantity => _t('Idadi', 'Quantity');
  String get supplyEstimate =>
      _t('Bei ya makadirio kwa kimoja (TSh)', 'Estimated price each (TSh)');
  String get supplyEstimateHelp => _t(
      'Ni makadirio tu. Bei halisi inatoka kwenye hesabu ya manunuzi na mapokezi.',
      'This is an estimate only. The real price comes from the purchase account and the delivery.');
  String get supplyNeededBy => _t('Inahitajika tarehe', 'Needed by');
  String get supplyAddLine => _t('Ongeza bidhaa', 'Add an item');
  String get supplyRemoveLine => _t('Ondoa bidhaa', 'Remove item');
  String get supplySend => _t('Tuma ombi', 'Send request');
  String get supplyNotSent =>
      _t('Haijatumwa — jaribu tena', 'Not sent — try again');
  String get supplySent => _t('Ombi limetumwa', 'Request sent');
  String get supplyNoLines => _t('Weka bidhaa angalau moja na bei ya makadirio',
      'Add at least one item with an estimated price');
  String get supplyWithdraw => _t('Ondoa ombi', 'Withdraw request');
  String get supplyWithdrawn => _t('Ombi limeondolewa', 'Request withdrawn');
  String get supplyRequester => _t('Aliyeomba', 'Requested by');
  String get supplyStation => _t('Kituo', 'Station');
  String get supplyEstimatedTotal =>
      _t('Makadirio ya jumla', 'Estimated total');
  String get supplyRequested => _t('Imeombwa', 'Requested');
  String get supplyReceived => _t('Imepokelewa', 'Received');
  String get supplyReceivedUnknown => _t('Haijulikani', 'Unknown');
  String get supplyDifference => _t('Tofauti', 'Difference');
  String get supplyDeliveries => _t('Mapokezi ya mzigo', 'Deliveries');
  String get supplyNoDeliveries =>
      _t('Hakuna mapokezi bado', 'No deliveries yet');
  String get supplySteps => _t('Hatua za idhini', 'Approval steps');

  /// The status word. A pending request says who it waits for.
  String supplyStatus(String status) => switch (status) {
        'pending' => _t('Inasubiri', 'Waiting'),
        'approved' => _t('Imeidhinishwa', 'Approved'),
        'rejected' => _t('Imekataliwa', 'Rejected'),
        'funded' => _t('Fedha zimetolewa', 'Money given'),
        'purchased' => _t('Imenunuliwa', 'Bought'),
        'closed' => _t('Imekamilika', 'Completed'),
        'withdrawn' => _t('Imeondolewa', 'Withdrawn'),
        _ => status,
      };

  /// Who a pending request waits for. In the small chain the first step is
  /// the station supervisor or the Outlet Lead, whoever acts first.
  String supplyWaitsFor(String? kind, String chain) => switch (kind) {
        'station' => chain == 'full'
            ? _t('msimamizi wa kituo', 'the station supervisor')
            : _t('msimamizi wa kituo au Kiongozi wa Kituo',
                'the station supervisor or the Outlet Lead'),
        'lead' => _t('Kiongozi wa Kituo', 'the Outlet Lead'),
        'final' => _t('Mmiliki au Fedha', 'the Owner or Finance'),
        _ => '',
      };

  String supplyPendingLine(String? kind, String chain) {
    final who = supplyWaitsFor(kind, chain);
    return who.isEmpty
        ? supplyStatus('pending')
        : _t('Inasubiri $who', 'Waiting for $who');
  }

  String supplyStatusLine(String status, String? kind, String chain) =>
      status == 'pending'
          ? supplyPendingLine(kind, chain)
          : supplyStatus(status);

  String supplyStepName(String kind) => switch (kind) {
        'station' => _t('Msimamizi wa kituo', 'Station supervisor'),
        'lead' => _t('Kiongozi wa Kituo', 'Outlet Lead'),
        _ => _t('Mmiliki au Fedha', 'Owner or Finance'),
      };

  String get supplyStepSkipped => _t('imerukwa', 'skipped');
  String get supplyStepApproved => _t('amekubali', 'approved');
  String get supplyStepRejected => _t('amekataa', 'refused');

  // Money held and explained.
  String supplyHeld(String amount) => _t(
      'Fedha za manunuzi: TZS $amount hazijaelezwa',
      'Purchase money: TZS $amount not explained');
  String get supplyExplain => _t('Eleza matumizi', 'Explain spending');
  String get supplyGiven => _t('Ulipewa', 'You were given');
  String get supplySpent => _t('Kilichotumika (TSh)', 'Spent (TSh)');
  String get supplyChange =>
      _t('Chenji uliyorudisha (TSh)', 'Change returned (TSh)');
  String get supplySupplier =>
      _t('Muuzaji uliyemnunulia', 'Supplier you bought from');
  String get supplyExplainSend => _t('Tuma matumizi', 'Send spending');
  String get supplyExplained => _t('Matumizi yametumwa', 'Spending sent');
  String get supplyExplainBlank => _t('Weka kilichotumika, chenji na muuzaji',
      'Enter what you spent, the change and the supplier');
  String supplyOverspend(String amount) => _t(
      'Umetumia TSh $amount zaidi ya ulichopewa. Ofisi italazimika kukubali.',
      'You spent TSh $amount more than you were given. The office has to accept it.');
  String supplyDoesNotAdd(String given) => _t(
      'Kilichotumika pamoja na chenji lazima kiwe TSh $given',
      'Spent plus change must be TSh $given');
  String get supplyAwaitingConfirm =>
      _t('Inasubiri uthibitisho wa ofisi', 'Waiting for the office to confirm');

  // Office side.
  String get supplyOfficeTitle => _t('Maombi ya mzigo', 'Supply requests');
  String get supplyWaitingEmpty =>
      _t('Hakuna maombi yanayokusubiri', 'No requests are waiting for you');
  String get supplyDecideReason => _t('Sababu', 'Reason');
  String get supplyApprovedTitle =>
      _t('Imeidhinishwa — inasubiri fedha', 'Approved — waiting for money');
  String get supplyGiveMoney => _t('Toa fedha', 'Give money');
  String get supplyGiveAmount =>
      _t('Kiasi cha kutoa (TSh)', 'Amount to give (TSh)');
  String supplyGiveLimit(String amount) => _t(
      'Si zaidi ya makadirio: TSh $amount',
      'Not more than the estimate: TSh $amount');
  String get supplyGiven2 => _t('Fedha zimetolewa', 'Money given');
  String get supplyConfirm => _t('Thibitisha matumizi', 'Confirm spending');
  String get supplyConfirmed =>
      _t('Matumizi yamethibitishwa', 'Spending confirmed');
  String get supplyAcceptOverspend =>
      _t('Nakubali matumizi yaliyozidi', 'I accept the overspend');
  String supplyOverspendNote(String amount) => _t(
      'Matumizi yamezidi fedha zilizotolewa kwa TSh $amount',
      'Spending went over the money given by TSh $amount');
  String get supplyHolder => _t('Aliyepewa fedha', 'Money given to');
  String get supplyChangeRow => _t('Chenji', 'Change');
  String get supplyNotDecidable =>
      _t('Huwezi kuamua ombi hili', 'You cannot decide this request');
  String get supplyNotFound => _t(
      'Ombi halionekani kwenye orodha yako', 'The request is not in your list');
  String get supplyOutstandingTitle =>
      _t('Fedha za manunuzi zisizofungwa', 'Purchase money not closed');
  String supplyAge(int days) =>
      days <= 0 ? _t('leo', 'today') : _t('siku $days', '$days days');
  String get supplyOutstandingExplained => _t(
      'Imeelezwa — inasubiri uthibitisho',
      'Explained — waiting for confirmation');
  String get supplyOutstandingOpen => _t('Haijaelezwa', 'Not explained');
  String get supplyPickRequest =>
      _t('Ombi la mzigo (si lazima)', 'Supply request (optional)');
  String get supplyNoRequest => _t('Hakuna ombi', 'No request');
  String get supplyPickEmpty => _t('Hakuna ombi lenye fedha kwenye kituo hiki',
      'No request with money at this station');

  String supplyRefusal(String code) => switch (code) {
        'own_record' => ownRecordRefused,
        'already_decided_other_step' => _t(
            'Umeshaamua hatua nyingine ya ombi hili',
            'You already decided another step of this request'),
        'wrong_step' => _t('Ombi hili limehamia hatua nyingine. Fungua upya.',
            'This request has moved to another step. Open it again.'),
        'not_pending' =>
          _t('Ombi hili limeshaamuliwa', 'This request is already decided'),
        'no_approver' => _t(
            'Hakuna mtu wa kuidhinisha ombi hili. Wasiliana na ofisi.',
            'Nobody can approve this request. Contact the office.'),
        'over_approved' => _t('Kiasi kinazidi makadirio ya ombi',
            'The amount is above the request estimate'),
        'does_not_add_up' => _t(
            'Kilichotumika na chenji havilingani na fedha ulizopewa',
            'Spent and change do not match the money given'),
        'overspend_needs_acceptance' => _t(
            'Matumizi yamezidi fedha zilizotolewa. Kubali waziwazi ili kuthibitisha.',
            'Spending went over the money given. Accept it clearly to confirm.'),
        'request_not_funded' => _t('Ombi hili bado halijapewa fedha',
            'This request has no money given yet'),
        'request_other_station' => _t('Ombi hili ni la kituo kingine',
            'This request is for another station'),
        'request_not_found' =>
          _t('Ombi halikupatikana', 'The request was not found'),
        'request_not_purchase' => _t(
            'Mzigo huu hauwezi kufungwa na ombi la mzigo',
            'This delivery cannot be linked to a supply request'),
        'client_id_used' => _t('Tuma upya: ombi hili lilishatumika kwingine',
            'Send again: this attempt was already used elsewhere'),
        'not_approved' =>
          _t('Ombi bado halijaidhinishwa', 'The request is not approved yet'),
        'not_funded' => _t('Hakuna fedha zilizotolewa kwa ombi hili',
            'No money was given for this request'),
        'not_purchased' =>
          _t('Matumizi bado hayajaelezwa', 'The spending is not explained yet'),
        'reason_required' => _t('Andika sababu', 'Write a reason'),
        'needed_by_past' =>
          _t('Tarehe ya mahitaji imepita', 'The needed-by date has passed'),
        'no_station' => _t('Hujapewa kituo', 'You have no station'),
        'unknown_product' => _t('Bidhaa haipo', 'The product does not exist'),
        'unit_required' => _t('Weka kipimo', 'Enter a unit'),
        'not_requester' => _t('Ni aliyeomba tu anaweza kuondoa ombi',
            'Only the requester can withdraw a request'),
        'forbidden' => notAllowed,
        'invalid' => detailsInvalid,
        _ => errorBody,
      };
}
