import '../../domain/model/search_result.dart';
import '../models/food_model.dart';
import '../../presentation/home/viewmodels/user_location_provider.dart';
import 'catalog_remote_datasource.dart';

abstract class SearchRemoteDataSource {
  Future<List<SearchResult>> searchHome(String query);
  Future<List<SearchResult>> searchStore99(String query);
}

/// Server-side search via `GET /food/search/unified`.
///
/// The endpoint is restaurant-shaped even when the query matched a dish, so
/// there is no separate dish array to merge. Dishes are surfaced from the
/// cross-restaurant food feed, filtered by name — the feed itself has no `q`
/// parameter.
class SearchRemoteDataSourceImpl implements SearchRemoteDataSource {
  final CatalogRemoteDataSource _catalog;
  final String? Function() _zoneId;

  const SearchRemoteDataSourceImpl(this._catalog, this._zoneId);

  @override
  Future<List<SearchResult>> searchHome(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final results = <SearchResult>[];

    // Without lat/lng the backend cannot return `distanceInKm`, so every
    // search hit — and the detail screen opened from one — showed no distance
    // while the same restaurant on Home showed a real one.
    final here = UserLocation.lastKnown;
    final restaurants = await _catalog.search(
      trimmed,
      zoneId: _zoneId(),
      lat: here?.latitude,
      lng: here?.longitude,
    );
    for (final r in restaurants) {
      results.add(SearchResult(
        id: r.id,
        title: r.name,
        subtitle: r.tags.isEmpty ? r.deliveryTime : r.tags.join(', '),
        imageUrl: r.imageUrl,
        type: SearchResultType.restaurant,
        rating: r.rating,
        reviewCount: r.reviewCount,
        deliveryTime: r.deliveryTime,
        rawItem: r,
      ));
    }

    results.addAll(await _dishMatches(trimmed));
    return results;
  }

  @override
  Future<List<SearchResult>> searchStore99(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    return _dishMatches(trimmed, promo: 'switch99', type: SearchResultType.store99);
  }

  Future<List<SearchResult>> _dishMatches(
    String query, {
    String? promo,
    SearchResultType type = SearchResultType.food,
  }) async {
    final lower = query.toLowerCase();
    bool matches(FoodModel f) =>
        f.name.toLowerCase().contains(lower) ||
        f.description.toLowerCase().contains(lower);

    // Searched across the whole catalogue, deliberately unscoped by zone, to
    // match what restaurant search already does — it returns out-of-zone
    // restaurants (Jaipur, Banda) and the app lets you order from them.
    //
    // Zone-scoping only the dishes made the two halves disagree: "paneer"
    // listed dgvb in restaurants but not its paneer, because dgvb has no zoneId
    // set and so is missing from every zoned feed. Filtering the zone in one
    // half and not the other hides items that are genuinely orderable.
    final foods =
        (await _catalog.getPublicFoods(promo: promo)).where(matches).toList();

    return foods
        .map((f) => SearchResult(
              id: f.id,
              title: f.name,
              subtitle: f.description,
              imageUrl: f.imageUrl,
              type: type,
              price: f.price,
              originalPrice: f.originalPrice,
              rating: f.rating,
              reviewCount: f.reviewCount,
              isVeg: f.isVeg,
              restaurantId: f.restaurantId,
              deliveryTime: f.deliveryTime,
              rawItem: f,
            ))
        .toList();
  }
}
