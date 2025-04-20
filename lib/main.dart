import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_page.dart';
import 'registration_page.dart';
import 'home_page.dart';
import 'services/auth_service.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'dart:developer' as developer;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  developer.log('Application started', name: 'main');
  _startAuthServices();
  runApp(const MyApp());
}

// Initialize authentication services
Future<void> _startAuthServices() async {
  try {
    // Check if user is logged in
    final isLoggedIn = await AuthService.isLoggedIn();
    if (isLoggedIn) {
      // Start token refresh timer
      AuthService.startTokenRefreshTimer();
      developer.log('Started token refresh timer', name: 'main');
    }
  } catch (e) {
    developer.log('Error initializing auth services: $e', name: 'main');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _sharedText = '';
  static const platform = MethodChannel('com.example.tagbox/share');

  @override
  void initState() {
    super.initState();
    developer.log('MyApp initState called', name: 'ShareIntent');
    _initSharing();
    _setupMethodCallHandler();
  }

  Future<void> _initSharing() async {
    try {
      final String? initialText = await platform.invokeMethod('getSharedText');
      if (initialText != null && initialText.trim().isNotEmpty && mounted) {
        setState(() {
          _sharedText = initialText;
        });
        // Clear the text after receiving it
        await platform.invokeMethod('clearSharedText');
      }
    } on PlatformException catch (e) {
      developer.log('Error getting shared text: $e', name: 'ShareIntent');
    }
  }

  void _setupMethodCallHandler() {
    platform.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'onSharedTextReceived':
          if (call.arguments != null && call.arguments.toString().trim().isNotEmpty && mounted) {
            setState(() {
              _sharedText = call.arguments as String;
            });
            developer.log(
              'Received shared text through method channel',
              name: 'ShareIntent',
              error: {'sharedText': _sharedText},
            );
          }
          break;
        default:
          developer.log(
            'Unknown method call received',
            name: 'ShareIntent',
            error: {'method': call.method},
          );
      }
    });
  }

  void _shareText() {
    developer.log('Sharing text', name: 'ShareIntent');
    Share.share('Check out this awesome app!');
  }

  @override
  Widget build(BuildContext context) {
    developer.log(
      'Building MyApp',
      name: 'ShareIntent',
      error: {'currentSharedText': _sharedText},
    );

    return MaterialApp(
      title: 'Tagbox',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: FutureBuilder<bool>(
        future: AuthService.isLoggedIn(),
        builder: (context, snapshot) {
          developer.log(
            'Auth state',
            name: 'ShareIntent',
            error: {
              'isLoggedIn': snapshot.data,
              'connectionState': snapshot.connectionState.toString(),
              'hasError': snapshot.hasError,
              'error': snapshot.error?.toString(),
            },
          );

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.data == true) {
            return FutureBuilder<Map<String, String?>>(
              future: AuthService.getStoredCredentials(),
              builder: (context, credentialsSnapshot) {
                if (credentialsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (credentialsSnapshot.hasData) {
                  final credentials = credentialsSnapshot.data!;
                  developer.log(
                    'Creating HomePage',
                    name: 'ShareIntent',
                    error: {
                      'email': credentials['email'],
                      'hasToken': credentials['token'] != null,
                      'sharedText': _sharedText,
                    },
                  );

                  return HomePage(
                    userEmail: credentials['email']!,
                    token: credentials['token']!,
                    initialSharedText: _sharedText.trim().isNotEmpty ? _sharedText : null,
                  );
                }

                // If we don't have credentials, go to login
                return const LoginPage();
              },
            );
          }

          developer.log('Returning to LoginPage', name: 'ShareIntent');
          return const LoginPage();
        },
      ),
    );
  }
}
