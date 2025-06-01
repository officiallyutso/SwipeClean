import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:math' as math;

// Add this import
import 'full_screen_photo_viewer.dart';

class SwipeableCard extends StatefulWidget {
  final AssetEntity photo;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;

  const SwipeableCard({
    Key? key,
    required this.photo,
    required this.onSwipeLeft,
    required this.onSwipeRight,
  }) : super(key: key);

  @override
  _SwipeableCardState createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  double _swipeThreshold = 100.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.0,
    ).animate(_controller);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final swipeDistance = _dragOffset.dx.abs();
    final swipeVelocity = details.velocity.pixelsPerSecond.dx.abs();

    if (swipeDistance > _swipeThreshold || swipeVelocity > 1000) {
      if (_dragOffset.dx > 0) {
        _animateSwipeRight();
      } else {
        _animateSwipeLeft();
      }
    } else {
      _animateReset();
    }
  }

  void _animateSwipeLeft() {
    final screenWidth = MediaQuery.of(context).size.width;
    _offsetAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset(-screenWidth * 2, _dragOffset.dy),
    ).animate(_controller);

    _rotationAnimation = Tween<double>(
      begin: _getRotation(),
      end: -0.5,
    ).animate(_controller);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(_controller);

    _controller.forward().then((_) {
      widget.onSwipeLeft();
      _resetCard();
    });
  }

  void _animateSwipeRight() {
    final screenWidth = MediaQuery.of(context).size.width;
    _offsetAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset(screenWidth * 2, _dragOffset.dy),
    ).animate(_controller);

    _rotationAnimation = Tween<double>(
      begin: _getRotation(),
      end: 0.5,
    ).animate(_controller);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(_controller);

    _controller.forward().then((_) {
      widget.onSwipeRight();
      _resetCard();
    });
  }

  void _animateReset() {
    _offsetAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(_controller);

    _rotationAnimation = Tween<double>(
      begin: _getRotation(),
      end: 0.0,
    ).animate(_controller);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.0,
    ).animate(_controller);

    _controller.forward().then((_) {
      _resetCard();
    });
  }

  void _resetCard() {
    setState(() {
      _dragOffset = Offset.zero;
      _isDragging = false;
    });
    _controller.reset();
  }

  double _getRotation() {
    return _dragOffset.dx / 1000;
  }

  Color _getOverlayColor() {
    if (_dragOffset.dx > 50) {
      return Colors.green.withOpacity(math.min(0.7, _dragOffset.dx / 200));
    } else if (_dragOffset.dx < -50) {
      return Colors.red.withOpacity(math.min(0.7, _dragOffset.dx.abs() / 200));
    }
    return Colors.transparent;
  }

  IconData _getOverlayIcon() {
    if (_dragOffset.dx > 50) {
      return Icons.favorite;
    } else if (_dragOffset.dx < -50) {
      return Icons.close;
    }
    return Icons.help;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cardWidth = screenSize.width * 0.85;
    final cardHeight = screenSize.height * 0.65;

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final offset = _controller.isAnimating ? _offsetAnimation.value : _dragOffset;
          final rotation = _controller.isAnimating ? _rotationAnimation.value : _getRotation();
          final scale = _controller.isAnimating ? _scaleAnimation.value : 1.0;

          return Transform.translate(
            offset: offset,
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: cardWidth,
                  height: cardHeight,
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // ADD TAP DETECTION HERE
                          GestureDetector(
                            onTap: () {
                              if (!_isDragging && _dragOffset.dx.abs() < 10) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FullScreenPhotoViewer(photo: widget.photo),
                                  ),
                                );
                              }
                            },
                            child: FutureBuilder<Widget>(
                              future: _buildPhotoWidget(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return snapshot.data!;
                                }
                                return Container(
                                  color: Colors.grey[300],
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                            ),
                          ),
                          // Overlay for swipe feedback
                          if (_isDragging && (_dragOffset.dx.abs() > 50))
                            Container(
                              color: _getOverlayColor(),
                              child: Center(
                                child: Icon(
                                  _getOverlayIcon(),
                                  size: 100,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          // Photo info overlay
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.8),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FutureBuilder<String>(
                                    future: _getPhotoInfo(),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        return Text(
                                          snapshot.data!,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        );
                                      }
                                      return SizedBox.shrink();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<Widget> _buildPhotoWidget() async {
    try {
      final file = await widget.photo.file;
      if (file != null && await file.exists()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
        );
      } else {
        // Fallback to thumbnail
        final thumbnail = await widget.photo.thumbnailDataWithSize(
          ThumbnailSize(800, 800),
        );
        if (thumbnail != null) {
          return Image.memory(
            thumbnail,
            fit: BoxFit.cover,
          );
        }
      }
    } catch (e) {
      print('Error loading photo: $e');
    }

    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image,
              size: 64,
              color: Colors.grey[600],
            ),
            SizedBox(height: 8),
            Text(
              'Unable to load image',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  
  Future<String> _getPhotoInfo() async {
    try {
      final dateTime = widget.photo.createDateTime;
      
      // Get file size by loading the file
      String sizeText = '';
      try {
        final file = await widget.photo.file;
        if (file != null && await file.exists()) {
          final sizeInBytes = await file.length();
          final sizeInMB = (sizeInBytes / (1024 * 1024)).toStringAsFixed(1);
          sizeText = '${sizeInMB}MB';
        }
      } catch (e) {
        sizeText = 'Size unavailable';
      }
      
      return '${_formatDate(dateTime)} • $sizeText • ${widget.photo.width}x${widget.photo.height}';
    } catch (e) {
      return 'Photo information unavailable';
    }
  }

  String _formatDate(DateTime dateTime) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }
}