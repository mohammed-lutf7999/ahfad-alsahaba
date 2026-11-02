import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart' as loc;
import '../models/challenge_message.dart';
import '../models/challenge_config.dart';
import '../models/multiplayer_player.dart';

/// خدمة الاتصال القريب (Bluetooth + WiFi)
class NearbyService extends ChangeNotifier {
  static NearbyService? _instance;
  static NearbyService get instance {
    _instance ??= NearbyService._();
    return _instance!;
  }
  NearbyService._();

  final Nearby _nearby = Nearby();
  final loc.Location _location = loc.Location();
  
  // معرّف الخدمة الفريد
  static const String serviceId = 'com.ahfad.challenge';
  
  // حالة الاتصال
  ConnectionState _connectionState = ConnectionState.disconnected;
  ConnectionState get connectionState => _connectionState;
  
  // معلومات اللاعب المحلي
  String _localId = '';
  String get localId => _localId;
  
  // اللاعبون المتصلون
  final Map<String, MultiplayerPlayer> _connectedPlayers = {};
  List<MultiplayerPlayer> get connectedPlayers => _connectedPlayers.values.toList();
  
  // التحديات المكتشفة (للعميل)
  final Map<String, DiscoveredChallenge> _discoveredChallenges = {};
  List<DiscoveredChallenge> get discoveredChallenges => _discoveredChallenges.values.toList();
  
  // إعدادات التحدي الحالي
  ChallengeConfig? _currentConfig;
  ChallengeConfig? get currentConfig => _currentConfig;
  
  // Callbacks
  Function(ChallengeMessage)? onMessageReceived;
  Function(String endpointId, String endpointName)? onPlayerConnected;
  Function(String endpointId)? onPlayerDisconnected;
  
  // حفظ أسماء اللاعبين المؤقتة (من ConnectionInfo)
  final Map<String, String> _pendingConnections = {};

  /// تفعيل خدمة الموقع برمجياً
  Future<bool> _enableLocationService() async {
    try {
      debugPrint('� Checking location service...');
      bool serviceEnabled = await _location.serviceEnabled();
      
      if (!serviceEnabled) {
        debugPrint('📍 Requesting location service...');
        serviceEnabled = await _location.requestService();
        debugPrint('📍 Location service enabled: $serviceEnabled');
      }
      
      return serviceEnabled;
    } catch (e) {
      debugPrint('❌ Location service error: $e');
      return false;
    }
  }

  /// طلب تفعيل البلوتوث
  Future<bool> _enableBluetooth() async {
    try {
      debugPrint('📶 Checking Bluetooth...');
      // nearby_connections يطلب تفعيل البلوتوث تلقائياً عند startAdvertising/startDiscovery
      // لكن يمكننا التحقق من الأذونات هنا
      return true;
    } catch (e) {
      debugPrint('❌ Bluetooth error: $e');
      return false;
    }
  }

