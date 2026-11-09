import 'package:flutter/material.dart';

import '../../core/theme/theme.dart';
import 'buttons.dart';
import 'sheet.dart';

/// Asks one yes/no question ("Batilisha mauzo haya?"). Returns true only when the
/// person confirms; dismissing counts as no. Fades in over 200 ms and out
/// over 120 ms (`m-in-fade` / `m-out-fade`). A [destructive] confirmation
/// uses the filled red-brown destructive button.
Future<bool> showMNConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
  bool sheet = false,
}) async {
  if (sheet) {
    return await showMNSheet<bool>(context,
            builder: (context) => MNSheet(children: [
                  Center(
                      child: Icon(
                          destructive
                              ? Icons.delete_outline
                              : Icons.error_outline,
                          size: 48,
                          color: destructive ? MNColors.red : MNColors.ink)),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: MNText.resolve(context, MNText.heading)),
                  if (message != null)
                    Text(message,
                        textAlign: TextAlign.center,
                        style: MNText.resolve(context, MNText.secondary)),
                  MNButton(confirmLabel,
                      onPressed: () => Navigator.pop(context, true)),
                  MNButton.secondary(cancelLabel,
                      onPressed: () => Navigator.pop(context, false)),
                ])) ??
        false;
  }
  final reduced = MNMotion.reduced(context);
  final result = await showGeneralDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: cancelLabel,
    barrierColor: MNColors.scrim,
    transitionDuration: reduced ? Duration.zero : MNMotion.fadeIn,
    pageBuilder: (context, _, __) => MNConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(
            parent: animation,
            curve: MNMotion.easeOut,
            reverseCurve: MNMotion.easeIn),
        child: child),
  );
  return result ?? false;
}

class MNConfirmDialog extends StatelessWidget {
  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  const MNConfirmDialog(
      {super.key,
      required this.title,
      this.message,
      required this.confirmLabel,
      required this.cancelLabel,
      this.destructive = false});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(MNSpace.x4),
              child: Material(
                color: MNColors.white,
                borderRadius: BorderRadius.circular(MNRadius.sheet),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(MNSpace.x6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                          header: true,
                          child: Text(title,
                              style: MNText.resolve(context, MNText.heading))),
                      if (message != null) ...[
                        const SizedBox(height: MNSpace.x2),
                        Text(message!,
                            style: MNText.resolve(context, MNText.body)
                                .copyWith(color: MNColors.ink2)),
                      ],
                      const SizedBox(height: MNSpace.x6),
                      MNButton(confirmLabel,
                          variant: destructive
                              ? MNButtonVariant.destructiveFilled
                              : MNButtonVariant.primary,
                          onPressed: () => Navigator.of(context).pop(true)),
                      const SizedBox(height: MNSpace.x2),
                      MNButton.secondary(cancelLabel,
                          onPressed: () => Navigator.of(context).pop(false)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
