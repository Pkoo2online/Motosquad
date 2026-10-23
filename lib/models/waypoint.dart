enum WaypointType {
  regroup,
  fuel,
  food,
  scenic,
  hazard,
  destination,
}

class Waypoint {
  final String id;
  final String name;
  final WaypointType type;
  final double latitude;
  final double longitude;
  final String? note;
  final DateTime createdAt;

  Waypoint({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'lat': latitude,
    'lng': longitude,
    'note': note,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Waypoint.fromJson(Map<String, dynamic> json) {
    return Waypoint(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Waypoint',
      type: WaypointType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => WaypointType.regroup,
      ),
      latitude: (json['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['lng'] as num?)?.toDouble() ?? 0.0,
      note: json['note'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
