import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_beacon/flutter_beacon.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/beacon.dart';

/// Detected iBeacon with signal strength
class DetectedBeacon {
  final String uuid;
  final int major;
  final int minor;
  final int rssi;
  final DateTime detectedAt;

  DetectedBeacon({
    required this.uuid,
    required this.major,
    required this.minor,
    required this.rssi,
    required this.detectedAt,
  });
}

/// BLE scanning service for detecting iBeacons
class BleService {
  final _detectedBeaconsController =
      StreamController<DetectedBeacon>.broadcast();
  StreamSubscription<fb.RangingResult>? _rangingSubscription;
  bool _isScanning = false;
  bool _isInitialized = false;
  List<Beacon> _targetBeacons = [];

  Stream<DetectedBeacon> get detectedBeacons =>
      _detectedBeaconsController.stream;
  bool get isScanning => _isScanning;

  /// Initialize the beacon scanner
  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize and check location/bluetooth permissions
      await fb.flutterBeacon.initializeScanning;
      _isInitialized = true;
      debugPrint('BLE: Flutter Beacon initialized');
    } catch (e) {
      debugPrint('BLE: Initialization error: $e');
      throw Exception('Failed to initialize beacon scanner: $e');
    }
  }

  /// Start scanning for iBeacons
  Future<void> startScanning(List<Beacon> beaconsToFind) async {
    if (_isScanning) return;
    if (beaconsToFind.isEmpty) {
      throw Exception('No beacons to scan for');
    }

    await _initialize();

    _isScanning = true;
    _targetBeacons = beaconsToFind;

    debugPrint('BLE: Starting scan for ${beaconsToFind.length} beacons');
    debugPrint('BLE: UUIDs: ${beaconsToFind.map((b) => b.beaconUuid).toList()}');

    // Create regions for each unique UUID
    final regions = _createRegions(beaconsToFind);
    debugPrint('BLE: Created ${regions.length} regions');

    // Start ranging beacons
    _rangingSubscription = fb.flutterBeacon.ranging(regions).listen(
      (fb.RangingResult result) {
        _handleRangingResult(result);
      },
      onError: (error) {
        debugPrint('BLE: Ranging error: $error');
      },
    );
  }

  /// Create regions from beacon list (one region per unique UUID)
  List<fb.Region> _createRegions(List<Beacon> beacons) {
    final uniqueUuids = <String>{};
    final regions = <fb.Region>[];

    for (final beacon in beacons) {
      final beaconUuid = beacon.beaconUuid;
      if (beaconUuid == null) continue; // Skip beacons without UUID

      final uuid = beaconUuid.toUpperCase();
      if (uniqueUuids.add(uuid)) {
        regions.add(fb.Region(
          identifier: 'region_$uuid',
          proximityUUID: uuid,
        ));
      }
    }

    return regions;
  }

  /// Handle ranging results from flutter_beacon
  void _handleRangingResult(fb.RangingResult result) {
    if (result.beacons.isEmpty) return;

    for (final beacon in result.beacons) {
      final detected = _tryMatchBeacon(beacon);
      if (detected != null) {
        _detectedBeaconsController.add(detected);
      }
    }
  }

  /// Try to match a detected beacon with our target beacons
  DetectedBeacon? _tryMatchBeacon(fb.Beacon beacon) {
    final uuid = beacon.proximityUUID.toUpperCase();
    final major = beacon.major;
    final minor = beacon.minor;

    // Check if this matches any of our target beacons
    for (final target in _targetBeacons) {
      if (target.matches(uuid, major, minor)) {
        debugPrint(
            'BLE: Detected beacon - UUID: $uuid, Major: $major, Minor: $minor, RSSI: ${beacon.rssi}');

        return DetectedBeacon(
          uuid: uuid,
          major: major,
          minor: minor,
          rssi: beacon.rssi,
          detectedAt: DateTime.now(),
        );
      }
    }

    return null;
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    if (!_isScanning) return;

    await _rangingSubscription?.cancel();
    _rangingSubscription = null;
    _isScanning = false;
    debugPrint('BLE: Stopped scanning');
  }

  /// Check if Bluetooth is enabled
  Future<bool> isBluetoothEnabled() async {
    try {
      await _initialize();
      // flutter_beacon handles permission checks internally
      return true;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    stopScanning();
    _detectedBeaconsController.close();
  }
}

/// Provider for BLE service
final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream provider for detected beacons
final detectedBeaconsProvider = StreamProvider<DetectedBeacon>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  return bleService.detectedBeacons;
});