  /// طلب الأذونات مع تفعيل الخدمات
  Future<bool> requestPermissions() async {
    debugPrint('� Requesting permissions and enabling services...');
    
    try {
      // 1. تفعيل خدمة الموقع أولاً
      final locationEnabled = await _enableLocationService();
      if (!locationEnabled) {
        debugPrint('❌ Location service not enabled');
        return false;
      }

      // تفعيل وفحص البلوتوث
      await _enableBluetooth();
      
      // 2. طلب إذن الموقع
      var locationStatus = await Permission.locationWhenInUse.status;
      debugPrint('� Location permission status: $locationStatus');
      
      if (!locationStatus.isGranted) {
        locationStatus = await Permission.locationWhenInUse.request();
        debugPrint('� Location permission after request: $locationStatus');
        
        if (locationStatus.isPermanentlyDenied) {
          debugPrint('❌ Location permanently denied - opening settings');
          await openAppSettings();
          return false;
        }
      }
      
      // 3. أذونات البلوتوث
      var bluetoothScanStatus = await Permission.bluetoothScan.request();
      debugPrint('📶 BluetoothScan: $bluetoothScanStatus');
      
      var bluetoothConnectStatus = await Permission.bluetoothConnect.request();
      debugPrint('📶 BluetoothConnect: $bluetoothConnectStatus');
      
      var bluetoothAdvertiseStatus = await Permission.bluetoothAdvertise.request();
      debugPrint('📶 BluetoothAdvertise: $bluetoothAdvertiseStatus');
      
      // 4. أذونات أجهزة WiFi القريبة
      var nearbyWifiStatus = await Permission.nearbyWifiDevices.request();
      debugPrint('📡 NearbyWifi: $nearbyWifiStatus');
      
      // التحقق النهائي
      final allGranted = locationStatus.isGranted &&
          bluetoothScanStatus.isGranted &&
          bluetoothConnectStatus.isGranted &&
          bluetoothAdvertiseStatus.isGranted;
      
      debugPrint('✅ All permissions granted: $allGranted');
      
      return allGranted;
    } catch (e) {
      debugPrint('❌ Permission error: $e');
      return false;
    }
  }

  /// بدء الإعلان (Host)
  Future<bool> startAdvertising({
    required String playerName,
    required ChallengeConfig config,
  }) async {
    try {
      _currentConfig = config;
      _connectionState = ConnectionState.advertising;
      notifyListeners();

      final result = await _nearby.startAdvertising(
        playerName,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: serviceId,
      );

      if (result) {
        _localId = config.challengeId;
        _connectionState = ConnectionState.advertising;
      } else {
        _connectionState = ConnectionState.disconnected;
      }
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('Advertising error: $e');
      _connectionState = ConnectionState.disconnected;
      notifyListeners();
      return false;
    }
  }

  /// بدء البحث (Client)
  Future<bool> startDiscovery({required String playerName}) async {
    try {
      _connectionState = ConnectionState.discovering;
      _discoveredChallenges.clear();
      notifyListeners();

      final result = await _nearby.startDiscovery(
        playerName,
        Strategy.P2P_CLUSTER,
        onEndpointFound: (endpointId, endpointName, serviceId) {
          _discoveredChallenges[endpointId] = DiscoveredChallenge(
            endpointId: endpointId,
            hostName: endpointName,
            discoveredAt: DateTime.now(),
          );
          notifyListeners();
        },
        onEndpointLost: (endpointId) {
          _discoveredChallenges.remove(endpointId);
          notifyListeners();
        },
        serviceId: serviceId,
      );

      if (!result) {
        _connectionState = ConnectionState.disconnected;
      }
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('Discovery error: $e');
      _connectionState = ConnectionState.disconnected;
      notifyListeners();
      return false;
    }
  }

  /// طلب الاتصال بتحدي (Client)
  Future<bool> requestConnection({
    required String endpointId,
    required String playerName,
  }) async {
    try {
      _connectionState = ConnectionState.connecting;
      notifyListeners();

      final result = await _nearby.requestConnection(
        playerName,
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );

      return result;
    } catch (e) {
      debugPrint('Connection request error: $e');
      _connectionState = ConnectionState.disconnected;
      notifyListeners();
      return false;
    }
  }

