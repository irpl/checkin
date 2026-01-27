class Beacon {
  final String id;
  final String campaignId;
  final String name;
  final String? beaconUuid;
  final int? major;
  final int? minor;
  final String? locationDescription;
  final bool isActive;
  final DateTime createdAt;

  Beacon({
    required this.id,
    required this.campaignId,
    required this.name,
    this.beaconUuid,
    this.major,
    this.minor,
    this.locationDescription,
    this.isActive = true,
    required this.createdAt,
  });

  factory Beacon.fromJson(Map<String, dynamic> json) {
    return Beacon(
      id: json['id'],
      campaignId: json['campaign_id'],
      name: json['name'],
      beaconUuid: json['beacon_uuid'],
      major: json['major'],
      minor: json['minor'],
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
      'beacon_uuid': beaconUuid,
      'major': major,
      'minor': minor,
      'location_description': locationDescription,
      'is_active': isActive,
    };
  }

  /// Check if a detected iBeacon matches this beacon's identifiers
  bool matches(String uuid, int? detectedMajor, int? detectedMinor) {
    if (beaconUuid == null) return false;

    // Compare UUIDs case-insensitive (with or without dashes)
    final normalizedBeaconUuid = beaconUuid!.toLowerCase().replaceAll('-', '');
    final normalizedDetectedUuid = uuid.toLowerCase().replaceAll('-', '');

    if (normalizedBeaconUuid != normalizedDetectedUuid) return false;

    // If major is specified, it must match
    if (major != null && major != detectedMajor) return false;

    // If minor is specified, it must match
    if (minor != null && minor != detectedMinor) return false;

    return true;
  }
}
