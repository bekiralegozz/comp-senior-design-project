import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/providers/wallet_provider.dart';

/// Transaction Dialog
/// Shows transaction status and progress
class TransactionDialog extends StatelessWidget {
  final TransactionStatus status;
  final String? txHash;
  final String? error;
  final VoidCallback? onClose;

  const TransactionDialog({
    super.key,
    required this.status,
    this.txHash,
    this.error,
    this.onClose,
  });

  static Future<void> show(
    BuildContext context, {
    required TransactionStatus status,
    String? txHash,
    String? error,
    VoidCallback? onClose,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: status == TransactionStatus.confirmed || status == TransactionStatus.failed,
      builder: (context) => TransactionDialog(
        status: status,
        txHash: txHash,
        error: error,
        onClose: onClose,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(),
            const SizedBox(height: 16),
            Text(
              _getTitle(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _getMessage(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (txHash != null) ...[
              const SizedBox(height: 16),
              _buildTxHashSection(context),
            ],
            if (error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  error!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 24),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    switch (status) {
      case TransactionStatus.awaitingSignature:
        return const Icon(
          Icons.draw,
          size: 64,
          color: Colors.orange,
        );
      case TransactionStatus.pending:
        return const SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(
            strokeWidth: 4,
          ),
        );
      case TransactionStatus.confirmed:
        return const Icon(
          Icons.check_circle,
          size: 64,
          color: Colors.green,
        );
      case TransactionStatus.failed:
        return const Icon(
          Icons.error,
          size: 64,
          color: Colors.red,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _getTitle() {
    switch (status) {
      case TransactionStatus.awaitingSignature:
        return 'Signature Required';
      case TransactionStatus.pending:
        return 'Processing Transaction';
      case TransactionStatus.confirmed:
        return 'Transaction Confirmed';
      case TransactionStatus.failed:
        return 'Transaction Failed';
      default:
        return 'Transaction';
    }
  }

  String _getMessage() {
    switch (status) {
      case TransactionStatus.awaitingSignature:
        return 'Please approve the transaction in your wallet';
      case TransactionStatus.pending:
        return 'Waiting for blockchain confirmation...';
      case TransactionStatus.confirmed:
        return 'Your transaction has been confirmed';
      case TransactionStatus.failed:
        return 'Your transaction could not be completed';
      default:
        return '';
    }
  }

  Widget _buildTxHashSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transaction Hash',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: txHash!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaction hash copied'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _truncateHash(txHash!),
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    if (status == TransactionStatus.confirmed || status == TransactionStatus.failed) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onClose?.call();
          },
          child: const Text('Close'),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  String _truncateHash(String hash) {
    if (hash.length <= 20) return hash;
    return '${hash.substring(0, 10)}...${hash.substring(hash.length - 10)}';
  }
}

