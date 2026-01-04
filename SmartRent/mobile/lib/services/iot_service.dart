import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/config.dart' as app_config;

/// Service for IoT device management
class IoTService {
  static final IoTService _instance = IoTService._internal();
  factory IoTService() => _instance;
  IoTService._internal();

  /// Get list of available (online & unassigned) devices
  Future<List<IoTDeviceInfo>> getAvailableDevices() async {
    try {
      final response = await http.get(
        Uri.parse('${app_config.AppConfig.baseUrl}/api/v1/iot/devices/available'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final devices = (data['devices'] as List)
            .map((d) => IoTDeviceInfo.fromJson(d))
            .toList();
        return devices;
      }
      return [];
    } catch (e) {
      print('Error fetching available devices: $e');
      return [];
    }
  }

  /// Get all registered devices (admin)
  Future<List<IoTDeviceInfo>> getAllDevices() async {
    try {
      final response = await http.get(
        Uri.parse('${app_config.AppConfig.baseUrl}/api/v1/iot/devices'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final devices = (data['devices'] as List)
            .map((d) => IoTDeviceInfo.fromJson(d))
            .toList();
        return devices;
      }
      return [];
    } catch (e) {
      print('Error fetching devices: $e');
      return [];
    }
  }

  /// Get device status
  Future<IoTDeviceInfo?> getDeviceStatus(String deviceId) async {
    try {
      final response = await http.get(
        Uri.parse('${app_config.AppConfig.baseUrl}/api/v1/iot/devices/$deviceId/status'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return IoTDeviceInfo.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error fetching device status: $e');
      return null;
    }
  }

  /// Request unlock
  Future<UnlockResult> requestUnlock(String deviceId, String walletAddress) async {
    try {
      final response = await http.post(
        Uri.parse('${app_config.AppConfig.baseUrl}/api/v1/iot/unlock'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'device_id': deviceId,
          'wallet_address': walletAddress,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return UnlockResult(
          success: true,
          commandId: data['command_id'],
          message: data['message'] ?? 'Unlock command sent',
        );
      } else {
        return UnlockResult(
          success: false,
          message: data['detail'] ?? 'Unlock failed',
        );
      }
    } catch (e) {
      return UnlockResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  /// Request lock
  Future<UnlockResult> requestLock(String deviceId, String walletAddress) async {
    try {
      final response = await http.post(
        Uri.parse('${app_config.AppConfig.baseUrl}/api/v1/iot/lock'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'device_id': deviceId,
          'wallet_address': walletAddress,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return UnlockResult(
          success: true,
          commandId: data['command_id'],
          message: data['message'] ?? 'Lock command sent',
        );
      } else {
        return UnlockResult(
          success: false,
          message: data['detail'] ?? 'Lock failed',
        );
      }
    } catch (e) {
      return UnlockResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  /// Link device to asset (on-chain registration)
  Future<LinkResult> linkDeviceToAsset(String deviceId, int tokenId, String walletAddress) async {
    try {
      final response = await http.post(
        Uri.parse('${app_config.AppConfig.baseUrl}/api/v1/iot/link'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'device_id': deviceId,
          'token_id': tokenId,
          'wallet_address': walletAddress,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return LinkResult(
          success: true,
          message: data['message'] ?? 'Device linked to asset',
          txHash: data['tx_hash'],
        );
      } else {
        return LinkResult(
          success: false,
          message: data['detail'] ?? 'Failed to link device',
        );
      }
    } catch (e) {
      return LinkResult(
        success: false,
        message: 'Connection error: $e',
      );
    }
  }

  /// Get device linked to a specific asset (by token_id)
  Future<IoTDeviceInfo?> getDeviceByAsset(int assetId) async {
    try {
      final response = await http.get(
        Uri.parse('${app_config.AppConfig.baseUrl}/api/v1/iot/devices/by-asset/$assetId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return IoTDeviceInfo.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error fetching device by asset: $e');
      return null;
    }
  }
}

/// IoT Device model (renamed to avoid conflict with models.dart)
class IoTDeviceInfo {
  final String deviceId;
  final String deviceType;
  final bool online;
  final String? lockState;
  final int? batteryLevel;
  final int? signalStrength;
  final String? ipAddress;
  final String? firmwareVersion;
  final DateTime? lastSeen;
  final DateTime? registeredAt;

  IoTDeviceInfo({
    required this.deviceId,
    required this.deviceType,
    required this.online,
    this.lockState,
    this.batteryLevel,
    this.signalStrength,
    this.ipAddress,
    this.firmwareVersion,
    this.lastSeen,
    this.registeredAt,
  });

  factory IoTDeviceInfo.fromJson(Map<String, dynamic> json) {
    return IoTDeviceInfo(
      deviceId: json['device_id'] ?? '',
      deviceType: json['device_type'] ?? 'smart_lock',
      online: json['online'] ?? false,
      lockState: json['lock_state'],
      batteryLevel: json['battery_level'],
      signalStrength: json['signal_strength'],
      ipAddress: json['ip_address'],
      firmwareVersion: json['firmware_version'],
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'])
          : null,
      registeredAt: json['registered_at'] != null
          ? DateTime.tryParse(json['registered_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'device_type': deviceType,
        'online': online,
        'lock_state': lockState,
        'battery_level': batteryLevel,
        'signal_strength': signalStrength,
        'ip_address': ipAddress,
        'firmware_version': firmwareVersion,
        'last_seen': lastSeen?.toIso8601String(),
        'registered_at': registeredAt?.toIso8601String(),
      };

  @override
  String toString() => 'IoTDeviceInfo($deviceId, online: $online)';
}

/// Result of unlock/lock request
class UnlockResult {
  final bool success;
  final String? commandId;
  final String message;

  UnlockResult({
    required this.success,
    this.commandId,
    required this.message,
  });
}

/// Result of device-asset link request
class LinkResult {
  final bool success;
  final String message;
  final String? txHash;

  LinkResult({
    required this.success,
    required this.message,
    this.txHash,
  });
}

// Helper getter
extension IoTDeviceInfoExtension on IoTDeviceInfo {
  bool get isOnline => online;
}
