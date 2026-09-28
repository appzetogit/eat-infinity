import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_user_application/src/data/models/promo_banner_model.dart';
import 'package:food_user_application/src/presentation/home/widgets/promo_banner_carousel.dart';

Widget _host(Widget child) => ScreenUtilInit(
  designSize: const Size(375, 812),
  builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
);

/// Renders on a phone-shaped surface instead of the 800x600 default.
///
/// The strip sizes itself from the width it is given, so on the default surface
/// it came out 800pt wide and taller than the 600pt viewport — a RenderFlex
/// overflow that says something about the test's window, not about the widget.
/// On a real device the carousel also lives in a scroll view, where extra
/// height scrolls rather than overflows.
void _usePhoneSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

PromoBannerModel _banner(String id) => PromoBannerModel.fromApi({
  'id': id,
  'imageUrl': 'https://example.test/$id.jpg',
});

void main() {
  // Regression: the carousel used to fall back to a count of 3 when it had no
  // banners — a leftover from three hardcoded promo cards that were removed.
  // The builder then indexed an empty list and every fresh install crashed the
  // home screen with:
  //   RangeError (length): Invalid value: Valid value range is empty: 0
  testWidgets('renders nothing and does not throw when there are no banners', (
    tester,
  ) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(_host(const PromoBannerCarousel(banners: [])));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(PageView), findsNothing);
    // No phantom page dots for banners that do not exist.
    expect(find.byType(AnimatedContainer), findsNothing);
  });

  testWidgets('renders one dot per real banner', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(
      _host(
        PromoBannerCarousel(
          banners: [_banner('a'), _banner('b'), _banner('c')],
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNWidgets(3));
  });

  testWidgets('a single banner still renders without paging', (tester) async {
    _usePhoneSurface(tester);
    await tester.pumpWidget(
      _host(PromoBannerCarousel(banners: [_banner('only')])),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(AnimatedContainer), findsOneWidget);
  });

  group('stripHeightFor', () {
    // The real banners on this backend are 2048x768.
    const realBannerAspect = 2048 / 768;

    test('a wide banner gets a card of its own shape, not a cropped one', () {
      final height = PromoBannerCarousel.stripHeightFor(
        cardWidth: 343,
        imageAspect: realBannerAspect,
        compact: false,
      );
      // 343 / 2.667 — the card is exactly the artwork's shape, so `cover` has
      // no overflow to trim and `contain` would leave no bars.
      expect(height, closeTo(343 / realBannerAspect, 0.01));
      expect(343 / height, closeTo(realBannerAspect, 0.01));
    });

    test('falls back to the banner shape until the image has decoded', () {
      expect(
        PromoBannerCarousel.stripHeightFor(
          cardWidth: 343,
          imageAspect: null,
          compact: false,
        ),
        closeTo(343 / PromoBannerCarousel.fallbackAspect, 0.01),
      );
    });

    test(
      'a freak portrait upload is reined in rather than filling the screen',
      () {
        // 0.5 (a tall poster) would otherwise ask for a 686pt-high strip.
        final height = PromoBannerCarousel.stripHeightFor(
          cardWidth: 343,
          imageAspect: 0.5,
          compact: false,
        );
        expect(height, closeTo(343 / PromoBannerCarousel.minAspect, 0.01));
        expect(height, lessThan(300));
      },
    );

    test('an ultra-wide panorama stays tall enough to see', () {
      expect(
        PromoBannerCarousel.stripHeightFor(
          cardWidth: 343,
          imageAspect: 8,
          compact: false,
        ),
        closeTo(343 / 3.2, 0.01),
      );
    });
  });
}
