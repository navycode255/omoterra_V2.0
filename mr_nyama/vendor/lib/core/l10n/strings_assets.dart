part of 'strings.dart';

/// Business assets, "Mali za biashara" (MN039). Assets are not stock or
/// products. Same rules as `Strings`: Swahili first, `_t(sw, en)`.
/// REVIEW: a Swahili speaker must check it.
extension AssetStrings on Strings {
  String get assetsTitle => _t('Mali za biashara', 'Business assets');
  String get assetsCaption =>
      _t('Vifaa na samani za biashara', 'Equipment and furniture');
  String get assetCategory => _t('Aina', 'Category');
  String get assetNumber => _t('Namba ya mali', 'Asset number');
  String get assetLocation => _t('Mahali', 'Location');
  String get assetArea => _t('Sehemu', 'Area');
  String get assetCustodian => _t('Mhusika', 'Custodian');
  String get assetCondition => _t('Hali', 'Condition');
  String get assetStatus => _t('Hali ya usajili', 'Registration status');
  String get assetQuantity => _t('Idadi', 'Quantity');
  String get assetUnit => _t('Kipimo', 'Unit');
  String get assetUnitPrice => _t('Bei ya kimoja', 'Price per item');
  String get assetTotalCost => _t('Jumla ya gharama', 'Total cost');
  String get assetPurchaseDate => _t('Tarehe ya kununua', 'Purchase date');
  String get assetSupplier => _t('Msambazaji', 'Supplier');
  String get assetReference => _t('Namba ya risiti', 'Receipt number');
  String get assetInService =>
      _t('Tarehe ya kuanza kutumika', 'Date placed into service');
  String get assetOpeningItem => _t('Mali ya zamani', 'Opening item');
  String get assetOpeningValue => _t('Thamani ya kuanzia', 'Opening value');
  String get assetCounted => _t('Kwa idadi', 'Counted');
  String get assetNumbered => _t('Kwa namba', 'Numbered');
  String get assetRegister => _t('Sajili mali', 'Register an asset');
  String get assetAddPurchase => _t('Ongeza manunuzi', 'Add a purchase');
  String get assetReason => _t('Sababu', 'Reason');
  String get assetSearch => _t('Tafuta mali', 'Search assets');
  String get assetAllLocations => _t('Biashara yote', 'Whole business');
  String get assetEmpty => _t(
      'Hakuna mali iliyosajiliwa bado.', 'No assets have been registered yet.');
  String get assetNotFound =>
      _t('Mali hii haipatikani.', 'This asset was not found.');
  String get assetChange => _t('Badilisha', 'Change');
  String get assetEditDetails => _t('Rekebisha maelezo', 'Edit details');
  String get assetNotes => _t('Maelezo', 'Notes');
  String get assetLots => _t('Manunuzi', 'Purchases');
  String get assetHistory => _t('Historia', 'History');
  String get leadAssets => _t('Mali za biashara', 'Business assets');

  // Owner forms (Task 6).
  String get assetNewPurchase => _t('Mali mpya iliyonunuliwa', 'Newly bought');
  String get assetOldItems =>
      _t('Mali ya zamani (kabla ya mfumo)', 'Existing (before the system)');
  String get assetAddItem => _t('Ongeza kitu kingine', 'Add another item');
  String get assetItemName => _t('Jina', 'Name');
  String get assetRemoveItem => _t('Ondoa kitu hiki', 'Remove this item');
  String assetItemTitle(int n) => _t('Kitu $n', 'Item $n');
  String get assetTracking => _t('Ufuatiliaji', 'Tracking');
  String get assetAddCategory => _t('Ongeza aina mpya', 'Add a new category');
  String get assetCategoryName => _t('Jina la aina', 'Category name');
  String get assetOpeningUnitValue =>
      _t('Thamani ya kuanzia kwa kimoja', 'Opening value per item');
  String get assetOriginalPrice =>
      _t('Bei ya awali ya kimoja', 'Original price per item');
  String get assetOriginalDate =>
      _t('Tarehe ya awali ya kununua', 'Original purchase date');
  String get assetNumbersLabel =>
      _t('Namba za mali (hiari)', 'Asset numbers (optional)');
  String get assetNumbersHint => _t('Ukiacha wazi, mfumo utaweka namba',
      'If left empty, the system will assign a number');
  String assetNumberN(int n) => _t('Namba $n', 'Number $n');
  String get assetSaveRegister => _t('Sajili', 'Register');
  String get assetRegistered => _t('Mali imesajiliwa.', 'Assets registered.');
  String get assetNoCustodian => _t('Hakuna', 'None');
  String get assetChangeWhat =>
      _t('Unabadilisha nini?', 'What are you changing?');
  String get assetFixLocation => _t('Rekebisha mahali (kosa la usajili)',
      'Correct the location (registration mistake)');
  String get assetChangeSave => _t('Hifadhi', 'Save');

