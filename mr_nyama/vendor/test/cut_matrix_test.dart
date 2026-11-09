import 'package:flutter_test/flutter_test.dart';
import 'package:mr_nyama_vendor/features/sales/stock_pool.dart';

// The same table as backend/tests/test_cut_matrix.py (PARITY), row for row, so
// a mismatch between phone and server is visible. Order of each tuple follows
// the rule: production B N P K (Kuku mzima, Nusu, Paja, Kidali);
// three X A B C; uneven Y A B C.
//
//  R01 B3: nothing sold. Sellable N = 2 per bird = 6, P = K = 6.
//  R02 B3, N1 sold: N=-1 -> cut 1 bird: B2, N1. Sellable N = 1 + 2*2 = 5.
//  R03 B3, P1 sold: B2 N1 P0 K1.   R04 B3, K1 sold: B2 N1 P1 K0.
//  R05..R07 N1 only: P sold -> N0 K1; K sold -> N0 P1; N sold -> 0.
//  R08..R10 pieces held B1 N1 P1 K1: the piece sold is drawn first, no cut.
//  R11 B1, P1 + K1 sold: cut 1 N then 1 B -> B0 N1.   R12 B1, P2 sold: K2 left.
//  R14 B1, N3 sold: ceil(3/2)=2 birds -> N1, B=-1.   R15 nothing held, P1 sold.
//  T01 X3, A1 sold -> X2 B1 C1.   U01 Y2, A1 sold -> cut 1: A1 B1 C1 Y1.
typedef Row = (
  String id,
  String rule,
  List<int> held,
  List<int> sold,
  List<int> remaining,
  List<int> sellable
);

const rules = <String, Map<String, CutRule>>{
  'production': {
    'N': CutRule('B', 2),
    'P': CutRule('N', 1),
    'K': CutRule('N', 1),
  },
  'three': {
    'A': CutRule('X', 1),
    'B': CutRule('X', 1),
    'C': CutRule('X', 1),
  },
  'uneven': {
    'A': CutRule('Y', 2),
    'B': CutRule('Y', 1),
    'C': CutRule('Y', 1),
  },
};
const order = <String, List<String>>{
  'production': ['B', 'N', 'P', 'K'],
  'three': ['X', 'A', 'B', 'C'],
  'uneven': ['Y', 'A', 'B', 'C'],
};

const List<Row> parity = [
  ('R01', 'production', [3, 0, 0, 0], [0, 0, 0, 0], [3, 0, 0, 0], [3, 6, 6, 6]),
  ('R02', 'production', [3, 0, 0, 0], [0, 1, 0, 0], [2, 1, 0, 0], [2, 5, 5, 5]),
  ('R03', 'production', [3, 0, 0, 0], [0, 0, 1, 0], [2, 1, 0, 1], [2, 5, 5, 6]),
  ('R04', 'production', [3, 0, 0, 0], [0, 0, 0, 1], [2, 1, 1, 0], [2, 5, 6, 5]),
  ('R05', 'production', [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1], [0, 0, 0, 1]),
  ('R06', 'production', [0, 1, 0, 0], [0, 0, 0, 1], [0, 0, 1, 0], [0, 0, 1, 0]),
  ('R07', 'production', [0, 1, 0, 0], [0, 1, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]),
  ('R08', 'production', [1, 1, 1, 1], [0, 0, 1, 0], [1, 1, 0, 1], [1, 3, 3, 4]),
  ('R09', 'production', [1, 1, 1, 1], [0, 0, 0, 1], [1, 1, 1, 0], [1, 3, 4, 3]),
  ('R10', 'production', [1, 1, 1, 1], [0, 1, 0, 0], [1, 0, 1, 1], [1, 2, 3, 3]),
  ('R11', 'production', [1, 0, 0, 0], [0, 0, 1, 1], [0, 1, 0, 0], [0, 1, 1, 1]),
  ('R12', 'production', [1, 0, 0, 0], [0, 0, 2, 0], [0, 0, 0, 2], [0, 0, 0, 2]),
  ('R13', 'production', [1, 0, 0, 0], [0, 0, 2, 2], [0, 0, 0, 0], [0, 0, 0, 0]),
  ('R14', 'production', [1, 0, 0, 0], [0, 3, 0, 0], [-1, 1, 0, 0], [-1, 1, 1, 1]),
  ('R15', 'production', [0, 0, 0, 0], [0, 0, 1, 0], [-1, 1, 0, 1], [-1, 1, 1, 2]),
  ('R16', 'production', [2, 0, 0, 0], [1, 0, 1, 0], [0, 1, 0, 1], [0, 1, 1, 2]),
  ('R17', 'production', [1, 0, 1, 0], [0, 0, 2, 0], [0, 1, 0, 1], [0, 1, 1, 2]),
  ('T01', 'three', [3, 0, 0, 0], [0, 1, 0, 0], [2, 0, 1, 1], [2, 2, 3, 3]),
  ('T02', 'three', [1, 0, 0, 0], [0, 1, 1, 1], [0, 0, 0, 0], [0, 0, 0, 0]),
  ('T03', 'three', [1, 0, 0, 0], [0, 2, 0, 0], [-1, 0, 2, 2], [-1, 0, 2, 2]),
  ('T04', 'three', [2, 0, 1, 0], [0, 0, 1, 0], [2, 0, 0, 0], [2, 2, 2, 2]),
  ('U01', 'uneven', [2, 0, 0, 0], [0, 1, 0, 0], [1, 1, 1, 1], [1, 3, 2, 2]),
  ('U02', 'uneven', [1, 0, 0, 0], [0, 3, 0, 0], [-1, 1, 2, 2], [-1, 1, 2, 2]),
];

