import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/rider.dart';
import '../models/waypoint.dart';
import '../providers/convoy_provider.dart';
import '../widgets/ptt_button.dart';
import '../widgets/rider_radar_card.dart';
import '../widgets/separation_banner.dart';
import 'sos_dialog.dart';

class ConvoyMapScreen extends StatefulWidget {
  const ConvoyMapScreen({super.key});

  @override
  State<ConvoyMapScreen> createState() => _ConvoyMapScreenState();
}

class _ConvoyMapScreenState extends State<ConvoyMapScreen> {
  final MapController _mapController = MapController();
  bool _followSelf = true;

  @override
  Widget build(BuildContext context) {
    final convoy = Provider.of<ConvoyProvider>(context);
    final currentRider = convoy.currentRider;

    final LatLng center = (currentRider != null && currentRider.latitude != 0)
        ? LatLng(currentRider.latitude, currentRider.longitude)
        : const LatLng(28.6139, 77.2090); // Default fallback coordinate

    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      body: Stack(
        children: [
          // 1. Live Flutter Map Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15.0,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && _followSelf) {
                  setState(() => _followSelf = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.motosquad.app',
              ),
              // Markers for Squad Riders
              MarkerLayer(
                markers: _buildMarkers(convoy),
              ),
            ],
          ),

          // 2. Top HUD Bar (Status, Convoy Code, Connection indicator)
          SafeArea(
            child: Column(
              children: [
                _buildTopHud(context, convoy),
                if (convoy.separationWarningMessage != null)
                  SeparationBanner(
                    message: convoy.separationWarningMessage!,
                    onTap: () => _openRidersSheet(context),
                  ),
                if (convoy.activeSos != null)
                  _buildSosAlertBanner(context, convoy),
              ],
            ),
          ),

          // 3. Floating Glove-Friendly Action Buttons (Center Recenter, Add Waypoint, SOS)
          Positioned(
            right: 16,
            bottom: 180,
            child: Column(
              children: [
                // SOS Distress Button (Big Red)
                FloatingActionButton(
                  heroTag: 'sos_btn',
                  backgroundColor: Colors.redAccent,
                  onPressed: () => _showSosDialog(context, convoy),
                  child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 12),
                // Add Waypoint (Leader/Scout)
                FloatingActionButton.small(
                  heroTag: 'wp_btn',
                  backgroundColor: const Color(0xFF1E222B),
                  onPressed: () => _showAddWaypointDialog(context, convoy),
                  child: const Icon(Icons.add_location_alt_outlined, color: Colors.amber),
                ),
                const SizedBox(height: 12),
                // Recenter GPS
                FloatingActionButton.small(
                  heroTag: 'gps_btn',
                  backgroundColor: const Color(0xFF1E222B),
                  onPressed: () {
                    setState(() => _followSelf = true);
                    if (currentRider != null && currentRider.latitude != 0) {
                      _mapController.move(LatLng(currentRider.latitude, currentRider.longitude), 16.0);
                    }
                  },
                  child: Icon(
                    Icons.my_location,
                    color: _followSelf ? Colors.greenAccent : Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // 4. Bottom Controls: PTT Intercom & Squad Drawer Handle
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 12, bottom: 24, left: 16, right: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.95),
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Rider summary bar toggle
                  InkWell(
                    onTap: () => _openRidersSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF242832),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.groups_outlined, color: Colors.cyanAccent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Squad (${convoy.squadRiders.length + 1} Riders)',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.keyboard_arrow_up, color: Colors.white70, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Push-To-Talk Intercom Button
                  PttButton(
                    isTransmitting: convoy.isTransmittingSelf,
                    isLockedByOther: convoy.activeSpeaker != null && convoy.activeSpeaker!.id != currentRider?.id,
                    activeSpeakerName: convoy.activeSpeaker?.callsign ?? convoy.activeSpeaker?.name,
                    onStartTalking: () => convoy.startTransmitting(),
                    onStopTalking: () => convoy.stopTransmitting(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHud(BuildContext context, ConvoyProvider convoy) {
    final rider = convoy.currentRider;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222B).withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: convoy.isConnected ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONVOY #${convoy.convoyCode}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    '${rider?.role.displayName} • ${rider?.callsign}',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              // Speedometer
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${rider?.speedKmh.toStringAsFixed(0) ?? 0}',
                    style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                  const Text('KM/H', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 16),
              // Battery
              Row(
                children: [
                  const Icon(Icons.battery_charging_full, color: Colors.greenAccent, size: 16),
                  Text('${rider?.batteryLevel ?? 100}%', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSosAlertBanner(BuildContext context, ConvoyProvider convoy) {
    final sos = convoy.activeSos!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade800,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.red, blurRadius: 10)],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SOS: ${sos.riderName} (${sos.callsign})',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  sos.reason,
                  style: const TextStyle(color: Colors.yellowAccent, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              _mapController.move(LatLng(sos.latitude, sos.longitude), 17.0);
            },
            child: const Text('LOCATE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers(ConvoyProvider convoy) {
    final List<Marker> markers = [];

    // Current rider marker
    if (convoy.currentRider != null && convoy.currentRider!.latitude != 0) {
      markers.add(
        Marker(
          point: LatLng(convoy.currentRider!.latitude, convoy.currentRider!.longitude),
          width: 50,
          height: 50,
          child: _buildRiderIcon(convoy.currentRider!, isSelf: true),
        ),
      );
    }

    // Squad riders markers
    for (final rider in convoy.squadRiders) {
      if (rider.latitude == 0) continue;
      markers.add(
        Marker(
          point: LatLng(rider.latitude, rider.longitude),
          width: 50,
          height: 50,
          child: _buildRiderIcon(rider, isSelf: false),
        ),
      );
    }

    // Waypoints markers
    for (final wp in convoy.waypoints) {
      markers.add(
        Marker(
          point: LatLng(wp.latitude, wp.longitude),
          width: 40,
          height: 40,
          child: Column(
            children: [
              Icon(Icons.location_on, color: _getWaypointColor(wp.type), size: 28),
              Text(
                wp.name,
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, backgroundColor: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildRiderIcon(Rider rider, {required bool isSelf}) {
    Color markerColor = Colors.cyanAccent;
    IconData iconData = Icons.two_wheeler;

    if (rider.isSosActive) {
      markerColor = Colors.redAccent;
      iconData = Icons.emergency;
    } else if (rider.role == RiderRole.leader) {
      markerColor = Colors.amber;
      iconData = Icons.star;
    } else if (rider.role == RiderRole.sweeper) {
      markerColor = Colors.blueAccent;
      iconData = Icons.shield;
    }

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: markerColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: markerColor.withOpacity(0.6),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(iconData, size: 18, color: Colors.black87),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            rider.callsign,
            style: TextStyle(
              color: isSelf ? Colors.greenAccent : Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Color _getWaypointColor(WaypointType type) {
    switch (type) {
      case WaypointType.fuel:
        return Colors.orangeAccent;
      case WaypointType.food:
        return Colors.greenAccent;
      case WaypointType.regroup:
        return Colors.cyanAccent;
      case WaypointType.hazard:
        return Colors.redAccent;
      case WaypointType.scenic:
      case WaypointType.destination:
        return Colors.purpleAccent;
    }
  }

  void _showSosDialog(BuildContext context, ConvoyProvider convoy) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SosDialog(
        onConfirmSos: (reason) {
          convoy.triggerEmergency(reason);
        },
      ),
    );
  }

  void _showAddWaypointDialog(BuildContext context, ConvoyProvider convoy) {
    final textCtrl = TextEditingController();
    WaypointType selectedType = WaypointType.regroup;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E222B),
          title: const Text('Drop Waypoint for Squad', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: textCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Waypoint Name (e.g. Shell Petrol Pump)',
                  labelStyle: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButton<WaypointType>(
                value: selectedType,
                dropdownColor: const Color(0xFF2A2E38),
                isExpanded: true,
                items: WaypointType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type.name.toUpperCase(), style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
                onChanged: (newType) {
                  if (newType != null) {
                    setDialogState(() => selectedType = newType);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () {
                if (textCtrl.text.isNotEmpty) {
                  convoy.addWaypoint(textCtrl.text, selectedType);
                }
                Navigator.pop(ctx);
              },
              child: const Text('DROP PIN'),
            ),
          ],
        ),
      ),
    );
  }

  void _openRidersSheet(BuildContext context) {
    final convoy = Provider.of<ConvoyProvider>(context, listen: false);
    final selfPos = convoy.currentRider != null && convoy.currentRider!.latitude != 0
        ? LatLng(convoy.currentRider!.latitude, convoy.currentRider!.longitude)
        : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'CONVOY MEMBERS',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Threshold: ${convoy.separationThresholdMeters.toInt()}m',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    if (convoy.currentRider != null)
                      RiderRadarCard(
                        rider: convoy.currentRider!,
                        selfLocation: selfPos,
                      ),
                    ...convoy.squadRiders.map((rider) => RiderRadarCard(
                          rider: rider,
                          selfLocation: selfPos,
                          onFocusOnMap: () {
                            Navigator.pop(ctx);
                            if (rider.latitude != 0) {
                              _mapController.move(LatLng(rider.latitude, rider.longitude), 16.0);
                            }
                          },
                        )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
