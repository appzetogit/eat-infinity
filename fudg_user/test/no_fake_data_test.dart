import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guard against fabricated content re-entering the app.
///
/// This exists because more than one agent/editor writes to this repo, and
/// regenerated screens have repeatedly reintroduced placeholder restaurants,
/// invented coupon codes and made-up statistics after they were removed. A
/// grep-style test is the cheapest thing that fails loudly the moment that
/// happens — run it in CI and the next regeneration is caught in seconds
/// instead of surviving to a build.
///
/// Adding a genuinely new pattern here is fine. Removing one because it "keeps
/// failing" is not: the failure is the point.
void main() {
  final lib = Directory('lib');

  test('no fabricated content in lib/', () {
    final checks = <String, RegExp>{
      'Third-party brands the platform has no relationship with':
          RegExp(r"""Domino|Pizza ?Hut|\bKFC\b|Burger King|Biryani Life|Garlic Hub|Lazzat|Zinger""",
              caseSensitive: false),
      'Coupon codes the backend does not issue':
          RegExp(r"""\b(TBL50|TBL25|TBL75|TBL150|SUVO25|MINT40|NEW15|SAVE30|FOOD75|FOOD50|BANK100|FREEDEL)\b"""),
      // Quote-agnostic on purpose: tying these to single-quoted Dart literals
      // let the same value through in a double-quoted string.
      'Fabricated statistics':
          RegExp(r"""2\.8K\+|1000\+|500K\+|120 Coins|₹1,620|₹620|₹597|Fudg Prime"""),
      'Placeholder contact details':
          RegExp(r"""98765[ ]?43210|www\.minto\.com|support@minto\.com"""),
      'Bundled content imagery (real content comes from the API)':
          RegExp(r"""assets/images/(dish|rest|cat|banner|badge)_"""),
      // Bare literal fallbacks: a decimal used as a rating fallback, or any
      // hardcoded "N km" distance. Both showed identically on every restaurant
      // card. Deliberately narrow — an earlier, looser version flagged
      // '100% safe & secure' copy and the dev-OTP default.
      'Literal rating or distance fallback':
          RegExp(r"""\?\s*'[0-9]+\.[0-9]+'|'[0-9]+(\.[0-9]+)?\s*km'"""),
      'Invented person names':
          RegExp(r"""Aamir Khan|tanu\.chouhan""", caseSensitive: false),
    };

    final violations = <String>[];

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];

        // Comments are allowed to name what was removed and why — that context
        // is what stops the next person reintroducing it.
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;

        checks.forEach((reason, pattern) {
          if (pattern.hasMatch(line)) {
            violations.add(
              '${entity.path}:${i + 1}\n    $reason\n    ${line.trim()}',
            );
          }
        });
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Fabricated content found in lib/. Real values must come from the '
          'backend; where the API has nothing, show an empty state rather than '
          'a placeholder.\n\n${violations.join('\n\n')}\n',
    );
  });
}
