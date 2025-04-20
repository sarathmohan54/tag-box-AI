import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../lib/services/reel_service.dart';
import '../lib/models/reel.dart';
import '../lib/utils/constants.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'reel_service_test.mocks.dart';
import 'package:flutter/services.dart';

@GenerateMocks([http.Client, SharedPreferences])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ReelService reelService;
  late MockSharedPreferences mockPrefs;
  late MockClient mockClient;
  const MethodChannel channel = MethodChannel('dev.fluttercommunity.plus/connectivity');

  setUp(() {
    mockPrefs = MockSharedPreferences();
    mockClient = MockClient();
    reelService = ReelService(
      token: 'test_token',
      prefs: mockPrefs,
      client: mockClient,
    );

    // Set up default stubs
    when(mockPrefs.getString('offline_reels')).thenReturn(null);
    when(mockPrefs.getString('pending_uploads')).thenReturn('[]');
    when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

    // Set up connectivity mock
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'check') {
          return 'wifi';
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  });

  group('ReelService Tests', () {
    test('getReels returns list of reels when online', () async {
      // Arrange
      when(mockClient.get(
        any,
        headers: {'Authorization': 'Bearer test_token'},
      )).thenAnswer((_) async => http.Response('''[
        {
          "id": 1,
          "platform": "instagram",
          "reel_id": "test123",
          "url": "https://instagram.com/p/test123",
          "thumbnail_url": "https://example.com/thumb.jpg",
          "caption": "Test reel",
          "author": "@testuser",
          "created_at": "2024-03-14T12:00:00Z",
          "metadata": {"likes": 100},
          "is_synced": true,
          "tags": []
        }
      ]''', 200));

      // Act
      final reels = await reelService.getReels();

      // Assert
      verify(mockClient.get(
        Uri.parse('${ApiConstants.baseUrl}/api/reels').replace(queryParameters: {
          'skip': '0',
          'limit': '20',
        }),
        headers: {'Authorization': 'Bearer test_token'},
      )).called(1);
      expect(reels.length, 1);
      expect(reels[0].id, 1);
      expect(reels[0].platform, 'instagram');
    });

    test('getReels returns offline reels when offline', () async {
      // Arrange
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          if (methodCall.method == 'check') {
            return 'none';
          }
          return null;
        },
      );
      
      when(mockPrefs.getString('offline_reels')).thenReturn('''[
        {
          "id": 2,
          "platform": "tiktok",
          "reel_id": "offline123",
          "url": "https://tiktok.com/v/offline123",
          "thumbnail_url": "https://example.com/thumb2.jpg",
          "caption": "Offline reel",
          "author": "@offlineuser",
          "created_at": "2024-03-14T12:00:00Z",
          "metadata": {"likes": 200},
          "is_synced": false,
          "tags": []
        }
      ]''');

      // Act
      final reels = await reelService.getReels();

      // Assert
      expect(reels.length, 1);
      expect(reels[0].id, 2);
      expect(reels[0].platform, 'tiktok');
      expect(reels[0].isSynced, false);
    });

    test('saveReel saves pending upload when offline', () async {
      // Arrange
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          if (methodCall.method == 'check') {
            return 'none';
          }
          return null;
        },
      );

      // Act
      final result = await reelService.saveReel(
        platform: 'instagram',
        reelId: 'test123',
        url: 'https://instagram.com/p/test123',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        caption: 'Test reel',
        author: '@testuser',
        tags: ['test'],
      );

      // Assert
      expect(result, null);
      verify(mockPrefs.setString('pending_uploads', any)).called(1);
    });

    test('extractReelInfo extracts Instagram reel info', () async {
      // Act
      final info = await reelService.extractReelInfo(
        'https://instagram.com/p/test123'
      );

      // Assert
      expect(info!['platform'], 'instagram');
      expect(info['reel_id'], 'test123');
    });

    test('extractReelInfo extracts TikTok reel info', () async {
      // Act
      final info = await reelService.extractReelInfo(
        'https://tiktok.com/@user/video/test123'
      );

      // Assert
      expect(info!['platform'], 'tiktok');
      expect(info['reel_id'], 'test123');
    });
  });
} 