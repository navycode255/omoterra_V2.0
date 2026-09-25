import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Where the system back button goes from [path] when there is nothing left
/// to pop, or null when back may leave the app.
///
/// Only the two role homes (and the signed-out entry screens) let the app
/// close. Every other page steps up to its parent, so a supplier who lands on
/// a page through `go` — after submitting a form, from a notification — is
/// walked back to Home instead of being thrown out of the app. '/' resolves to
/// the active role's home through the router redirect.
String? backFallback(String path) {
  const exits = {
    '/buyer',
    '/supplier',
    '/language',
    '/welcome',
    '/session',
    '/setup',
  };
  if (exits.contains(path)) return null;
  final parts = path.split('/').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return null;
  final first = parts.first;
  if (parts.length == 1) {
    return switch (first) {
      'phone' => '/welcome',
      'otp' => '/phone',
      'explore' || 'orders' || 'request' || 'business' => '/buyer',
      'business-submitted' => '/buyer',
      'stock' || 'supplier-orders' || 'supplier-demand' => '/supplier',
      'sales' || 'payouts' => '/supplier',
      'addresses' => '/account',
      _ => '/',
    };
  }
  final id = parts[1];
  return switch (first) {
    'stock' when parts.length > 2 => '/stock/$id',
    'stock' || 'batches' => '/stock',
    'listing' => '/explore',
    'checkout' => '/listing/$id',
    'confirmation' || 'order' || 'requests' => '/orders',
    'request-submitted' => '/buyer',
    'business' when parts.length > 2 => '/business/$id',
    'register-role' => '/account',
    _ => '/${parts.take(parts.length - 1).join('/')}',
  };
}

/// Sends the system back gesture to [backFallback] when the page has nothing
/// to pop. Pages that can pop (pushed routes, or in-page steps registered as
/// local history entries) are left to the navigator.
class RouteBackGuard extends StatelessWidget {
  final String path;
  final Widget child;
  const RouteBackGuard({super.key, required this.path, required this.child});

  /// The parent route for the page around [context], if it has one.
  static String? fallbackOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_BackFallbackScope>()
      ?.fallback;

  @override
  Widget build(BuildContext context) {
    final fallback = backFallback(path);
    if (fallback == null) return child;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return _BackFallbackScope(
        fallback: fallback,
        child: PopScope(
            canPop: canPop,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && !canPop) GoRouter.of(context).go(fallback);
            },
            child: child));
  }
}

class _BackFallbackScope extends InheritedWidget {
  final String fallback;
  const _BackFallbackScope({required this.fallback, required super.child});
  @override
  bool updateShouldNotify(_BackFallbackScope old) => old.fallback != fallback;
}

/// Makes each step of a multi-step form a back-button stop: after moving
/// forward, call [pushStep] with how to undo it; system back (or [popStep]
/// from an on-screen Back button) then returns to the previous step instead
/// of leaving the form.
mixin StepBackHistory<T extends StatefulWidget> on State<T> {
  final _steps = <LocalHistoryEntry>[];

  void pushStep(VoidCallback onBack) {
    late final LocalHistoryEntry entry;
    entry = LocalHistoryEntry(onRemove: () {
      _steps.remove(entry);
      if (mounted) setState(onBack);
    });
    _steps.add(entry);
    ModalRoute.of(context)?.addLocalHistoryEntry(entry);
  }

  void popStep() {
    if (_steps.isNotEmpty) _steps.last.remove();
  }
}
