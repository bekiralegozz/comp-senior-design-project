import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:convert/convert.dart';
import '../constants/config.dart';

/// Wallet Provider - State management for wallet connection
class WalletProvider with ChangeNotifier {
  static const String _walletAddressKey = 'wallet_address';
  static const String _privateKeyKey = 'wallet_private_key';
  
  String? _walletAddress;
  Credentials? _credentials;
  Web3Client? _web3Client;
  EtherAmount? _balance;
  bool _isConnected = false;
  bool _isLoading = false;

  String? get walletAddress => _walletAddress;
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  EtherAmount? get balance => _balance;
  Web3Client? get web3Client => _web3Client;
  Credentials? get credentials => _credentials;

  String get shortAddress {
    if (_walletAddress == null) return '';
    return '${_walletAddress!.substring(0, 6)}...${_walletAddress!.substring(_walletAddress!.length - 4)}';
  }

  /// Initialize provider and restore session
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Initialize Web3 client
      _web3Client = Web3Client(
        AppConfig.polygonRpcUrl,
        http.Client(),
      );

      // Try to restore previous session
      await _restoreSession();
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing wallet provider: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Restore previous wallet session
  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString(_walletAddressKey);
      final privateKey = prefs.getString(_privateKeyKey);

      if (address != null && privateKey != null) {
        _walletAddress = address;
        _credentials = EthPrivateKey.fromHex(privateKey);
        _isConnected = true;
        
        // Load balance
        await _updateBalance();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error restoring session: $e');
      }
    }
  }

  /// Connect with private key
  Future<bool> connectWithPrivateKey(String privateKey) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Validate and create credentials
      final credentials = EthPrivateKey.fromHex(privateKey);
      final address = await credentials.extractAddress();

      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_walletAddressKey, address.hex);
      await prefs.setString(_privateKeyKey, privateKey);

      // Update state
      _walletAddress = address.hex;
      _credentials = credentials;
      _isConnected = true;

      // Load balance
      await _updateBalance();

      _isLoading = false;
      notifyListeners();
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error connecting with private key: $e');
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Connect with demo wallet (for testing)
  Future<bool> connectDemo() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Demo wallet address (your actual wallet)
      const demoAddress = '0x7dCC13517a1f9238FA532629341cBFac5B9d8838';

      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_walletAddressKey, demoAddress);

      // Update state
      _walletAddress = demoAddress;
      _isConnected = true;

      // Load balance
      await _updateBalance();

      _isLoading = false;
      notifyListeners();
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error connecting demo wallet: $e');
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update wallet balance
  Future<void> _updateBalance() async {
    if (_walletAddress == null || _web3Client == null) return;

    try {
      final address = EthereumAddress.fromHex(_walletAddress!);
      _balance = await _web3Client!.getBalance(address);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error updating balance: $e');
      }
    }
  }

  /// Refresh balance
  Future<void> refreshBalance() async {
    await _updateBalance();
  }

  /// Disconnect wallet
  Future<void> disconnect() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Clear preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_walletAddressKey);
      await prefs.remove(_privateKeyKey);

      // Clear state
      _walletAddress = null;
      _credentials = null;
      _balance = null;
      _isConnected = false;
    } catch (e) {
      if (kDebugMode) {
        print('Error disconnecting: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send transaction
  Future<String?> sendTransaction({
    required String to,
    required String value,
    String? data,
  }) async {
    if (_credentials == null || _web3Client == null) {
      throw Exception('Wallet not connected');
    }

    try {
      final transaction = Transaction(
        to: EthereumAddress.fromHex(to),
        value: EtherAmount.fromUnitAndValue(EtherUnit.wei, BigInt.parse(value)),
        data: data != null ? Uint8List.fromList(hex.decode(data.replaceAll('0x', ''))) : null,
      );

      final txHash = await _web3Client!.sendTransaction(
        _credentials!,
        transaction,
        chainId: int.parse(AppConfig.chainId),
      );

      // Update balance after transaction
      await _updateBalance();

      return txHash;
    } catch (e) {
      if (kDebugMode) {
        print('Error sending transaction: $e');
      }
      rethrow;
    }
  }

  /// Sign message
  Future<String?> signMessage(String message) async {
    if (_credentials == null) {
      throw Exception('Wallet not connected');
    }

    try {
      final messageBytes = Uint8List.fromList(hex.decode(message.replaceAll('0x', '')));
      final signature = await _credentials!.signPersonalMessage(messageBytes);
      return '0x${hex.encode(signature)}';
    } catch (e) {
      if (kDebugMode) {
        print('Error signing message: $e');
      }
      rethrow;
    }
  }

  String get balanceFormatted {
    if (_balance == null) return '0.00';
    final eth = _balance!.getValueInUnit(EtherUnit.ether);
    return eth.toStringAsFixed(4);
  }
}
