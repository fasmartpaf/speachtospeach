import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as loc;
import '../models/running_models.dart';

class LocationService {
  final List<LocationPoint> _route = [];
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  
  List<LocationPoint> get route => List.unmodifiable(_route);
  
  /// Check and request location permissions
  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Start tracking location
  Future<void> startTracking({
    required Function(LocationPoint) onLocationUpdate,
    Function(String)? onError,
  }) async {
    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      onError?.call('Location permission denied');
      return;
    }

    _isTracking = true;
    _route.clear();

    // Request high accuracy location
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        final point = LocationPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          timestamp: DateTime.now(),
          speed: position.speed, // m/s, convert to km/h if needed
          altitude: position.altitude,
        );

        _route.add(point);
        onLocationUpdate(point);
      },
      onError: (error) {
        onError?.call(error.toString());
      },
    );
  }

  /// Stop tracking
  Future<void> stopTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
  }

  /// Calculate distance between two points (in kilometers)
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // Convert to km
  }

  /// Calculate total distance from route
  double calculateTotalDistance(List<LocationPoint> route) {
    if (route.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 1; i < route.length; i++) {
      totalDistance += calculateDistance(
        route[i - 1].latitude,
        route[i - 1].longitude,
        route[i].latitude,
        route[i].longitude,
      );
    }
    return totalDistance;
  }

  /// Calculate average pace (minutes per kilometer)
  double calculateAveragePace(double distanceKm, Duration duration) {
    if (distanceKm == 0 || duration.inSeconds == 0) return 0.0;
    final minutes = duration.inMinutes;
    return minutes / distanceKm;
  }

  /// Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }

  bool get isTracking => _isTracking;
}
