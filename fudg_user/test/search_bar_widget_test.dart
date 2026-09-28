import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_user_application/src/presentation/common_widgets/search_bar_widget.dart';

/// The widget uses ScreenUtil extensions, so it needs the same init the app does.
Widget _host(Widget child) => ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, _) => MaterialApp(
        // Mirrors the app theme, which fills every TextField — the reason the
        // hint was invisible on the search screen.
        theme: ThemeData(
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
      ),
    );

const _categories = ['Milk', 'Curd & Yogurt', 'Fresh Vegetables'];

void main() {
  testWidgets('hint rotates through categories while the field is empty',
      (tester) async {
    await tester.pumpWidget(_host(
      const SearchBarWidget(categories: _categories),
    ));
    await tester.pump();

    expect(find.text('Search "Milk"'), findsOneWidget);

    // Advance past the rotate interval, then past the cross-fade.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Search "Curd & Yogurt"'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Search "Fresh Vegetables"'), findsOneWidget);

    // Wraps back to the start rather than running off the end.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Search "Milk"'), findsOneWidget);
  });

  testWidgets('typing stops rotation and reveals the clear button',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(
      SearchBarWidget(controller: controller, categories: _categories),
    ));
    await tester.pump();

    expect(find.byIcon(Icons.close_rounded), findsNothing);

    await tester.enterText(find.byType(TextField), 'paneer');
    await tester.pump();

    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.text('Search "Milk"'), findsNothing);

    // Hint must stay put while there is text in the field.
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Search "Curd & Yogurt"'), findsNothing);

    // Clearing restores the rotating hint.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Search "Curd & Yogurt"'), findsOneWidget);
  });

  testWidgets('editable mode still shows the rotating hint when empty',
      (tester) async {
    await tester.pumpWidget(_host(
      const SearchBarWidget(categories: _categories, autofocus: true),
    ));
    await tester.pump();

    // The search screen uses this path; home uses readOnly. The hint must
    // render behind the TextField, not vanish.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search "Milk"'), findsOneWidget);

    // The field must not paint a fill, or it covers the hint behind it.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.filled, isFalse);
  });

  testWidgets('readOnly mode is a button and has no text field',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(
      SearchBarWidget(
        readOnly: true,
        categories: _categories,
        onTap: () => taps++,
      ),
    ));
    await tester.pump();

    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byType(SearchBarWidget));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('mic and scanner fire their callbacks', (tester) async {
    var mic = 0;
    var scan = 0;
    await tester.pumpWidget(_host(
      SearchBarWidget(
        categories: _categories,
        onMicTap: () => mic++,
        onScanTap: () => scan++,
      ),
    ));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.tap(find.byIcon(Icons.qr_code_scanner_rounded));
    await tester.pump();

    expect(mic, 1);
    expect(scan, 1);
  });

  testWidgets('a single category does not animate, and none still renders',
      (tester) async {
    await tester.pumpWidget(_host(
      const SearchBarWidget(categories: ['Milk']),
    ));
    await tester.pump();
    expect(find.text('Search "Milk"'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Search "Milk"'), findsOneWidget);

    await tester.pumpWidget(_host(const SearchBarWidget()));
    await tester.pump();
    expect(find.text('Search for dishes and restaurants'), findsOneWidget);
  });
}
