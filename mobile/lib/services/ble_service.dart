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

    print('BLE: Starting scan for ${beaconsToFind.length} beacons');
    print('BLE:   iBeacons: ${ibeacons.map((b) => b.beaconUuid).toList()}');
    print(
        'BLE:   Eddystone: ${eddystones.map((b) => '${b.eddystoneNamespace}:${b.eddystoneInstance}').toList()}');

    // Start scanning
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        _processScaResult(result);
      }
    });

    // Start continuous scanning with periodic restarts
    _startContinuousScan();
  }

  void _processScaResult(ScanResult result) {
    // Try to parse as beacon and check if it matches our targets
    final beacon = _parseBeaconFromScanResult(result);
    if (beacon != null) {
      if (beacon.beaconType == BeaconType.eddystone) {
        print(
            'BLE: ✓ Detected target Eddystone: namespace=${beacon.eddystoneNamespace} instance=${beacon.eddystoneInstance}');
      } else {
        print(
            'BLE: ✓ Detected target iBeacon: UUID=${beacon.uuid} major=${beacon.major} minor=${beacon.minor}');
      }
      _detectedBeaconsController.add(beacon);
    }
  }

  void _startContinuousScan() async {
    // Start scan
    debugPrint("Does this go forever?");
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10),
      androidUsesFineLocation: true,
    );

    // Restart scan after timeout to keep it going
    _scanTimer = Timer(const Duration(seconds: 11), () {
      if (_isScanning) {
        _startContinuousScan();
      }
    });
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

  /// Try to parse iBeacon or AltBeacon from manufacturer data
  DetectedBeacon? _tryParseIBeacon(ScanResult result) {
    final manufacturerData = result.advertisementData.manufacturerData;

    // Get target iBeacon UUIDs for logging
    final targetUuids = _targetBeacons
        .where(
            (b) => b.beaconType == BeaconType.ibeacon && b.beaconUuid != null)
        .map((b) => b.beaconUuid!.toLowerCase().replaceAll('-', ''))
        .toSet();

    // Log all manufacturer data for debugging
    // for (final entry in manufacturerData.entries) {
    //   final manufacturerId = entry.key;
    //   final data = entry.value;
    //   debugPrint(
    //       'BLE: Manufacturer 0x${manufacturerId.toRadixString(16)}: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
    // }

    // Try iBeacon format first (Apple's company ID 0x004C)
    final appleData = manufacturerData[0x004C];
    if (appleData != null && appleData.length >= 23) {
      debugPrint('Apple stuff');
      debugPrint(
          '${appleData.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      if (appleData[0] == 0x02 && appleData[1] == 0x15) {
        final uuidBytes = appleData.sublist(2, 18);
        final uuid = _bytesToUuid(uuidBytes);
        final major = (appleData[18] << 8) | appleData[19];
        final minor = (appleData[20] << 8) | appleData[21];

        debugPrint(
            'BLE: Found Apple iBeacon - UUID=$uuid major=$major minor=$minor');

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
      }
    }

    // Try AltBeacon format (Radius Networks company ID 0x0118)
    final altBeaconData = manufacturerData[0x0118];
    if (altBeaconData != null && altBeaconData.length >= 24) {
      if (altBeaconData[0] == 0xBE && altBeaconData[1] == 0xAC) {
        final uuidBytes = altBeaconData.sublist(2, 18);
        final uuid = _bytesToUuid(uuidBytes);
        final major = (altBeaconData[18] << 8) | altBeaconData[19];
        final minor = (altBeaconData[20] << 8) | altBeaconData[21];

        debugPrint(
            'BLE: Found AltBeacon - UUID=$uuid major=$major minor=$minor');

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
      }
    }

    // Try ANY manufacturer ID with iBeacon format (0x02 0x15 prefix)
    for (final entry in manufacturerData.entries) {
      final manufacturerId = entry.key;
      final data = entry.value;

      // Skip Apple and AltBeacon as we already checked them
      if (manufacturerId == 0x004C || manufacturerId == 0x0118) continue;

      if (data.length >= 23 && data[0] == 0x02 && data[1] == 0x15) {
        final uuidBytes = data.sublist(2, 18);
        final uuid = _bytesToUuid(uuidBytes);
        final major = (data[18] << 8) | data[19];
        final minor = (data[20] << 8) | data[21];

        debugPrint(
            'BLE: Found iBeacon (manufacturer 0x${manufacturerId.toRadixString(16)}) - UUID=$uuid major=$major minor=$minor');

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
      }
    }

    // Generic scan: look for UUID pattern in any manufacturer data
    for (final entry in manufacturerData.entries) {
      final data = entry.value;

      // Need at least 21 bytes for UUID + major + minor
      if (data.length >= 21) {
        // Try to find iBeacon signature anywhere in the data
        for (int i = 0; i <= data.length - 23; i++) {
          if (data[i] == 0x02 && data[i + 1] == 0x15) {
            final uuidBytes = data.sublist(i + 2, i + 18);
            final uuid = _bytesToUuid(uuidBytes);
            final major = (data[i + 18] << 8) | data[i + 19];
            final minor = (data[i + 20] << 8) | data[i + 21];

            final normalizedUuid = uuid.toLowerCase().replaceAll('-', '');
            if (targetUuids.contains(normalizedUuid)) {
              debugPrint(
                  'BLE: Found iBeacon via pattern scan - UUID=$uuid major=$major minor=$minor');

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
            }
          }
        }
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
