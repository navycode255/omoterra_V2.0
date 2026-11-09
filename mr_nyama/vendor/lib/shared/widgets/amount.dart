import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/theme.dart';

enum MNAmountSize { large, row, price }

/// A shilling amount in tabular figures: `.big` (34/40), `.amt` (16/20) or
/// `.price` (16/20, red). The value comes from server totals or the product
/// configuration; this widget only formats it.
class MNAmount extends StatelessWidget {
  final int shillings;
  final MNAmountSize size;
  final Color? color;

  const MNAmount(this.shillings,
      {super.key, this.size = MNAmountSize.row, this.color});

  @override
  Widget build(BuildContext context) {
    final style = switch (size) {
      MNAmountSize.large => MNText.amountLarge,
      MNAmountSize.row => MNText.amount,
      MNAmountSize.price => MNText.price,
    };
    return Text(formatTsh(shillings),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
        style: color == null ? style : style.copyWith(color: color));
  }
}

/// A labelled headline amount (label above `.big`), optionally with a
/// caption. Scales down to fit narrow screens and large text instead of
/// clipping.
class MNAmountDisplay extends StatelessWidget {
  final String label;
  final int shillings;
  final String? caption;
  final Color foreground;

  const MNAmountDisplay(
      {super.key,
      required this.label,
      required this.shillings,
      this.caption,
      this.foreground = MNColors.ink});

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$label, ${formatTsh(shillings)}'
            '${caption == null ? '' : ', $caption'}',
        container: true,
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: MNText.body
                      .copyWith(color: foreground, fontSize: 14, height: 1.3)),
              const SizedBox(height: MNSpace.x1),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(formatTsh(shillings),
                    style: MNText.amountLarge.copyWith(
                        color: foreground, fontSize: 38, height: 1.2)),
              ),
              if (caption != null) ...[
                const SizedBox(height: MNSpace.x1),
                Text(caption!,
                    style: MNText.body.copyWith(
                        color: foreground, fontSize: 14, height: 1.3)),
              ],
            ],
          ),
        ),
      );
}
