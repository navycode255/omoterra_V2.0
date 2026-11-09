/// Pieces cut at the station (owner decisions 25 October 2026): Kuku mzima is
/// cut into 2 Nusu kuku, a Nusu kuku into 1 Paja and 1 Kidali. Selling a
/// piece the station lacks cuts what it comes from, and what is not sold
/// stays as exact pieces: one Paja sold from 3 birds leaves Kuku mzima 2,
/// Nusu kuku 1 and Kidali 1. This is the server's `cuts.availability` run
/// again over the sales saved on this phone and not yet sent.
library;

/// A piece's rule: the product it is cut from and how many one gives.
class CutRule {
  final String from;
  final int count;
  const CutRule(this.from, this.count);
}

class PoolEntry {
  final String id;

  /// The server's own stock of this product (on hand minus its unverified
  /// sales; below zero when pieces were sold beyond it), as a whole-number
  /// string; null when the server sent none.
  final String? held;
  final int pendingSold;
  final CutRule? cut;
  const PoolEntry(
      {required this.id, this.held, this.pendingSold = 0, this.cut});
}

/// What lies at the station once the cuts the sales need are made, and what
/// can be sold (that plus what the units above can still be cut into).
/// Products whose `held` the server did not send are left out. Below zero
/// only when the whole stock is oversold: sales are never blocked.
({Map<String, int> remaining, Map<String, int> sellable}) poolStock(
    List<PoolEntry> entries) {
  final rest = <String, int>{
    for (final e in entries)
      if (int.tryParse(e.held ?? '') case final held?)
        e.id: held - e.pendingSold
  };
  // Parent -> piece -> how many one parent gives.
  final yields = <String, Map<String, int>>{};
  final parentOf = <String, String>{};
  for (final e in entries) {
    final cut = e.cut;
    if (cut != null && cut.count > 0 && rest.containsKey(e.id)) {
      (yields[cut.from] ??= {})[e.id] = cut.count;
      parentOf[e.id] = cut.from;
    }
  }
  int depth(String id) {
    var n = 0;
    for (var p = id; parentOf.containsKey(p) && n <= parentOf.length; n++) {
      p = parentOf[p]!;
    }
    return n;
  }

  final parents = yields.keys.toList()
    ..sort((a, b) => depth(b).compareTo(depth(a)));
  for (final parent in parents) {
    var cut = 0;
    yields[parent]!.forEach((piece, n) {
      final have = rest[piece] ?? 0;
      if (have < 0) {
        final need = (-have + n - 1) ~/ n;
        if (need > cut) cut = need;
      }
    });
    if (cut == 0) continue;
    yields[parent]!
        .forEach((piece, n) => rest[piece] = (rest[piece] ?? 0) + cut * n);
    rest[parent] = (rest[parent] ?? 0) - cut;
  }
  final sellable = <String, int>{};
  for (final id in rest.keys) {
    var total = rest[id]!, product = id, times = 1, steps = 0;
    while (parentOf.containsKey(product) && steps++ <= parentOf.length) {
      times *= yields[parentOf[product]!]![product]!;
      product = parentOf[product]!;
      final above = rest[product] ?? 0;
      if (above > 0) total += above * times;
    }
    sellable[id] = total;
  }
  return (remaining: rest, sellable: sellable);
}
