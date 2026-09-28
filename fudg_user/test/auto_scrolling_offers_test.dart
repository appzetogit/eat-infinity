import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_user_application/src/presentation/home/widgets/restaurant_card.dart';

/// The offers ticker rotates on a timer and pauses while touched, so it is easy
/// to leave a Timer running past dispose or to keep rotating under the user's
/// finger. These pin both.
Widget _host(List<String> offers) => ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, _) => MaterialApp(
        home: Scaffold(
          body: AutoScrollingOffers(
            offers: offers,
            style: const TextStyle(fontSize: 12),
            interval: const Duration(milliseconds: 3500),
          ),
        ),
      ),
    );

void main() {
  testWidgets('renders nothing when the restaurant has no offers',
      (tester) async {
    await tester.pumpWidget(_host(const []));
    await tester.pump();
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('shows the first offer, then rotates to the next',
      (tester) async {
    await tester.pumpWidget(_host(const ['50% OFF up to ₹100', 'FREE delivery']));
    await tester.pump();
    expect(find.text('50% OFF up to ₹100'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pumpAndSettle();
    expect(find.text('FREE delivery'), findsOneWidget);
  });

  testWidgets('a single offer never rotates, so no timer is left running',
      (tester) async {
    await tester.pumpWidget(_host(const ['50% OFF up to ₹100']));
    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pumpAndSettle();
    expect(find.text('50% OFF up to ₹100'), findsOneWidget);
  });

  testWidgets('holding the row pauses rotation', (tester) async {
    await tester.pumpWidget(_host(const ['50% OFF up to ₹100', 'FREE delivery']));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('50% OFF up to ₹100')),
    );
    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pump(const Duration(milliseconds: 3500));
    expect(find.text('50% OFF up to ₹100'), findsOneWidget,
        reason: 'it must not slide away while the finger is down');

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
