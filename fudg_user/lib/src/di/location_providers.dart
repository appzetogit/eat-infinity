import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../platform/location/location_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});
