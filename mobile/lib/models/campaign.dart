class CampaignTimeBlock {
  final String id;
  final String campaignId;
  final int dayOfWeek; // 0=Sunday, 1=Monday, ..., 6=Saturday
  final String startTime; // Format: "HH:MM:SS"
  final String endTime;   // Format: "HH:MM:SS"
  final int? presencePercentage; // Override for this time block, null = use campaign default
  final DateTime createdAt;

  CampaignTimeBlock({
    required this.id,
    required this.campaignId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.presencePercentage,
    required this.createdAt,
  });

  factory CampaignTimeBlock.fromJson(Map<String, dynamic> json) {
    return CampaignTimeBlock(
      id: json['id'],
      campaignId: json['campaign_id'],
      dayOfWeek: json['day_of_week'],
      startTime: json['start_time'],
      endTime: json['end_time'],
      presencePercentage: json['presence_percentage'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'presence_percentage': presencePercentage,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get dayName {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return days[dayOfWeek];
  }

  String get timeDisplay {
    // Format: "09:00 - 11:00"
    return '${startTime.substring(0, 5)} - ${endTime.substring(0, 5)}';
  }
}

class Campaign {
  final String id;
  final String organizationId;
  final String name;
  final String? description;
  final String campaignType; // 'instant' or 'duration'
  final int requiredDurationMinutes;
  final int requiredPresencePercentage;
  final int proximityDelaySeconds;
  // Time restrictions (legacy - kept for backward compatibility)
  final bool timeRestrictionEnabled;
  final String? allowedStartTime; // Format: "HH:MM:SS"
  final String? allowedEndTime;   // Format: "HH:MM:SS"
  // New time blocks system
  final List<CampaignTimeBlock> timeBlocks;
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
    this.timeBlocks = const [],
    this.isActive = true,
    required this.createdAt,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    // Parse time blocks if available
    List<CampaignTimeBlock> timeBlocks = [];
    if (json['time_blocks'] != null) {
      final blocksData = json['time_blocks'] as List;
      timeBlocks = blocksData.map((block) => CampaignTimeBlock.fromJson(block)).toList();
    }

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
      timeBlocks: timeBlocks,
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
    // If using new time blocks system
    if (timeBlocks.isNotEmpty) {
      final now = DateTime.now();
      final currentDayOfWeek = now.weekday % 7; // Convert to 0=Sunday format
      final currentTime = _timeOfDay(now.hour, now.minute, now.second);

      // Check if current time matches any time block for today
      for (final block in timeBlocks) {
        if (block.dayOfWeek != currentDayOfWeek) continue;

        final startTime = _parseTimeString(block.startTime);
        final endTime = _parseTimeString(block.endTime);
        if (startTime == null || endTime == null) continue;

        // Time blocks should not span midnight (validated by DB constraint)
        if (currentTime >= startTime && currentTime <= endTime) {
          return true;
        }
      }
      return false; // No matching time block found
    }

    // Fallback to legacy time restriction system
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

  /// Get the current time block (if any)
  CampaignTimeBlock? getCurrentTimeBlock() {
    if (timeBlocks.isEmpty) return null;

    final now = DateTime.now();
    final currentDayOfWeek = now.weekday % 7; // Convert to 0=Sunday format
    final currentTime = _timeOfDay(now.hour, now.minute, now.second);

    for (final block in timeBlocks) {
      if (block.dayOfWeek != currentDayOfWeek) continue;

      final startTime = _parseTimeString(block.startTime);
      final endTime = _parseTimeString(block.endTime);
      if (startTime == null || endTime == null) continue;

      if (currentTime >= startTime && currentTime <= endTime) {
        return block;
      }
    }
    return null;
  }

  /// Get the effective presence percentage for the current time
  /// Returns the time-block-specific percentage if set, otherwise campaign default
  int getEffectivePresencePercentage() {
    final currentBlock = getCurrentTimeBlock();
    if (currentBlock?.presencePercentage != null) {
      return currentBlock!.presencePercentage!;
    }
    return requiredPresencePercentage;
  }

  /// Get a formatted time range string for display (legacy support)
  String? get timeRestrictionDisplay {
    // If using new time blocks, show first block as representative
    if (timeBlocks.isNotEmpty) {
      final firstBlock = timeBlocks.first;
      return '${firstBlock.dayName} ${firstBlock.timeDisplay}${timeBlocks.length > 1 ? ' (+${timeBlocks.length - 1} more)' : ''}';
    }

    // Fallback to legacy
    if (!timeRestrictionEnabled || allowedStartTime == null || allowedEndTime == null) {
      return null;
    }
    // Format: "09:00 - 11:00"
    return '${allowedStartTime!.substring(0, 5)} - ${allowedEndTime!.substring(0, 5)}';
  }

  /// Get all time blocks grouped by day for display
  Map<String, List<CampaignTimeBlock>> get timeBlocksByDay {
    final Map<String, List<CampaignTimeBlock>> grouped = {};
    for (final block in timeBlocks) {
      final day = block.dayName;
      grouped.putIfAbsent(day, () => []).add(block);
    }
    return grouped;
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
