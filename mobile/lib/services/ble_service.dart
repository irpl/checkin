import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/beacon.dart';

/// Detected beacon with signal strength (supports both iBeacon and Eddystone)
class DetectedBeacon {
  final BeaconType beaconType;
  // iBeacon fields
  final String? uuid;
  final int? major;
  final int? minor;
  // Eddystone fields
  final String? eddystoneNamespace;
  final String? eddystoneInstance;
  // Common fields
  final int rssi;
  final DateTime detectedAt;

  DetectedBeacon.iBeacon({
    required String this.uuid,
    this.major,
    this.minor,
    required this.rssi,
    required this.detectedAt,
  })  : beaconType = BeaconType.ibeacon,
        eddystoneNamespace = null,
        eddystoneInstance = null;

  DetectedBeacon.eddystone({
    required String this.eddystoneNamespace,
    required String this.eddystoneInstance,
    required this.rssi,
    required this.detectedAt,
  })  : beaconType = BeaconType.eddystone,
        uuid = null,
        major = null,
        minor = null;
}

/// BLE scanning service for detecting iBeacons and Eddystone beacons
class BleService {
  final _detectedBeaconsController =
      StreamController<DetectedBeacon>.broadcast();
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _isScanning = false;
  List<Beacon> _targetBeacons = [];
  Timer? _scanTimer;

  Stream<DetectedBeacon> get detectedBeacons =>
      _detectedBeaconsController.stream;
  bool get isScanning => _isScanning;

  // Eddystone-UID service UUID
  static const String eddystoneServiceUuid =
      '0000feaa-0000-1000-8000-00805f9b34fb';

  /// Start scanning for BLE beacons
  Future<void> startScanning(List<Beacon> beaconsToFind) async {
    if (_isScanning) return;

    // Check if Bluetooth is available and on
    if (!await FlutterBluePlus.isSupported) {
      throw Exception('Bluetooth is not supported on this device');
    }

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      throw Exception('Bluetooth is not enabled');
    }

    _isScanning = true;
    _targetBeacons = beaconsToFind;

    // Log what we're looking for
    final ibeacons =
        beaconsToFind.where((b) => b.beaconType == BeaconType.ibeacon).toList();
    final eddystones = beaconsToFind
        .where((b) => b.beaconType == BeaconType.eddystone)
        .toList();

    debugPrint('BLE: Starting scan for ${beaconsToFind.length} beacons');
    debugPrint('BLE:   iBeacons: ${ibeacons.map((b) => b.beaconUuid).toList()}');
    debugPrint(
        'BLE:   Eddystone: ${eddystones.map((b) => '${b.eddystoneNamespace}:${b.eddystoneInstance}').toList()}');

    // Start scanning - single call with long timeout
    await FlutterBluePlus.startScan(
      timeout: const Duration(hours: 1),
      androidScanMode: AndroidScanMode.lowLatency,
    );

    // Listen to scan results
    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        _handleScanResults(results);
      },
      onError: (error) {
        debugPrint('BLE: Scan error: $error');
      },
    );
  }

  void _handleScanResults(List<ScanResult> results) {
    for (final result in results) {
      final beacon = _parseBeaconFromScanResult(result);
      if (beacon != null) {
        _detectedBeaconsController.add(beacon);
      }
    }
  }

  /// Parse beacon data from scan result (supports iBeacon, AltBeacon, and Eddystone)
  DetectedBeacon? _parseBeaconFromScanResult(ScanResult result) {
    // First try Eddystone (check service data)
    final eddystone = _tryParseEddystone(result);
    if (eddystone != null) return eddystone;

    // Then try iBeacon/AltBeacon (check manufacturer data)
    final ibeacon = _tryParseIBeacon(result);
    if (ibeacon != null) return ibeacon;

    return null;
  }

  /// Try to parse Eddystone-UID from service data
  DetectedBeacon? _tryParseEddystone(ScanResult result) {
    final serviceData = result.advertisementData.serviceData;

    // Check for Eddystone service UUID (0xFEAA)
    for (final entry in serviceData.entries) {
      final uuid = entry.key.toString().toLowerCase();
      final data = entry.value;

      // Eddystone service UUID can appear as "feaa" or full UUID
      if (uuid.contains('feaa') && data.isNotEmpty) {
        // First byte is frame type
        final frameType = data[0];

        // Eddystone-UID frame type is 0x00
        if (frameType == 0x00 && data.length >= 18) {
          // Byte 1: TX power
          // Bytes 2-11: Namespace ID (10 bytes)
          // Bytes 12-17: Instance ID (6 bytes)

          final namespaceBytes = data.sublist(2, 12);
          final instanceBytes = data.sublist(12, 18);

          final namespace = namespaceBytes
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join();
          final instance = instanceBytes
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join();

          // Check if this matches any of our target Eddystone beacons
          for (final target in _targetBeacons) {
            if (target.matchesEddystone(namespace, instance)) {
              return DetectedBeacon.eddystone(
                eddystoneNamespace: namespace,
                eddystoneInstance: instance,
                rssi: result.rssi,
                detectedAt: DateTime.now(),
              );
            }
          }
        }
      }
    }

    return null;
  }

  /// Try to parse iBeacon from manufacturer data (Apple's company ID 0x004C)
  DetectedBeacon? _tryParseIBeacon(ScanResult result) {
    final manufacturerData = result.advertisementData.manufacturerData;

    // iBeacon uses Apple's company ID: 0x004C
    final appleData = manufacturerData[0x004C];
    if (appleData == null || appleData.length < 23) {
      return null;
    }

    // Check iBeacon prefix: 0x02 0x15
    if (appleData[0] != 0x02 || appleData[1] != 0x15) {
      return null;
    }

    // Parse UUID (bytes 2-17)
    final uuidBytes = appleData.sublist(2, 18);
    final uuid = _bytesToUuid(uuidBytes);

    // Parse Major (bytes 18-19) and Minor (bytes 20-21)
    final major = (appleData[18] << 8) | appleData[19];
    final minor = (appleData[20] << 8) | appleData[21];

    // Check if this matches any of our target beacons
    for (final target in _targetBeacons) {
      if (target.matchesIBeacon(uuid, major, minor)) {
        return DetectedBeacon.iBeacon(
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

    _scanTimer?.cancel();
    _scanTimer = null;
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
