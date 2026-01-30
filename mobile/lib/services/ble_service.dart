import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
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
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _isScanning = false;
  List<Beacon> _targetBeacons = [];

  Stream<DetectedBeacon> get detectedBeacons =>
      _detectedBeaconsController.stream;
  bool get isScanning => _isScanning;

  /// Start scanning for iBeacons
  Future<void> startScanning(List<Beacon> beaconsToFind) async {
    if (_isScanning) return;
    if (beaconsToFind.isEmpty) {
      throw Exception('No beacons to scan for');
    }

    _isScanning = true;
    _targetBeacons = beaconsToFind;

    debugPrint('BLE: Starting scan for ${beaconsToFind.length} beacons');

    // Start scanning
    await FlutterBluePlus.startScan(
      timeout: const Duration(hours: 24), // Long-running scan
      androidUsesFineLocation: true,
    );

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        for (final result in results) {
          _processAdvertisementData(result);
        }
      },
      onError: (error) {
        debugPrint('BLE: Scan error: $error');
      },
    );
  }

  /// Process advertisement data to detect iBeacons
  void _processAdvertisementData(ScanResult result) {
    final manufacturerData = result.advertisementData.manufacturerData;

    // iBeacon uses Apple's company ID: 0x004C
    final appleData = manufacturerData[0x004C];
    if (appleData == null || appleData.length < 23) return;

    // Check iBeacon prefix: 0x02 0x15
    if (appleData[0] != 0x02 || appleData[1] != 0x15) return;

    // Parse iBeacon data
    final uuid = _parseUuid(appleData.sublist(2, 18));
    final major = (appleData[18] << 8) + appleData[19];
    final minor = (appleData[20] << 8) + appleData[21];

    // Check if this matches any of our target beacons
    for (final target in _targetBeacons) {
      if (target.matches(uuid, major, minor)) {
        debugPrint(
            'BLE: Detected iBeacon - UUID: $uuid, Major: $major, Minor: $minor, RSSI: ${result.rssi}');

        _detectedBeaconsController.add(DetectedBeacon(
          uuid: uuid,
          major: major,
          minor: minor,
          rssi: result.rssi,
          detectedAt: DateTime.now(),
        ));
        break;
      }
    }
  }

  /// Parse UUID bytes into string format
  String _parseUuid(List<int> bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}'
        .toUpperCase();
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    if (!_isScanning) return;

    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
    debugPrint('BLE: Stopped scanning');
  }

  /// Check if Bluetooth is enabled
  Future<bool> isBluetoothEnabled() async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
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
