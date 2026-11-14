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
      debugPrint('📍 Checking location service...');
      bool serviceEnabled = await _location.serviceEnabled();
      
      if (!serviceEnabled) {
        debugPrint('📍 Requesting location service...');
        serviceEnabled = await _location.requestService();
        debugPrint('📍 Location service enabled: $serviceEnabled');
      }
      
      return serviceEnabled;
    } catch (e) {
      debugPrint('⚠️ Location service query notice: $e');
      return true;
    }
  }

  /// فحص تفعيل البلوتوث الحقيقي
  Future<bool> _enableBluetooth() async {
    try {
      debugPrint('📶 Checking Bluetooth status...');
      final status = await Permission.bluetooth.serviceStatus;
      debugPrint('📶 Bluetooth service status: $status');
      return status.isEnabled;
    } catch (e) {
      debugPrint('⚠️ Bluetooth query notice: $e');
      return true;
    }
  }

  /// طلب الأذونات المفصل المتوافق مع جميع أجيال أندرويد (SDK-Aware)
  Future<NearbyPermissionResult> requestPermissionsDetailed() async {
    debugPrint('📱 Requesting Nearby permissions with SDK-aware logic...');
    
    try {
      // 1. فحص خدمة الموقع
      await _enableLocationService();

      // 2. فحص حالة البلوتوث
      await _enableBluetooth();
      
      // 3. أذونات البلوتوث الحديثة (Android 12+)
      final bluetoothScanStatus = await Permission.bluetoothScan.request();
      final bluetoothConnectStatus = await Permission.bluetoothConnect.request();
      final bluetoothAdvertiseStatus = await Permission.bluetoothAdvertise.request();
      
      // 4. أجهزة WiFi القريبة (Android 13+)
      final nearbyWifiStatus = await Permission.nearbyWifiDevices.request();
      debugPrint('📡 NearbyWifi: $nearbyWifiStatus');

      // 5. إذن الموقع (GPS)
      var locationStatus = await Permission.locationWhenInUse.status;
      if (!locationStatus.isGranted) {
        locationStatus = await Permission.locationWhenInUse.request();
      }

      final isPermanentlyDenied = locationStatus.isPermanentlyDenied ||
          bluetoothScanStatus.isPermanentlyDenied ||
          bluetoothConnectStatus.isPermanentlyDenied ||
          bluetoothAdvertiseStatus.isPermanentlyDenied ||
          nearbyWifiStatus.isPermanentlyDenied;

      // التقييم الذكي المتكيف (SDK-Aware Evaluation):
      // أ) الأجهزة الحديثة (Android 12+): يكفي منح حزمة البلوتوث الحديثة
      final modernBluetoothGranted = bluetoothScanStatus.isGranted &&
          bluetoothConnectStatus.isGranted &&
          bluetoothAdvertiseStatus.isGranted;

      // ب) الأجهزة الكلاسيكية (Android <= 11): تعتمد على إذن الموقع
      final legacyLocationGranted = locationStatus.isGranted;

      // ج) دعم أجهزة الواي فاي المجاورة (Android 13+)
      final nearbyWifiGranted = nearbyWifiStatus.isGranted;

      // د) القبول الإجمالي: يتحقق بنجاح البلوتوث الحديث أو إذن الموقع أو أجهزة الواي فاي
      final isSuccess = modernBluetoothGranted || legacyLocationGranted || nearbyWifiGranted;
      
      debugPrint('✅ All permissions evaluated: success=$isSuccess (modern: $modernBluetoothGranted, legacy: $legacyLocationGranted, wifi: $nearbyWifiGranted)');
      
      return NearbyPermissionResult(
        isGranted: isSuccess,
        isPermanentlyDenied: isPermanentlyDenied && !isSuccess,
        failureReason: isSuccess ? null : 'الأذونات غير كافية لتشغيل التقارب المحلي',
      );
    } catch (e) {
      debugPrint('❌ Permission error: $e');
      return NearbyPermissionResult(
        isGranted: false,
        isPermanentlyDenied: false,
        failureReason: e.toString(),
      );
    }
  }

  /// طلب الأذونات مع تفعيل الخدمات (متوافق مع الواجهات الحالية)
  Future<bool> requestPermissions() async {
    final result = await requestPermissionsDetailed();
    return result.isGranted;
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


/// نتيجة فحص أذونات التقارب المحلي
class NearbyPermissionResult {
  final bool isGranted;
  final bool isPermanentlyDenied;
  final String? failureReason;

  const NearbyPermissionResult({
    required this.isGranted,
    this.isPermanentlyDenied = false,
    this.failureReason,
  });
}
