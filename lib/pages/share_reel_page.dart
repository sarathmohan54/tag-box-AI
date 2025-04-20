import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'dart:convert';
import '../models/reel.dart';
import '../models/category.dart';
import '../services/reel_service.dart';
import '../utils/constants.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/social_media_webview.dart';

class ShareReelPage extends StatefulWidget {
  final String token;
  final String? initialUrl;
  final VoidCallback? onSaved;

  const ShareReelPage({
    super.key,
    required this.token,
    this.initialUrl,
    this.onSaved,
  });

  @override
  State<ShareReelPage> createState() => _ShareReelPageState();
}

class _ShareReelPageState extends State<ShareReelPage> {
  final _urlController = TextEditingController();
  final _tagController = TextEditingController();
  late ReelService _reelService;
  List<Category> _categories = [];
  List<String> _selectedTags = [];
  List<Category> _selectedCategories = [];
  bool _isLoading = false;
  Map<String, dynamic>? _reelInfo;
  bool _isInitialized = false;
  bool _isServiceReady = false;
  String? _errorMessage;
  String? _previewImageUrl;

  // Add a debouncer for URL changes
  Timer? _extractionDebouncer;

  // Add these variables and methods to the _ShareReelPageState class
  bool _isUrlInvalid = false;
  
  String? _getUrlHelperText() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return null;
    
    if (url.contains('instagram.com/reel/')) {
      if (!url.contains('/reel/') || url.endsWith('/reel/')) {
        return 'For Instagram: Include the full URL with reel ID';
      }
    }
    
