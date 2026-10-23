import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../models/rider.dart';
import '../models/sos_alert.dart';
import '../models/waypoint.dart';
import '../services/location_service.dart';
import '../services/socket_ptt_service.dart';
import '../services/offline_storage_service.dart';
import '../services/audio_alert_service.dart';

class ConvoyProvider with ChangeNotifier {
  final LocationService _locationService = LocationService();
  final SocketPttService _socketPttService = SocketPttService();
  final OfflineStorageService _storageService = OfflineStorageService();
  final AudioAlertService _audioAlertService = AudioAlertService();

  Rider? _currentRider;
  String _convoyCode = '';
  String _serverUrl = 'http://10.0.2.2:4040'; // Default Android emulator local, or host IP

  final Map<String, Rider> _squadRiders = {};
  final List<Waypoint> _waypoints = [];
  SosAlert? _activeSos;
  Rider? _activeSpeaker;
  bool _isConnected = false;
  bool _isTransmittingSelf = false;

  // Convoy gap monitoring
  final double _separationThresholdMeters = 500.0;
  String? _separationWarningMessage;

  // Stream subscriptions
  StreamSubscription? _posSub;
  StreamSubscription? _ridersSub;
  StreamSubscription? _sosSub;
  StreamSubscription? _speakerSub;
  StreamSubscription? _connSub;

  // Getters
  Rider? get currentRider => _currentRider;
  String get convoyCode => _convoyCode;
  List<Rider> get squadRiders => _squadRiders.values.toList();
  List<Waypoint> get waypoints => _waypoints;
  SosAlert? get activeSos => _activeSos;
  Rider? get activeSpeaker => _activeSpeaker;
  bool get isConnected => _isConnected;
  bool get isTransmittingSelf => _isTransmittingSelf;
  String? get separationWarningMessage => _separationWarningMessage;
  double get separationThresholdMeters => _separationThresholdMeters;

  void initializeRider({
    required String name,
    required String callsign,
    required RiderRole role,
    required String convoyCode,
    String? serverUrl,
  }) {
    if (serverUrl != null && serverUrl.isNotEmpty) {
      _serverUrl = serverUrl;
    }

    _convoyCode = convoyCode;
    _currentRider = Rider(
      id: const Uuid().v4(),
      name: name,
      callsign: callsign,
      role: role,
      latitude: 28.6139, // Default fallback coordinate so map loads immediately
      longitude: 77.2090,
    );

    _setupSubscriptions();
    _initLocationTracking();
    notifyListeners();
  }

  void _setupSubscriptions() {
    _connSub = _socketPttService.connectionStatusStream.listen((connected) {
      _isConnected = connected;
      notifyListeners();
      if (connected) {
        _syncOfflineQueue();
      }
    });

    _ridersSub = _socketPttService.ridersStream.listen((riders) {
      for (final r in riders) {
        if (r.id != _currentRider?.id) {
          _squadRiders[r.id] = r;
        }
      }
      _checkConvoySeparation();
      notifyListeners();
    });

    _sosSub = _socketPttService.sosStream.listen((alert) {
      _activeSos = alert;
      _audioAlertService.playSosAlarm();
      notifyListeners();
    });

    _speakerSub = _socketPttService.pttActiveRiderStream.listen((speaker) {
      _activeSpeaker = speaker;
      notifyListeners();
    });

    _socketPttService.connect(
      serverUrl: _serverUrl,
      convoyCode: _convoyCode,
      currentRider: _currentRider!,
    );
  }

