import 'package:flutter/widgets.dart';
import '../../core/api/providers.dart' show apiUrl, apiUrlAllowed;

/// Approved product photographs bundled with the app, by the catalogue's
/// `imageKey`. Server-hosted photos always take precedence. The sales catalogue
/// can also use the approved menu photos for recognised names without a key.
const _bundled = {
  // bbq-chicken-breast.png from the design handoff.
  'kidali': 'assets/images/grill.png',
  'shingo': 'assets/products/bbq-chicken-necks-skewer.png',
  'mishkaki': 'assets/owner/mishkaki.png',
  'maini': 'assets/owner/maini.png',
  'ndizi': 'assets/owner/ndizi.png',
  'firigisi': 'assets/owner/firigisi.png',
  'mzima': 'assets/owner/mzima.png',
  'nusu': 'assets/owner/nusu.png',
  'paja': 'assets/owner/paja.png',
};

const _menuNames = {
  'kuku mishkaki': 'mishkaki',
  'maini': 'maini',
  'ndizi kaanga': 'ndizi',
  'firigisi': 'firigisi',
  'firigisi mbili': 'firigisi',
  'kidali': 'kidali',
  'kidali (robo)': 'kidali',
  'kuku mzima': 'mzima',
  'nusu kuku': 'nusu',
  'paja': 'paja',
  'paja (robo)': 'paja',
  'shingo': 'shingo',
};

ImageProvider? productImageFor(String? key, {String? productName}) {
  if (key != null &&
      RegExp(r'^uploads/[0-9a-f]{32}/[0-9a-f]{64}\.jpg$').hasMatch(key) &&
      apiUrlAllowed(apiUrl)) {
    return NetworkImage(
        '${apiUrl.replaceFirst(RegExp(r"/+$"), "")}/api/v1/media/$key');
  }
  final asset = _bundled[key ?? _menuNames[productName?.trim().toLowerCase()]];
  return asset == null ? null : AssetImage(asset);
}