    return null;
  }

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
    _initializeService();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _processInitialUrl();
  }

  Future<void> _processInitialUrl() async {
    if (!_isInitialized && widget.initialUrl != null) {
      _isInitialized = true;
      print('Processing initial URL: ${widget.initialUrl}');
      
      // Wait for service to be ready
      if (!_isServiceReady) {
        print('Waiting for service to be ready...');
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 100));
          return !_isServiceReady;
        });
      }
      
      setState(() {
        _urlController.text = widget.initialUrl!;
      });
      
      // Small delay to ensure URL is set
      await Future.delayed(const Duration(milliseconds: 100));
      await _extractReelInfo();
    }
  }

  void _onUrlChanged() {
    if (_urlController.text.isNotEmpty && _isServiceReady) {
      print('URL changed: ${_urlController.text}');
      _debounceReelExtraction();
    }
  }

  void _debounceReelExtraction() {
    if (_extractionDebouncer?.isActive ?? false) {
      _extractionDebouncer!.cancel();
    }
    _extractionDebouncer = Timer(const Duration(milliseconds: 500), () {
      _extractReelInfo();
    });
  }

  Future<void> _initializeService() async {
    try {
      print('Initializing service...');
      final prefs = await SharedPreferences.getInstance();
      _reelService = ReelService(token: widget.token, prefs: prefs);
      await _loadCategories();
      setState(() {
        _isServiceReady = true;
      });
      print('Service initialized successfully');
    } catch (e) {
      print('Error initializing service: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      print('Loading categories...');
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/categories'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
      );

      print('Categories response status: ${response.statusCode}');
      print('Categories response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> categoriesJson = json.decode(response.body);
        if (mounted) {
          setState(() {
            _categories = categoriesJson
                .map((json) => Category.fromJson(json))
                .toList();
          });
        }
        print('Successfully loaded ${_categories.length} categories');
      } else {
        print('Failed to load categories: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load categories. Please try again later.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading categories: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading categories: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _extractReelInfo() async {
    if (_urlController.text.isEmpty) {
      setState(() {
        _isLoading = false;
        _showErrorMessage('Please enter a video URL');
        _isUrlInvalid = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _reelInfo = null;
      _errorMessage = null;
      _isUrlInvalid = false;
    });

    try {
      final extractedInfo = await _reelService.extractReelInfo(_urlController.text);
      
      // Check if there was an error during extraction
      if (extractedInfo.containsKey('error')) {
        setState(() {
          _isLoading = false;
          _reelInfo = null;
          
          // Handle different error types
          String errorType = extractedInfo['error'];
          switch (errorType) {
            case 'incomplete_url':
              _showErrorMessage('Please provide a complete URL including the video ID');
              _isUrlInvalid = true;
              break;
            case 'invalid_url':
              _showErrorMessage('The URL format is invalid');
              _isUrlInvalid = true;
              break;
            case 'missing_id':
              _showErrorMessage('Could not extract the video ID from the URL');
              _isUrlInvalid = true;
              break;
            case 'processing_error':
            default:
              _showErrorMessage('Error processing the URL: ${extractedInfo['metadata']?['error'] ?? 'Unknown error'}');
          }
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _reelInfo = extractedInfo;
        _errorMessage = null;
        _isUrlInvalid = false;
      });
      
      // Set proper platform-specific defaults for better UI
      if (_reelInfo!['platform'] == 'facebook') {
        setState(() {
          if (_reelInfo!['caption'] == null || _reelInfo!['caption'].isEmpty) {
            _reelInfo!['caption'] = 'Facebook Video';
          }
          
          // Ensure Facebook author is never empty or Unknown
          if (_reelInfo!['author'] == null || 
              _reelInfo!['author'].isEmpty || 
              _reelInfo!['author'] == 'Unknown') {
            _reelInfo!['author'] = '@facebook_user';
          }
          
          // Set tag controller to match author
          _tagController.text = _reelInfo!['author'];
        });
      } else if (_reelInfo!['platform'] == 'instagram') {
        setState(() {
          if (_reelInfo!['caption'] == null || _reelInfo!['caption'].isEmpty) {
            _reelInfo!['caption'] = 'Instagram Video';
          }
          
          // Ensure Instagram author is never empty or generic
          if (_reelInfo!['author'] == null || 
              _reelInfo!['author'] == 'Instagram User' || 
              _reelInfo!['author'].isEmpty) {
            _reelInfo!['author'] = '@instagram_user';
          }
          
          // Set tag controller to match author
          _tagController.text = _reelInfo!['author'];
        });
      }
      
      // Only call _previewReel if we have valid info
      _previewReel();
    } catch (e) {
      print('Error extracting reel info: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to extract reel information: ${e.toString()}';
      });
    }
  }

  void _previewReel() {
    if (_reelInfo == null) {
      return;
    }

    // Update UI with the extracted information
    setState(() {
      _reelInfo!['caption'] = _reelInfo!['caption'] ?? '';
      
      // For Instagram, show a better preview
      if (_reelInfo!['platform'] == 'instagram') {
        final reelId = _reelInfo!['reel_id'] ?? '';
        _previewImageUrl = 'https://via.placeholder.com/300x400?text=Instagram+Reel:+$reelId';
        
        // Set some default text for author if not available
        if (_reelInfo!['author'] == 'Instagram User') {
          _tagController.text = '@instagram_user';
        } else {
          _tagController.text = _reelInfo!['author'] ?? '';
        }
      } else {
        _previewImageUrl = _reelInfo!['thumbnail_url'] ?? '';
        _tagController.text = _reelInfo!['author'] ?? '';
      }
      
      _urlController.text = _reelInfo!['url'] ?? '';
    });
  }

  void _handleSharedText(String sharedText) {
    if (mounted && _isServiceReady) {
      setState(() {
        _urlController.text = sharedText;
      });
    }
  }

  void _addTag(String tag) {
    if (tag.isNotEmpty && !_selectedTags.contains(tag)) {
      setState(() {
        _selectedTags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _selectedTags.remove(tag);
    });
  }

  Future<void> _saveReel() async {
    if (_reelInfo == null) {
      _showErrorMessage('Please extract reel information first');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get the selected category IDs
      List<int> selectedCategoryIds = _selectedCategories.map((c) => c.id).toList();

      // Create tag objects from tag strings
      List<Map<String, dynamic>> tagObjects = _selectedTags.map((tag) {
        return {'name': tag};
      }).toList();

      // Create the request body
      Map<String, dynamic> reelData = {
        'platform': _reelInfo!['platform'],
        'reel_id': _reelInfo!['reel_id'] ?? '',
        'url': _urlController.text.trim(),
        'thumbnail_url': _reelInfo!['thumbnail_url'] ?? '',
        'caption': _reelInfo!['caption'] ?? '',
        'author': _tagController.text,
        'reel_metadata': _reelInfo!['metadata'] ?? {},
        'categories': selectedCategoryIds,
        'tags': tagObjects,
      };

      // Save the reel
      final response = await _reelService.saveReel(reelData);

      setState(() {
        _isLoading = false;
      });

      // Check for URL errors in the extracted info
      if (_reelInfo!.containsKey('error')) {
        _showErrorMessage('Please provide a valid and complete URL');
        return;
      }

      if (response != null) {
        // Check if the reel was already in collection (from the message)
        final responseBody = response as Map<String, dynamic>;
        final message = responseBody['message'] as String?;
        final alreadySaved = message != null && 
            (message.contains('already saved') || message.contains('already in your collection'));
        
        if (alreadySaved) {
          _showSuccessMessage('This reel is already in your collection');
        } else {
          _showSuccessMessage('Reel saved successfully');
          
          // Reset the form
          _urlController.clear();
          _tagController.clear();
          setState(() {
            _reelInfo = null;
            _previewImageUrl = null;
            _selectedCategories = [];
            _selectedTags = [];
          });
        }
        
        // Navigate back or to home page
        if (widget.onSaved != null) {
          widget.onSaved!();
        } else {
          Navigator.of(context).pop();
        }
      } else {
        _showErrorMessage('Failed to save the reel');
      }
    } catch (e) {
      print('Error saving reel: $e');
      setState(() {
        _isLoading = false;
      });
      
      // Check if it's a duplicate key error
      if (e.toString().contains('duplicate key') || 
          e.toString().contains('already exists') ||
          e.toString().contains('Unique constraint failed')) {
        _showErrorMessage('This reel is already in your collection');
      } else {
        _showErrorMessage('Error saving reel: ${e.toString()}');
      }
    }
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _tagController.dispose();
    _extractionDebouncer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Reel'),
      ),
      body: _isServiceReady ? SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Reel URL',
                hintText: 'Paste Facebook, Instagram, TikTok, or YouTube URL',
                border: const OutlineInputBorder(),
                errorText: _isUrlInvalid ? 'Please enter a complete URL with video ID' : null,
                helperText: _getUrlHelperText(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_urlController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _urlController.clear();
                            _reelInfo = null;
                            _isUrlInvalid = false;
                          });
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.paste),
                      tooltip: 'Paste from clipboard',
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          setState(() {
                            _urlController.text = data!.text!;
                            _isUrlInvalid = false;
                          });
                          _extractReelInfo();
                        }
                      },
                    ),
                  ],
                ),
              ),
              maxLines: 1,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onChanged: (value) {
                // Reset validation state when user types
                if (_isUrlInvalid) {
                  setState(() {
                    _isUrlInvalid = false;
                  });
                }
                _debounceReelExtraction();
              },
            ),
            const SizedBox(height: 16),
            
            _buildCategorySelection(),
            
            const SizedBox(height: 16),
            
            // Tags Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    decoration: const InputDecoration(
                      labelText: 'Add Tags',
                      hintText: 'Enter a tag and press add',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _addTag,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _addTag(_tagController.text),
                  child: const Text('Add Tag'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Selected Tags
            Wrap(
              spacing: 8,
              children: _selectedTags.map((tag) {
                return Chip(
                  label: Text(tag),
                  onDeleted: () => _removeTag(tag),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_reelInfo != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildThumbnailPreview(),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _reelInfo!['caption'] ?? 'No caption',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _reelInfo!['author'] ?? 'Unknown author',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            
            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveReel,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Save Reel'),
            ),
          ],
        ),
      ) : const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildCategorySelection() {
    if (_categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Categories',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.category_outlined, color: Colors.grey[500]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No categories available',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to profile page to add categories
                      Navigator.pushNamed(context, '/profile').then((_) {
                        // Reload categories when returning
                        _loadCategories();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor,
                      backgroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: const Text('Add New'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Categories',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((category) {
            final isSelected = _selectedCategories.contains(category);
            return FilterChip(
              selected: isSelected,
              label: Text(category.name),
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    // Only allow one category to be selected
                    _selectedCategories = [category];
                  } else {
                    _selectedCategories.remove(category);
                  }
                });
              },
              selectedColor: Theme.of(context).primaryColor.withOpacity(0.8),
              checkmarkColor: Colors.white,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildThumbnailPreview() {
    print('Building thumbnail preview.');
    print('Platform: ${_reelInfo?['platform']}');
    print('URL: ${_reelInfo?['url']}');
    
    if (_reelInfo?['platform'] == 'youtube') {
      return _buildYouTubePreview();
    } else if (_reelInfo?['platform'] == 'instagram') {
      return _buildEnhancedInstagramPreview();
    } else if (_reelInfo?['platform'] == 'facebook') {
      return _buildEnhancedFacebookPreview();
    } else {
      return _buildGenericThumbnailPreview();
    }
  }

  Widget _buildYouTubePreview() {
    final reel = _reelInfo ?? {};
    final videoId = reel['reel_id'] ?? '';
    final url = reel['url'] ?? '';
    final metadata = reel['metadata'] ?? {};
    
    // Create YouTube embed URL
    String embedUrl = '';
    if (videoId.isNotEmpty) {
      embedUrl = 'https://www.youtube.com/embed/$videoId';
    }
    
    // Get embed URLs
    List<String> embedUrls = [];
    if (embedUrl.isNotEmpty) {
      embedUrls.add(embedUrl);
    }
    
    if (metadata['embed_urls'] != null && metadata['embed_urls'] is List) {
      embedUrls.addAll(List<String>.from(metadata['embed_urls']));
    } else if (reel['embed_urls'] != null && reel['embed_urls'] is List) {
      embedUrls.addAll(List<String>.from(reel['embed_urls']));
    } else if (metadata['embed_url'] != null) {
      embedUrls.add(metadata['embed_url'].toString());
    } else if (reel['embed_url'] != null) {
      embedUrls.add(reel['embed_url'].toString());
    }
    
    // Add URL as fallback
    if (url.isNotEmpty && !embedUrls.contains(url)) {
      embedUrls.add(url);
    }
    
    // Extract WebView settings
    Map<String, dynamic>? webviewSettings;
    if (metadata['webview_settings'] != null && metadata['webview_settings'] is Map) {
      webviewSettings = Map<String, dynamic>.from(metadata['webview_settings']);
    }
    
    // Create the YouTube preview
    return Container(
      constraints: const BoxConstraints(maxHeight: 500),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        color: Colors.black,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SocialMediaWebView(
          platform: 'youtube',
          url: embedUrls.isNotEmpty ? embedUrls.first : url,
          fallbackUrls: embedUrls.length > 1 ? embedUrls : null,
          settings: webviewSettings,
          reel_id: videoId,
          onTap: () {
            _launchURL(url);
          },
        ),
      ),
    );
  }

  Widget _buildEnhancedInstagramPreview() {
    final reel = _reelInfo ?? {};
    final reelId = reel['reel_id'] ?? '';
    final url = reel['url'] ?? '';
    
    if (reelId.isEmpty && url.isEmpty) {
      return _buildGenericThumbnailPreview();
    }
    
    // Controller setup
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black);
    
    // Navigation delegate for loading states and errors
    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (String url) {
          print('Instagram preview page started loading: $url');
        },
        onPageFinished: (String url) {
          print('Instagram preview page finished loading: $url');
        },
        onWebResourceError: (WebResourceError error) {
          print('Instagram preview error: ${error.description}');
        },
      ),
    );
    
    // Create the HTML content with multiple fallbacks
    final htmlContent = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
          body {
            margin: 0;
            padding: 0;
            background-color: #000;
            color: #fff;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            font-family: Arial, sans-serif;
          }
          .container {
            width: 100%;
            height: 100%;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            position: relative;
          }
          .instagram-embed-container {
            width: 100%;
            height: 100%;
            overflow: hidden;
            position: relative;
          }
          .iframe-container {
            width: 100%;
            height: 100%;
            display: none;
          }
          .fallback-container {
            width: 100%;
            height: 100%;
            display: none;
            justify-content: center;
            align-items: center;
            flex-direction: column;
            text-align: center;
            padding: 20px;
            box-sizing: border-box;
          }
          .loading {
            display: flex;
            justify-content: center;
            align-items: center;
            flex-direction: column;
          }
          .spinner {
            width: 40px;
            height: 40px;
            border: 4px solid rgba(255, 255, 255, 0.3);
            border-radius: 50%;
            border-top: 4px solid #E1306C;
            animation: spin 1s linear infinite;
            margin-bottom: 10px;
          }
          .instagram-logo {
            width: 40px;
            height: 40px;
            margin-bottom: 10px;
            background: radial-gradient(circle at 30% 107%, #fdf497 0%, #fdf497 5%, #fd5949 45%, #d6249f 60%, #285AEB 90%);
            border-radius: 12px;
            display: flex;
            justify-content: center;
            align-items: center;
          }
          .instagram-logo svg {
            width: 24px;
            height: 24px;
            fill: white;
          }
          .platform-indicator {
            position: absolute;
            top: 10px;
            right: 10px;
            background-color: rgba(0, 0, 0, 0.7);
            color: white;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: bold;
            display: flex;
            align-items: center;
          }
          .platform-indicator span {
            margin-left: 5px;
          }
          .platform-indicator svg {
            fill: white;
          }
          @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
          }
          .instagram-content {
            max-width: 100%;
            width: 100%;
            aspect-ratio: 9/16;
            background-color: #000;
            position: relative;
            display: flex;
            justify-content: center;
            align-items: center;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="loading" id="loadingIndicator">
            <div class="spinner"></div>
            <div>Loading Instagram content...</div>
          </div>
          
          <div class="instagram-embed-container" id="instagramEmbed" style="display: none;">
            <div class="instagram-content">
              <!-- Instagram content embed will be inserted here -->
            </div>
          </div>
          
          <div class="iframe-container" id="iframeContainer" style="display: none;">
            <iframe 
              src="$url" 
              width="100%" 
              height="100%" 
              style="border:none;overflow:hidden" 
              scrolling="no" 
              frameborder="0" 
              allowfullscreen="true">
            </iframe>
          </div>
          
          <div class="fallback-container" id="fallbackContainer" style="display: none;">
            <div class="instagram-logo">
              <svg viewBox="0 0 24 24">
                <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073z"/>
                <path d="M12 6.865c-2.841 0-5.144 2.303-5.144 5.144s2.303 5.144 5.144 5.144 5.144-2.303 5.144-5.144-2.303-5.144-5.144-5.144zm0 8.485c-1.845 0-3.341-1.496-3.341-3.341s1.496-3.341 3.341-3.341 3.341 1.496 3.341 3.341-1.496 3.341-3.341 3.341z"/>
                <circle cx="17.335" cy="6.665" r="1.2"/>
              </svg>
            </div>
            <div>Instagram content could not be loaded</div>
            <div style="margin-top: 5px; font-size: 12px; opacity: 0.8;">Tap to open in Instagram app</div>
          </div>
          
          <div class="platform-indicator">
            <svg width="14" height="14" viewBox="0 0 24 24">
              <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073z"/>
              <path d="M12 6.865c-2.841 0-5.144 2.303-5.144 5.144s2.303 5.144 5.144 5.144 5.144-2.303 5.144-5.144-2.303-5.144-5.144-5.144zm0 8.485c-1.845 0-3.341-1.496-3.341-3.341s1.496-3.341 3.341-3.341 3.341 1.496 3.341 3.341-1.496 3.341-3.341 3.341z"/>
              <circle cx="17.335" cy="6.665" r="1.2"/>
            </svg>
            <span>INSTAGRAM</span>
          </div>
        </div>
        
        <script>
          // Setup timeouts for fallbacks
          let loadTimeout = setTimeout(showFallback, 10000);
          let instagramLoadAttempted = false;
          
          function showFallback() {
            document.getElementById('loadingIndicator').style.display = 'none';
            document.getElementById('instagramEmbed').style.display = 'none';
            document.getElementById('iframeContainer').style.display = 'none';
            document.getElementById('fallbackContainer').style.display = 'flex';
          }
          
          function tryInstagramEmbed() {
            if (instagramLoadAttempted) return;
            instagramLoadAttempted = true;
            
            // Load the Instagram embed script
            var script = document.createElement('script');
            script.src = 'https://www.instagram.com/embed.js';
            script.async = true;
            script.onload = function() {
              try {
                // Create Instagram embed element
                const instagramEmbed = document.getElementById('instagramEmbed');
                const instagramContent = instagramEmbed.querySelector('.instagram-content');
                
                instagramContent.innerHTML = '<blockquote class="instagram-media" data-instgrm-permalink="${url}" data-instgrm-version="14"></blockquote>';
                instagramEmbed.style.display = 'block';
                
                // Process Instagram embeds
                if (window.instgrm) {
                  window.instgrm.Embeds.process();
                  
                  // Check if Instagram embed loaded successfully
                  setTimeout(function() {
                    const embedContent = document.querySelector('.instagram-media');
                    if (embedContent && embedContent.offsetHeight > 50) {
                      clearTimeout(loadTimeout);
                      document.getElementById('loadingIndicator').style.display = 'none';
                    } else {
                      tryIframeEmbed();
                    }
                  }, 3000);
                } else {
                  tryIframeEmbed();
                }
              } catch (e) {
                console.error('Error setting up Instagram embed:', e);
                tryIframeEmbed();
              }
            };
            
            script.onerror = function() {
              console.error('Failed to load Instagram embed script');
              tryIframeEmbed();
            };
            
            document.body.appendChild(script);
          }
          
          function tryIframeEmbed() {
            document.getElementById('loadingIndicator').style.display = 'none';
            document.getElementById('instagramEmbed').style.display = 'none';
            document.getElementById('iframeContainer').style.display = 'block';
            
            // If iframe doesn't load in 5 seconds, show fallback
            setTimeout(function() {
              const iframe = document.querySelector('#iframeContainer iframe');
              if (!iframe || !iframe.contentWindow.document) {
                showFallback();
              }
            }, 5000);
          }
          
          // Start loading Instagram embed first
          tryInstagramEmbed();
          
          // After 3 seconds, try the iframe as a backup if Instagram hasn't loaded
          setTimeout(function() {
            if (document.getElementById('loadingIndicator').style.display !== 'none') {
              tryIframeEmbed();
            }
          }, 3000);
        </script>
      </body>
      </html>
    ''';
    
    // Load the HTML content
    controller.loadHtmlString(htmlContent);
    
    // Return the WebView wrapped in a platform indicator
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 9 / 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                // Main WebView
                WebViewWidget(controller: controller),
                
                // Overlay to handle taps (to open in Instagram app)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      String igUrl = url;
                      
                      // Generate various URL formats to try
                      List<String> urlsToTry = [];
                      
                      // Add app URLs first
                      if (reelId.isNotEmpty) {
                        urlsToTry.add('instagram://reels/$reelId');
                        urlsToTry.add('instagram://p/$reelId');
                        urlsToTry.add('instagram://media?id=$reelId');
                      }
                      
                      // Add web URLs
                      urlsToTry.add(igUrl);
                      if (reelId.isNotEmpty) {
                        if (url.contains('/reel/')) {
                          urlsToTry.add('https://www.instagram.com/reel/$reelId/');
                          urlsToTry.add('https://instagram.com/reel/$reelId/');
                        } else if (url.contains('/p/')) {
                          urlsToTry.add('https://www.instagram.com/p/$reelId/');
                          urlsToTry.add('https://instagram.com/p/$reelId/');
                        }
                      }
                      
                      for (final urlToTry in urlsToTry) {
                        try {
                          if (await canLaunchUrl(Uri.parse(urlToTry))) {
                            await launchUrl(
                              Uri.parse(urlToTry),
                              mode: LaunchMode.externalApplication,
                            );
                            break;
                          }
                        } catch (e) {
                          print('Error launching $urlToTry: $e');
                        }
                      }
                    },
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.camera_alt, color: Colors.white),
              label: Text('Open in Instagram App', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFE1306C),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                String igUrl = url;
                
                // Generate various URL formats to try
                List<String> urlsToTry = [];
                
                // Add app URLs first
                if (reelId.isNotEmpty) {
                  urlsToTry.add('instagram://reels/$reelId');
                  urlsToTry.add('instagram://p/$reelId');
                  urlsToTry.add('instagram://media?id=$reelId');
                }
                
                // Add web URLs
                urlsToTry.add(igUrl);
                if (reelId.isNotEmpty) {
                  if (url.contains('/reel/')) {
                    urlsToTry.add('https://www.instagram.com/reel/$reelId/');
                    urlsToTry.add('https://instagram.com/reel/$reelId/');
                  } else if (url.contains('/p/')) {
                    urlsToTry.add('https://www.instagram.com/p/$reelId/');
                    urlsToTry.add('https://instagram.com/p/$reelId/');
                  }
                }
                
                for (final urlToTry in urlsToTry) {
                  try {
                    if (await canLaunchUrl(Uri.parse(urlToTry))) {
                      await launchUrl(
                        Uri.parse(urlToTry),
                        mode: LaunchMode.externalApplication,
                      );
                      break;
                    }
                  } catch (e) {
                    print('Error launching $urlToTry: $e');
                  }
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnhancedFacebookPreview() {
    final reel = _reelInfo ?? {};
    final videoId = reel['reel_id'] ?? '';
    final url = reel['url'] ?? '';
    
    if (videoId.isEmpty && url.isEmpty) {
      return _buildGenericThumbnailPreview();
    }
    
    // Controller setup
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black);
    
    // Navigation delegate for loading states and errors
    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (String url) {
          print('Facebook preview page started loading: $url');
        },
        onPageFinished: (String url) {
          print('Facebook preview page finished loading: $url');
        },
        onWebResourceError: (WebResourceError error) {
          print('Facebook preview error: ${error.description}');
        },
      ),
    );
    
    // Generate the embed URL for the video
    final embedUrl = 'https://www.facebook.com/plugins/video.php?href=${Uri.encodeComponent(url)}&show_text=false';
    
    // Create the HTML content with multiple fallbacks
    final htmlContent = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
          body {
            margin: 0;
            padding: 0;
            background-color: #000;
            color: #fff;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            font-family: Arial, sans-serif;
          }
          .container {
            width: 100%;
            height: 100%;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            position: relative;
          }
          .fb-embed-container {
            width: 100%;
            height: 100%;
            overflow: hidden;
            position: relative;
          }
          .iframe-container {
            width: 100%;
            height: 100%;
            display: none;
          }
          .fallback-container {
            width: 100%;
            height: 100%;
            display: none;
            justify-content: center;
            align-items: center;
            flex-direction: column;
            text-align: center;
            padding: 20px;
            box-sizing: border-box;
          }
          .loading {
            display: flex;
            justify-content: center;
            align-items: center;
            flex-direction: column;
          }
          .spinner {
            width: 40px;
            height: 40px;
            border: 4px solid rgba(255, 255, 255, 0.3);
            border-radius: 50%;
            border-top: 4px solid #1877f2;
            animation: spin 1s linear infinite;
            margin-bottom: 10px;
          }
          .fb-logo {
            width: 40px;
            height: 40px;
            margin-bottom: 10px;
            background-color: #1877f2;
            border-radius: 50%;
            display: flex;
            justify-content: center;
            align-items: center;
          }
          .fb-logo svg {
            width: 24px;
            height: 24px;
            fill: white;
          }
          .platform-indicator {
            position: absolute;
            top: 10px;
            right: 10px;
            background-color: rgba(0, 0, 0, 0.7);
            color: white;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: bold;
            display: flex;
            align-items: center;
          }
          .platform-indicator span {
            margin-left: 5px;
          }
          @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="loading" id="loadingIndicator">
            <div class="spinner"></div>
            <div>Loading Facebook Video...</div>
          </div>
          
          <div class="fb-embed-container" id="fbEmbed" style="display: none;">
            <!-- Facebook video embed will be inserted here -->
          </div>
          
          <div class="iframe-container" id="iframeContainer" style="display: none;">
            <iframe 
              src="$embedUrl" 
              width="100%" 
              height="100%" 
              style="border:none;overflow:hidden" 
              scrolling="no" 
              frameborder="0" 
              allowfullscreen="true" 
              allow="autoplay; clipboard-write; encrypted-media; picture-in-picture; web-share">
            </iframe>
          </div>
          
          <div class="fallback-container" id="fallbackContainer" style="display: none;">
            <div class="fb-logo">
              <svg viewBox="0 0 36 36">
                <path d="M20.181 35.87C29.094 34.791 36 27.202 36 18c0-9.941-8.059-18-18-18S0 8.059 0 18c0 8.442 5.811 15.526 13.652 17.471L14 34h5.5l.681 1.87Z" fill="#1877F2"/>
                <path d="M24.5 18.5h-4v-3c0-1.103.897-2 2-2h2v-3.5h-3.25c-2.9 0-5.25 2.35-5.25 5.25v3.25h-3.5V22h3.5v10.75c1.295.224 2.624.25 4 .25 1.376 0 2.705-.026 4-.25V22h2.75l1.5-3.5z" fill="#fff"/>
              </svg>
            </div>
            <div>Facebook content could not be loaded</div>
            <div style="margin-top: 5px; font-size: 12px; opacity: 0.8;">Tap to open in Facebook app</div>
          </div>
          
          <div class="platform-indicator">
            <svg width="14" height="14" viewBox="0 0 36 36">
              <path d="M20.181 35.87C29.094 34.791 36 27.202 36 18c0-9.941-8.059-18-18-18S0 8.059 0 18c0 8.442 5.811 15.526 13.652 17.471L14 34h5.5l.681 1.87Z" fill="#1877F2"/>
              <path d="M24.5 18.5h-4v-3c0-1.103.897-2 2-2h2v-3.5h-3.25c-2.9 0-5.25 2.35-5.25 5.25v3.25h-3.5V22h3.5v10.75c1.295.224 2.624.25 4 .25 1.376 0 2.705-.026 4-.25V22h2.75l1.5-3.5z" fill="#fff"/>
            </svg>
            <span>FACEBOOK</span>
          </div>
        </div>
        
        <script>
          // Setup timeouts for fallbacks
          let loadTimeout = setTimeout(showFallback, 10000);
          let fbLoadAttempted = false;
          
          function showFallback() {
            document.getElementById('loadingIndicator').style.display = 'none';
            document.getElementById('fbEmbed').style.display = 'none';
            document.getElementById('iframeContainer').style.display = 'none';
            document.getElementById('fallbackContainer').style.display = 'flex';
          }
          
          function tryFacebookEmbed() {
            if (fbLoadAttempted) return;
            fbLoadAttempted = true;
            
            // Load the Facebook SDK
            (function(d, s, id) {
              var js, fjs = d.getElementsByTagName(s)[0];
              if (d.getElementById(id)) return;
              js = d.createElement(s); js.id = id;
              js.src = "https://connect.facebook.net/en_US/sdk.js#xfbml=1&version=v18.0";
              fjs.parentNode.insertBefore(js, fjs);
            }(document, 'script', 'facebook-jssdk'));
            
            // Setup Facebook SDK callback
            window.fbAsyncInit = function() {
              try {
                // Create the fb-post div and insert it into the container
                const fbEmbed = document.getElementById('fbEmbed');
                fbEmbed.innerHTML = '<div class="fb-video" data-href="${url}" data-width="auto" data-height="auto" data-autoplay="true" data-allowfullscreen="true"></div>';
                fbEmbed.style.display = 'block';
                
                // Parse the newly added elements
                FB.XFBML.parse(fbEmbed, function() {
                  clearTimeout(loadTimeout);
                  document.getElementById('loadingIndicator').style.display = 'none';
                });
                
                // If FB embed doesn't render within 5 seconds, try the iframe
                setTimeout(function() {
                  if (document.getElementById('loadingIndicator').style.display !== 'none') {
                    tryIframeEmbed();
                  }
                }, 5000);
              } catch (e) {
                console.error('Error setting up Facebook embed:', e);
                tryIframeEmbed();
              }
            };
          }
          
          function tryIframeEmbed() {
            document.getElementById('loadingIndicator').style.display = 'none';
            document.getElementById('fbEmbed').style.display = 'none';
            document.getElementById('iframeContainer').style.display = 'block';
            
            // If iframe doesn't load in 5 seconds, show fallback
            setTimeout(function() {
              const iframe = document.querySelector('#iframeContainer iframe');
              if (!iframe || !iframe.contentWindow.document) {
                showFallback();
              }
            }, 5000);
          }
          
          // Start loading Facebook embed first
          tryFacebookEmbed();
          
          // After 3 seconds, try the iframe as a backup if Facebook hasn't loaded
          setTimeout(function() {
            if (document.getElementById('loadingIndicator').style.display !== 'none') {
              tryIframeEmbed();
            }
          }, 3000);
        </script>
      </body>
      </html>
    ''';
    
    // Load the HTML content
    controller.loadHtmlString(htmlContent);
    
    // Return the WebView wrapped in a platform indicator
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                // Main WebView
                WebViewWidget(controller: controller),
                
                // Overlay to handle taps (to open in Facebook app)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      String fbUrl = url;
                      
                      // Generate various URL formats to try
                      List<String> urlsToTry = [];
                      
                      // Add app URLs first
                      if (videoId.isNotEmpty) {
                        urlsToTry.add('fb://reel/$videoId');
                        urlsToTry.add('fb://watch/?v=$videoId');
                      }
                      
                      // Add web URLs
                      urlsToTry.add(fbUrl);
                      if (videoId.isNotEmpty) {
                        urlsToTry.add('https://www.facebook.com/watch/?v=$videoId');
                        urlsToTry.add('https://m.facebook.com/watch/?v=$videoId');
                      }
                      
                      for (final urlToTry in urlsToTry) {
                        try {
                          if (await canLaunchUrl(Uri.parse(urlToTry))) {
                            await launchUrl(
                              Uri.parse(urlToTry),
                              mode: LaunchMode.externalApplication,
                            );
                            break;
                          }
                        } catch (e) {
                          print('Error launching $urlToTry: $e');
                        }
                      }
                    },
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.facebook, color: Colors.white),
              label: Text('Open in Facebook App', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1877F2),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () async {
                String fbUrl = url;
                
                // Generate various URL formats to try
                List<String> urlsToTry = [];
                
                // Add app URLs first
                if (videoId.isNotEmpty) {
                  urlsToTry.add('fb://reel/$videoId');
                  urlsToTry.add('fb://watch/?v=$videoId');
                }
                
                // Add web URLs
                urlsToTry.add(fbUrl);
                if (videoId.isNotEmpty) {
                  urlsToTry.add('https://www.facebook.com/watch/?v=$videoId');
                  urlsToTry.add('https://m.facebook.com/watch/?v=$videoId');
                }
                
                for (final urlToTry in urlsToTry) {
                  try {
                    if (await canLaunchUrl(Uri.parse(urlToTry))) {
                      await launchUrl(
                        Uri.parse(urlToTry),
                        mode: LaunchMode.externalApplication,
                      );
                      break;
                    }
                  } catch (e) {
                    print('Error launching $urlToTry: $e');
                  }
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenericThumbnailPreview() {
    final reel = _reelInfo ?? {};
    final thumbnailUrl = reel['thumbnail_url'] ?? '';
    final platform = reel['platform'] ?? 'other';
    
    if (thumbnailUrl.isEmpty) {
      // Return a platform-specific placeholder
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                platform == 'youtube' ? Icons.play_circle_outline :
                platform == 'instagram' ? Icons.camera_alt :
                platform == 'facebook' ? Icons.facebook :
                Icons.video_library, 
                size: 48, 
                color: Colors.grey
              ),
              const SizedBox(height: 16),
              Text(
                'No preview available for this $platform content',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      );
    }
    
    // Return an image preview
    return Container(
      constraints: const BoxConstraints(maxHeight: 500),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CachedNetworkImage(
          imageUrl: thumbnailUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[200],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.error_outline, size: 48, color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorMessage(String message) {
    setState(() {
      _errorMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }

  Widget _buildPreviewSection() {
    if (_reelInfo == null) {
      // Return a placeholder when there's no reel info
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.video_library, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Enter a valid social media URL to see a preview',
                style: TextStyle(color: Colors.grey[700])
              ),
            ],
          ),
        ),
      );
    }
    
    // Show appropriate preview based on platform
    final platform = _reelInfo!['platform'];
    
    if (platform == 'instagram') {
      return _buildSocialMediaPreview('instagram');
    } else if (platform == 'facebook') {
      return _buildSocialMediaPreview('facebook');
    } else if (platform == 'youtube') {
      return _buildYouTubePreview();
    } else {
      // Return a generic preview for other platforms
      return _buildGenericThumbnailPreview();
    }
  }

  Widget _buildSocialMediaPreview(String platform) {
    final reel = _reelInfo ?? {};
    final reelId = reel['reel_id'] ?? '';
    final url = reel['url'] ?? '';
    final metadata = reel['metadata'] ?? {};
    
    // Check if we have the necessary data
    if (reelId.isEmpty && url.isEmpty) {
      return _buildGenericThumbnailPreview();
    }
    
    // Get embed URLs
    List<String> embedUrls = [];
    if (metadata['embed_urls'] != null && metadata['embed_urls'] is List) {
      embedUrls = List<String>.from(metadata['embed_urls']);
    } else if (reel['embed_urls'] != null && reel['embed_urls'] is List) {
      embedUrls = List<String>.from(reel['embed_urls']);
    } else if (metadata['embed_url'] != null) {
      embedUrls = [metadata['embed_url'].toString()];
    } else if (reel['embed_url'] != null) {
      embedUrls = [reel['embed_url'].toString()];
    }
    
    // Add URL as fallback
    if (url.isNotEmpty && !embedUrls.contains(url)) {
      embedUrls.add(url);
    }
    
    // If we still don't have any URLs, create platform-specific defaults
    if (embedUrls.isEmpty) {
      if (platform == 'facebook' && reelId.isNotEmpty) {
        final watchUrl = 'https://www.facebook.com/watch/?v=$reelId';
        final encodedWatchUrl = Uri.encodeComponent(watchUrl);
        embedUrls = [
          'https://www.facebook.com/plugins/video.php?href=$encodedWatchUrl&show_text=false&t=0',
          'https://www.facebook.com/plugins/post.php?href=$encodedWatchUrl&show_text=true', 
          watchUrl
        ];
      } else if (platform == 'instagram' && reelId.isNotEmpty) {
        final isReel = url.contains('/reel/');
        embedUrls = [
          'https://www.instagram.com/${isReel ? 'reel' : 'p'}/$reelId/embed/',
          'https://www.instagram.com/p/$reelId/embed/',
          'https://www.instagram.com/reel/$reelId/embed/',
          url
        ];
      }
    }
    
    // Extract WebView settings
    Map<String, dynamic>? webviewSettings;
    if (metadata['webview_settings'] != null && metadata['webview_settings'] is Map) {
      webviewSettings = Map<String, dynamic>.from(metadata['webview_settings']);
    }
    
    // Create the platform-specific preview
    return Container(
      constraints: const BoxConstraints(maxHeight: 500),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        color: Colors.black,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SocialMediaWebView(
          platform: platform,
          url: embedUrls.isNotEmpty ? embedUrls.first : url,
          fallbackUrls: embedUrls.length > 1 ? embedUrls : null,
          settings: webviewSettings,
          reel_id: reelId,
          onTap: () {
            _launchURL(url);
          },
        ),
      ),
    );
  }
} 