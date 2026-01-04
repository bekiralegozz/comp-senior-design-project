import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

import '../constants/config.dart';
import '../services/models.dart';
import '../services/iot_service.dart';
import '../services/wallet_service.dart';

/// ==========================================================
/// SMART LOCK SCREEN - IoT Smart Lock Control
/// ==========================================================
///
/// Modern and animated smart lock control screen.
/// Connects to ESP32-based smart lock via backend API.
///
/// States:
/// - Rental date arrived: Can unlock normally
/// - Rental date not arrived: Shows warning + admin override option

class SmartLockScreen extends StatefulWidget {
  final Rental rental;
  
  const SmartLockScreen({
    Key? key,
    required this.rental,
  }) : super(key: key);

  @override
  State<SmartLockScreen> createState() => _SmartLockScreenState();
}

class _SmartLockScreenState extends State<SmartLockScreen>
    with TickerProviderStateMixin {
  
  // Lock state
  bool _isLocked = true;
  bool _isProcessing = false;
  bool _showSuccess = false;
  String? _deviceId;
  IoTDeviceInfo? _deviceStatus;
  
  // Services
  final IoTService _iotService = IoTService();
  final WalletService _walletService = WalletService();
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _lockController;
  late AnimationController _successController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _lockRotation;
  late Animation<double> _successScale;
  
  @override
  void initState() {
    super.initState();
    
    // Pulse animation for the lock ring
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Lock rotation animation
    _lockController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _lockRotation = Tween<double>(begin: 0, end: 0.25).animate(
      CurvedAnimation(parent: _lockController, curve: Curves.elasticOut),
    );
    
    // Success animation
    _successController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _successScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _lockController.dispose();
    _successController.dispose();
    super.dispose();
  }
  
  /// Check if rental date has arrived
  bool get isRentalDateArrived {
    if (widget.rental.startDate == null) return false;
    return DateTime.now().isAfter(widget.rental.startDate!) || 
           DateTime.now().isAtSameMomentAs(widget.rental.startDate!);
  }
  
  /// Check if rental has ended
  bool get isRentalEnded {
    if (widget.rental.endDate == null) return false;
    return DateTime.now().isAfter(widget.rental.endDate!);
  }
  
  /// Unlock the smart lock
  Future<void> _unlockDoor({bool adminOverride = false}) async {
    if (_isProcessing) return;
    
    // Get wallet address
    final walletAddress = _walletService.getAddress();
    if (walletAddress == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please connect your wallet first'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    // Get device ID from rental's asset
    // For now, use a placeholder device ID based on rental
    // In production, this should come from blockchain (RentalHub.getDeviceByAsset)
    final deviceId = _deviceId ?? 'ESP32-ROOM-${widget.rental.assetId ?? "101"}';
    
    setState(() {
      _isProcessing = true;
    });
    
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    try {
      // Call backend API to unlock the door
      final result = await _iotService.requestUnlock(deviceId, walletAddress);
      
      if (result.success) {
        // Success!
        setState(() {
          _isLocked = false;
          _isProcessing = false;
          _showSuccess = true;
        });
        
        // Play animations
        _lockController.forward();
        _successController.forward();
        
        // Haptic success
        HapticFeedback.heavyImpact();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        // Auto-lock after 10 seconds (simulate)
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) {
            setState(() {
              _isLocked = true;
              _showSuccess = false;
            });
            _lockController.reverse();
            _successController.reverse();
          }
        });
      } else {
        // Failed
        setState(() {
          _isProcessing = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unlock: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Show admin override confirmation dialog
  Future<void> _showAdminOverrideDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Early Access'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Rental Start Date',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.rental.startDate != null
                        ? '${widget.rental.startDate!.day}/${widget.rental.startDate!.month}/${widget.rental.startDate!.year}'
                        : 'Not set',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your rental period has not started yet. '
              'Do you want to use admin privileges to unlock the door early?',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action will be logged for security purposes.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unlock Anyway'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _unlockDoor(adminOverride: true);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isLocked 
          ? const Color(0xFF1A1A2E) 
          : const Color(0xFF0D3B0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Smart Lock',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Property info header
            _buildPropertyHeader(),
            
            // Main lock area
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Lock visualization
                    _buildLockVisualization(),
                    
                    const SizedBox(height: 40),
                    
                    // Status text
                    _buildStatusText(),
                    
                    const SizedBox(height: 40),
                    
                    // Action button
                    _buildActionButton(),
                  ],
                ),
              ),
            ),
            
            // Bottom info
            _buildBottomInfo(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPropertyHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.home_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.rental.asset?.title ?? 'Property #${widget.rental.id}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Rental ID: ${widget.rental.id.length > 8 ? widget.rental.id.substring(0, 8) : widget.rental.id}...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isRentalDateArrived
                  ? Colors.green.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isRentalDateArrived ? 'Active' : 'Upcoming',
              style: TextStyle(
                color: isRentalDateArrived ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLockVisualization() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse ring
            if (_isLocked && !_isProcessing)
              Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 2,
                    ),
                  ),
                ),
              ),
            
            // Main lock circle
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isLocked
                      ? [
                          const Color(0xFF2D2D44),
                          const Color(0xFF1A1A2E),
                        ]
                      : [
                          const Color(0xFF1E5631),
                          const Color(0xFF0D3B0D),
                        ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isLocked ? Colors.blue : Colors.green)
                        .withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child: _isProcessing
                    ? _buildProcessingIndicator()
                    : _showSuccess
                        ? _buildSuccessIcon()
                        : _buildLockIcon(),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildProcessingIndicator() {
    return SizedBox(
      width: 80,
      height: 80,
      child: CircularProgressIndicator(
        strokeWidth: 4,
        valueColor: AlwaysStoppedAnimation<Color>(
          Colors.white.withOpacity(0.8),
        ),
      ),
    );
  }
  
  Widget _buildLockIcon() {
    return AnimatedBuilder(
      animation: _lockRotation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _lockRotation.value * math.pi * 2,
          child: Icon(
            _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
            color: Colors.white,
            size: 80,
          ),
        );
      },
    );
  }
  
  Widget _buildSuccessIcon() {
    return AnimatedBuilder(
      animation: _successScale,
      builder: (context, child) {
        return Transform.scale(
          scale: _successScale.value,
          child: const Icon(
            Icons.check_circle_rounded,
            color: Colors.white,
            size: 80,
          ),
        );
      },
    );
  }
  
  Widget _buildStatusText() {
    String title;
    String subtitle;
    Color color;
    
    if (_isProcessing) {
      title = 'Unlocking...';
      subtitle = 'Please wait';
      color = Colors.white;
    } else if (_showSuccess) {
      title = 'Unlocked!';
      subtitle = 'Door is open';
      color = Colors.green;
    } else if (_isLocked) {
      title = 'Locked';
      subtitle = 'Tap to unlock';
      color = Colors.white;
    } else {
      title = 'Unlocked';
      subtitle = 'Auto-locks in 10s';
      color = Colors.green;
    }
    
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 16,
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionButton() {
    if (_showSuccess || !_isLocked) {
      return const SizedBox.shrink();
    }
    
    return GestureDetector(
      onTap: _isProcessing
          ? null
          : () {
              if (isRentalEnded) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Your rental period has ended.'),
                    backgroundColor: Colors.red,
                  ),
                );
              } else if (isRentalDateArrived) {
                _unlockDoor();
              } else {
                _showAdminOverrideDialog();
              }
            },
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isRentalDateArrived
                ? [const Color(0xFF4CAF50), const Color(0xFF2E7D32)]
                : [Colors.orange, Colors.deepOrange],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: (isRentalDateArrived ? Colors.green : Colors.orange)
                  .withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isRentalDateArrived
                  ? Icons.lock_open_rounded
                  : Icons.admin_panel_settings_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              isRentalDateArrived ? 'Unlock Door' : 'Early Access',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBottomInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Rental period info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildDateInfo(
                    'Check-in',
                    widget.rental.startDate,
                    Icons.login_rounded,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.white.withOpacity(0.1),
                ),
                Expanded(
                  child: _buildDateInfo(
                    'Check-out',
                    widget.rental.endDate,
                    Icons.logout_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Security notice
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.security_rounded,
                color: Colors.white.withOpacity(0.4),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'Secured by SmartRent IoT',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildDateInfo(String label, DateTime? date, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.6),
          size: 20,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          date != null
              ? '${date.day}/${date.month}/${date.year}'
              : 'Not set',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Custom AnimatedBuilder wrapper for null-safety
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    Key? key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(key: key, listenable: animation);

  @override
  Widget build(BuildContext context) => builder(context, child);
}
