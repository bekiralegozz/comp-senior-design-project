import 'package:flutter/material.dart';
import '../constants/config.dart';

/// Error Dialog Widget
/// Shows error message with icon and details
class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? details;
  final VoidCallback? onRetry;
  final VoidCallback? onClose;

  const ErrorDialog({
    Key? key,
    required this.title,
    required this.message,
    this.details,
    this.onRetry,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error Icon
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Title
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),

            // Message
            Text(
              message,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),

            // Error Details (collapsible)
            if (details != null) ...[
              const SizedBox(height: AppSpacing.md),
              ExpansionTile(
                title: Text(
                  'Error Details',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: SelectableText(
                      details!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            // Action Buttons
            Row(
              children: [
                if (onRetry != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onRetry?.call();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onClose?.call();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show error dialog
Future<void> showErrorDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? details,
  VoidCallback? onRetry,
  VoidCallback? onClose,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => ErrorDialog(
      title: title,
      message: message,
      details: details,
      onRetry: onRetry,
      onClose: onClose,
    ),
  );
}

/// Parse error message for better user experience
String parseErrorMessage(dynamic error) {
  final errorString = error.toString().toLowerCase();

  // User rejected transaction
  if (errorString.contains('user rejected') ||
      errorString.contains('user denied') ||
      errorString.contains('rejected')) {
    return 'Transaction was rejected. Please try again.';
  }

  // Insufficient funds
  if (errorString.contains('insufficient') ||
      errorString.contains('not enough')) {
    return 'Insufficient balance. Please add more ETH to your wallet.';
  }

  // Network errors
  if (errorString.contains('network') ||
      errorString.contains('timeout') ||
      errorString.contains('connection')) {
    return 'Network error. Please check your connection and try again.';
  }

  // Gas errors
  if (errorString.contains('gas')) {
    return 'Gas estimation failed. The transaction might fail or require more gas.';
  }

  // Contract errors
  if (errorString.contains('revert') || errorString.contains('execution')) {
    return 'Transaction failed. The contract rejected this operation.';
  }

  // Wallet connection errors
  if (errorString.contains('wallet') ||
      errorString.contains('not connected')) {
    return 'Wallet not connected. Please connect your wallet first.';
  }

  // Default error message
  return 'An error occurred. Please try again.';
}