List<PoolEntry> entries(String rule, List<int> held, List<int> sold,
    {bool withRule = true}) {
  final names = order[rule]!;
  return [
    for (var i = 0; i < names.length; i++)
      PoolEntry(
          id: names[i],
          held: '${held[i]}',
          pendingSold: sold[i],
          cut: withRule ? rules[rule]![names[i]] : null),
  ];
}

void main() {
  for (final row in parity) {
    test('${row.$1} ${row.$2} held ${row.$3} sold ${row.$4}', () {
      final names = order[row.$2]!;
      final s = poolStock(entries(row.$2, row.$3, row.$4));
      expect([for (final n in names) s.remaining[n]], row.$5);
      expect([for (final n in names) s.sellable[n]], row.$6);
    });
  }

  test('no unit is created or lost: bird-equivalents before and after',
      () {
    // Quarter-birds: B=4, N=2, P=K=1 (production).
    const weight = {'B': 4, 'N': 2, 'P': 1, 'K': 1};
    for (final row in parity.where((r) => r.$2 == 'production')) {
      final names = order['production']!;
      final s = poolStock(entries('production', row.$3, row.$4));
      var before = 0, after = 0;
      for (var i = 0; i < 4; i++) {
        before += (row.$3[i] - row.$4[i]) * weight[names[i]]!;
        after += s.remaining[names[i]]! * weight[names[i]]!;
      }
      expect(after, before, reason: row.$1);
    }
  });

  test('without the rule on the phone nothing is cut (server with no rule)',
      () {
    // Rows R03 with no cut_from: 3 birds, a Paja sold. The server with an
    // empty rule gives the same figures (cut_matrix: test_without_a_rule...).
    final s = poolStock(
        entries('production', [3, 0, 0, 0], [0, 0, 1, 0], withRule: false));
    expect(s.remaining,
        {'B': 3, 'N': 0, 'P': -1, 'K': 0});
    expect(s.sellable['P'], -1);
    // With the rule the same sale leaves 2 / 1 / 0 / 1 (R03): a phone that
    // lost its rule shows the Paja oversold while the server still sells it.
    expect(
        poolStock(entries('production', [3, 0, 0, 0], [0, 0, 1, 0])).remaining,
        {'B': 2, 'N': 1, 'P': 0, 'K': 1});
  });

  test('a rule with no stock figure from the server is left out', () {
    final s = poolStock([
      const PoolEntry(id: 'B', held: '3'),
      const PoolEntry(id: 'N', cut: CutRule('B', 2)), // held not sent
    ]);
    expect(s.remaining.containsKey('N'), false);
    expect(s.remaining['B'], 3);
  });

  test('a rule with count 0 or a loop does not cut or hang', () {
    final s = poolStock([
      const PoolEntry(id: 'B', held: '3', pendingSold: 0),
      const PoolEntry(id: 'N', held: '0', pendingSold: 1, cut: CutRule('B', 0)),
    ]);
    expect(s.remaining, {'B': 3, 'N': -1});
    final loop = poolStock([
      const PoolEntry(id: 'A', held: '1', cut: CutRule('B', 2)),
      const PoolEntry(id: 'B', held: '0', pendingSold: 1, cut: CutRule('A', 2)),
    ]);
    expect(loop.remaining.keys.toSet(), {'A', 'B'});
  });
}
