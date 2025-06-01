import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/photo_service.dart';
import '../widgets/swipeable_card.dart';

class PhotoSwipeScreen extends StatefulWidget {
  @override
  _PhotoSwipeScreenState createState() => _PhotoSwipeScreenState();
}

class _PhotoSwipeScreenState extends State<PhotoSwipeScreen>
    with TickerProviderStateMixin {
  final PhotoService _photoService = PhotoService();
  List<AssetEntity> _photos = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  int _keptCount = 0;
  int _trashedCount = 0;

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    _loadPhotos();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    try {
      final photos = await _photoService.getAllPhotos();
      final trashedIds = await _photoService.getTrashedPhotoIds();
      
      setState(() {
        _photos = photos.where((photo) => !trashedIds.contains(photo.id)).toList();
        _isLoading = false;
      });
      
      _updateProgress();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading photos: $e')),
      );
    }
  }

  void _updateProgress() {
    if (_photos.isNotEmpty) {
      _progressController.animateTo(_currentIndex / _photos.length);
    }
  }

  void _onSwipeLeft() async {
    if (_currentIndex < _photos.length) {
      await _photoService.moveToTrash(_photos[_currentIndex]);
      setState(() {
        _trashedCount++;
        _currentIndex++;
      });
      _updateProgress();
      _showFeedback('Moved to trash', Colors.red, Icons.delete);
    }
  }

  void _onSwipeRight() {
    if (_currentIndex < _photos.length) {
      setState(() {
        _keptCount++;
        _currentIndex++;
      });
      _updateProgress();
      _showFeedback('Photo kept', Colors.green, Icons.favorite);
    }
  }

  void _showFeedback(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: color,
        duration: Duration(milliseconds: 800),
      ),
    );
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('🎉 All Done!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('You\'ve reviewed all your photos!'),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Icon(Icons.favorite, color: Colors.green, size: 32),
                    SizedBox(height: 4),
                    Text('$_keptCount kept'),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 32),
                    SizedBox(height: 4),
                    Text('$_trashedCount trashed'),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Loading Photos...'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your photos...'),
            ],
          ),
        ),
      );
    }

    if (_photos.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('No Photos'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No photos to review',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                'All photos have been processed or none are available',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentIndex >= _photos.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCompletionDialog();
      });
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('SwipeClean'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(4.0),
          child: AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: _progressAnimation.value,
                backgroundColor: Colors.blue[100],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              );
            },
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_currentIndex + 1} of ${_photos.length}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.favorite, color: Colors.green, size: 16),
                    Text(' $_keptCount  '),
                    Icon(Icons.delete, color: Colors.red, size: 16),
                    Text(' $_trashedCount'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SwipeableCard(
                photo: _photos[_currentIndex],
                onSwipeLeft: _onSwipeLeft,
                onSwipeRight: _onSwipeRight,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  onPressed: _onSwipeLeft,
                  backgroundColor: Colors.red,
                  heroTag: "delete",
                  child: Icon(Icons.close, color: Colors.white),
                ),
                FloatingActionButton(
                  onPressed: _onSwipeRight,
                  backgroundColor: Colors.green,
                  heroTag: "keep",
                  child: Icon(Icons.favorite, color: Colors.white),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            child: Text(
              'Swipe left to delete • Swipe right to keep',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}