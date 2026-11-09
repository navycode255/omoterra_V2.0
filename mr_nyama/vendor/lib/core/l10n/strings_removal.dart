part of 'strings.dart';

/// Deleting what was added by mistake, and undoing "left" (owner decision
/// 28 October 2026). Same rules as `Strings`: Swahili first, `_t(sw, en)`.
extension RemovalStrings on Strings {
  String get deleteAccount => _t('Futa', 'Delete');
  String get deleteAccountBody => _t(
      'Kwa aliyeongezwa kwa makosa tu. Mwenye kumbukumbu (mauzo, makabidhiano, hesabu…) hawezi kufutwa: tumia "Ameondoka kazini".',
      'Only for someone added by mistake. Anyone with records (sales, handovers, counts…) cannot be deleted: use "Mark as left".');
  String deleteConfirmTitle(String name) => _t('Futa $name?', 'Delete $name?');
  String get deleteConfirmBody => _t(
      'Ataondolewa kwenye orodha zote na namba yake ya simu itatumika tena.',
      'They disappear from every list and their phone number is free again.');
  String get deleteYes => _t('Ndiyo, futa', 'Yes, delete');
  String get deletedToast => _t('Imefutwa.', 'Deleted.');
  String get returnAccount => _t('Rudisha kazini', 'Bring back');
  String get returnAccountBody => _t(
      'Ameondoka kwa makosa? Anarudi akiwa hai na anaingia kwa PIN yake. Mpangie kituo tena.',
      'Marked as left by mistake? They come back active and sign in with their PIN. Assign their station again.');
  String get deleteProduct => _t('Futa bidhaa', 'Delete product');
  String get deleteProductBody => _t(
      'Kwa bidhaa iliyoongezwa kwa makosa tu. Bidhaa iliyopokelewa au kuuzwa haifutwi: iache kuuzwa badala yake.',
      'Only for a product added by mistake. One received or sold cannot be deleted: stop selling it instead.');
  String get productCategories => _t('Makundi ya bidhaa', 'Product categories');
  String get productCategoriesCaption => _t(
      'Gusa kundi lililoongezwa kwa makosa ili kulifuta.',
      'Tap a category added by mistake to delete it.');
  String productCount(int n) => _t('Bidhaa $n', '$n products');
  String get deleteCategory => _t('Futa kundi', 'Delete category');
  String get deleteCategoryBody => _t(
      'Kundi lisilo na bidhaa tu ndilo linafutwa.',
      'Only a category with no products can be deleted.');
  String get deleteStation => _t('Futa kituo', 'Delete station');
  String get deleteStationBody => _t(
      'Vituo vilivyoongezwa kwa makosa tu ndivyo vinafutwa. Historia ya mauzo na stoo inabaki.',
      'Only stations created by mistake can be deleted. Sales and stock history stay.');
  String get deleteCustomer => _t('Futa mteja', 'Delete customer');
  String get deleteCustomerBody => _t(
      'Kwa mteja aliyeongezwa kwa makosa tu. Aliyewahi kukopa hafutwi: msimamishe badala yake.',
      'Only for a customer added by mistake. One who ever bought on credit cannot be deleted: suspend them instead.');
}