  Future<void> _initLocationTracking() async {
    try {
      final hasPerm = await _locationService.checkAndRequestPermissions();
      if (hasPerm) {
        final pos = await _locationService.getCurrentPosition();
        if (pos != null && _currentRider != null) {
          _currentRider!.latitude = pos.latitude;
          _currentRider!.longitude = pos.longitude;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Location permission init: $e');
    }
    _startLocationUpdates();
  }

  void _startLocationUpdates() {
    try {
      _locationService.startTracking(onPositionChanged: (Position pos) {
        if (_currentRider == null) return;

        _currentRider!.latitude = pos.latitude;
        _currentRider!.longitude = pos.longitude;
        _currentRider!.speedKmh = (pos.speed * 3.6).clamp(0.0, 300.0);
        _currentRider!.heading = pos.heading;
        _currentRider!.lastSeen = DateTime.now();

        if (_isConnected) {
          _socketPttService.sendLocationUpdate(
            convoyCode: _convoyCode,
            riderId: _currentRider!.id,
            latitude: pos.latitude,
            longitude: pos.longitude,
            speed: _currentRider!.speedKmh,
            heading: pos.heading,
            battery: _currentRider!.batteryLevel,
          );
        } else {
          // Buffer locally for offline resilience
          _storageService.queueUnsentLocation(_currentRider!.toJson());
        }

        _checkConvoySeparation();
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Location stream error: $e');
    }
  }

  void _checkConvoySeparation() {
    if (_currentRider == null || _currentRider!.latitude == 0) return;

    final selfPos = LatLng(_currentRider!.latitude, _currentRider!.longitude);
    String? warning;

    // Check distance to Leader if we are not the leader
    if (_currentRider!.role != RiderRole.leader) {
      final leader = _squadRiders.values.cast<Rider?>().firstWhere(
        (r) => r?.role == RiderRole.leader,
        orElse: () => null,
      );

      if (leader != null && leader.latitude != 0) {
        final distToLeader = LocationService.calculateDistanceMeters(
          selfPos,
          LatLng(leader.latitude, leader.longitude),
        );

        if (distToLeader > _separationThresholdMeters) {
          warning = 'Warning: You are ${(distToLeader / 1000).toStringAsFixed(1)}km behind Lead Rider!';
        }
      }
    }

    // Check if any rider is falling behind (for Leader & Sweeper)
    if (_currentRider!.role == RiderRole.leader || _currentRider!.role == RiderRole.sweeper) {
      for (final rider in _squadRiders.values) {
        if (rider.latitude == 0) continue;
        final dist = LocationService.calculateDistanceMeters(
          selfPos,
          LatLng(rider.latitude, rider.longitude),
        );
        if (dist > _separationThresholdMeters) {
          warning = '${rider.name} (${rider.callsign}) is lagging behind by ${(dist / 1000).toStringAsFixed(1)}km!';
          break;
        }
      }
    }

    if (warning != null && _separationWarningMessage != warning) {
      _audioAlertService.playSeparationAlert();
    }
    _separationWarningMessage = warning;
  }

  Future<void> _syncOfflineQueue() async {
    final queue = await _storageService.flushQueue();
    for (final item in queue) {
      if (item['type'] == 'location') {
        final payload = item['payload'] as Map<String, dynamic>;
        _socketPttService.sendLocationUpdate(
          convoyCode: _convoyCode,
          riderId: payload['id'],
          latitude: payload['lat'],
          longitude: payload['lng'],
          speed: payload['speed'],
          heading: payload['heading'],
          battery: payload['battery'],
        );
      }
    }
  }

  // PTT Actions
  void startTransmitting() {
    if (_currentRider == null || _isTransmittingSelf) return;
    _isTransmittingSelf = true;
    _audioAlertService.playPttStartChirp();
    _socketPttService.startPtt(convoyCode: _convoyCode, rider: _currentRider!);
    notifyListeners();
  }

  void stopTransmitting() {
    if (!_isTransmittingSelf || _currentRider == null) return;
    _isTransmittingSelf = false;
    _audioAlertService.playPttRogerBeep();
    _socketPttService.stopPtt(convoyCode: _convoyCode, riderId: _currentRider!.id);
    notifyListeners();
  }

  // SOS Distress Actions
  void triggerEmergency(String reason) {
    if (_currentRider == null) return;
    final sos = SosAlert(
      id: const Uuid().v4(),
      riderId: _currentRider!.id,
      riderName: _currentRider!.name,
      callsign: _currentRider!.callsign,
      latitude: _currentRider!.latitude,
      longitude: _currentRider!.longitude,
      reason: reason,
    );

    _activeSos = sos;
    _currentRider!.isSosActive = true;
    _currentRider!.sosReason = reason;

    _audioAlertService.playSosAlarm();
    _socketPttService.triggerSos(convoyCode: _convoyCode, alert: sos);
    notifyListeners();
  }

  void resolveEmergency() {
    if (_activeSos != null) {
      _activeSos!.isResolved = true;
      _activeSos = null;
      if (_currentRider != null) {
        _currentRider!.isSosActive = false;
        _currentRider!.sosReason = null;
      }
      notifyListeners();
    }
  }

  void addWaypoint(String name, WaypointType type, {String? note}) {
    if (_currentRider == null || _currentRider!.latitude == 0) return;
    final wp = Waypoint(
      id: const Uuid().v4(),
      name: name,
      type: type,
      latitude: _currentRider!.latitude,
      longitude: _currentRider!.longitude,
      note: note,
    );
    _waypoints.add(wp);
    _socketPttService.addWaypoint(convoyCode: _convoyCode, waypoint: wp);
    notifyListeners();
  }

  @override
  void dispose() {
    _locationService.stopTracking();
    _socketPttService.dispose();
    _audioAlertService.dispose();
    _posSub?.cancel();
    _ridersSub?.cancel();
    _sosSub?.cancel();
    _speakerSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }
}
