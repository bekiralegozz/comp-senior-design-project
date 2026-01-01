import 'package:flutter/foundation.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/blockchain_config.dart';
import '../constants/config.dart';

/// Wallet Service - WalletConnect Integration
/// Handles wallet connection, transaction signing, and blockchain interaction
class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  // WalletConnect  
  IWeb3App? _web3App;
  SessionData? _currentSession;
  String? _latestWcUri; // Latest WalletConnect URI for QR display
  
  // Web3 Client
  late Web3Client _web3Client;
  
  bool _initialized = false;

  /// Initialize wallet service
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize Web3 client (Polygon)
    _web3Client = Web3Client(
      BlockchainConfig.polygonRpcUrl,
      http.Client(),
    );

    // Initialize WalletConnect
    await _initializeWalletConnect();

    _initialized = true;
  }

  /// Initialize WalletConnect
  Future<void> _initializeWalletConnect() async {
    try {
      _web3App = await Web3App.createInstance(
        projectId: AppConfig.walletConnectProjectId,
        metadata: const PairingMetadata(
          name: 'SmartRent',
          description: 'Decentralized Real Estate Rental Platform',
          url: 'https://smartrent.app',
          icons: ['https://smartrent.app/icon.png'],
        ),
      );

      // Setup event listeners
      _setupEventListeners();

      // Restore session if exists
      await _restoreSession();
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing WalletConnect: $e');
      }
    }
  }

  /// Setup WalletConnect event listeners
  void _setupEventListeners() {
    if (_web3App == null) return;

    // Session events
    _web3App!.onSessionConnect.subscribe((args) {
      if (kDebugMode) {
        print('🎉 Session connected: ${args?.session.topic}');
        print('   Accounts: ${args?.session.namespaces['eip155']?.accounts}');
      }
      _currentSession = args?.session;
      _saveSession();
    });

    _web3App!.onSessionDelete.subscribe((args) {
      if (kDebugMode) {
        print('🔌 Session deleted: ${args?.topic}');
      }
      _currentSession = null;
      _clearSession();
    });
    
    if (kDebugMode) {
      print('✅ Event listeners setup complete');
    }
  }

  /// Connect wallet via WalletConnect (Mobile Deep Link)
  Future<WalletSession?> connect() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      if (_web3App == null) {
        throw WalletException('WalletConnect not initialized');
      }

      // Create connection
      final ConnectResponse response = await _web3App!.connect(
        requiredNamespaces: {
          'eip155': RequiredNamespace(
            chains: ['eip155:${BlockchainConfig.chainId}'],
            methods: [
              'eth_sendTransaction',
              'eth_signTransaction',
              'eth_sign',
              'personal_sign',
              'eth_signTypedData',
            ],
            events: ['chainChanged', 'accountsChanged'],
          ),
        },
      );

      // Get WalletConnect URI
      final String wcUri = response.uri.toString();
      _latestWcUri = wcUri; // Store for immediate access
      
      if (kDebugMode) {
        print('🔗 WalletConnect URI: $wcUri');
      }

      // 🎯 Platform-specific connection handling
      if (kIsWeb) {
        // WEB: Return URI for QR code display
        if (kDebugMode) {
          print('📱 Web platform: Show QR code for scanning');
        }
      } else {
        // MOBILE: Launch wallet app via deep link
        if (kDebugMode) {
          print('📱 Mobile platform: Launching wallet app...');
        }
        await _launchWalletApp(wcUri);
      }

      // Wait for session approval from wallet app
      if (kDebugMode) {
        print('⏳ Waiting for wallet approval...');
      }

      final session = await response.session.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw WalletException('Connection timeout - User did not approve in wallet'),
      );

      _currentSession = session;
      await _saveSession();

      if (kDebugMode) {
        print('✅ Wallet connected successfully');
      }

      return WalletSession(
        accounts: session.namespaces['eip155']?.accounts
                .map((account) => account.split(':').last)
                .toList() ??
            [],
        chainId: BlockchainConfig.chainId.toString(),
        wcUri: wcUri,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error connecting wallet: $e');
      }
      throw WalletException('Failed to connect wallet: $e');
    }
  }

  /// Launch wallet app via deep link
  Future<void> _launchWalletApp(String wcUri) async {
    // Try multiple wallet apps in order of preference
    final List<String> walletDeepLinks = [
      // Trust Wallet (most popular)
      'https://link.trustwallet.com/wc?uri=$wcUri',
      // MetaMask
      'https://metamask.app.link/wc?uri=$wcUri',
      // Rainbow Wallet
      'https://rnbwapp.com/wc?uri=$wcUri',
      // Generic WalletConnect deep link (fallback)
      wcUri,
    ];

    bool launched = false;

    for (final deepLink in walletDeepLinks) {
      try {
        final uri = Uri.parse(deepLink);
        
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          launched = true;
          
          if (kDebugMode) {
            print('✅ Launched wallet with: $deepLink');
          }
          break;
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to launch: $deepLink - $e');
        }
        continue;
      }
    }

    if (!launched) {
      throw WalletException(
        'No compatible wallet app found. Please install Trust Wallet or MetaMask.',
      );
    }
  }

  /// Disconnect wallet
  Future<void> disconnect() async {
    if (_currentSession != null && _web3App != null) {
      try {
        await _web3App!.disconnectSession(
          topic: _currentSession!.topic,
          reason: Errors.getSdkError(Errors.USER_DISCONNECTED),
        );
      } catch (e) {
        if (kDebugMode) {
          print('Error disconnecting: $e');
        }
      }
    }

    _currentSession = null;
    await _clearSession();
  }

  /// Force disconnect (Deep clean)
  /// Useful for stuck sessions or connection issues
  Future<void> forceDisconnect() async {
    try {
      if (_web3App != null) {
        // Try to disconnect all sessions
        final sessions = _web3App!.getActiveSessions();
        for (final session in sessions.values) {
          try {
            await _web3App!.disconnectSession(
              topic: session.topic,
              reason: Errors.getSdkError(Errors.USER_DISCONNECTED),
            );
          } catch (e) {
            print('Error disconnecting session ${session.topic}: $e');
          }
        }
      }
    } catch (e) {
      print('Error during force disconnect: $e');
    } finally {
      _currentSession = null;
      await _clearSession();
      // Clear checking of initialization to force re-init if needed
      _initialized = false;
    }
  }

  /// Get latest WalletConnect URI (for QR code display)
  String? getLatestWcUri() {
    return _latestWcUri;
  }

  /// Get wallet address
  String? getAddress() {
    if (_currentSession == null) return null;
    
    final accounts = _currentSession!.namespaces['eip155']?.accounts ?? [];
    if (accounts.isEmpty) return null;

    // Extract address from CAIP-10 format (eip155:chainId:address)
    return accounts.first.split(':').last;
  }

  /// Get wallet balance
  Future<EtherAmount> getBalance() async {
    final address = getAddress();
    if (address == null) {
      throw WalletException('No wallet connected');
    }

    try {
      final balance = await _web3Client.getBalance(
        EthereumAddress.fromHex(address),
      );
      return balance;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting balance: $e');
      }
      throw WalletException('Failed to get balance: $e');
    }
  }

  /// Send transaction via WalletConnect
  Future<String> sendTransaction({
    required String to,
    required EtherAmount value,
    String? data,
    int? gas,
  }) async {
    if (_currentSession == null || _web3App == null) {
      throw WalletException('No wallet connected');
    }

    final address = getAddress();
    if (address == null) {
      throw WalletException('No wallet address found');
    }

    try {
      // Prepare transaction
      final Map<String, dynamic> transaction = {
        'from': address,
        'to': to,
        'value': '0x${value.getInWei.toRadixString(16)}',
        if (data != null) 'data': data,
        if (gas != null) 'gas': '0x${gas.toRadixString(16)}',
      };

      // Request transaction signature from wallet
      final String txHash = await _web3App!.request(
        topic: _currentSession!.topic,
        chainId: 'eip155:${BlockchainConfig.chainId}',
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [transaction],
        ),
      );

      return txHash;
    } catch (e) {
      if (kDebugMode) {
        print('Error sending transaction: $e');
      }
      throw WalletException('Failed to send transaction: $e');
    }
  }

  /// Sign message via WalletConnect
  Future<String> signMessage(String message) async {
    if (_currentSession == null || _web3App == null) {
      throw WalletException('No wallet connected');
    }

    final address = getAddress();
    if (address == null) {
      throw WalletException('No wallet address found');
    }

    try {
      final String signature = await _web3App!.request(
        topic: _currentSession!.topic,
        chainId: 'eip155:${BlockchainConfig.chainId}',
        request: SessionRequestParams(
          method: 'personal_sign',
          params: [message, address],
        ),
      );

      return signature;
    } catch (e) {
      if (kDebugMode) {
        print('Error signing message: $e');
      }
      throw WalletException('Failed to sign message: $e');
    }
  }

  /// Check if wallet is connected
  bool isConnected() {
    return _currentSession != null && getAddress() != null;
  }

  /// Get Web3 client instance
  Web3Client getWeb3Client() {
    return _web3Client;
  }

  /// Save session to local storage
  Future<void> _saveSession() async {
    if (_currentSession == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final address = getAddress();
      if (address != null) {
        await prefs.setString('wallet_address', address);
        await prefs.setString('wallet_chain_id', BlockchainConfig.chainId.toString());
        await prefs.setString('session_topic', _currentSession!.topic);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving session: $e');
      }
    }
  }

  /// Restore session from local storage
  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionTopic = prefs.getString('session_topic');
      
      if (_web3App != null) {
        final sessions = _web3App!.getActiveSessions();
        
        if (kDebugMode) {
          print('🔍 Active sessions count: ${sessions.length}');
          print('🔍 Session topics: ${sessions.keys.toList()}');
        }
        
        if (sessionTopic != null && sessions.containsKey(sessionTopic)) {
          _currentSession = sessions[sessionTopic];
          if (kDebugMode) {
            print('✅ Restored session from storage: $sessionTopic');
          }
        } else if (sessions.isNotEmpty) {
          // If no stored session but there are active sessions, use the first one
          _currentSession = sessions.values.first;
          await _saveSession();
          if (kDebugMode) {
            print('✅ Found active session, using: ${_currentSession!.topic}');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error restoring session: $e');
      }
    }
  }

  /// Clear session from local storage
  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('wallet_address');
      await prefs.remove('wallet_chain_id');
      await prefs.remove('session_topic');
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing session: $e');
      }
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _web3Client.dispose();
  }
}

/// Wallet session model
class WalletSession {
  final List<String> accounts;
  final String chainId;
  final String? wcUri; // WalletConnect URI for QR code

  WalletSession({
    required this.accounts,
    required this.chainId,
    this.wcUri,
  });

  String get address => accounts.first;
}

/// Wallet exception
class WalletException implements Exception {
  final String message;

  WalletException(this.message);

  @override
  String toString() => 'WalletException: $message';
}

