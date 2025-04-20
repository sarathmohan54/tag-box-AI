import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tagbox/common/theme.dart';
import 'package:tagbox/utils/utils.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

class SocialMediaWebView extends StatefulWidget {
  final String platform;
  final String url;
  final List<String>? fallbackUrls;
  final Map<String, dynamic>? settings;
  final String? reel_id;
  final VoidCallback? onTap;

  const SocialMediaWebView({
    super.key,
    required this.platform,
    required this.url,
    this.fallbackUrls,
    this.settings,
    this.reel_id,
    this.onTap,
  });

  @override
  State<SocialMediaWebView> createState() => _SocialMediaWebViewState();
}

class _SocialMediaWebViewState extends State<SocialMediaWebView> with AutomaticKeepAliveClientMixin {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  int _currentUrlIndex = 0;
  bool _isPaused = false;
  Timer? _loadingTimer;
  bool _isControllerInitialized = false;
  
  String get currentUrl {
    if (_currentUrlIndex == 0) {
      return widget.url;
    } else if (widget.fallbackUrls != null && _currentUrlIndex <= widget.fallbackUrls!.length) {
      return widget.fallbackUrls![_currentUrlIndex - 1];
    } else {
      return widget.url;
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeController();
    
    // Set a timeout for loading
    _loadingTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    });
  }
  
  @override
  void didUpdateWidget(SocialMediaWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Only reload if the URL or platform changed
    if (oldWidget.url != widget.url || oldWidget.platform != widget.platform) {
      _currentUrlIndex = 0;
      _hasError = false;
      _isLoading = true;
      _loadContent();
    }
  }

  void _initializeController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            _injectCustomJS();
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("WebView error: ${error.description}");
            _handleError();
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      );
    
    _isControllerInitialized = true;
    _loadContent();
  }
  
  Future<void> _loadContent() async {
    if (!_isControllerInitialized) return;
    
    try {
      await _controller.loadRequest(Uri.parse(currentUrl));
    } catch (e) {
      debugPrint("Error loading URL: $e");
      _handleError();
    }
  }
  
  void _handleError() {
    if (widget.fallbackUrls != null && _currentUrlIndex < widget.fallbackUrls!.length) {
      // Try the next fallback URL
      _currentUrlIndex++;
      _loadContent();
    } else {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }
  
  void _injectCustomJS() {
    switch (widget.platform.toLowerCase()) {
      case 'youtube':
        _injectYouTubeJS();
        break;
      case 'instagram':
        _injectInstagramJS();
        break;
      case 'facebook':
        _injectFacebookJS();
        break;
    }
  }
  
  Future<void> _injectYouTubeJS() async {
    // Hide YouTube UI elements and make video responsive
    const String youtubeJS = '''
      (function() {
        // Hide unnecessary UI elements
        var style = document.createElement('style');
        style.textContent = `
          .ytp-chrome-top, .ytp-chrome-bottom, .ytp-pause-overlay { display: none !important; }
          .html5-video-container { width: 100% !important; height: 100% !important; }
        `;
        document.head.appendChild(style);
        
        // Force video to fill container
        var video = document.querySelector('video');
        if (video) {
          video.style.width = '100%';
          video.style.height = '100%';
        }
      })();
    ''';
    
    try {
      await _controller.runJavaScript(youtubeJS);
    } catch (e) {
      debugPrint('Error injecting YouTube JS: $e');
    }
  }
  
  Future<void> _injectInstagramJS() async {
    // Hide Instagram UI elements and make the embed responsive
    const String instagramJS = '''
      (function() {
        var style = document.createElement('style');
        style.textContent = `
          .x9f619, ._aa56, .x78zum5, ._aap6, ._aap7 { display: none !important; }
          .EmbedIframe { width: 100% !important; height: 100% !important; }
          body { overflow: hidden; }
        `;
        document.head.appendChild(style);
        
        // Hide header
        var header = document.querySelector('header');
        if (header) {
          header.style.display = 'none';
        }
      })();
    ''';
    
    try {
      await _controller.runJavaScript(instagramJS);
    } catch (e) {
      debugPrint('Error injecting Instagram JS: $e');
    }
  }
  
  Future<void> _injectFacebookJS() async {
    // Hide Facebook UI elements and make the embed responsive
    const String facebookJS = '''
      (function() {
        var style = document.createElement('style');
        style.textContent = `
          .fb_iframe_widget_fluid_desktop iframe { width: 100% !important; height: 100% !important; }
          ._8o, ._42ef, ._5pcb { display: none !important; }
          body { overflow: hidden; }
        `;
        document.head.appendChild(style);
      })();
    ''';
    
    try {
      await _controller.runJavaScript(facebookJS);
    } catch (e) {
      debugPrint('Error injecting Facebook JS: $e');
    }
  }
  
  Future<void> _retryLoading() async {
    if (mounted) {
      setState(() {
        _hasError = false;
        _isLoading = true;
      });
    }
    
    _currentUrlIndex = 0;
    await _loadContent();
  }
  
  Future<void> _togglePause() async {
    const String toggleVideoJS = '''
      (function() {
        var videos = document.querySelectorAll('video');
        videos.forEach(function(video) {
          if (video.paused) {
            video.play();
          } else {
            video.pause();
          }
        });
        return videos.length > 0 ? (videos[0].paused ? 'paused' : 'playing') : 'no_video';
      })();
    ''';
    
    try {
      final result = await _controller.runJavaScriptReturningResult(toggleVideoJS);
      final status = result.toString().replaceAll('"', '');
      
      if (mounted) {
        setState(() {
          _isPaused = status == 'paused';
        });
      }
    } catch (e) {
      debugPrint('Error toggling video: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return GestureDetector(
      onTap: widget.onTap ?? _togglePause,
      child: Stack(
        children: [
          WebViewWidget(
            controller: _controller,
            gestureRecognizers: {
              Factory<TapGestureRecognizer>(() => TapGestureRecognizer()
                ..onTapDown = (_) {
                  if (widget.onTap != null) {
                    widget.onTap!();
                  } else {
                    _togglePause();
                  }
                }),
            },
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          if (_hasError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 40,
                    color: _getPlatformColor(),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Failed to load content',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _retryLoading,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(100, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          Positioned(
            bottom: 8,
            right: 8,
            child: _buildPlatformIndicator(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPlatformIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getPlatformIcon(),
            size: 12,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            widget.platform.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getPlatformColor() {
    switch (widget.platform.toLowerCase()) {
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
  
  IconData _getPlatformIcon() {
    switch (widget.platform.toLowerCase()) {
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
  
  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }
} 