import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Signature effects already played this session, by the record they
/// celebrate (sale client ID, closing count ID). An effect plays once;
/// reopening or a rebuild (for example after a background sync changes the
/// record's status) shows the settled frame instead.
final playedEffectsProvider = Provider<Set<String>>((ref) => <String>{});
