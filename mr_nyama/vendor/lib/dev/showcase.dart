// Development tool: literal strings are allowed here (outside the l10n guard).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme/theme.dart';
import '../shared/widgets/amount.dart';
import '../shared/widgets/app_header.dart';
import '../shared/widgets/bottom_nav.dart';
import '../shared/widgets/buttons.dart';
import '../shared/widgets/cart_summary.dart';
import '../shared/widgets/dialogs.dart';
import '../shared/widgets/input_field.dart';
import '../shared/widgets/logo.dart';
import '../shared/widgets/pin.dart';
import '../shared/widgets/product_card.dart';
import '../shared/widgets/quantity.dart';
import '../shared/widgets/rows.dart';
import '../shared/widgets/sheet.dart';
import '../shared/widgets/states.dart';
import '../shared/widgets/sync_indicator.dart';
import '../shared/widgets/tile.dart';
import 'sample_data.dart';

/// The component showcase exists only in debug/profile builds started with
/// `--dart-define=MN_SHOWCASE=true`. In release builds this is a compile-time
/// false, so the route and its sample data are never reachable.
const devShowcaseEnabled = !kReleaseMode && bool.fromEnvironment('MN_SHOWCASE');

/// Every design-system component with isolated sample state. Nothing here
/// reads or writes app state (the real cart, session or sync).
class ShowcaseScreen extends StatefulWidget {
  const ShowcaseScreen({super.key});

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  // Local sample state only.
  final _cart = <String, int>{};
  int _qty = 2;
  int _pin = 0;
  bool _pinError = false;
  int _nav = 0;
  var _sync = MNSyncStatus.sent;
  bool _voided = false;
  String? _fieldError;

  int get _items => _cart.values.fold(0, (a, b) => a + b);
  int get _total => _cart.entries.fold(
      0,
      (s, e) =>
          s + sampleProducts.firstWhere((p) => p.id == e.key).price * e.value);

