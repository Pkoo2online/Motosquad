import 'package:flutter/foundation.dart';

enum RiderRole {
  leader,   // Front Navigator / Ride Captain
  sweeper,  // Rear Guard / Tail who ensures nobody is left behind
  scout,    // Ahead scout checking road conditions/traffic
  pack,     // Regular convoy member
}

extension RiderRoleExt on RiderRole {
  String get displayName {
    switch (this) {
      case RiderRole.leader:
        return 'Ride Leader';
      case RiderRole.sweeper:
        return 'Tail Sweeper';
      case RiderRole.scout:
        return 'Scout';
      case RiderRole.pack:
        return 'Rider';
    }
  }

  String get code => toString().split('.').last;

  static RiderRole fromCode(String code) {
    return RiderRole.values.firstWhere(
      (r) => r.code.toLowerCase() == code.toLowerCase(),
      orElse: () => RiderRole.pack,
    );
  }
}

class Rider {
  final String id;
  final String name;
  final String callsign; // e.g. "Ghost-1", "Viper"
  final RiderRole role;
  double latitude;
  double longitude;
  double speedKmh;
  double heading;
  int batteryLevel;
  DateTime lastSeen;
  bool isTransmitting;
  bool isSosActive;
  String? sosReason;
  bool isMeshPeer; // True if connected via BLE mesh rather than cellular

  Rider({
    required this.id,
    required this.name,
    required this.callsign,
    required this.role,
    required this.latitude,
    required this.longitude,
    this.speedKmh = 0.0,
    this.heading = 0.0,
    this.batteryLevel = 100,
    DateTime? lastSeen,
    this.isTransmitting = false,
    this.isSosActive = false,
    this.sosReason,
    this.isMeshPeer = false,
  }) : lastSeen = lastSeen ?? DateTime.now();

  bool get isLaggingBehind {
    // Rider hasn't updated in > 45 seconds
    return DateTime.now().difference(lastSeen).inSeconds > 45;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'callsign': callsign,
    'role': role.code,
    'lat': latitude,
    'lng': longitude,
    'speed': speedKmh,
    'heading': heading,
    'battery': batteryLevel,
    'lastSeen': lastSeen.toIso8601String(),
    'isTransmitting': isTransmitting,
    'isSosActive': isSosActive,
    'sosReason': sosReason,
    'isMeshPeer': isMeshPeer,
  };

  factory Rider.fromJson(Map<String, dynamic> json) {
    return Rider(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Rider',
      callsign: json['callsign'] ?? 'Bike',
      role: RiderRoleExt.fromCode(json['role'] ?? 'pack'),
      latitude: (json['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['lng'] as num?)?.toDouble() ?? 0.0,
      speedKmh: (json['speed'] as num?)?.toDouble() ?? 0.0,
      heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
      batteryLevel: (json['battery'] as num?)?.toInt() ?? 100,
      lastSeen: json['lastSeen'] != null ? DateTime.tryParse(json['lastSeen']) ?? DateTime.now() : DateTime.now(),
      isTransmitting: json['isTransmitting'] ?? false,
      isSosActive: json['isSosActive'] ?? false,
      sosReason: json['sosReason'],
      isMeshPeer: json['isMeshPeer'] ?? false,
    );
  }
}
