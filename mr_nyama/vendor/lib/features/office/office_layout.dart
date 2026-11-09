import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';

/// Keeps office pages readable on tablets and clear of system gestures.
class OfficeContent extends StatelessWidget {
  final Widget child;
  const OfficeContent({super.key, required this.child});

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(MNSpace.x4),
              child: child,
            ),
          ),
        ),
      );
}

/// A quiet bordered surface for related management actions.
class OfficePanel extends StatelessWidget {
  final Widget child;
  const OfficePanel({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: MNColors.white,
          border: Border.all(color: MNColors.border),
          borderRadius: BorderRadius.circular(MNRadius.medium),
        ),
        child: child,
      );
}
