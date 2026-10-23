import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/rider.dart';
import '../services/location_service.dart';

class RiderRadarCard extends StatelessWidget {
  final Rider rider;
  final LatLng? selfLocation;
  final VoidCallback? onFocusOnMap;

  const RiderRadarCard({
    super.key,
    required this.rider,
    this.selfLocation,
    this.onFocusOnMap,
  });

  @override
  Widget build(BuildContext context) {
    double distanceKm = 0.0;
    if (selfLocation != null && rider.latitude != 0.0) {
      final meters = LocationService.calculateDistanceMeters(
        selfLocation!,
        LatLng(rider.latitude, rider.longitude),
      );
      distanceKm = meters / 1000.0;
    }

    Color roleColor;
    switch (rider.role) {
      case RiderRole.leader:
        roleColor = Colors.amber;
        break;
      case RiderRole.sweeper:
        roleColor = Colors.lightBlueAccent;
        break;
      case RiderRole.scout:
        roleColor = Colors.purpleAccent;
        break;
      case RiderRole.pack:
        roleColor = Colors.white70;
        break;
    }

    final bool isOffline = rider.isLaggingBehind;

    return InkWell(
      onTap: onFocusOnMap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: rider.isSosActive
              ? Colors.red.shade900.withOpacity(0.4)
              : const Color(0xFF1E222B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: rider.isSosActive
                ? Colors.redAccent
                : (rider.isTransmitting ? Colors.greenAccent : Colors.white10),
            width: rider.isTransmitting || rider.isSosActive ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Avatar with role badge
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF2E3440),
                  child: Text(
                    rider.callsign.isNotEmpty ? rider.callsign.substring(0, 1).toUpperCase() : 'R',
                    style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                if (rider.isTransmitting)
                  const Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 7,
                      backgroundColor: Colors.greenAccent,
                      child: Icon(Icons.mic, size: 9, color: Colors.black),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        rider.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          rider.role.displayName.toUpperCase(),
                          style: TextStyle(
                            color: roleColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${rider.speedKmh.toStringAsFixed(0)} km/h',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.battery_std, size: 14, color: _getBatteryColor(rider.batteryLevel)),
                      Text(
                        '${rider.batteryLevel}%',
                        style: TextStyle(color: _getBatteryColor(rider.batteryLevel), fontSize: 12),
                      ),
                      if (rider.isMeshPeer) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.bluetooth_connected, size: 14, color: Colors.blueAccent),
                        const Text('BLE Mesh', style: TextStyle(color: Colors.blueAccent, fontSize: 11)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Distance indicator
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isOffline ? 'OFFLINE' : '${distanceKm.toStringAsFixed(1)} km',
                  style: TextStyle(
                    color: isOffline ? Colors.orangeAccent : Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  isOffline ? 'Lagging' : 'away',
                  style: TextStyle(
                    color: isOffline ? Colors.orangeAccent : Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getBatteryColor(int level) {
    if (level > 50) return Colors.greenAccent;
    if (level > 20) return Colors.amber;
    return Colors.redAccent;
  }
}
