import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  bool _isTracking = false;

  Future<void> initialize(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (!context.mounted) return;
      // Ask user for permission with a nice UI
      bool userAgreed = await _showPermissionRationale(context);
      if (userAgreed) {
        permission = await Geolocator.requestPermission();
      }
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return;
    }

    // Now request background permission if not granted
    if (permission == LocationPermission.whileInUse) {
      // Background location requires a separate request
      // We could ask again with rationale
    }
  }

  Future<bool> _showPermissionRationale(BuildContext context) async {
    if (!context.mounted) return false;
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Background Location Needed'),
        content: const Text(
          'NeoAgent uses your approximate background location to trigger geofence reminders (e.g. "Remind me to buy milk when I walk past the supermarket").\n\n'
          'Your location is never tracked continuously or stored on our servers. We only use it locally to check against your active tasks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Allow'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> startGeofenceTracking(String backendUrl, String token) async {
    if (_isTracking) return;
    _isTracking = true;

    // This runs a periodic check. In a real app, you'd use flutter_background_service
    // to keep this alive even when the app is swiped away.
    // For simplicity, we just simulate a foreground loop here.
    _trackLoop(backendUrl, token);
  }

  void _trackLoop(String backendUrl, String token) async {
    while (_isTracking) {
      try {
        await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));

        // Here we would normally fetch active geofences from local DB or backend
        // and calculate the distance. If inside a geofence, we trigger:
        
        // Example logic:
        // double distanceInMeters = Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
        // if (distanceInMeters < 100) { triggerBackend(position, label); }

      } catch (e) {
        debugPrint('Geofence tracking error: $e');
      }
      
      // Check every 5 minutes
      await Future.delayed(const Duration(minutes: 5));
    }
  }

  // ignore: unused_element
  Future<void> _triggerBackendGeofence(String backendUrl, String token, String label) async {
    try {
      await http.post(
        Uri.parse('$backendUrl/api/triggers/geofence'),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': token,
        },
        body: jsonEncode({
          'label': label,
          'latitude': 0, // Sending 0 to respect privacy (approx position)
          'longitude': 0,
          'action': 'User entered geofence: $label'
        }),
      );
    } catch (e) {
      debugPrint('Failed to trigger geofence: $e');
    }
  }
}
