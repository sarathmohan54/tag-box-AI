import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';
import 'dart:async';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _emailKey = 'user_email';
  static const _rememberMeKey = 'remember_me';
  static const _biometricEnabledKey = 'biometric_enabled';
  static const _tokenExpiryKey = 'token_expiry';
  static const _refreshWindowDays = 7; // Refresh if token will expire within 7 days
  static Timer? _tokenRefreshTimer;
  
  static final LocalAuthentication _localAuth = LocalAuthentication();

  // Start a timer to periodically check and refresh the token
  static void startTokenRefreshTimer() {
    stopTokenRefreshTimer(); // Cancel any existing timer
    
    // Check token every 6 hours
    _tokenRefreshTimer = Timer.periodic(const Duration(hours: 6), (timer) async {
      final token = await getToken();
      if (token != null) {
        final shouldRefresh = await _shouldRefreshToken();
        if (shouldRefresh) {
          print('Token refresh timer: refreshing token');
          await _refreshToken(token);
        }
      }
    });
  }
  
  static void stopTokenRefreshTimer() {
    _tokenRefreshTimer?.cancel();
    _tokenRefreshTimer = null;
  }
  
  // Check if token should be refreshed
  static Future<bool> _shouldRefreshToken() async {
    final expiryStr = await _storage.read(key: _tokenExpiryKey);
    if (expiryStr != null) {
      final expiry = DateTime.parse(expiryStr);
      final refreshWindow = DateTime.now().add(Duration(days: _refreshWindowDays));
      
      // If token will expire within the refresh window, we should refresh it
      return expiry.isBefore(refreshWindow);
    }
    return false;
  }

  // Check if user is logged in and token is valid
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    final email = await getEmail();
    if (token == null || email == null) {
      return false;
    }

    // Check token expiry
    final expiryStr = await _storage.read(key: _tokenExpiryKey);
    if (expiryStr != null) {
      final expiry = DateTime.parse(expiryStr);
      
      // If token is already expired, try to refresh
      if (expiry.isBefore(DateTime.now())) {
        print('Token expired, attempting refresh');
        final refreshed = await _refreshToken(token);
        return refreshed;
      }
      
      // If token will expire soon, proactively refresh in background
      final refreshWindow = DateTime.now().add(Duration(days: _refreshWindowDays));
      if (expiry.isBefore(refreshWindow)) {
        print('Token expiring soon, refreshing in background');
        // Don't wait for refresh to complete
        _refreshToken(token).then((success) {
          print('Background token refresh ${success ? 'succeeded' : 'failed'}');
        });
      }
    }

    return true;
  }

  // Token refresh logic
  static Future<bool> _refreshToken(String currentToken) async {
    try {
      print('Attempting to refresh token');
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/refresh-token'),
        headers: {
          'Authorization': 'Bearer $currentToken',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        print('Token refresh request timed out');
        // Don't throw error on timeout, just return a dummy response
        // to prevent logout on network issues
        return http.Response('{"error": "timeout"}', 408);
      });

      print('Token refresh response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newToken = data['access_token'];
        await saveToken(newToken);
        
        // Set token expiry to 29 days from now (1 day before actual expiry)
        final expiry = DateTime.now().add(const Duration(days: 29));
        await _storage.write(key: _tokenExpiryKey, value: expiry.toIso8601String());
        
        print('Token refreshed successfully');
        return true;
      } else if (response.statusCode >= 500 || response.statusCode == 408) {
        // Server error or timeout - don't log out the user
        print('Server error during token refresh, keeping existing token');
        return true;
      } else if (response.statusCode == 401) {
        // If refresh failed with 401, the token is invalid
        print('Token is invalid, logging out');
        await logout();
        return false;
      } else {
        // Any other error, try to keep the user logged in
        print('Unknown error during token refresh, keeping existing token');
        return true;
      }
    } catch (e) {
      print('Error refreshing token: $e');
      // Don't logout on network errors
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Connection refused') ||
          e.toString().contains('Network is unreachable')) {
        print('Network error during token refresh, keeping existing token');
        return true;
      }
      
      // For other errors, logout
      await logout();
      return false;
    }
  }

  // Get stored credentials
  static Future<Map<String, String?>> getStoredCredentials() async {
    final token = await getToken();
    final email = await getEmail();
    
    // Validate token if exists
    if (token != null) {
      final isValid = await isLoggedIn();
      if (!isValid) {
        return {
          'token': null,
          'email': email,
        };
      }
    }
    
    return {
      'token': token,
      'email': email,
    };
  }

  // Token management
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    
    // Set token expiry to 29 days from now (1 day before actual expiry)
    final expiry = DateTime.now().add(const Duration(days: 29));
    await _storage.write(key: _tokenExpiryKey, value: expiry.toIso8601String());
    
    // Start the token refresh timer
    startTokenRefreshTimer();
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
    stopTokenRefreshTimer();
  }

  // User email management
  static Future<void> saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  // Remember me functionality
  static Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, value);
  }

  static Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }

  // Biometric authentication
  static Future<void> setBiometricEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, value);
  }

  static Future<bool> getBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  static Future<bool> isBiometricAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access the app',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  // Enhanced logout
  static Future<void> logout() async {
    stopTokenRefreshTimer();
    await Future.wait([
      deleteToken(),
      _storage.delete(key: _tokenExpiryKey),
      getRememberMe().then((rememberMe) async {
        if (!rememberMe) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_emailKey);
        }
      }),
    ]);
  }
} 