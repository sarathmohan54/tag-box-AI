import 'dart:ui';
import 'dart:convert';
import 'category.dart';

extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) return this;
    return this[0].toUpperCase() + this.substring(1);
  }
}

class Tag {
  final int id;
  final String name;
  final DateTime createdAt;

  Tag({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'],
      name: json['name'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class Reel {
  final String id;
  final String url;
  final String title;
  final String platform;
  final String author;
  final DateTime createdAt;
  final String? thumbnailUrl;
  final Map<String, dynamic> metadata;
  final List<Category> categories;

  const Reel({
    required this.id,
    required this.url,
    required this.title,
    required this.platform,
    required this.author,
    required this.createdAt,
    this.thumbnailUrl,
    this.metadata = const {},
    this.categories = const [],
  });

  factory Reel.fromJson(Map<String, dynamic> json) {
    List<Category> categoriesList = [];
    if (json['categories'] != null) {
      categoriesList = List<Category>.from(
        json['categories'].map((x) => Category.fromJson(x))
      );
    }

    return Reel(
      id: json['id'],
      url: json['url'],
      title: json['title'] ?? 'Untitled Video',
      platform: json['platform'] ?? 'Unknown',
      author: json['author'] ?? 'Unknown Creator',
      createdAt: json['created_at'] != null 
        ? DateTime.parse(json['created_at']) 
        : DateTime.now(),
      thumbnailUrl: json['thumbnail_url'],
      metadata: json['metadata'] != null 
        ? json['metadata'] is String 
          ? jsonDecode(json['metadata']) 
          : Map<String, dynamic>.from(json['metadata'])
        : {},
      categories: categoriesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'platform': platform,
      'author': author,
      'created_at': createdAt.toIso8601String(),
      'thumbnail_url': thumbnailUrl,
      'metadata': metadata,
      'categories': categories.map((x) => x.toJson()).toList(),
    };
  }

  Reel copyWith({
    String? id,
    String? url,
    String? title,
    String? platform,
    String? author,
    DateTime? createdAt,
    String? thumbnailUrl,
    Map<String, dynamic>? metadata,
    List<Category>? categories,
  }) {
    return Reel(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      platform: platform ?? this.platform,
      author: author ?? this.author,
      createdAt: createdAt ?? this.createdAt,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      metadata: metadata ?? this.metadata,
      categories: categories ?? this.categories,
    );
  }

  String get displayThumbnailUrl {
    if (thumbnailUrl != null && !thumbnailUrl!.contains('placehold.co')) {
      return thumbnailUrl!;
    }
    
    // Generate appropriate fallback thumbnails based on platform
    switch (platform.toLowerCase()) {
      case 'youtube':
        return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
      case 'instagram':
        return 'https://placehold.co/600x800/E1306C/FFFFFF.png?text=Instagram+Video';
      case 'facebook':
        return 'https://placehold.co/600x800/4267B2/FFFFFF.png?text=Facebook+Video';
      case 'tiktok':
        return 'https://placehold.co/600x800/000000/FFFFFF.png?text=TikTok+Video';
      default:
        return 'https://placehold.co/600x800/808080/FFFFFF.png?text=${platform.capitalize()}+Content';
    }
  }
} 