  /// معالجة بدء الاتصال
  void _onConnectionInitiated(String endpointId, ConnectionInfo info) async {
    // حفظ اسم اللاعب مؤقتاً للاستخدام عند نجاح الاتصال
    _pendingConnections[endpointId] = info.endpointName;
    debugPrint('⚡ Connection initiated with: ${info.endpointName} (ID: $endpointId)');
    
    // قبول الاتصال تلقائياً
    await _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayloadReceived,
      onPayloadTransferUpdate: _onPayloadTransferUpdate,
    );
  }

  /// معالجة نتيجة الاتصال
  void _onConnectionResult(String endpointId, Status status) {
    final endpointName = _pendingConnections.remove(endpointId) ?? 'Unknown';
    
    if (status == Status.CONNECTED) {
      debugPrint('✅ Connected to: $endpointName (ID: $endpointId)');
      
      _connectionState = ConnectionState.connected;
      
      // إضافة اللاعب للقائمة ببيانات مبدئية
      _connectedPlayers[endpointId] = MultiplayerPlayer(
        id: endpointId,
        name: endpointName,
        avatarIndex: 0,
        isConnected: true,
      );
      
      // إعلام المستمع بالاتصال الجديد
      onPlayerConnected?.call(endpointId, endpointName);
    } else {
      debugPrint('❌ Connection failed to: $endpointName');
      _connectionState = ConnectionState.disconnected;
    }
    notifyListeners();
  }

  /// معالجة قطع الاتصال
  void _onDisconnected(String endpointId) {
    _connectedPlayers.remove(endpointId);
    onPlayerDisconnected?.call(endpointId);
    
    if (_connectedPlayers.isEmpty) {
      _connectionState = ConnectionState.disconnected;
    }
    notifyListeners();
  }

  /// معالجة استلام البيانات
  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES && payload.bytes != null) {
      try {
        // استخدام utf8 لفك التشفير لدعم اللغة العربية
        final data = utf8.decode(payload.bytes!);
        final message = ChallengeMessage.decode(data);
        onMessageReceived?.call(message);
      } catch (e) {
        debugPrint('Payload decode error from $endpointId: $e');
      }
    }
  }

  /// معالجة تحديث نقل البيانات
  void _onPayloadTransferUpdate(String endpointId, PayloadTransferUpdate update) {
    // يمكن استخدامه لعرض حالة النقل
  }

  /// إرسال رسالة لجميع المتصلين
  Future<void> broadcastMessage(ChallengeMessage message) async {
    if (_connectedPlayers.isEmpty) {
      debugPrint('⚠️ No connected players to broadcast to');
      return;
    }
    
    // استخدام utf8 للتشفير لدعم اللغة العربية
    final bytes = Uint8List.fromList(utf8.encode(message.encode()));
    debugPrint('📡 Broadcasting ${message.type} to ${_connectedPlayers.length} players');
    
    for (final endpointId in _connectedPlayers.keys) {
      try {
        await _nearby.sendBytesPayload(endpointId, bytes);
      } catch (e) {
        debugPrint('❌ Failed to send to $endpointId: $e');
      }
    }
  }

  /// إرسال رسالة لنقطة معينة
  Future<void> sendMessage(String endpointId, ChallengeMessage message) async {
    // استخدام utf8 للتشفير لدعم اللغة العربية
    final bytes = Uint8List.fromList(utf8.encode(message.encode()));
    await _nearby.sendBytesPayload(endpointId, bytes);
  }

  /// إيقاف كل شيء
  Future<void> stopAll() async {
    await _nearby.stopAdvertising();
    await _nearby.stopDiscovery();
    await _nearby.stopAllEndpoints();
    
    _connectionState = ConnectionState.disconnected;
    _connectedPlayers.clear();
    _discoveredChallenges.clear();
    _currentConfig = null;
    notifyListeners();
  }

  /// إضافة لاعب
  void addPlayer(String endpointId, MultiplayerPlayer player) {
    _connectedPlayers[endpointId] = player;
    notifyListeners();
  }

  /// إزالة لاعب
  void removePlayer(String endpointId) {
    _connectedPlayers.remove(endpointId);
    notifyListeners();
  }
}

/// حالة الاتصال
enum ConnectionState {
  disconnected,
  advertising,
  discovering,
  connecting,
  connected,
}

/// تحدي مكتشف
class DiscoveredChallenge {
  final String endpointId;
  final String hostName;
  final DateTime discoveredAt;
  ChallengeConfig? config;

  DiscoveredChallenge({
    required this.endpointId,
    required this.hostName,
    required this.discoveredAt,
    this.config,
  });
}
