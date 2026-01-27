import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_beacon/flutter_beacon.dart';
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
/// Uses CoreLocation on iOS (Apple-recommended) and BLE scanning on Android
class BleService {
  final _detectedBeaconsController =
      StreamController<DetectedBeacon>.broadcast();
  StreamSubscription<RangingResult>? _rangingSubscription;
  bool _isScanning = false;
  List<Beacon> _targetBeacons = [];

  Stream<DetectedBeacon> get detectedBeacons =>
      _detectedBeaconsController.stream;
  bool get isScanning => _isScanning;

  /// Start scanning for iBeacons
  Future<void> startScanning(List<Beacon> beaconsToFind) async {
    if (_isScanning) return;

    _targetBeacons = beaconsToFind;

    // Initialize flutter_beacon
    try {
      await flutterBeacon.initializeScanning;
    } catch (e) {
      debugPrint('BLE: Failed to initialize scanning: $e');
      throw Exception('Failed to initialize beacon scanning');
    }

    // Check authorization status on iOS
    if (Platform.isIOS) {
      final authStatus = await flutterBeacon.authorizationStatus;
      debugPrint('BLE: iOS authorization status: $authStatus');

      if (authStatus != AuthorizationStatus.allowed &&
          authStatus != AuthorizationStatus.always) {
        await flutterBeacon.requestAuthorization;
      }
    }

    // Check if Bluetooth is enabled
    final bluetoothState = await flutterBeacon.bluetoothState;
    if (bluetoothState != BluetoothState.stateOn) {
      throw Exception('Bluetooth is not enabled');
    }

    _isScanning = true;

    // Get unique UUIDs from target beacons
    final uuids = beaconsToFind
        .where((b) => b.beaconUuid != null)
        .map((b) => b.beaconUuid!)
        .toSet()
        .toList();

    debugPrint('BLE: Starting scan for ${beaconsToFind.length} beacons');
    debugPrint('BLE: UUIDs to monitor: $uuids');

    // Create regions for each UUID
    final regions = uuids
        .asMap()
        .entries
        .map((entry) => Region(
              identifier: 'region_${entry.key}',
              proximityUUID: entry.value,
            ))
        .toList();

    // Start ranging beacons
    _rangingSubscription = flutterBeacon.ranging(regions).listen(
      (RangingResult result) {
        _handleRangingResult(result);
      },
      onError: (error) {
        debugPrint('BLE: Ranging error: $error');
      },
    );
  }

  void _handleRangingResult(RangingResult result) {
    for (final beacon in result.beacons) {
      final uuid = beacon.proximityUUID;
      final major = beacon.major;
      final minor = beacon.minor;

      // Check if this matches any of our target beacons
      for (final target in _targetBeacons) {
        if (target.matches(uuid, major, minor)) {
          _detectedBeaconsController.add(DetectedBeacon(
            uuid: uuid,
            major: major,
            minor: minor,
            rssi: beacon.rssi,
            detectedAt: DateTime.now(),
          ));
          break;
        }
      }
    }
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    if (!_isScanning) return;

    await _rangingSubscription?.cancel();
    _rangingSubscription = null;
    _isScanning = false;
  }

  /// Check Bluetooth status
  Future<bool> isBluetoothEnabled() async {
    try {
      final state = await flutterBeacon.bluetoothState;
      return state == BluetoothState.stateOn;
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
