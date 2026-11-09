part of 'strings.dart';

/// Resolving problems, approvals and the owner's alert settings (MN027). Same
/// rules as `Strings`: Swahili first, `_t(sw, en)`.
extension ApprovalStrings on Strings {
  String get problemResolve => _t('Tatua', 'Resolve');
  String get problemHowResolved =>
      _t('Limetatuliwaje?', 'How was it resolved?');
  String get problemResolved => _t('Tatizo limetatuliwa.', 'Problem resolved.');
  String get problemSentForApproval =>
      _t('Limetumwa kwa idhini.', 'Sent for approval.');
  String get problemResolveHelp => _t(
      'Inarekodi uamuzi na sababu yake. Haibadilishi stoo wala fedha.',
      'This records the decision and its reason. It does not change stock or money.');
  String resolutionName(String code) => switch (code) {
        'loss' => _t('Hasara', 'Loss'),
        'found_movement' =>
          _t('Imepatikana kwenye rekodi', 'Found in the records'),
        'count_correction' => _t('Hesabu ilikosewa', 'Count was wrong'),
        'gain' => _t('Ziada', 'Gain'),
        'recount' => _t('Imehesabiwa upya', 'Recounted'),
        'confirmed' => _t('Imethibitishwa', 'Confirmed'),
        'investigated' => _t('Imechunguzwa', 'Investigated'),
        'reviewed' => _t('Imekaguliwa', 'Reviewed'),
        'standard_cost_set' =>
          _t('Gharama ya kawaida imewekwa', 'Standard cost set'),
        _ => code,
      };

  String get approvalsTitle => _t('Idhini', 'Approvals');
  String get approvalsCaption =>
      _t('Maombi yanayosubiri uamuzi', 'Requests waiting for a decision');
  String get approvalsEmpty =>
      _t('Hakuna ombi linalosubiri.', 'No requests are waiting.');
  String approvalAskedBy(String name) =>
      _t('Ameomba: $name', 'Requested by $name');
  String get approvalValueUnknown => _t('Thamani haijulikani', 'Value unknown');
  String get approvalWaiting => _t('Ombi lako linasubiri uamuzi.',
      'Your request is waiting for a decision.');
  String get approvalApprove => _t('Kubali', 'Approve');
  String get approvalReject => _t('Kataa', 'Refuse');
  String get approvalDecisionSaved =>
      _t('Uamuzi umehifadhiwa.', 'Decision saved.');
  String get approvalReason => _t('Sababu', 'Reason');

  String get alertSettingsTitle =>
      _t('Idhini na tahadhari', 'Approvals and alerts');
  String get alertSettingsCaption => _t(
      'Viwango vya idhini, muda wa tahadhari na SMS',
      'Approval limits, alert times and texts');
  String get alertSettingsHelp => _t(
      'Kila kiwango ni chako kuweka. Tahadhari isiyowekwa imezimwa; kikomo kisichowekwa kinapeleka ombi ngazi ya juu. Weka 0 kuondoa namba.',
      'Every value is yours to set. An unset alert is off; an unset limit sends a request up a tier. Enter 0 to clear a number.');
  String get notSet => _t('Haijawekwa', 'Not set');
  String get settingClear => _t('Ondoa', 'Clear');
  String get settingChange => _t('Badilisha', 'Change');
  String get settingSaved => _t('Imehifadhiwa.', 'Saved.');
  String settingReason(String name) =>
      _t('Mmiliki amebadilisha: $name', 'Owner changed: $name');
  String get sectionLimits => _t('Vikomo vya idhini', 'Approval limits');
  String get limitSupervisor => _t('Msimamizi hadi', 'Supervisor up to');
  String get limitFinance => _t('Fedha hadi', 'Finance up to');
  String get limitOwner => _t('Mmiliki hadi', 'Owner up to');
  String get independentApprovers =>
      _t('Waidhinishaji huru', 'Independent approvers');
  String approversCount(int n) => _t('Watu $n', '$n people');
  String get sectionAlerts => _t('Tahadhari', 'Alerts');
  String get alertClosingDue => _t('Funga Siku kabla ya saa', 'Closing due by');
  String get alertSilentMinutes =>
      _t('Simu kimya kwa dakika', 'Silent phone, minutes');
  String get alertLowSales => _t('Mauzo ya chini', 'Low sales');
  String get alertLowSalesTime =>
      _t('Mauzo ya chini: angalia saa', 'Low sales: check at');
  String get alertLowSalesShare =>
      _t('Mauzo ya chini: asilimia ya lengo', 'Low sales: share of target, %');
  String get alertSummaryTime =>
      _t('Muhtasari wa mmiliki saa', "Owner's summary at");
  String get sectionEscalation => _t('Kupanda ngazi', 'Escalation');
  String get escalateWarning =>
      _t('Tahadhari baada ya saa', 'Warnings after hours');
  String get escalateCritical =>
      _t('Hatari baada ya saa', 'Critical after hours');
  String get supervisorSms => _t('SMS kwa wasimamizi', 'Texts to supervisors');
}
