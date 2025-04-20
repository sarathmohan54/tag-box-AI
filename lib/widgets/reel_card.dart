import 'package:flutter/material.dart';
import '../models/reel.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'social_media_webview.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:tagbox/common/theme.dart';

class ReelCard extends StatelessWidget {
  final Reel reel;
  final String? reelId;
  final VoidCallback? onDelete;
  final bool showActions;
  final bool isPreview;

  const ReelCard({
    super.key,
    required this.reel,
    this.reelId,
    this.onDelete,
    this.showActions = true,
    this.isPreview = false,
  });

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;
    final platform = _determinePlatform(reel.url);
    final thumbnailUrl = reel.thumbnailUrl;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _launchURL(context, reel.url),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: isLandscape ? 16 / 9 : 4 / 3,
              child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                  ? _buildThumbnailImage(context, thumbnailUrl, platform)
                  : _buildVideoPreview(context, platform),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getPlatformIcon(platform),
                        size: 14,
                        color: _getPlatformColor(platform),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        platform.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      if (reel.createdAt != null) Text(
                        _formatDate(reel.createdAt!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reel.title ?? 'Untitled Reel',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (showActions) const SizedBox(height: 12),
                  if (showActions) _buildActionButtons(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _determinePlatform(String url) {
    final lowerUrl = url.toLowerCase();
    
    if (lowerUrl.contains('facebook.com') || lowerUrl.contains('fb.watch')) {
      return 'facebook';
    } else if (lowerUrl.contains('instagram.com')) {
      return 'instagram';
    } else if (lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be')) {
      return 'youtube';
    } else {
      return 'other';
    }
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.share, size: 20),
          onPressed: () => _shareReel(context),
          visualDensity: VisualDensity.compact,
          tooltip: 'Share',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.open_in_browser, size: 20),
          onPressed: () => _launchURL(context, reel.url),
          visualDensity: VisualDensity.compact,
          tooltip: 'Open in browser',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        if (onDelete != null) ...[
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
            tooltip: 'Delete',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ],
    );
  }

  Future<void> _shareReel(BuildContext context) async {
    await Share.share(
      'Check out this reel: ${reel.title ?? ''}\n${reel.url}',
      subject: reel.title,
    );
  }

  Color _getPlatformColor(String platform) {
    switch (platform.toLowerCase()) {
      case 'facebook':
        return const Color(0xFF3B5998);
      case 'instagram':
        return const Color(0xFFE1306C);
      case 'youtube':
        return const Color(0xFFFF0000);
      default:
        return Colors.grey;
    }
  }
  
  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'facebook':
        return Icons.facebook;
      case 'instagram':
        return Icons.camera_alt;
      case 'youtube':
        return Icons.play_circle_outline;
      default:
        return Icons.play_arrow;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  Widget _buildThumbnailImage(BuildContext context, String url, String platform) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => Container(
              color: _getPlatformColor(platform).withOpacity(0.1),
              child: Center(
                child: Icon(
                  _getPlatformIcon(platform),
                  size: 40,
                  color: _getPlatformColor(platform).withOpacity(0.7),
                ),
              ),
            ),
            memCacheWidth: 400, // Limit memory cache size
            maxWidthDiskCache: 800, // Limit disk cache size
            fadeInDuration: const Duration(milliseconds: 300),
            imageBuilder: (context, imageProvider) => Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.cover,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.transparent,
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
          ),
        ),
        const Center(
          child: _PlayButton(),
        ),
      ],
    );
  }

  Widget _buildVideoPreview(BuildContext context, String platform) {
    // Extract embed URLs from the original URL
    final List<String> embedUrls = _getEmbedUrls(reel.url, platform);
    
    return VideoPreview(
      platform: platform,
      url: embedUrls.isNotEmpty ? embedUrls.first : reel.url,
      fallbackUrls: embedUrls.length > 1 ? embedUrls : null,
      reel_id: reelId,
      onTap: () => _launchURL(context, reel.url),
    );
  }
  
  Future<void> _launchURL(BuildContext context, String url) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        // Fall back to in-app browser if external launch fails
        await launchUrl(Uri.parse(url));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open URL: $e')),
        );
      }
      debugPrint('Error launching URL: $e');
    }
  }
  
  List<String> _getEmbedUrls(String originalUrl, String platform) {
    final List<String> embedUrls = [];
    final Uri? uri = Uri.tryParse(originalUrl);
    
    if (uri == null) return embedUrls;
    
    if (platform == 'youtube') {
      final String? videoId = _extractYouTubeVideoId(originalUrl);
      if (videoId != null) {
        embedUrls.add('https://www.youtube.com/embed/$videoId');
      }
    } else if (platform == 'facebook') {
      // Facebook dynamic embed generation
      if (originalUrl.contains('/videos/')) {
        final RegExp videoRegex = RegExp(r'\/videos\/(\d+)');
        final Match? match = videoRegex.firstMatch(originalUrl);
        if (match != null && match.groupCount >= 1) {
          final String videoId = match.group(1)!;
          embedUrls.add('https://www.facebook.com/plugins/video.php?href=${Uri.encodeComponent(originalUrl)}&show_text=0');
        }
      } else if (originalUrl.contains('/posts/')) {
        embedUrls.add('https://www.facebook.com/plugins/post.php?href=${Uri.encodeComponent(originalUrl)}&show_text=0');
      }
    } else if (platform == 'instagram') {
      // Instagram always uses the same embed pattern
      embedUrls.add('https://www.instagram.com/p/${uri.pathSegments.lastWhere((segment) => segment.isNotEmpty, orElse: () => '')}/embed/');
    }
    
    // Add original URL as a fallback
    if (embedUrls.isEmpty) {
      embedUrls.add(originalUrl);
    }
    
    return embedUrls;
  }
  
  String? _extractYouTubeVideoId(String url) {
    // Handle youtube.com/watch?v=VIDEO_ID
    RegExp regExp1 = RegExp(r'youtube\.com\/watch\?v=([^&]+)');
    Match? match = regExp1.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    
    // Handle youtu.be/VIDEO_ID
    RegExp regExp2 = RegExp(r'youtu\.be\/([^?&]+)');
    match = regExp2.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    
    return null;
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.play_arrow,
        color: Colors.white,
        size: 32,
      ),
    );
  }
}

class VideoPreview extends StatelessWidget {
  final String platform;
  final String url;
  final List<String>? fallbackUrls;
  final Map<String, dynamic>? settings;
  final String? reel_id;
  final VoidCallback? onTap;
  
  const VideoPreview({
    super.key,
    required this.platform,
    required this.url,
    this.fallbackUrls,
    this.settings,
    this.reel_id,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        child: SocialMediaWebView(
          platform: platform,
          url: url,
          fallbackUrls: fallbackUrls,
          settings: settings,
          reel_id: reel_id,
          onTap: onTap,
        ),
      ),
    );
  }
} 