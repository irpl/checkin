enum BeaconType { ibeacon, eddystone }

class Beacon {
  final String id;
  final String campaignId;
  final String name;
  final BeaconType beaconType;
  // iBeacon fields
  final String? beaconUuid;
  final int? major;
  final int? minor;
  // Eddystone-UID fields
  final String? eddystoneNamespace; // 10 bytes as hex (20 chars)
  final String? eddystoneInstance;  // 6 bytes as hex (12 chars)
  // Common fields
  final String? locationDescription;
  final bool isActive;
  final DateTime createdAt;

  Beacon({
    required this.id,
    required this.campaignId,
    required this.name,
    this.beaconType = BeaconType.ibeacon,
    this.beaconUuid,
    this.major,
    this.minor,
    this.eddystoneNamespace,
    this.eddystoneInstance,
    this.locationDescription,
    this.isActive = true,
    required this.createdAt,
  });

  factory Beacon.fromJson(Map<String, dynamic> json) {
    return Beacon(
      id: json['id'],
      campaignId: json['campaign_id'],
      name: json['name'],
      beaconType: json['beacon_type'] == 'eddystone'
          ? BeaconType.eddystone
          : BeaconType.ibeacon,
      beaconUuid: json['beacon_uuid'],
      major: json['major'],
      minor: json['minor'],
      eddystoneNamespace: json['eddystone_namespace'],
      eddystoneInstance: json['eddystone_instance'],
      locationDescription: json['location_description'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'name': name,
      'beacon_type': beaconType == BeaconType.eddystone ? 'eddystone' : 'ibeacon',
      'beacon_uuid': beaconUuid,
      'major': major,
      'minor': minor,
      'eddystone_namespace': eddystoneNamespace,
      'eddystone_instance': eddystoneInstance,
      'location_description': locationDescription,
      'is_active': isActive,
    };
  }

  /// Check if a detected iBeacon matches this beacon's identifiers
  bool matchesIBeacon(String uuid, int? detectedMajor, int? detectedMinor) {
    if (beaconType != BeaconType.ibeacon) return false;
    if (beaconUuid == null) return false;

    // Compare UUIDs without dashes and case-insensitive
    final normalizedBeaconUuid = beaconUuid!.toLowerCase().replaceAll('-', '');
    final normalizedDetectedUuid = uuid.toLowerCase().replaceAll('-', '');

    if (normalizedBeaconUuid != normalizedDetectedUuid) return false;

    // If major is specified, it must match
    if (major != null && major != detectedMajor) return false;

    // If minor is specified, it must match
    if (minor != null && minor != detectedMinor) return false;

    return true;
  }

  /// Check if a detected Eddystone-UID matches this beacon's identifiers
  bool matchesEddystone(String namespace, String instance) {
    if (beaconType != BeaconType.eddystone) return false;
    if (eddystoneNamespace == null || eddystoneInstance == null) return false;

    // Compare namespace and instance (case-insensitive)
    return eddystoneNamespace!.toLowerCase() == namespace.toLowerCase() &&
        eddystoneInstance!.toLowerCase() == instance.toLowerCase();
  }

  /// Legacy method for backwards compatibility
  bool matches(String uuid, int? detectedMajor, int? detectedMinor) {
    return matchesIBeacon(uuid, detectedMajor, detectedMinor);
  }
}
