class Campaign {
  final String id;
  final String organizationId;
  final String name;
  final String? description;
  final String campaignType; // 'instant' or 'duration'
  final int requiredDurationMinutes;
  final int requiredPresencePercentage;
  final int proximityDelaySeconds;
  // Time restrictions
  final bool timeRestrictionEnabled;
  final String? allowedStartTime; // Format: "HH:MM:SS"
  final String? allowedEndTime;   // Format: "HH:MM:SS"
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
    this.timeRestrictionEnabled = false,
    this.allowedStartTime,
    this.allowedEndTime,
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
      timeRestrictionEnabled: json['time_restriction_enabled'] ?? false,
      allowedStartTime: json['allowed_start_time'],
      allowedEndTime: json['allowed_end_time'],
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
      'time_restriction_enabled': timeRestrictionEnabled,
      'allowed_start_time': allowedStartTime,
      'allowed_end_time': allowedEndTime,
      'is_active': isActive,
    };
  }

  /// Check if check-in is allowed at the current time
  bool isCheckinAllowedNow() {
    if (!timeRestrictionEnabled) return true;
    if (allowedStartTime == null || allowedEndTime == null) return true;

    final now = DateTime.now();
    final currentTime = _timeOfDay(now.hour, now.minute, now.second);
    final startTime = _parseTimeString(allowedStartTime!);
    final endTime = _parseTimeString(allowedEndTime!);

    if (startTime == null || endTime == null) return true;

    // Handle case where end time is after start time (same day)
    if (endTime >= startTime) {
      return currentTime >= startTime && currentTime <= endTime;
    }
    // Handle case where time range spans midnight (e.g., 22:00 to 02:00)
    else {
      return currentTime >= startTime || currentTime <= endTime;
    }
  }

  /// Get a formatted time range string for display
  String? get timeRestrictionDisplay {
    if (!timeRestrictionEnabled || allowedStartTime == null || allowedEndTime == null) {
      return null;
    }
    // Format: "09:00 - 11:00"
    return '${allowedStartTime!.substring(0, 5)} - ${allowedEndTime!.substring(0, 5)}';
  }

  // Helper to create a comparable time value (seconds since midnight)
  int _timeOfDay(int hours, int minutes, int seconds) {
    return hours * 3600 + minutes * 60 + seconds;
  }

  // Parse time string "HH:MM:SS" or "HH:MM" to seconds since midnight
  int? _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    final seconds = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    if (hours == null || minutes == null) return null;
    return _timeOfDay(hours, minutes, seconds);
  }
}
