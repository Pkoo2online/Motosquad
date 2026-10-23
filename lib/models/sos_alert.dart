class SosAlert {
  final String id;
  final String riderId;
  final String riderName;
  final String callsign;
  final double latitude;
  final double longitude;
  final String reason; // "Crash detected", "Mechanical breakdown", "Medical distress", "Separated"
  final DateTime timestamp;
  bool isResolved;

  SosAlert({
    required this.id,
    required this.riderId,
    required this.riderName,
    required this.callsign,
    required this.latitude,
    required this.longitude,
    required this.reason,
    DateTime? timestamp,
    this.isResolved = false,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'riderId': riderId,
    'riderName': riderName,
    'callsign': callsign,
    'lat': latitude,
    'lng': longitude,
    'reason': reason,
    'timestamp': timestamp.toIso8601String(),
    'isResolved': isResolved,
  };

  factory SosAlert.fromJson(Map<String, dynamic> json) {
    return SosAlert(
      id: json['id'] ?? '',
      riderId: json['riderId'] ?? '',
      riderName: json['riderName'] ?? 'Rider',
      callsign: json['callsign'] ?? 'Bike',
      latitude: (json['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['lng'] as num?)?.toDouble() ?? 0.0,
      reason: json['reason'] ?? 'SOS Emergency',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      isResolved: json['isResolved'] ?? false,
    );
  }
}
