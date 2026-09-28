import 'package:flutter_test/flutter_test.dart';
import 'package:food_user_application/src/data/models/promo_banner_model.dart';

/// The admin panel accepts MP4 uploads and reports them as `mediaType: video`.
/// Nothing read that field, so a video banner went to the image pipeline and
/// rendered as an empty placeholder.
void main() {
  PromoBannerModel parse(Map<String, dynamic> json) =>
      PromoBannerModel.fromApi(json);

  test('a video banner is recognised from mediaType', () {
    final b = parse({
      'id': '1',
      'imageUrl': '/uploads/food/home-promotion-banners/clip.mp4',
      'mediaType': 'video',
    });
    expect(b.isVideo, isTrue);
  });

  test('falls back to the extension when mediaType is absent', () {
    // Not every banner CMS behind this model sends mediaType.
    expect(parse({'id': '1', 'imageUrl': '/uploads/a/clip.MP4'}).isVideo, isTrue);
    expect(
      parse({'id': '1', 'imageUrl': '/uploads/a/clip.mp4?v=2'}).isVideo,
      isTrue,
    );
  });

  test('stills are still stills', () {
    expect(
      parse({'id': '1', 'imageUrl': '/uploads/a/banner.webp'}).isVideo,
      isFalse,
    );
    expect(
      parse({
        'id': '1',
        'imageUrl': '/uploads/a/banner.jpg',
        'mediaType': 'image',
      }).isVideo,
      isFalse,
    );
  });
}
