import 'package:flutter/material.dart';
import 'social_media_webview.dart';

class VideoPreview extends StatelessWidget {
  final String platform;
  final String url;
  final String? thumbnailUrl;
  final Map<String, dynamic> metadata;
  final VoidCallback? onTap;
  
  const VideoPreview({
    Key? key,
    required this.platform,
    required this.url,
    this.thumbnailUrl,
    this.metadata = const {},
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Extract embed URLs from metadata
    List<String> embedUrls = [];
    if (metadata['embed_urls'] != null && metadata['embed_urls'] is List) {
      embedUrls = List<String>.from(metadata['embed_urls']);
    } else if (metadata['embed_url'] != null) {
      embedUrls = [metadata['embed_url'].toString()];
    }
    
    // Add original URL as fallback
    if (!embedUrls.contains(url)) {
      embedUrls.add(url);
    }

    // Platform-specific settings
    Map<String, dynamic> settings = {
      'user_agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
      'javascript_enabled': true,
      'support_zoom': false,
    };

    // Merge with any settings from metadata
    if (metadata['webview_settings'] != null && metadata['webview_settings'] is Map) {
      settings.addAll(Map<String, dynamic>.from(metadata['webview_settings']));
    }
    
    // Get the video/reel ID
    String? reelId;
    if (metadata['reel_id'] != null) {
      reelId = metadata['reel_id'].toString();
    } else if (metadata['video_id'] != null) {
      reelId = metadata['video_id'].toString();
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: SocialMediaWebView(
          platform: platform,
          url: embedUrls.first,
          fallbackUrls: embedUrls.length > 1 ? embedUrls : null,
          settings: settings,
          reel_id: reelId,
          onTap: onTap,
        ),
      ),
    );
  }
}