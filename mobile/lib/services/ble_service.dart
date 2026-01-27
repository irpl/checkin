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

    if (!await FlutterBluePlus.isSupported) {
      throw Exception('Bluetooth is not supported on this device');
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      throw Exception('Bluetooth is not enabled');
    }

    _isScanning = true;
    _targetBeacons = beaconsToFind;

    debugPrint('BLE: Starting scan for ${beaconsToFind.length} beacons');
    debugPrint('BLE: UUIDs: ${beaconsToFind.map((b) => b.beaconUuid).toList()}');

    // Start scanning with long timeout
    await FlutterBluePlus.startScan(
      timeout: const Duration(hours: 1),
      androidScanMode: AndroidScanMode.lowLatency,
    );

    // Listen to scan results
    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        for (final result in results) {
          final detected = _tryParseIBeacon(result);
          if (detected != null) {
            _detectedBeaconsController.add(detected);
          }
        }
      },
      onError: (error) {
        debugPrint('BLE: Scan error: $error');
      },
    );
  }

  /// Try to parse iBeacon from manufacturer data (Apple company ID 0x004C)
  DetectedBeacon? _tryParseIBeacon(ScanResult result) {
    final manufacturerData = result.advertisementData.manufacturerData;

    final appleData = manufacturerData[0x004C];
    if (appleData == null || appleData.length < 23) return null;

    // Check iBeacon prefix: 0x02 0x15
    if (appleData[0] != 0x02 || appleData[1] != 0x15) return null;

    // Parse UUID (bytes 2-17)
    final uuidBytes = appleData.sublist(2, 18);
    final uuid = _bytesToUuid(uuidBytes);

    // Parse Major (bytes 18-19) and Minor (bytes 20-21)
    final major = (appleData[18] << 8) | appleData[19];
    final minor = (appleData[20] << 8) | appleData[21];

    // Check if this matches any of our target beacons
    for (final target in _targetBeacons) {
      if (target.matches(uuid, major, minor)) {
        return DetectedBeacon(
          uuid: uuid,
          major: major,
          minor: minor,
          rssi: result.rssi,
          detectedAt: DateTime.now(),
        );
      }
    }

    return null;
  }

  /// Convert bytes to UUID string format
  String _bytesToUuid(List<int> bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Stop scanning
  Future<void> stopScanning() async {
    if (!_isScanning) return;

    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
  }

  /// Check Bluetooth status
  Future<bool> isBluetoothEnabled() async {
    if (!await FlutterBluePlus.isSupported) return false;
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

/// Stream provider for detected beacons
final detectedBeaconsProvider = StreamProvider<DetectedBeacon>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  return bleService.detectedBeacons;
});
