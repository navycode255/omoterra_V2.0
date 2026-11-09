# Mr. Nyama shared widgets

Reusable UI for the vendor app. Every widget is built from the design tokens in
`lib/core/theme/` and follows `mr_nyama/AGENTS.md` (Swahili, red/black/white,
Manrope, 56 px buttons, 48 px tap targets, no badges, reduced motion).
`lib/dev/showcase.dart` renders all of them; `test/components_test.dart` and
`test/component_hardening_test.dart` pin their behaviour.

## Architecture

```
core/theme/      tokens.dart   MNColors, MNSpace, MNRadius, MNSize, MNText
                 motion.dart   MNMotion durations, curves, reduced-motion helpers
                 theme.dart    mrNyamaTheme() so stock Material widgets match
shared/widgets/  primitives    MNPressable, MNIcon, MNSpinner, MNImageSpinner,
                               MNLoadingImage (server photos: ember ring, fade-in)
                 controls      MNButton, MNTextButton, MNIconButton, MNTextField,
                               MNQuantitySelector, MNChipBar, MNPaymentOption, PIN
                 layout        MNAppHeader, MNBottomNav, MNSheet, MNListRow + rows,
                               MNTile, MNReferenceAction, MNProductCard/Grid
                 feedback      MNAsyncView, MNEmptyState, MNErrorState, MNRefreshArea,
                               MNLoadingState, MNSkeleton, MNNote, MNSyncIndicator,
                               showMNConfirmDialog, showNumberSheet
                 filters       MNFilterSheet, MNFilterGroup, MNFilterOption,
                               MNFilterSwitch, MNCheckMark, showMNDateWheelSheet
shared/motion/   fire.dart     Funga Siku signature (do not restyle)
features/*       screens       compose the widgets above; no raw colours or sizes
```

Rules that hold for every widget:

- **Tokens only.** No hex values, font sizes or durations outside `core/theme/`.
- **Press feedback goes through `MNPressable`**: scale and colour, never a ripple.
  `onTap: null` means disabled; it sets the semantics and blocks taps.
- **One spoken label per control.** The control sets `semanticLabel` and wraps its
  visible text in `ExcludeSemantics`, so TalkBack never reads it twice.
- **Strings come from `stringsProvider`.** Widgets that need built-in wording
  (retry, loading, remaining) are `ConsumerWidget`s; everything else takes text in.
- **Motion respects `MNMotion.of(context, …)` / `MNMotion.reduced(context)`.**
- **Large text never clips.** Rows grow, amounts use `FittedBox`, empty states
  scroll, and the product grid sizes each row to its tallest card.

## Screen states: `MNAsyncView`

Use it for any screen or panel backed by an `AsyncValue`, so loading, empty, error
and refresh behave the same everywhere.

| Prop | Type | Meaning |
|---|---|---|
| `value` | `AsyncValue<T>` | the provider's state |
| `data` | `Widget Function(T)` | content when there is data |
| `isEmpty` | `bool Function(T)?` | when the data counts as empty |
| `empty` | `WidgetBuilder?` | usually an `MNEmptyState` |
| `onRetry` | `VoidCallback?` | shown on the error state |
| `refreshing` | `bool` | empty data shows skeletons instead of "empty" while a fetch runs |
| `loadingRows` | `int` | skeleton rows (default 5) |

```dart
MNAsyncView(
  value: ref.watch(productsProvider),
  isEmpty: (p) => p.isEmpty,
  refreshing: ref.watch(catalogRefreshProvider).isLoading,
  loadingRows: 4,
  empty: (_) => MNEmptyState(icon: MNIconData.bag, title: strings.noProducts),
  onRetry: () => ref.invalidate(productsProvider),
  data: (products) => ProductList(products),
)
```

`refreshing` never hides data that is already on screen. Screens with extra
states, such as delivery and receive (offline), still switch by hand and use
the same state widgets.

## Component API summary

| Widget | Key props | Notes |
|---|---|---|
| `MNButton` | `label`, `onPressed`, `variant`, `icon`, `busy` | 56 px; `.secondary` / `.destructive` constructors; `busy` blocks repeat taps |
| `MNTextButton` / `MNIconButton` | `label`, `onPressed` | 48 px minimum; icon button needs a `label` for screen readers |
| `MNTextField` | `label`, `controller`, `error`, `focusNode`, `autofocus`, `autofillHints`, `keyboardType` | caller-owned `focusNode` is never disposed by the field |
| `MNQuantitySelector` | `value`, `onChanged`, `itemLabel`, `min`, `max`, `large`, `compact` | exposes increase/decrease semantics actions; `compact` is the Kikapu stepper (30 px squares, 48 px targets), the canonical inline idadi stepper |
| `showNumberSheet` | `title`, `initial`, `max` | keypad entry; `initial` clamped into `0..max` |
| `MNChipBar` | `labels`, `selected`, `onSelect` | no counts on chips |
| `MNListRow` | `title`, `subtitle`, `leading`, `trailing`, `onTap`, `first`, `semanticLabel` | `first` drops the top hairline |
| `MNTransactionRow` | `time`, `product`, `quantity`, `paymentMethod`, `mobileMoney`, `amount`, `voided` | icon comes from `mobileMoney`, never from the label text |
| `MNStockRow` / `MNProductRow` / `MNMenuRow` / `MNInfoRow` | see source | |
| `MNProductCard` / `MNProductGrid` | `name`, `price` (nullable), `remaining`, `quantity`, `outOfStock`, callbacks | null price → "no price" and cannot be added |
| `MNReferenceAction` | `icon`, `label`, `subtitle`, `onTap`, `primary`, `compact` | announced as "label, subtitle" |
| `MNEmptyState` / `MNErrorState` / `MNLoadingState` | see `states.dart` | prefer `MNAsyncView` on screens |
| `MNNote` | `text`, `tone` | inline info / warning / error; live region |
| `MNSyncIndicator` | `status`, `compact`, `onDark`, `pendingCount`, `onTap` | green sent / grey animated sending / soft-red cloud-clock + count; delivery only: "sent" is not "verified" |
| `showMNSheet` + `MNSheet` | `title`, `children` | keeps clear of the keyboard and gesture inset |
| `showMNConfirmDialog` | `title`, `confirmLabel`, `cancelLabel`, `destructive` | dismissing returns `false` |

## Best practices

1. Check `lib/shared/widgets/` before building a screen-local widget. If two
   screens need the same thing, move it here with a test.
2. Money is an `int` of shillings from the server catalogue; format with
   `formatTsh` / `MNAmount`. Never compute or hardcode a price in a widget.
3. Record state must be truthful: saved on phone, sent and verified are different
   states. Never show "verified" without server confirmation.
4. Add a test for each new prop or state. Cover small phones (320 px) and 2× text
   (`phoneSizes`, `textScales` in `test/helpers.dart`) and run
   `meetsGuideline(androidTapTargetGuideline)` on interactive widgets.
5. Changing a widget's look away from `docs/mr_nyama/design/` needs the owner's
   approval, recorded in the implementation plan.
