import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every path the app navigates to must be a registered route.
///
/// GoRouter resolves routes at navigation time, so a missing one is invisible
/// until a partner actually walks that path — and then it is a dead-end error
/// screen, not an exception anyone sees in testing. Two shipped this way:
///
///   * `/account-status` — RouterNotifier redirected here for every newly
///     registered partner, but the route was never added. Submitting KYC
///     dropped them on "no routes for location: /account-status".
///   * `/profile` — the bottom bars on the wallet and history screens
///     navigate here by path.
///
/// This test reads the router and the call sites directly, so a new
/// `context.go('/somewhere')` without a matching route fails here first.
void main() {
  final routerSource = File('lib/core/router/app_router.dart').readAsStringSync();

  Set<String> registeredRoutes() {
    // Top-level paths, plus `parent/child` for nested routes.
    final paths = RegExp(r"path: '([^']+)'")
        .allMatches(routerSource)
        .map((m) => m.group(1)!)
        .toSet();
    final absolute = paths.where((p) => p.startsWith('/')).toSet();
    final relative = paths.where((p) => !p.startsWith('/'));
    // A relative segment is reachable under any absolute parent; compose all
    // combinations rather than parsing the nesting exactly.
    for (final parent in absolute.toList()) {
      for (final child in relative) {
        absolute.add('$parent/$child');
      }
    }
    return absolute;
  }

  Set<String> navigationTargets() {
    final targets = <String>{};
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      // context.go('/x') / context.push('/x') / context.replace('/x')
      for (final m in RegExp(r"context\.(?:go|push|replace)\(\s*'(/[^']*)'")
          .allMatches(source)) {
        targets.add(m.group(1)!);
      }
      // Redirect destinations in RouterNotifier: => '/x' and ? null : '/x'
      if (file.path.endsWith('router_notifier.dart')) {
        for (final m in RegExp(r"'(/[a-z-]+)'").allMatches(source)) {
          targets.add(m.group(1)!);
        }
      }
    }
    return targets;
  }

  test('every navigation target has a registered route', () {
    final registered = registeredRoutes();
    final missing = navigationTargets().difference(registered).toList()..sort();

    expect(
      missing,
      isEmpty,
      reason: 'These paths are navigated to but not registered in '
          'app_router.dart: $missing',
    );
  });

  test('the two routes that shipped missing are registered', () {
    final registered = registeredRoutes();
    expect(registered, contains('/account-status'));
    expect(registered, contains('/profile'));
  });
}
