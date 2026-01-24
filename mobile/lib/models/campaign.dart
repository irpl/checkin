class Campaign {
  final String id;
  final String organizationId;
  final String name;
  final String? description;
  final String campaignType; // 'instant' or 'duration'
  final int requiredDurationMinutes;
  final int requiredPresencePercentage;
  final int proximityDelaySeconds;
  final bool isActive;
  final DateTime createdAt;

  Campaign({
    required this.id,
    required this.organizationId,
    required this.name,
    this.description,
    required this.campaignType,
    this.requiredDurationMinutes = 0,
    this.requiredPresencePercentage = 100,
    this.proximityDelaySeconds = 0,
    this.isActive = true,
    required this.createdAt,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: json['id'],
      organizationId: json['organization_id'],
      name: json['name'],
      description: json['description'],
      campaignType: json['campaign_type'],
      requiredDurationMinutes: json['required_duration_minutes'] ?? 0,
      requiredPresencePercentage: json['required_presence_percentage'] ?? 100,
      proximityDelaySeconds: json['proximity_delay_seconds'] ?? 0,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'name': name,
      'description': description,
      'campaign_type': campaignType,
      'required_duration_minutes': requiredDurationMinutes,
      'required_presence_percentage': requiredPresencePercentage,
      'proximity_delay_seconds': proximityDelaySeconds,
      'is_active': isActive,
    };
  }
}
