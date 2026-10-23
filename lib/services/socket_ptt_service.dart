import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/rider.dart';
import '../models/sos_alert.dart';
import '../models/waypoint.dart';
import '../models/convoy_message.dart';

class SocketPttService {
  IO.Socket? _socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  // Stream controllers for UI subscription
  final _ridersStreamController = StreamController<List<Rider>>.broadcast();
  final _sosStreamController = StreamController<SosAlert>.broadcast();
  final _pttActiveRiderController = StreamController<Rider?>.broadcast();
  final _audioChunkController = StreamController<List<int>>.broadcast();
  final _waypointController = StreamController<Waypoint>.broadcast();
  final _messageController = StreamController<ConvoyMessage>.broadcast();
  final _connectionStatusController = StreamController<bool>.broadcast();

  Stream<List<Rider>> get ridersStream => _ridersStreamController.stream;
  Stream<SosAlert> get sosStream => _sosStreamController.stream;
  Stream<Rider?> get pttActiveRiderStream => _pttActiveRiderController.stream;
  Stream<List<int>> get audioChunkStream => _audioChunkController.stream;
  Stream<Waypoint> get waypointStream => _waypointController.stream;
  Stream<ConvoyMessage> get messageStream => _messageController.stream;
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  void connect({required String serverUrl, required String convoyCode, required Rider currentRider}) {
    if (_socket != null && _socket!.connected) return;

    if (serverUrl.isEmpty) {
      _isConnected = false;
      _connectionStatusController.add(false);
      return;
    }

    try {
      _socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(1500)
            .setReconnectionDelayMax(6000)
            .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        _connectionStatusController.add(true);
        
        // Join convoy room
        _socket!.emit('join-convoy', {
          'convoyCode': convoyCode,
          'rider': currentRider.toJson(),
        });
      });

      _socket!.onConnectError((_) {
        _isConnected = false;
        _connectionStatusController.add(false);
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        _connectionStatusController.add(false);
      });

      // Listen for full convoy riders list or incremental updates
      _socket!.on('convoy-riders-update', (data) {
        if (data is List) {
          final riders = data.map((json) => Rider.fromJson(json as Map<String, dynamic>)).toList();
          _ridersStreamController.add(riders);
        }
      });

      // Listen for PTT talk transmission status
      _socket!.on('ptt-status', (data) {
        if (data != null && data['transmittingRider'] != null) {
          _pttActiveRiderController.add(Rider.fromJson(data['transmittingRider']));
        } else {
          _pttActiveRiderController.add(null);
        }
      });

      // Listen for raw audio packets
      _socket!.on('ptt-audio', (data) {
        if (data != null && data['chunk'] != null) {
          // Audio stream data received
        }
      });

      // Emergency SOS received from a rider
      _socket!.on('sos-broadcast', (data) {
        if (data != null) {
          final alert = SosAlert.fromJson(data as Map<String, dynamic>);
          _sosStreamController.add(alert);
        }
      });

      // New waypoint placed by Leader or Scout
      _socket!.on('waypoint-broadcast', (data) {
        if (data != null) {
          final wp = Waypoint.fromJson(data as Map<String, dynamic>);
          _waypointController.add(wp);
        }
      });

      // Convoy chat or quick instruction broadcast
      _socket!.on('convoy-message-broadcast', (data) {
        if (data != null) {
          final msg = ConvoyMessage.fromJson(data as Map<String, dynamic>);
          _messageController.add(msg);
        }
      });
    } catch (_) {
      _isConnected = false;
      _connectionStatusController.add(false);
    }
  }

  void sendLocationUpdate({
    required String convoyCode,
    required String riderId,
    required double latitude,
    required double longitude,
    required double speed,
    required double heading,
    required int battery,
  }) {
    if (_socket == null || !_isConnected) return;
    _socket!.emit('location-update', {
      'convoyCode': convoyCode,
      'riderId': riderId,
      'lat': latitude,
      'lng': longitude,
      'speed': speed,
      'heading': heading,
      'battery': battery,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void startPtt({required String convoyCode, required Rider rider}) {
    if (_socket == null || !_isConnected) return;
    _socket!.emit('ptt-start', {
      'convoyCode': convoyCode,
      'rider': rider.toJson(),
    });
  }

  void stopPtt({required String convoyCode, required String riderId}) {
    if (_socket == null || !_isConnected) return;
    _socket!.emit('ptt-stop', {
      'convoyCode': convoyCode,
      'riderId': riderId,
    });
  }

  void triggerSos({required String convoyCode, required SosAlert alert}) {
    if (_socket == null || !_isConnected) return;
    _socket!.emit('sos-trigger', {
      'convoyCode': convoyCode,
      'alert': alert.toJson(),
    });
  }

  void addWaypoint({required String convoyCode, required Waypoint waypoint}) {
    if (_socket == null || !_isConnected) return;
    _socket!.emit('add-waypoint', {
      'convoyCode': convoyCode,
      'waypoint': waypoint.toJson(),
    });
  }

  void sendMessage({required String convoyCode, required ConvoyMessage message}) {
    if (_socket == null || !_isConnected) return;
    _socket!.emit('send-convoy-message', {
      'convoyCode': convoyCode,
      'message': message.toJson(),
    });
  }

  void disconnect() {
    try {
      _socket?.disconnect();
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _ridersStreamController.close();
    _sosStreamController.close();
    _pttActiveRiderController.close();
    _audioChunkController.close();
    _waypointController.close();
    _messageController.close();
    _connectionStatusController.close();
  }
}
