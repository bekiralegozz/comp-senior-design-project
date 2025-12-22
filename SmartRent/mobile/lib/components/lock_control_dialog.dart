import 'package:flutter/material.dart';
import 'dart:async';

/// Dialog to control smart lock after rental
/// Shows up after rental is completed, prompts user to unlock the device
class LockControlDialog extends StatefulWidget {
  final int deviceId;
  final String deviceName;
  final Function(String action) onLockControl;
  
  const LockControlDialog({
    Key? key,
    required this.deviceId,
    required this.deviceName,
    required this.onLockControl,
  }) : super(key: key);

  @override
  State<LockControlDialog> createState() => _LockControlDialogState();
}

class _LockControlDialogState extends State<LockControlDialog> with SingleTickerProviderStateMixin {
  bool _isUnlocking = false;
  bool _isSuccess = false;
  String _statusMessage = '';
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleUnlock() async {
    setState(() {
      _isUnlocking = true;
      _statusMessage = 'Kilit açılıyor...';
    });

    try {
      await widget.onLockControl('unlock');
      
      if (!mounted) return;
      
      setState(() {
        _isSuccess = true;
        _statusMessage = '✓ Kilit başarıyla açıldı!';
      });

      // Auto close after 2 seconds
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.of(context).pop(true);
      
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isUnlocking = false;
        _statusMessage = '✗ Hata: ${e.toString()}';
      });
      
      // Show error, then reset
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      
      setState(() {
        _statusMessage = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surface.withOpacity(0.8),
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lock Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isSuccess 
                      ? Colors.green.withOpacity(0.1) 
                      : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                ),
                child: Icon(
                  _isSuccess ? Icons.lock_open : Icons.lock,
                  size: 48,
                  color: _isSuccess 
                      ? Colors.green 
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Title
              Text(
                'Kilit Kontrolü',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Device Name
              Text(
                widget.deviceName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Status Message
              if (_statusMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isSuccess 
                        ? Colors.green.withOpacity(0.1)
                        : _statusMessage.contains('Hata')
                            ? Colors.red.withOpacity(0.1)
                            : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isUnlocking && !_isSuccess)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      if (_isUnlocking && !_isSuccess) const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            color: _isSuccess 
                                ? Colors.green 
                                : _statusMessage.contains('Hata')
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              
              if (_statusMessage.isNotEmpty) const SizedBox(height: 24),
              
              // Action Buttons
              if (!_isUnlocking && !_isSuccess)
                Column(
                  children: [
                    // Unlock Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _handleUnlock,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_open, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Kilidi Aç',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Cancel Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Daha Sonra',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper function to show lock control dialog
Future<bool?> showLockControlDialog({
  required BuildContext context,
  required int deviceId,
  required String deviceName,
  required Function(String action) onLockControl,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return LockControlDialog(
        deviceId: deviceId,
        deviceName: deviceName,
        onLockControl: onLockControl,
      );
    },
  );
}

