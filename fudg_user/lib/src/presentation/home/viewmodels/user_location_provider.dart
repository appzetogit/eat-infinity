import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// The device's current position, or null when location is off or denied.
///
/// Shared so the restaurant listing can send `lat`/`lng` alongside zone
/// detection. Without those params the backend cannot compute `distanceInKm`,
/// which is why every restaurant card showed no real distance.
///
/// Cached for [_ttl]: a fresh GPS fix per list request would be slow and drain
/// battery, and a customer does not move far enough between requests for it to
/// matter.
final userLocationProvider = FutureProvider<Position?>((ref) async {
  return UserLocation.current();
});

/// Plain lat/lng for callers that only need the numbers.
final userLatLngProvider = Provider<({double lat, double lng})?>((ref) {
  final p = ref.watch(userLocationProvider).asData?.value;
  return p == null ? null : (lat: p.latitude, lng: p.longitude);
});

class UserLocation {
  const UserLocation._();

  static const _ttl = Duration(minutes: 5);

  static Position? _cached;
  static DateTime? _cachedAt;

  /// Last known position without waiting on the GPS stack. Used by synchronous
  /// call sites (the repository, search) that cannot await a fix mid-request.
  ///
  /// Deliberately ignores [_ttl]. Both callers use this only to send lat/lng so
  /// the backend can return `distanceInKm`, and returning null past the TTL made
  /// them silently omit the coordinates — distances showed on a fresh launch and
  /// then vanished five minutes later. A slightly stale fix rounds to the same
  /// kilometre; no fix at all shows an em dash. [current] still refreshes on the
  /// TTL, so the staleness is bounded in practice.
  static Position? get lastKnown => _cached;

  /// TTL-aware view of the cache, used only to decide whether to hit the GPS
  /// stack again. [lastKnown] must not use this or it would go back to
  /// returning null and dropping the coordinates.
  static Position? get _fresh {
    final at = _cachedAt;
    if (_cached == null || at == null) return null;
    return DateTime.now().difference(at) > _ttl ? null : _cached;
  }

  static Future<Position?> current() async {
    final fresh = _fresh;
    if (fresh != null) return fresh;

    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _cached = position;
      _cachedAt = DateTime.now();
      return position;
    } catch (_) {
      return null;
    }
  }
}
