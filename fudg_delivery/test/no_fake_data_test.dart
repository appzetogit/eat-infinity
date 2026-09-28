import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guard against fabricated content re-entering the rider app.
///
/// Every value on these screens belongs to a real partner, a real order or a
/// real payout. Placeholder names, invented amounts and stand-in ETAs have all
/// been removed at least once already; this is the cheapest thing that fails
/// the moment one comes back.
///
/// Adding a new pattern here is fine. Removing one because it "keeps failing"
/// is not — the failure is the point.
void main() {
  test('no fabricated content in lib/', () {
    final checks = <String, RegExp>{
      'Placeholder identity':
          RegExp(r"""Ali Khan|Aamir Khan|John Doe|DP78562|MF78562|SUVIO"""),
      'Invented money or counts':
          RegExp(r"""₹1,248|₹7,856|₹620|₹597|512 Ratings|182 orders"""),
      'Placeholder contact details':
          RegExp(r"""98765[ ]?43210|support@minto\.com|www\.minto\.com"""),
      // The trip screens fell back to these when the API had not answered.
      'Literal ETA / clock / distance fallback':
          RegExp(r"""'[0-9]{2}:[0-9]{2} ?(AM|PM)'|'[0-9]+ min'|'[0-9]+(\.[0-9]+)? km'"""),
      'Hardcoded sample address':
          RegExp(r"""Shree Complex|Andheri East|Mumbai 4000"""),
    };

    final violations = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        // Comments are allowed to name what was removed and why — that context
        // is what stops the next person putting it back.
        final trimmed = lines[i].trimLeft();
        if (trimmed.startsWith('//')) continue;

        checks.forEach((reason, pattern) {
          if (pattern.hasMatch(lines[i])) {
            violations.add('${entity.path}:${i + 1}\n    $reason\n    $trimmed');
          }
        });
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'Fabricated content found in lib/. Real values must come from the '
          'backend; where the API has nothing, show an em dash or an empty '
          'state rather than a placeholder.\n\n${violations.join('\n\n')}\n',
    );
  });
}
