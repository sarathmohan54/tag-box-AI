import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

/// General utility functions for the app

/// Format a date as a readable string
String formatDate(DateTime date, {bool showTime = false}) {
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
    if (showTime) {
      return DateFormat('MMM d, yyyy - h:mm a').format(date);
    }
    return DateFormat('MMM d, yyyy').format(date);
  }
}

/// Launch a URL
Future<void> launchURL(String url, {LaunchMode mode = LaunchMode.platformDefault}) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: mode);
    } else {
      debugPrint('Could not launch $url');
    }
  } catch (e) {
    debugPrint('Error launching URL: $e');
  }
}

/// Get the platform name from a URL
String getPlatformFromUrl(String url) {
  final lowerUrl = url.toLowerCase();
  
  if (lowerUrl.contains('facebook.com') || lowerUrl.contains('fb.watch')) {
    return 'facebook';
  } else if (lowerUrl.contains('instagram.com')) {
    return 'instagram';
  } else if (lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be')) {
    return 'youtube';
  } else if (lowerUrl.contains('tiktok.com')) {
    return 'tiktok';
  } else {
    return 'other';
  }
}

/// Get display name for platform with proper capitalization
String getPlatformDisplayName(String platform) {
  switch (platform.toLowerCase()) {
    case 'facebook':
      return 'Facebook';
    case 'instagram':
      return 'Instagram';
    case 'youtube':
      return 'YouTube';
    case 'tiktok':
      return 'TikTok';
    default:
      return platform.isNotEmpty 
          ? platform[0].toUpperCase() + platform.substring(1) 
          : 'Unknown';
  }
}

/// Get platform colors
Color getPlatformColor(String platform) {
  switch (platform.toLowerCase()) {
    case 'facebook':
      return const Color(0xFF3B5998);
    case 'instagram':
      return const Color(0xFFE1306C);
    case 'youtube':
      return const Color(0xFFFF0000);
    case 'tiktok':
      return Colors.black;
    default:
      return Colors.grey;
  }
}

/// Get platform icon
IconData getPlatformIcon(String platform) {
  switch (platform.toLowerCase()) {
    case 'facebook':
      return Icons.facebook;
    case 'instagram':
      return Icons.camera_alt;
    case 'youtube':
      return Icons.play_circle_outline;
    case 'tiktok':
      return Icons.music_note;
    default:
      return Icons.play_arrow;
  }
}

/// Check if the device is connected to the internet
Future<bool> hasInternetConnection() async {
  try {
    final result = await InternetAddress.lookup('google.com');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } on SocketException catch (_) {
    return false;
  }
} 