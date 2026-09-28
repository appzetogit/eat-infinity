import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression: a child placed outside its parent's bounds paints under
/// `Clip.none` but never receives a tap, because hit testing still stops at the
/// parent's box. That is what made the Veg Mode switch dead — it was drawn
/// below the banner's stack, so every tap on it landed on nothing.
void main() {
  Future<bool> tappedAt(WidgetTester tester, {required double bottom}) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              height: 100,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const SizedBox(width: 200, height: 100),
                  Positioned(
                    left: 0,
                    bottom: bottom,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => tapped = true,
                      child: const SizedBox(width: 60, height: 40),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // 10pt up from the child's bottom edge: inside the child either way, but
    // outside the parent when the child is pushed out on a negative offset.
    await tester.tapAt(Offset(30, 100 - bottom - 10));
    await tester.pump();
    return tapped;
  }

  testWidgets('a child pushed outside the parent cannot be tapped', (t) async {
    expect(await tappedAt(t, bottom: -30), isFalse);
  });

  testWidgets('the same child inside the parent can be', (t) async {
    expect(await tappedAt(t, bottom: 0), isTrue);
  });
}
