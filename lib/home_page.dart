import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_page.dart';
import 'profile_page.dart';
import 'pages/share_reel_page.dart';
import 'services/auth_service.dart';
import 'services/reel_service.dart';
import 'utils/constants.dart';
import 'widgets/reel_card.dart';
import 'models/reel.dart';
import 'models/category.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:developer' as developer;
import 'utils/debouncer.dart';

class HomePage extends StatefulWidget {
  final String userEmail;
  final String token;
  final String? initialSharedText;

  const HomePage({
    super.key,
    required this.userEmail,
    required this.token,
    this.initialSharedText,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  final _debouncer = Debouncer(milliseconds: 500);
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late ReelService _reelService;
  List<Reel> _reels = [];
  List<Category> _categories = [];
  List<Category> _selectedCategories = [];
  Set<String> _platforms = {};
  String? _selectedPlatform;
  DateTimeRange? _selectedDateRange;
  Category? _selectedCategory;
  bool _isLoadingCategories = false;
  
  bool _isLoading = true;
  bool _isFilterDebouncing = false;
  bool _isSearchActive = false;
  String? _error;

  // Styles definitions for reuse
  static const _chipLabelStyle = TextStyle(fontSize: 12);
  static const _errorTextStyle = TextStyle(color: Colors.red);
  static const _filterIconSize = 20.0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeService();
    
    // Handle initial shared text if present
    if (widget.initialSharedText != null && widget.initialSharedText!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSharedContent(widget.initialSharedText!);
      });
    }
  }

  Future<void> _initializeService() async {
    final prefs = await SharedPreferences.getInstance();
    _reelService = ReelService(token: widget.token, prefs: prefs);
    await _loadCategories();
    _loadReels();

    // Check for offline reels that need to be synced
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      await _reelService.syncPendingUploads();
    }
  }

  Future<void> _loadCategories() async {
    if (_isLoadingCategories) return;
    
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final List<Category> categories = await _reelService.getCategories();
      
      if (mounted) {
        setState(() {
          _categories = categories;
          // If we had a previously selected category, try to find its match in the new list
          if (_selectedCategory != null) {
            _selectedCategory = _categories.firstWhere(
              (c) => c.id == _selectedCategory!.id,
              orElse: () => _categories.isNotEmpty ? _categories.first : Category.all(),
            );
          } else {
            _selectedCategory = _categories.isNotEmpty ? _categories.first : Category.all();
          }
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
          // Set default categories in case of error
          _categories = [Category.all()];
          _selectedCategory = Category.all();
          debugPrint('Error loading categories: $e');
        });
      }
    }
  }

  void _loadReels({bool refresh = false}) {
    if (_isLoading && !refresh) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _reels = [];
      }
    });
    
    // Get selected category ID (if not "All")
    int? categoryId = _selectedCategory?.id == 0 ? null : _selectedCategory?.id;
    
    _reelService.getReels(categoryId: categoryId).then((reels) {
      if (mounted) {
        setState(() {
          _reels = reels;
          _isLoading = false;
        });
      }
    }).catchError((error) {
      debugPrint('Error loading reels: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _refreshReels() async {
    _loadReels(refresh: true);
  }

  Future<void> _deleteReel(int reelId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/api/reels/$reelId'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _reels.removeWhere((reel) => reel.id == reelId.toString());
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reel deleted successfully')),
          );
        }
      } else {
        throw Exception('Failed to delete reel');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting reel: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting reel: $e')),
        );
      }
    }
  }

  void _handleCategorySelected(Category category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
      _onFiltersChanged();
    });
  }

  void _handlePlatformSelected(String? platform) {
    setState(() {
      _selectedPlatform = platform;
      _onFiltersChanged();
    });
  }

  void _handleDateRangeSelected(DateTimeRange? dateRange) {
    setState(() {
      _selectedDateRange = dateRange;
      _onFiltersChanged();
    });
  }

  void _onFiltersChanged() {
    if (_isFilterDebouncing) return;

    setState(() {
      _isFilterDebouncing = true;
    });

    _debouncer.run(() {
      _loadReels();
      if (mounted) {
        setState(() {
          _isFilterDebouncing = false;
        });
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedCategories = [];
      _selectedPlatform = null;
      _selectedDateRange = null;
      _searchController.clear();
    });
    _loadReels();
  }

  Future<void> _handleSharedContent(String sharedText) async {
    if (sharedText.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShareReelPage(
          token: widget.token,
          initialUrl: sharedText,
          onSaved: () {
            _refreshReels();
          },
        ),
      ),
    );
  }

  Future<void> _openShareReel(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShareReelPage(
          token: widget.token,
          onSaved: () {
            _refreshReels();
          },
        ),
      ),
    );
  }

  Future<void> _openProfilePage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(
          userEmail: widget.userEmail,
          token: widget.token,
        ),
      ),
    );
  }

  Future<void> _performLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_email');
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error during logout: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Scaffold(
      appBar: AppBar(
        title: _isSearchActive
            ? TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search reels...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  _debouncer.run(() {
                    _loadReels();
                  });
                },
              )
            : const Text('My Reels'),
        actions: [
          IconButton(
            icon: Icon(_isSearchActive ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearchActive = !_isSearchActive;
                if (!_isSearchActive) {
                  _searchController.clear();
                  _loadReels();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: _openProfilePage,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _performLogout,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: RefreshIndicator(
              key: _refreshIndicatorKey,
              onRefresh: _refreshReels,
              child: _error != null
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_error', style: _errorTextStyle),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshReels,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
                : _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _reels.isEmpty
                    ? const Center(child: Text('No reels found. Try different filters or add a new reel.'))
                    : NotificationListener<ScrollNotification>(
                        onNotification: (ScrollNotification scrollInfo) {
                          // Implement lazy loading or pagination here if needed
                          return false;
                        },
                        child: GridView.builder(
                          key: const PageStorageKey<String>('reelsGrid'),
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: _reels.length,
                          cacheExtent: 1000, // Increase cache for smoother scrolling
                          itemBuilder: (context, index) {
                            final reel = _reels[index];
                            return RepaintBoundary(
                              child: _buildReelCard(reel, index),
                            );
                          },
                        ),
                      ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openShareReel(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildReelCard(Reel reel, int index) {
    // Using the key with ValueKey for efficient updates
    return ReelCard(
      key: ValueKey('reel-${reel.id}'),
      reel: reel,
      onDelete: () => _deleteReel(int.parse(reel.id)),
      // Pass 'true' only for a few visible items to improve performance
      showActions: true,
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Filters:', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (_selectedCategories.isNotEmpty || _selectedPlatform != null || _selectedDateRange != null)
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear All'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryFilters(),
                const SizedBox(width: 8),
                _buildPlatformFilters(),
                const SizedBox(width: 8),
                _buildDateFilter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: _categories.map<Widget>((Category category) {
        final isSelected = _selectedCategories.contains(category);
        return FilterChip(
          label: Text(category.name, style: _chipLabelStyle),
          selected: isSelected,
          onSelected: (_) => _handleCategorySelected(category),
          backgroundColor: Colors.grey[200],
          selectedColor: Colors.blue[100],
          checkmarkColor: const Color(0xFF2196F3),
        );
      }).toList(),
    );
  }

  Widget _buildPlatformFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: _platforms.map<Widget>((platform) {
        final isSelected = _selectedPlatform == platform;
        IconData? icon;
        Color? color;
        
        switch (platform.toLowerCase()) {
          case 'instagram':
            icon = Icons.camera_alt;
            color = const Color(0xFFE1306C);
            break;
          case 'facebook':
            icon = Icons.facebook;
            color = const Color(0xFF4267B2);
            break;
          case 'youtube':
            icon = Icons.play_circle_filled;
            color = const Color(0xFFFF0000);
            break;
          case 'tiktok':
            icon = Icons.music_video;
            color = Colors.black;
            break;
          default:
            icon = Icons.video_library;
            color = Colors.grey;
        }
        
        return FilterChip(
          avatar: Icon(icon, size: _filterIconSize, color: isSelected ? Colors.white : color),
          label: Text(platform, style: _chipLabelStyle),
          selected: isSelected,
          onSelected: (_) => _handlePlatformSelected(isSelected ? null : platform),
          backgroundColor: Colors.grey[200],
          selectedColor: color.withOpacity(0.7),
          showCheckmark: false,
        );
      }).toList(),
    );
  }

  Widget _buildDateFilter() {
    return ActionChip(
      avatar: const Icon(Icons.calendar_today, size: _filterIconSize),
      label: Text(
        _selectedDateRange != null
            ? '${_selectedDateRange!.start.month}/${_selectedDateRange!.start.day} - ${_selectedDateRange!.end.month}/${_selectedDateRange!.end.day}'
            : 'Date Range',
        style: _chipLabelStyle,
      ),
      backgroundColor: _selectedDateRange != null ? Colors.blue[100] : Colors.grey[200],
      onPressed: () async {
        final DateTimeRange? result = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDateRange: _selectedDateRange ?? DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          ),
        );
        
        if (result != null) {
          _handleDateRangeSelected(result);
        }
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.dispose();
    _scrollController.dispose();
    super.dispose();
  }
} 