  /// Quantity with its unit, "3 pcs".
  String assetQuantityUnit(int quantity, String unit) =>
      unit.isEmpty ? '$quantity' : '$quantity $unit';

  String assetTrackingLabel(String value) =>
      value == 'numbered' ? assetNumbered : assetCounted;

  String assetChangeLabel(String value) => switch (value) {
        'register' || 'registered' => _t('Imesajiliwa', 'Registered'),
        'purchase' => _t('Manunuzi', 'Purchase'),
        'quantity' => _t('Idadi', 'Quantity'),
        'condition' => _t('Hali', 'Condition'),
        'area' => _t('Sehemu', 'Area'),
        'custodian' => _t('Mhusika', 'Custodian'),
        'location' => _t('Mahali', 'Location'),
        _ => value,
      };

  String conditionLabel(String value) => switch (value) {
        'new' => _t('Mpya', 'New'),
        'good' => _t('Nzuri', 'Good'),
        'needs_maintenance' => _t('Inahitaji matengenezo', 'Needs maintenance'),
        'damaged' => _t('Imeharibika', 'Damaged'),
        'under_repair' => _t('Inatengenezwa', 'Under repair'),
        'unusable' => _t('Haitumiki', 'Unusable'),
        'disposed' => _t('Imeondolewa', 'Disposed'),
        _ => value,
      };

  String assetStatusLabel(String value) => switch (value) {
        'in_use' => _t('Inatumika', 'In use'),
        'in_transit' => _t('Njiani', 'In transit'),
        'missing' => _t('Haipo', 'Missing'),
        'written_off' => _t('Imefutwa', 'Written off'),
        'disposed' => _t('Imeondolewa', 'Disposed'),
        _ => value,
      };

  /// One sentence per server refusal code. `number_taken` reads well with
  /// or without the number (the race path can leave it out).
  String assetError(AssetError e) => switch (e.code) {
        'forbidden' => _t('Huna ruhusa ya kufanya hivi.',
            'You do not have permission to do this.'),
        'not_found' => _t('Mali hii haipatikani.', 'This asset was not found.'),
        'client_id_used' => _t(
            'Ombi hili limeshatumika kwa taarifa nyingine. Anza upya.',
            'This request was already used for different details. Start again.'),
        'name_taken' =>
          _t('Jina hili tayari limetumika.', 'This name is already in use.'),
        'no_change' => _t('Hakuna kilichobadilika.', 'Nothing has changed.'),
        'numbered_quantity' => _t(
            'Mali yenye namba ni moja tu. Sajili kila moja kivyake.',
            'A numbered item is always one. Register each one separately.'),
        'numbers_exceed_quantity' => _t('Namba ni nyingi kuliko idadi.',
            'There are more numbers than the quantity.'),
        'number_taken' => (e.number ?? '').isEmpty
            ? _t('Namba hiyo tayari imetumika.',
                'That number is already in use.')
            : _t('Namba ${e.number} tayari imetumika.',
                'Number ${e.number} is already in use.'),
        'price_required' =>
          _t('Weka bei ya kimoja.', 'Enter the price per item.'),
        'unknown_category' =>
          _t('Aina hii haipo.', 'This category does not exist.'),
        'unknown_custodian' =>
          _t('Mhusika huyu hapatikani.', 'This person was not found.'),
        'invalid_change' =>
          _t('Badiliko hili haliruhusiwi.', 'This change is not allowed.'),
        'invalid_condition' =>
          _t('Hali hii si sahihi.', 'This condition is not valid.'),
        'invalid_price' => _t('Bei si sahihi.', 'The price is not valid.'),
        'invalid_quantity' => _t('Idadi si sahihi. Andika namba nzima.',
            'The quantity is not valid. Enter a whole number.'),
        'invalid_tracking' =>
          _t('Chagua kwa idadi au kwa namba.', 'Choose counted or numbered.'),
        'items_required' =>
          _t('Ongeza angalau mali moja.', 'Add at least one asset.'),
        'name_required' => _t('Andika jina.', 'Enter a name.'),
        'one_custodian' =>
          _t('Chagua mhusika mmoja tu.', 'Choose only one custodian.'),
        'purchase_date_required' =>
          _t('Andika tarehe ya kununua.', 'Enter the purchase date.'),
        'reason_required' => _t('Andika sababu.', 'Enter a reason.'),
        'invalid' => _t('Taarifa si sahihi. Kagua na ujaribu tena.',
            'The details are not valid. Check and try again.'),
        _ => _t('Imekataliwa. Jaribu tena.', 'Refused. Try again.'),
      };
}
