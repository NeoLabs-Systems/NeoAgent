import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../src/backend_client.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  bool _isTracking = false;

  /// Bumped on every start and stop, so a loop still sleeping from an earlier
  /// start ends instead of running beside a new one.
  int _trackingGeneration = 0;
  final Set<int> _insideFenceIds = <int>{};

  Future<void> initialize(BuildContext context) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (!context.mounted) return;
      final userAgreed = await _showPermissionRationale(context);
      if (userAgreed) {
        permission = await Geolocator.requestPermission();
      }
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    if (permission == LocationPermission.whileInUse) {
      await Geolocator.requestPermission();
    }
  }

  Future<bool> _showPermissionRationale(BuildContext context) async {
    if (!context.mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(appStrings.backgroundLocationNeeded),
            content: Text(
              appStrings.neoagentUsesYourApproximateBackgroundLocation +
              appStrings.yourLocationIsNeverTrackedContinuously,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(appStrings.notNow2),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(appStrings.allow),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> startGeofenceTracking(
    BackendClient client,
    String backendUrl,
  ) async {
    if (_isTracking) return;
    _isTracking = true;
    _trackLoop(client, backendUrl, ++_trackingGeneration);
  }

  void stopGeofenceTracking() {
    _isTracking = false;
    _trackingGeneration++;
    _insideFenceIds.clear();
  }

  Future<void> _trackLoop(
    BackendClient client,
    String backendUrl,
    int generation,
  ) async {
    while (_isTracking && generation == _trackingGeneration) {
      try {
        final response = await client.fetchGeofences(backendUrl);
        final raw = response['geofences'];
        final fences = raw is List
            ? raw
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : const <Map<String, dynamic>>[];
        if (fences.isEmpty) {
          _insideFenceIds.clear();
          await Future<void>.delayed(const Duration(minutes: 5));
          continue;
        }

        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
          ),
        );

        for (final fence in fences) {
          final id = (fence['id'] as num?)?.toInt();
          final latitude = (fence['latitude'] as num?)?.toDouble();
          final longitude = (fence['longitude'] as num?)?.toDouble();
          final radius = (fence['radius_meters'] as num?)?.toDouble() ?? 100;
          if (latitude == null || longitude == null) continue;

          final distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            latitude,
            longitude,
          );
          final inside = distance <= radius;
          if (inside) {
            final firstEntry = id == null || _insideFenceIds.add(id);
            if (firstEntry) {
              await client.triggerGeofenceEvent(
                backendUrl,
                label: fence['label']?.toString() ?? 'unknown',
                latitude: position.latitude,
                longitude: position.longitude,
                radiusMeters: radius.round(),
                action: fence['trigger_action']?.toString(),
              );
            }
          } else if (id != null) {
            _insideFenceIds.remove(id);
          }
        }
      } catch (e) {
        debugPrint(appStrings.geofenceTrackingErrorArg1(e));
      }

      await Future<void>.delayed(const Duration(minutes: 5));
    }
  }
}
