import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';

class TelemetryProvider extends ChangeNotifier {
  Position? _position;
  AccelerometerEvent? _accel;
  double? _headingDeg;
  bool _running = false;
  DateTime? _lastUpdate;

  final List<LatLng> _trail = <LatLng>[];

  StreamSubscription<Position>? _posSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;

  Position? get position => _position;
  AccelerometerEvent? get acceleration => _accel;
  double? get headingDegrees => _headingDeg;
  bool get isRunning => _running;
  DateTime? get lastUpdate => _lastUpdate;
  List<LatLng> get trail => List.unmodifiable(_trail);

  double? get speedKmh => _position?.speed.isFinite == true ? _position!.speed * 3.6 : null;

  String get headingText {
    final h = _headingDeg;
    if (h == null || !h.isFinite) return '-';
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final idx = ((h % 360) / 45).round() % 8;
    return '${dirs[idx]}';
  }

  Future<bool> _ensurePermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      return false;
    }
    return true;
  }

  Future<void> start() async {
    if (_running) return;
    final ok = await _ensurePermissions();
    if (!ok) return;

    _running = true;

    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 1,
      ),
    ).listen((pos) {
      _position = pos;
      _headingDeg = pos.heading.isFinite ? pos.heading : _headingDeg;
      if (pos.latitude.isFinite && pos.longitude.isFinite) {
        final point = LatLng(pos.latitude, pos.longitude);
        if (_trail.isEmpty || _trail.last != point) {
          _trail.add(point);
          if (_trail.length > 5000) {
            _trail.removeAt(0);
          }
        }
      }
      _lastUpdate = DateTime.now();
      notifyListeners();
    });

    _accelSub = accelerometerEvents.listen((event) {
      _accel = event;
      _lastUpdate = DateTime.now();
      if (_running) notifyListeners();
    });

    notifyListeners();
  }

  Future<void> stop() async {
    _running = false;
    await _posSub?.cancel();
    await _accelSub?.cancel();
    _posSub = null;
    _accelSub = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _accelSub?.cancel();
    super.dispose();
  }
}
