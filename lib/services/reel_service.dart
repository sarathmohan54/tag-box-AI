import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reel.dart';
import '../models/category.dart';
import '../utils/constants.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

class ReelService {
  final String token;
  final SharedPreferences _prefs;
  final http.Client _client;
  final Dio _dio;
  static const String _offlineReelsKey = 'offline_reels';
  static const String _pendingUploadsKey = 'pending_uploads';
  static const String _categoriesKey = 'categories_cache';
  final String _baseUrl = ApiConstants.baseUrl;

  ReelService({
    required this.token,
    required SharedPreferences prefs,
    http.Client? client,
    Dio? dio,
  }) : _prefs = prefs,
       _client = client ?? http.Client(),
       _dio = dio ?? Dio();

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Fetch categories
  Future<List<Category>> getCategories() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print('No internet connection, returning offline categories');
        return _getOfflineCategories();
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/categories');

      final response = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> categoriesJson = json.decode(response.body);
        final categories = categoriesJson.map((json) => Category.fromJson(json)).toList();
        
        // Add 'All' category at the beginning
        categories.insert(0, Category.all());
        
        // Cache categories for offline use
        _saveCategoriesOffline(categories);
        
        return categories;
      } else {
        final error = json.decode(response.body)['detail'] ?? 'Unknown error';
        print('Failed to get categories: $error');
        throw Exception('Failed to get categories: $error');
      }
    } catch (e) {
      print('Error getting categories: $e');
      
      // Return cached categories if error
      return _getOfflineCategories();
    }
  }

  // Save categories for offline access
  Future<void> _saveCategoriesOffline(List<Category> categories) async {
    final categoriesJson = categories.map((category) => category.toJson()).toList();
    await _prefs.setString(_categoriesKey, json.encode(categoriesJson));
  }

  // Get categories from offline storage
  Future<List<Category>> _getOfflineCategories() async {
    final categoriesJson = _prefs.getString(_categoriesKey);
    if (categoriesJson == null) {
      // Return at least the "All" category if no cached data
      return [Category.all()];
    }

    try {
      final List<dynamic> decodedCategories = json.decode(categoriesJson);
      final categories = decodedCategories.map((json) => Category.fromJson(json)).toList();
      
      // Ensure "All" category is present
      if (categories.isEmpty || categories[0].id != 0) {
        categories.insert(0, Category.all());
      }
      
      return categories;
    } catch (e) {
      print('Error parsing cached categories: $e');
      return [Category.all()];
    }
  }

  // Fetch reels with filtering and search
  Future<List<Reel>> getReels({
    String? search,
    int? categoryId,
    String? categoryIds,
    String? tag,
    String? platform,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print('No internet connection, returning offline reels');
        return _getOfflineReels();
      }

      final queryParams = <String, String>{};
      if (search != null) queryParams['search'] = search;
      if (categoryId != null) queryParams['category_id'] = categoryId.toString();
      if (categoryIds != null) queryParams['category_ids'] = categoryIds;
      if (tag != null) queryParams['tag'] = tag;
      if (platform != null) queryParams['platform'] = platform;
      
      // Format dates properly to ensure they're consistent with backend expectations
      if (startDate != null) {
        // Make sure date is in UTC and formatted correctly
        DateTime utcStart = startDate.toUtc();
        // Set to beginning of day for startDate
        utcStart = DateTime.utc(utcStart.year, utcStart.month, utcStart.day, 0, 0, 0);
        queryParams['start_date'] = utcStart.toIso8601String();
        print('Start date param: ${queryParams['start_date']}');
      }
      
      if (endDate != null) {
        // Make sure date is in UTC and formatted correctly
        DateTime utcEnd = endDate.toUtc();
        // Set to end of day for endDate to include the entire day
        utcEnd = DateTime.utc(utcEnd.year, utcEnd.month, utcEnd.day, 23, 59, 59, 999);
        queryParams['end_date'] = utcEnd.toIso8601String();
        print('End date param: ${queryParams['end_date']}');
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/reels').replace(
        queryParameters: queryParams,
      );

      print('Fetching reels from: $uri');

      final response = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      print('Get reels response status: ${response.statusCode}');
      print('Get reels response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> reelsJson = json.decode(response.body);
        print('Retrieved ${reelsJson.length} reels from server');
        
        // If we were filtering by date, log some details about the results
        if (startDate != null || endDate != null) {
          print('Date filter was applied:');
          if (startDate != null) print('  - Start date: ${startDate.toString()}');
          if (endDate != null) print('  - End date: ${endDate.toString()}');
          print('  - Results count: ${reelsJson.length}');
          
          // Log a few dates from results for debugging, if any exist
          if (reelsJson.isNotEmpty) {
            int samplesToLog = reelsJson.length > 3 ? 3 : reelsJson.length;
            print('Sample created_at dates from results:');
            for (int i = 0; i < samplesToLog; i++) {
              print('  - Reel #${i+1}: ${reelsJson[i]['created_at']}');
            }
          }
        }
        
        final reels = reelsJson.map((json) => Reel.fromJson(json)).toList();
        
        // Save reels for offline access
        _saveReelsOffline(reels);
        
        return reels;
      } else {
        final error = json.decode(response.body)['detail'] ?? 'Unknown error';
        print('Failed to get reels: $error');
        throw Exception('Failed to get reels: $error');
      }
    } catch (e) {
      print('Error getting reels: $e');
      // Return cached reels if error
      return _getOfflineReels();
    }
  }

  // Save reels for offline access
  Future<void> _saveReelsOffline(List<Reel> reels) async {
    final reelsJson = reels.map((reel) => reel.toJson()).toList();
    await _prefs.setString(_offlineReelsKey, json.encode(reelsJson));
  }

  // Get reels from offline storage
  Future<List<Reel>> _getOfflineReels() async {
    final reelsJson = _prefs.getString(_offlineReelsKey);
    if (reelsJson == null) return [];

    final List<dynamic> decodedReels = json.decode(reelsJson);
    return decodedReels.map((json) => Reel.fromJson(json)).toList();
  }

  // Save a reel with offline support
  Future<dynamic> saveReel(Map<String, dynamic> reelData) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/api/reels',
        data: jsonEncode(reelData),
        options: Options(
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        ),
      );
      
      // Handle both 201 (new reel created) and 200 (reel already existed) as success
      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Reel saved successfully with status: ${response.statusCode}');
        return response.data;
      } else {
        print('Unexpected status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      // Check if this is a DioException with a response
      if (e is DioException && e.response != null) {
        final responseData = e.response!.data;
        
        // Handle 409 Conflict (already exists) by returning the existing data
        if (e.response!.statusCode == 409 && responseData is Map<String, dynamic>) {
          print('Reel already exists, returning existing reel info');
          return responseData;
        }
        
        // For other response errors, log and rethrow
        print('Error from API: ${e.response!.data}');
      }
      
      print('Error saving reel: $e');
      rethrow;
    }
  }

  // Save pending upload for offline mode
  Future<void> _savePendingUpload(Map<String, dynamic> reelData) async {
    final pendingUploads = await _getPendingUploads();
    pendingUploads.add(reelData);
    await _prefs.setString(_pendingUploadsKey, json.encode(pendingUploads));
  }

  // Get pending uploads
  Future<List<Map<String, dynamic>>> _getPendingUploads() async {
    final uploadsJson = _prefs.getString(_pendingUploadsKey);
    if (uploadsJson == null) return [];

    final List<dynamic> decoded = json.decode(uploadsJson);
    return decoded.cast<Map<String, dynamic>>();
  }

  // Sync pending uploads when online
  Future<void> syncPendingUploads() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    final pendingUploads = await _getPendingUploads();
    if (pendingUploads.isEmpty) return;

    final List<Map<String, dynamic>> failedUploads = [];

    for (final reelData in pendingUploads) {
      try {
        final response = await _client.post(
          Uri.parse('${ApiConstants.baseUrl}/api/reels'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: json.encode(reelData),
        );

        if (response.statusCode != 200) {
          failedUploads.add(reelData);
        }
      } catch (e) {
        failedUploads.add(reelData);
      }
    }

    await _prefs.setString(_pendingUploadsKey, json.encode(failedUploads));
  }

  // Extract reel information from social media URLs
  Future<Map<String, dynamic>> extractReelInfo(String url) async {
    // Trim URL and ensure it has proper protocol
    url = url.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    try {
      final Uri uri = Uri.parse(url);
      
      // Check if URL is valid
      if (!uri.hasAuthority || uri.host.isEmpty) {
        return {
          'error': 'invalid_url',
          'platform': 'unknown',
          'thumbnail_url': 'https://via.placeholder.com/300x400?text=Invalid+URL',
          'caption': 'Invalid URL provided',
          'author': 'Unknown',
          'metadata': {'error': 'Invalid URL format'},
        };
      }

      if (url.contains('youtube.com') || url.contains('youtu.be')) {
        return await _extractYouTubeInfo(url);
      } else if (url.contains('instagram.com')) {
        print('Processing Instagram URL: $url');
        
        final pathSegments = uri.pathSegments;
        print('Instagram path segments: $pathSegments');
        
        // Check if it's a valid Instagram reel or post URL
        if ((pathSegments.contains('reel') || pathSegments.contains('p'))) {
          // Check if the URL is incomplete (ends with just /reel/ or /p/ without an ID)
          if (pathSegments.length < 2 || 
              (pathSegments.contains('reel') && pathSegments.indexOf('reel') == pathSegments.length - 1) ||
              (pathSegments.contains('p') && pathSegments.indexOf('p') == pathSegments.length - 1)) {
            
            print('Instagram URL is incomplete: $url');
            return {
              'error': 'incomplete_url',
              'platform': 'instagram',
              'thumbnail_url': 'https://placehold.co/600x800/C13584,E1306C,F77737/FFFFFF.png?text=Instagram+Video',
              'caption': 'Please provide a complete Instagram URL',
              'author': 'Instagram',
              'metadata': {'error': 'The URL is incomplete. Please provide the full reel URL with ID.'},
            };
          }
          
          // Process as normal if URL is complete
          String reelId = '';
          bool isPost = false;
          
          if (pathSegments.contains('reel')) {
            reelId = pathSegments[pathSegments.indexOf('reel') + 1];
            isPost = false;
          } else if (pathSegments.contains('p')) {
            reelId = pathSegments[pathSegments.indexOf('p') + 1];
            isPost = true;
          }
          
          if (reelId.isEmpty) {
            print('Could not extract Instagram reel ID from URL: $url');
            return {
              'error': 'missing_id',
              'platform': 'instagram',
              'thumbnail_url': 'https://placehold.co/600x800/C13584,E1306C,F77737/FFFFFF.png?text=Missing+ID',
              'caption': 'Could not extract reel ID from URL',
              'author': 'Instagram',
              'metadata': {'error': 'Could not find a valid reel ID in the URL.'},
            };
          }

          print('Extracted Instagram reel ID: $reelId (isPost: $isPost)');
          
          // Create content-type specific thumbnail
          final contentType = isPost ? 'Post' : 'Video';
          final thumbnailUrl = 'https://placehold.co/600x800/C13584,E1306C,F77737/FFFFFF.png?text=Instagram+$contentType:+$reelId';
          
          // Create enhanced metadata
          final metadata = {
            'source': 'instagram', 
            'reel_id': reelId,
            'source_type': isPost ? 'post' : 'reel',
            'extracted_at': DateTime.now().toIso8601String(),
            'thumbnail_urls': [
              thumbnailUrl,
              // Try several CDN formats that Instagram uses
              'https://scontent.cdninstagram.com/v/t51.29350-15/$reelId.jpg',
              'https://scontent.cdninstagram.com/v/t51.2885-15/$reelId.jpg',
              'https://instagram.fphx1-2.fna.fbcdn.net/v/t51.2885-15/$reelId.jpg',
            ]
          };
          
          return {
            'platform': 'instagram',
            'reel_id': reelId,
            'url': url,
            'thumbnail_url': thumbnailUrl,
            'caption': 'Instagram $contentType',
            'author': 'Instagram User',
            'metadata': metadata,
          };
        } else {
          // Not a reel or post URL
          print('Not a valid Instagram reel/post URL: $url');
          return {
            'error': 'invalid_url',
            'platform': 'instagram',
            'thumbnail_url': 'https://placehold.co/600x800/C13584,E1306C,F77737/FFFFFF.png?text=Invalid+URL',
            'caption': 'Invalid Instagram URL',
            'author': 'Instagram',
            'metadata': {'error': 'This URL does not appear to be a valid Instagram reel or post URL.'},
          };
        }
      }

      // Default for unsupported platforms
      return {
        'platform': 'unknown',
        'reel_id': '',
        'url': url,
        'thumbnail_url': 'https://placehold.co/300x400/808080/FFFFFF.png?text=Unsupported+Platform',
        'caption': 'Video from unsupported platform',
        'author': 'Unknown',
        'metadata': {'error': 'Unsupported platform'},
      };
    } catch (e) {
      print('Error extracting reel info: $e');
      return {
        'error': 'processing_error',
        'platform': 'unknown',
        'thumbnail_url': 'https://placehold.co/300x400/808080/FFFFFF.png?text=Error',
        'caption': 'Error processing URL',
        'author': 'Unknown',
        'metadata': {'error': e.toString()},
      };
    }
  }

  // Get a better Instagram thumbnail URL
  String _getEnhancedInstagramThumbnail(Map<String, dynamic> reelInfo) {
    // If we already have a good thumbnail URL, use it
    if (reelInfo['thumbnail_url'] != null && 
        !reelInfo['thumbnail_url'].toString().contains('placeholder') &&
        !reelInfo['thumbnail_url'].toString().contains('placehold.co')) {
      return reelInfo['thumbnail_url'];
    }
    
    final reelId = reelInfo['reel_id'];
    final isPost = reelInfo['metadata']?['source_type'] == 'post' || 
                  (reelInfo['url'] != null && reelInfo['url'].toString().contains('/p/'));
    
    // Try to construct Instagram thumbnail URL formats
    final possibleThumbnails = [
      'https://scontent.cdninstagram.com/v/t51.29350-15/${reelId}_n.jpg',
      'https://scontent.cdninstagram.com/v/t51.2885-15/${reelId}_n.jpg',
      'https://instagram.fche1-1.fna.fbcdn.net/v/${reelId}_n.jpg',
    ];
    
    // Add thumbnails to metadata for later use
    if (reelInfo['metadata'] == null) {
      reelInfo['metadata'] = {};
    }
    
    if (reelInfo['metadata']['thumbnail_urls'] == null) {
      reelInfo['metadata']['thumbnail_urls'] = possibleThumbnails;
    }
    
    final contentType = isPost ? 'Post' : 'Video';
    
    // Use a nice Instagram-themed placeholder with gradient
    return 'https://placehold.co/600x800/C13584,E1306C,F77737/FFFFFF.png?text=Instagram+$contentType${reelId.isNotEmpty ? ":+$reelId" : ""}';
  }
  
  // Enhance Instagram metadata
  Map<String, dynamic> _enhanceInstagramMetadata(Map<String, dynamic> reelInfo) {
    final metadata = reelInfo['metadata'] ?? {};
    
    // Ensure we have basic fields
    if (metadata['reel_id'] == null) {
      metadata['reel_id'] = reelInfo['reel_id'];
    }
    
    if (metadata['title'] == null) {
      metadata['title'] = reelInfo['caption'] ?? 'Instagram Video';
    }
    
    if (metadata['author_name'] == null) {
      metadata['author_name'] = reelInfo['author'] ?? '@instagram_user';
    }
    
    if (metadata['extracted_at'] == null) {
      metadata['extracted_at'] = DateTime.now().toIso8601String();
    }
    
    // Extract tags from caption if available
    if (reelInfo['caption'] != null && (metadata['tags'] == null || (metadata['tags'] as List).isEmpty)) {
      final caption = reelInfo['caption'].toString();
      final hashtagRegex = RegExp(r'#(\w+)');
      final matches = hashtagRegex.allMatches(caption);
      
      if (matches.isNotEmpty) {
        final tags = matches.map((match) => match.group(1)!.toLowerCase()).toList();
        metadata['tags'] = tags;
      }
    }
    
    return metadata;
  }

  // Helper method to decode Unicode escape sequences and HTML entities
  String _decodeString(String input) {
    if (input.isEmpty) {
      return 'Facebook Video';
    }

    // First pass: Decode HTML entities
    var decoded = input
      .replaceAllMapped(RegExp(r'&#x([0-9A-Fa-f]+);'), (match) {
        try {
          final codePoint = int.parse(match.group(1)!, radix: 16);
          return String.fromCharCode(codePoint);
        } catch (e) {
          print('Error decoding hex entity: ${match.group(0)}');
          return '';
        }
      })
      .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
        try {
          final codePoint = int.parse(match.group(1)!);
          return String.fromCharCode(codePoint);
        } catch (e) {
          print('Error decoding decimal entity: ${match.group(0)}');
          return '';
        }
      });

    // Second pass: Common HTML entities
    decoded = decoded
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&nbsp;', ' ');

    // Third pass: Unicode escapes and special characters
    decoded = decoded
      .replaceAll(r'\"', '"')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\r', '')
      .replaceAll(r'\t', ' ')
      .replaceAll(r'\\', '\\');

    // Fourth pass: Clean up
    decoded = decoded
      .replaceAll(RegExp(r'\s+'), ' ')  // Replace multiple spaces with single space
      .replaceAll(RegExp(r'&[^;]+;'), '')  // Remove any remaining HTML entities
      .trim();  // Trim whitespace

    // Return default text if result is empty
    return decoded.trim().isEmpty ? 'Facebook Video' : decoded;
  }

  // Add the missing YouTube extraction method
  Future<Map<String, dynamic>> _extractYouTubeInfo(String url) async {
    try {
      // Extract YouTube video ID
      String? videoId;
      if (url.contains('youtu.be/')) {
        videoId = url.split('youtu.be/')[1].split('?')[0];
      } else if (url.contains('youtube.com/watch')) {
        videoId = url.split('v=')[1].split('&')[0];
      } else if (url.contains('youtube.com/shorts/')) {
        videoId = url.split('shorts/')[1].split('?')[0];
      }

      if (videoId == null || videoId.isEmpty) {
        return {
          'error': 'missing_id',
          'platform': 'youtube',
          'thumbnail_url': 'https://via.placeholder.com/300x400?text=Missing+ID',
          'caption': 'Could not extract video ID from URL',
          'author': 'YouTube',
          'metadata': {'error': 'Could not find a valid video ID in the URL.'},
        };
      }

      print('Extracted YouTube video ID: $videoId');
      
      // Build thumbnail URLs for different resolutions
      final thumbnailUrls = [
        'https://img.youtube.com/vi/$videoId/maxresdefault.jpg',
        'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
        'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
        'https://img.youtube.com/vi/$videoId/sddefault.jpg',
      ];

      return {
        'platform': 'youtube',
        'reel_id': videoId,
        'url': url,
        'thumbnail_url': thumbnailUrls[0],
        'caption': 'YouTube Video',
        'author': 'YouTube Creator',
        'metadata': {
          'source': 'youtube',
          'video_id': videoId,
          'thumbnail_urls': thumbnailUrls,
        },
      };
    } catch (e) {
      print('Error extracting YouTube info: $e');
      return {
        'error': 'processing_error',
        'platform': 'youtube',
        'thumbnail_url': 'https://via.placeholder.com/300x400?text=Error',
        'caption': 'Error processing YouTube URL',
        'author': 'Unknown',
        'metadata': {'error': e.toString()},
      };
    }
  }
} 