  void _setCart(String id, int q) =>
      setState(() => q <= 0 ? _cart.remove(id) : _cart[id] = q);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MNAppHeader(
        title: 'Vipengele (dev)',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: MNSpace.x3),
            child: MNSyncIndicator(status: _sync, compact: true, onDark: true),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: MNSpace.x6),
        children: [
          Container(
            color: MNColors.warningSurface,
            padding: const EdgeInsets.all(MNSpace.x3),
            child: Text(
                'SAMPULI TU — si data halisi. Haipo kwenye toleo la '
                'kazi.',
                style: MNText.status.copyWith(color: MNColors.warning)),
          ),
          _section('Nembo'),
          _pad(const Row(children: [
            MNLogo(height: 48, semanticLabel: 'Mr. Nyama'),
            SizedBox(width: MNSpace.x3),
            Expanded(
              child: Text('Faili rasmi la nembo halipo bado '
                  '(assets/brand/README.md).'),
            ),
          ])),
          _section('Vitufe'),
          _pad(Column(children: [
            MNButton('Hifadhi mauzo', onPressed: () {}),
            _gap,
            MNButton.secondary('Rudi nyumbani', onPressed: () {}),
            _gap,
            MNButton.destructive('Batilisha mauzo haya', onPressed: () {}),
            _gap,
            const MNButton('Imezimwa', onPressed: null),
            _gap,
            MNButton('Inahifadhi', onPressed: () {}, busy: true),
            _gap,
            Row(children: [
              MNTextButton('Ona yote', onPressed: () {}),
              const Spacer(),
              MNIconButton(MNIconData.search,
                  label: 'Tafuta', onPressed: () {}),
            ]),
          ])),
          _section('Vigae'),
          _pad(Row(children: [
            Expanded(
                child: MNTile(
                    icon: MNIconData.bag,
                    label: 'Mauzo',
                    primary: true,
                    onTap: () {})),
            const SizedBox(width: MNSpace.x2),
            Expanded(
                child: MNTile(
                    icon: MNIconData.truck,
                    label: 'Pokea Bidhaa',
                    onTap: () {})),
          ])),
          _section('Kiasi'),
          _pad(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MNAmountDisplay(
                  label: 'Mauzo ya leo (sampuli)',
                  shillings: _total,
                  caption: 'Bidhaa $_items'),
              _gap,
              const Wrap(
                  spacing: MNSpace.x4,
                  runSpacing: MNSpace.x2,
                  children: [
                    MNAmount(24000),
                    MNAmount(2500, size: MNAmountSize.price),
                  ]),
            ],
          )),
          _section('Kadi za bidhaa'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MNSpace.x4),
            child: MNProductGrid(
              children: [
                for (final p in sampleProducts)
                  MNProductCard(
                    name: p.name,
                    price: p.price,
                    image: p.image,
                    remaining: p.remaining,
                    outOfStock: p.remaining == '0',
                    quantity: _cart[p.id] ?? 0,
                    selected: (_cart[p.id] ?? 0) > 0,
                    onTap: () => _openQuantitySheet(p),
                    onAdd: () => _setCart(p.id, (_cart[p.id] ?? 0) + 1),
                    onDecrease: () => _setCart(p.id, (_cart[p.id] ?? 0) - 1),
                  ),
              ],
            ),
          ),
          _section('Safu'),
          MNProductRow(
              first: true,
              name: sampleProducts[0].name,
              price: sampleProducts[0].price,
              image: sampleProducts[0].image,
              trailing: MNQuantitySelector(
                  value: _qty,
                  min: 0,
                  itemLabel: sampleProducts[0].name,
                  onChanged: (v) => setState(() => _qty = v)),
              onTap: () {}),
          MNTransactionRow(
              time: '10:42',
              product: 'Kidali (Robo)',
              quantity: 2,
              paymentMethod: 'Taslimu',
              mobileMoney: false,
              amount: 5000,
              image: sampleProducts[0].image,
              voided: _voided,
              onLongPress: _confirmVoid),
          MNStockRow(
              name: sampleProducts[1].name,
              price: sampleProducts[1].price,
              image: sampleProducts[1].image,
              quantity: sampleProducts[1].remaining),
          MNStockRow(
              name: sampleProducts[3].name,
              trailing: MNQuantitySelector(
                  value: 12,
                  itemLabel: sampleProducts[3].name,
                  onChanged: (_) {})),
          MNMenuRow(icon: MNIconData.key, label: 'Badilisha PIN', onTap: () {}),
          MNMenuRow(
              icon: MNIconData.logout,
              label: 'Toka kwenye akaunti',
              color: MNColors.red,
              onTap: () {}),
          _section('Uga wa maandishi'),
          _pad(Column(children: [
            MNTextField(
                label: 'Namba ya simu',
                hint: '712 345 678',
                icon: MNIconData.phone,
                keyboardType: TextInputType.phone,
                error: _fieldError),
            _gap,
            MNButton.secondary(
                _fieldError == null ? 'Onyesha kosa' : 'Ondoa kosa',
                onPressed: () => setState(() => _fieldError =
                    _fieldError == null ? 'Namba si sahihi' : null)),
          ])),
          _section('PIN'),
          _pad(Column(children: [
            MNPinDots(filled: _pin, error: _pinError),
            const SizedBox(height: MNSpace.x6),
            MNPinKeypad(
              onDigit: (_) => setState(() {
                _pinError = false;
                _pin = (_pin + 1).clamp(0, 4);
                if (_pin == 4) {
                  _pinError = true;
                  _pin = 4;
                }
              }),
              onBackspace: () => setState(() {
                _pinError = false;
                _pin = (_pin - 1).clamp(0, 4);
              }),
            ),
          ])),
          _section('Usawazishaji'),
          _pad(Wrap(spacing: MNSpace.x4, runSpacing: MNSpace.x2, children: [
            for (final s in MNSyncStatus.values)
              GestureDetector(
                  onTap: () => setState(() => _sync = s),
                  child: MNSyncIndicator(status: s)),
          ])),
          _section('Dirisha na karatasi'),
          _pad(Column(children: [
            MNButton.secondary('Fungua uthibitisho', onPressed: _confirmVoid),
            _gap,
            MNButton.secondary('Fungua karatasi',
                onPressed: () => _openQuantitySheet(sampleProducts[0])),
          ])),
          _section('Hali'),
          const SizedBox(height: 320, child: MNLoadingState(rows: 4)),
          SizedBox(
              height: 360,
              child: MNEmptyState(
                  icon: MNIconData.bag,
                  title: 'Hakuna mauzo bado',
                  message: 'Mfano wa hali tupu.',
                  action: MNButton('Rekodi mauzo', onPressed: () {}))),
          SizedBox(height: 380, child: MNErrorState(onRetry: () {})),
          _section('Urambazaji'),
          MNBottomNav(
            currentIndex: _nav,
            onSelect: (i) => setState(() => _nav = i),
            items: const [
              MNNavItem(MNIconData.home, 'Nyumbani'),
              MNNavItem(MNIconData.bag, 'Mauzo'),
              MNNavItem(MNIconData.box, 'Bidhaa'),
            ],
          ),
        ],
      ),
      bottomNavigationBar:
          MNCartBar(itemCount: _items, total: _total, onTap: () {}),
    );
  }

  Future<void> _confirmVoid() async {
    final yes = await showMNConfirmDialog(context,
        title: 'Batilisha mauzo haya?',
        message:
            'Mauzo yatawekewa alama kuwa yamebatilishwa, hayatafutwa kabisa.',
        confirmLabel: 'Ndiyo, batilisha',
        cancelLabel: 'Hapana',
        destructive: true);
    if (yes) setState(() => _voided = !_voided);
  }

  Future<void> _openQuantitySheet(SampleProduct p) => showMNSheet<void>(
        context,
        builder: (context) => StatefulBuilder(
          builder: (context, setSheet) {
            final q = (_cart[p.id] ?? 0).clamp(1, 999);
            return MNSheet(title: p.name, children: [
              Text(formatTsh(p.price), style: MNText.price),
              Center(
                child: MNQuantitySelector(
                    value: q,
                    min: 1,
                    large: true,
                    itemLabel: p.name,
                    onChanged: (v) {
                      _setCart(p.id, v);
                      setSheet(() {});
                    }),
              ),
              MNButton('Ongeza kwenye mauzo', onPressed: () {
                if ((_cart[p.id] ?? 0) == 0) _setCart(p.id, 1);
                Navigator.of(context).pop();
              }),
            ]);
          },
        ),
      );

  static const _gap = SizedBox(height: MNSpace.x2);

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(
            MNSpace.x4, MNSpace.x6, MNSpace.x4, MNSpace.x2),
        child: Text(title, style: MNText.title),
      );

  Widget _pad(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: MNSpace.x4),
      child: child);
}
