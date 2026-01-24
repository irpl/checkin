class Checkin {
  final String id;
  final String clientId;
  final String campaignId;
  final String? beaconId;
  final String status; // 'pending', 'confirmed', 'completed', 'expired'
  final DateTime firstDetectedAt;
  final DateTime? presenceConfirmedAt;
  final Map<String, dynamic>? formResponse;
  final DateTime? checkedInAt;
  final DateTime createdAt;

  Checkin({
    required this.id,
    required this.clientId,
    required this.campaignId,
    this.beaconId,
    required this.status,
    required this.firstDetectedAt,
    this.presenceConfirmedAt,
    this.formResponse,
    this.checkedInAt,
    required this.createdAt,
  });

  factory Checkin.fromJson(Map<String, dynamic> json) {
    return Checkin(
      id: json['id'],
      clientId: json['client_id'],
      campaignId: json['campaign_id'],
      beaconId: json['beacon_id'],
      status: json['status'],
      firstDetectedAt: DateTime.parse(json['first_detected_at']),
      presenceConfirmedAt: json['presence_confirmed_at'] != null
          ? DateTime.parse(json['presence_confirmed_at'])
          : null,
      formResponse: json['form_response'],
      checkedInAt: json['checked_in_at'] != null
          ? DateTime.parse(json['checked_in_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'campaign_id': campaignId,
      'beacon_id': beaconId,
      'status': status,
      'first_detected_at': firstDetectedAt.toIso8601String(),
      'presence_confirmed_at': presenceConfirmedAt?.toIso8601String(),
      'form_response': formResponse,
      'checked_in_at': checkedInAt?.toIso8601String(),
    };
  }

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isCompleted => status == 'completed';
  bool get isExpired => status == 'expired';
}
