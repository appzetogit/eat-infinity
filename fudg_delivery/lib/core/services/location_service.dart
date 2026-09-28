import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Streams GPS positions while the partner is online. On Android this runs
/// as a foreground service with a persistent notification (via geolocator's
/// `foregroundNotificationConfig`) so pings keep flowing when the app is
/// backgrounded; on iOS it relies on the `location` background mode.
class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  final _positionController = StreamController<Position>.broadcast();
  Position? lastPosition;

  Stream<Position> get positionStream => _positionController.stream;
  bool get isTracking => _positionSubscription != null;

  bool _startupPromptAsked = false;

  /// Asks for location access once, when the app opens.
  ///
  /// Riders were first prompted only on tapping Online, so the very first
  /// thing a new partner had to do was toggle offline and back on before the
  /// app would even ask.
  ///
  /// Deliberately lighter than [ensurePermissions]: it never force-opens
  /// system settings at launch. A permanent denial or disabled GPS is still
  /// handled there, at the point it actually blocks going online.
  Future<void> promptOnStartup() async {
    if (_startupPromptAsked) return;
    _startupPromptAsked = true;

    if (await Geolocator.checkPermission() == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    if (Platform.isAndroid && await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<bool> ensurePermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return false;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return false;
      }
    }

    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return false;
    }

    if (Platform.isAndroid) {
      final backgroundStatus = await Permission.locationAlways.status;
      if (!backgroundStatus.isGranted) {
        await Permission.locationAlways.request();
      }
      final notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted) {
        await Permission.notification.request();
      }
    }

    return true;
  }

  void startTracking() {
    if (isTracking) return;

    final locationSettings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 15,
            intervalDuration: const Duration(seconds: 5),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'You are online',
              notificationText: 'Sharing your live location for deliveries',
              enableWakeLock: true,
            ),
          )
        : AppleSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 15,
            pauseLocationUpdatesAutomatically: false,
            showBackgroundLocationIndicator: true,
            allowBackgroundLocationUpdates: true,
          );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((pos) {
              lastPosition = pos;
              _positionController.add(pos);
            });
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void dispose() {
    stopTracking();
    _positionController.close();
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(service.dispose);
  return service;
});
