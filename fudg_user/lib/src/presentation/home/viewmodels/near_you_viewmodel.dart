import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/catalog_remote_datasource.dart';
import '../../../data/models/restaurant_model.dart';
import '../../../di/catalog_providers.dart';
import '../../../di/location_providers.dart';
import '../../../platform/location/location_service.dart';

class NearYouState {
  final AsyncValue<List<RestaurantModel>> restaurants;
  final UserLocationResult? location;

  const NearYouState({
    required this.restaurants,
    this.location,
  });

  NearYouState copyWith({
    AsyncValue<List<RestaurantModel>>? restaurants,
    UserLocationResult? location,
  }) {
    return NearYouState(
      restaurants: restaurants ?? this.restaurants,
      location: location ?? this.location,
    );
  }
}

final nearYouViewModelProvider = NotifierProvider<NearYouViewModel, NearYouState>(() {
  return NearYouViewModel();
});

class NearYouViewModel extends Notifier<NearYouState> {
  late final LocationService _locationService;
  late final CatalogRemoteDataSource _catalogDataSource;

  @override
  NearYouState build() {
    _locationService = ref.watch(locationServiceProvider);
    _catalogDataSource = ref.watch(catalogRemoteDataSourceProvider);
    Future.microtask(() => loadNearbyRestaurants());
    return const NearYouState(restaurants: AsyncValue.loading());
  }

  Future<void> loadNearbyRestaurants({bool isRefresh = false}) async {
    if (!isRefresh) {
      state = state.copyWith(restaurants: const AsyncValue.loading());
    }

    try {
      // 1. Fetch current GPS location
      final locResult = await _locationService.getCurrentLocationAndAddress();
      final double? lat = locResult.latitude;
      final double? lng = locResult.longitude;

      // 2. Query backend API with real latitude & longitude
      final list = await _catalogDataSource.getRestaurants(
        lat: lat,
        lng: lng,
        limit: 50,
      );

      // Filter list to valid restaurants
      state = state.copyWith(
        restaurants: AsyncValue.data(list),
        location: locResult,
      );
    } catch (e, st) {
      state = state.copyWith(
        restaurants: AsyncValue.error(e, st),
      );
    }
  }
}
