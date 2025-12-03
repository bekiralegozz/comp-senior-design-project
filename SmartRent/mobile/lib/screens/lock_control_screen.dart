import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

/// Full-featured lock control screen for managing smart locks
/// Allows unlocking/locking, viewing device status, and activity logs
class LockControlScreen extends ConsumerStatefulWidget {
  final int deviceId;
  final String deviceName;
  final int assetId;
  
  const LockControlScreen({
    Key? key,
    required this.deviceId,
    required this.deviceName,
    required this.assetId,
  }) : super(key: key);

  @override
  ConsumerState<LockControlScreen> createState() => _LockControlScreenState();
}

class _LockControlScreenState extends ConsumerState<LockControlScreen> {
  Map<String, dynamic>? _deviceStatus;
  bool _isLoading = true;
  bool _isControlling = false;
  String _statusMessage = '';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDeviceStatus();
    // Auto-refresh every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadDeviceStatus();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDeviceStatus() async {
    try {
      // TODO: Replace with actual API call
      // final apiService = ref.read(apiServiceProvider);
      // final status = await apiService.getDeviceStatus(widget.deviceId);
      
      // Mock data for now
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      setState(() {
        _deviceStatus = {
          'id': widget.deviceId,
          'device_id': 'ESP32_001',
          'device_name': widget.deviceName,
          'is_online': true,
          'lock_state': 'locked',
          'battery_level': 85,
          'signal_strength': -45,
          'last_seen_at': DateTime.now().subtract(const Duration(seconds: 10)).toIso8601String(),
          'pending_commands': 0,
          'recent_activity': [
            {
              'event_type': 'lock_locked',
              'message': 'Kilit kapatıldı',
              'created_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
              'log_level': 'info',
            },
            {
              'event_type': 'lock_unlocked',
              'message': 'Kilit açıldı',
              'created_at': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
              'log_level': 'info',
            },
          ],
        };
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'Hata: ${e.toString()}';
      });
    }
  }

  Future<void> _controlLock(String action) async {
    setState(() {
      _isControlling = true;
      _statusMessage = action == 'unlock' ? 'Kilit açılıyor...' : 'Kilit kapatılıyor...';
    });

    try {
      // TODO: Replace with actual API call
      // final apiService = ref.read(apiServiceProvider);
      // await apiService.controlLock(widget.deviceId, action);
      
      await Future.delayed(const Duration(seconds: 2)); // Simulate API call
      
      if (!mounted) return;
      
      setState(() {
        _statusMessage = action == 'unlock' ? '✓ Kilit açıldı!' : '✓ Kilit kapatıldı!';
        _isControlling = false;
        if (_deviceStatus != null) {
          _deviceStatus!['lock_state'] = action == 'unlock' ? 'unlocked' : 'locked';
        }
      });
      
      // Refresh status after control
      await Future.delayed(const Duration(seconds: 1));
      _loadDeviceStatus();
      
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isControlling = false;
        _statusMessage = '✗ Hata: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadDeviceStatus,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _deviceStatus == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_statusMessage.isNotEmpty ? _statusMessage : 'Cihaz bilgisi yüklenemedi'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDeviceStatus,
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDeviceStatus,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Device Status Card
                        _buildStatusCard(),
                        
                        const SizedBox(height: 20),
                        
                        // Control Buttons
                        _buildControlButtons(),
                        
                        const SizedBox(height: 20),
                        
                        // Status Message
                        if (_statusMessage.isNotEmpty)
                          _buildStatusMessage(),
                        
                        if (_statusMessage.isNotEmpty)
                          const SizedBox(height: 20),
                        
                        // Device Info
                        _buildDeviceInfo(),
                        
                        const SizedBox(height: 20),
                        
                        // Recent Activity
                        _buildRecentActivity(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatusCard() {
    final isOnline = _deviceStatus!['is_online'] as bool;
    final lockState = _deviceStatus!['lock_state'] as String;
    final batteryLevel = _deviceStatus!['battery_level'] as int?;
    
    final bool isLocked = lockState == 'locked';
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isLocked ? Colors.red.shade400 : Colors.green.shade400,
              isLocked ? Colors.red.shade600 : Colors.green.shade600,
            ],
          ),
        ),
        child: Column(
          children: [
            // Lock Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.3),
              ),
              child: Icon(
                isLocked ? Icons.lock : Icons.lock_open,
                size: 64,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Lock State
            Text(
              isLocked ? 'KİLİTLİ' : 'AÇIK',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Online Status
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline ? Colors.white : Colors.white.withOpacity(0.5),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isOnline ? 'Çevrimiçi' : 'Çevrimdışı',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            
            if (batteryLevel != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    batteryLevel > 20 ? Icons.battery_std : Icons.battery_alert,
                    color: Colors.white.withOpacity(0.9),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$batteryLevel%',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    final lockState = _deviceStatus!['lock_state'] as String;
    final isLocked = lockState == 'locked';
    
    return Row(
      children: [
        // Unlock Button
        Expanded(
          child: SizedBox(
            height: 60,
            child: ElevatedButton(
              onPressed: _isControlling || !isLocked ? null : () => _controlLock('unlock'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isControlling)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    const Icon(Icons.lock_open, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    isLocked ? 'AÇ' : 'AÇIK',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Lock Button
        Expanded(
          child: SizedBox(
            height: 60,
            child: ElevatedButton(
              onPressed: _isControlling || isLocked ? null : () => _controlLock('lock'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isControlling)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    const Icon(Icons.lock, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    isLocked ? 'KİLİTLİ' : 'KİLİTLE',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusMessage() {
    final isError = _statusMessage.contains('✗') || _statusMessage.contains('Hata');
    final isSuccess = _statusMessage.contains('✓');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isError 
            ? Colors.red.withOpacity(0.1)
            : isSuccess
                ? Colors.green.withOpacity(0.1)
                : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError 
              ? Colors.red
              : isSuccess
                  ? Colors.green
                  : Colors.blue,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : isSuccess ? Icons.check_circle_outline : Icons.info_outline,
            color: isError ? Colors.red : isSuccess ? Colors.green : Colors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMessage,
              style: TextStyle(
                color: isError ? Colors.red : isSuccess ? Colors.green : Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cihaz Bilgileri',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Cihaz ID', _deviceStatus!['device_id'] as String),
            _buildInfoRow('Sinyal Gücü', '${_deviceStatus!['signal_strength']} dBm'),
            _buildInfoRow('Son Görülme', _formatTimestamp(_deviceStatus!['last_seen_at'] as String)),
            _buildInfoRow('Bekleyen Komutlar', '${_deviceStatus!['pending_commands']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final activities = _deviceStatus!['recent_activity'] as List<dynamic>;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Son Aktiviteler',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (activities.isEmpty)
              const Text('Henüz aktivite yok')
            else
              ...activities.map((activity) => _buildActivityItem(activity as Map<String, dynamic>)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final eventType = activity['event_type'] as String;
    final message = activity['message'] as String;
    final timestamp = activity['created_at'] as String;
    
    IconData icon;
    Color color;
    
    if (eventType.contains('unlock')) {
      icon = Icons.lock_open;
      color = Colors.green;
    } else if (eventType.contains('lock')) {
      icon = Icons.lock;
      color = Colors.red;
    } else {
      icon = Icons.info;
      color = Colors.blue;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return 'Az önce';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes} dakika önce';
      } else if (difference.inDays < 1) {
        return '${difference.inHours} saat önce';
      } else {
        return '${difference.inDays} gün önce';
      }
    } catch (e) {
      return timestamp;
    }
  }
}


