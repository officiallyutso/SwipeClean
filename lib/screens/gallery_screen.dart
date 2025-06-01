import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:swipeclean/screens/photo_swipe_screen.dart';
import 'dart:typed_data';
import 'dart:io';
import '../services/photo_service.dart';

class GalleryScreen extends StatefulWidget {
  @override
  _GalleryScreenState createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final PhotoService _photoService = PhotoService();
  Map<String, List<AssetEntity>> _albumPreviews = {};
  Map<String, int> _albumCounts = {};
  bool _isLoading = true;
  bool _isGridView = true;
  final int _previewLimit = 10; // Show only 10 photos per album preview

  @override
  void initState() {
    super.initState();
    _loadAlbumPreviews();
  }

  Future<void> _loadAlbumPreviews() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: false,
      );
      
      final albumPreviewMap = <String, List<AssetEntity>>{};
      final albumCountMap = <String, int>{};
      
      for (var album in albums) {
        final assetCount = await album.assetCountAsync;
        if (assetCount > 0) {
          // Get only preview photos (limit to _previewLimit)
          final previewCount = assetCount > _previewLimit ? _previewLimit : assetCount;
          final previewPhotos = await album.getAssetListRange(start: 0, end: previewCount);
          
          albumPreviewMap[album.name] = previewPhotos;
          albumCountMap[album.name] = assetCount;
        }
      }
      
      setState(() {
        _albumPreviews = albumPreviewMap;
        _albumCounts = albumCountMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _viewAlbum(String albumName) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => AlbumViewScreen(
          albumName: albumName,
          photoService: _photoService,
        ),
      ),
    ).then((_) {
      // Refresh previews when returning from album view
      _loadAlbumPreviews();
    });
  }

  void _swipeAlbum(String albumName) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => PhotoSwipeScreen(
          albumName: albumName, // Pass the album name
        ),
      ),
    ).then((_) {
      // Refresh previews when returning from swipe screen
      _loadAlbumPreviews();
    });
  }

  void _showAlbumOptions(String albumName) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(
          albumName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        message: Text(
          '${_albumCounts[albumName]} photos',
          style: TextStyle(
            fontSize: 14,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _viewAlbum(albumName);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo_on_rectangle, color: CupertinoColors.systemBlue),
                SizedBox(width: 8),
                Text('View Album'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _swipeAlbum(albumName);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.hand_draw, color: CupertinoColors.systemBlue),
                SizedBox(width: 8),
                Text('Swipe Album to Clean'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDefaultAction: true,
          child: Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground.withOpacity(0.9),
        border: Border(),
        leading: CupertinoNavigationBarBackButton(
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(
          'Photo Albums',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
            color: CupertinoColors.label,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(
            _isGridView ? CupertinoIcons.list_bullet : CupertinoIcons.square_grid_2x2,
            color: CupertinoColors.systemBlue,
          ),
          onPressed: () {
            setState(() {
              _isGridView = !_isGridView;
            });
          },
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? Center(
                child: CupertinoActivityIndicator(radius: 20),
              )
            : CustomScrollView(
                physics: BouncingScrollPhysics(),
                slivers: [
                  if (_albumPreviews.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.photo,
                              size: 64,
                              color: CupertinoColors.systemGrey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No Photos Found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.none,
                                color: CupertinoColors.secondaryLabel,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._albumPreviews.entries.map((entry) {
                      return SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildAlbumPreview(entry.key, entry.value),
                          ]),
                        ),
                      );
                    }).toList(),
                ],
              ),
      ),
    );
  }

  Widget _buildAlbumPreview(String albumName, List<AssetEntity> previewPhotos) {
    final totalCount = _albumCounts[albumName] ?? previewPhotos.length;
    final hasMore = totalCount > _previewLimit;
    
    return GestureDetector(
      onTap: () => _showAlbumOptions(albumName), // Show options instead of direct navigation
      child: Container(
        margin: EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      albumName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '$totalCount photos',
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.secondaryLabel,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                        color: CupertinoColors.systemGrey,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _isGridView
                ? _buildPhotoPreviewGrid(previewPhotos, hasMore)
                : _buildPhotoPreviewList(previewPhotos, hasMore),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPreviewGrid(List<AssetEntity> photos, bool hasMore) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: photos.length > 6 ? 6 : photos.length, // Show max 6 in preview
            itemBuilder: (context, index) {
              final photo = photos[index];
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: CupertinoColors.systemGrey6,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: FutureBuilder<Uint8List?>(
                    future: photo.thumbnailDataWithSize(ThumbnailSize(200, 200)),
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data != null) {
                        return Image.memory(
                          snapshot.data!,
                          fit: BoxFit.cover,
                        );
                      }
                      return Container(
                        color: CupertinoColors.systemGrey5,
                        child: Icon(
                          CupertinoIcons.photo,
                          color: CupertinoColors.systemGrey,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          if (hasMore)
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Tap to view options',
                style: TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.systemBlue,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreviewList(List<AssetEntity> photos, bool hasMore) {
    final displayPhotos = photos.take(3).toList(); // Show max 3 in list preview
    
    return Column(
      children: [
        ...displayPhotos.map((photo) {
          return Container(
            margin: EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: CupertinoColors.systemGrey5,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: FutureBuilder<Uint8List?>(
                        future: photo.thumbnailDataWithSize(ThumbnailSize(120, 120)),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            return Image.memory(
                              snapshot.data!,
                              fit: BoxFit.cover,
                            );
                          }
                          return Icon(
                            CupertinoIcons.photo,
                            color: CupertinoColors.systemGrey,
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          photo.title ?? 'Photo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: CupertinoColors.label,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _formatDate(photo.createDateTime),
                          style: TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.secondaryLabel,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        SizedBox(height: 2),
                        FutureBuilder<String>(
                          future: _getImageSize(photo),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Text(
                                snapshot.data!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: CupertinoColors.secondaryLabel,
                                  decoration: TextDecoration.none,
                                ),
                              );
                            }
                            return Text(
                              'Calculating size...',
                              style: TextStyle(
                                fontSize: 12,
                                color: CupertinoColors.secondaryLabel,
                                decoration: TextDecoration.none,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        if (hasMore)
          Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Tap to view options',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.systemBlue,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<String> _getImageSize(AssetEntity photo) async {
    try {
      final file = await photo.file;
      if (file != null) {
        final bytes = await file.length();
        return _formatFileSize(bytes);
      }
      return 'Size unknown';
    } catch (e) {
      return 'Size unknown';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}

// Keep the existing AlbumViewScreen and PhotoViewScreen classes unchanged...

// New Album View Screen
class AlbumViewScreen extends StatefulWidget {
  final String albumName;
  final PhotoService photoService;

  const AlbumViewScreen({
    Key? key,
    required this.albumName,
    required this.photoService,
  }) : super(key: key);

  @override
  _AlbumViewScreenState createState() => _AlbumViewScreenState();
}

class _AlbumViewScreenState extends State<AlbumViewScreen> {
  List<AssetEntity> _photos = [];
  bool _isLoading = true;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _loadAlbumPhotos();
  }

  Future<void> _loadAlbumPhotos() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: false,
      );
      
      final album = albums.firstWhere((album) => album.name == widget.albumName);
      final assetCount = await album.assetCountAsync;
      final photos = await album.getAssetListRange(start: 0, end: assetCount);
      
      setState(() {
        _photos = photos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePhoto(AssetEntity photo) async {
    bool? confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Delete Photo'),
        content: Text('Are you sure you want to permanently delete this photo? This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Correct way to delete photos using PhotoManager.editor
        final List<String> result = await PhotoManager.editor.deleteWithIds([photo.id]);
        
        if (result.contains(photo.id)) {
          // Photo was successfully deleted
          setState(() {
            _photos.remove(photo);
          });
          
          // Show success message
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: Text('Success'),
              content: Text('Photo deleted successfully.'),
              actions: [
                CupertinoDialogAction(
                  child: Text('OK'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        } else {
          // Deletion failed
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: Text('Error'),
              content: Text('Failed to delete photo. Please try again.'),
              actions: [
                CupertinoDialogAction(
                  child: Text('OK'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        // Handle error
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text('Error'),
            content: Text('An error occurred while deleting the photo: ${e.toString()}'),
            actions: [
              CupertinoDialogAction(
                child: Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  void _viewPhoto(AssetEntity photo) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => PhotoViewScreen(
          photo: photo,
          onDelete: () => _deletePhoto(photo),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground.withOpacity(0.9),
        border: Border(),
        leading: CupertinoNavigationBarBackButton(
          onPressed: () => Navigator.pop(context),
        ),
        middle: Text(
          widget.albumName,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
            color: CupertinoColors.label,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(
            _isGridView ? CupertinoIcons.list_bullet : CupertinoIcons.square_grid_2x2,
            color: CupertinoColors.systemBlue,
          ),
          onPressed: () {
            setState(() {
              _isGridView = !_isGridView;
            });
          },
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? Center(child: CupertinoActivityIndicator(radius: 20))
            : _photos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.photo,
                          size: 64,
                          color: CupertinoColors.systemGrey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No Photos in Album',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.all(16),
                    child: _isGridView
                        ? _buildPhotoGrid()
                        : _buildPhotoList(),
                  ),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return GridView.builder(
      physics: BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        final photo = _photos[index];
        return GestureDetector(
          onTap: () => _viewPhoto(photo),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: CupertinoColors.systemGrey6,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FutureBuilder<Uint8List?>(
                future: photo.thumbnailDataWithSize(ThumbnailSize(200, 200)),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return Image.memory(
                      snapshot.data!,
                      fit: BoxFit.cover,
                    );
                  }
                  return Container(
                    color: CupertinoColors.systemGrey5,
                    child: Icon(
                      CupertinoIcons.photo,
                      color: CupertinoColors.systemGrey,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotoList() {
    return ListView.builder(
      physics: BouncingScrollPhysics(),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        final photo = _photos[index];
        return Container(
          margin: EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => _viewPhoto(photo),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.systemGrey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: CupertinoColors.systemGrey5,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: FutureBuilder<Uint8List?>(
                        future: photo.thumbnailDataWithSize(ThumbnailSize(120, 120)),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            return Image.memory(
                              snapshot.data!,
                              fit: BoxFit.cover,
                            );
                          }
                          return Icon(
                            CupertinoIcons.photo,
                            color: CupertinoColors.systemGrey,
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          photo.title ?? 'Photo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: CupertinoColors.label,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _formatDate(photo.createDateTime),
                          style: TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.secondaryLabel,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Icon(
                      CupertinoIcons.delete,
                      color: CupertinoColors.systemRed,
                      size: 20,
                    ),
                    onPressed: () => _deletePhoto(photo),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class PhotoViewScreen extends StatelessWidget {
  final AssetEntity photo;
  final VoidCallback onDelete;

  const PhotoViewScreen({
    Key? key,
    required this.photo,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black.withOpacity(0.8),
        border: Border(),
        leading: CupertinoNavigationBarBackButton(
          color: CupertinoColors.white,
          onPressed: () => Navigator.pop(context),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(
            CupertinoIcons.delete,
            color: CupertinoColors.systemRed,
          ),
          onPressed: () async {
            bool? confirm = await showCupertinoDialog<bool>(
              context: context,
              builder: (context) => CupertinoAlertDialog(
                title: Text('Delete Photo'),
                content: Text('Are you sure you want to permanently delete this photo? This action cannot be undone.'),
                actions: [
                  CupertinoDialogAction(
                    child: Text('Cancel'),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    child: Text('Delete'),
                    onPressed: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              try {
                // Correct way to delete photos using PhotoManager.editor
                final List<String> result = await PhotoManager.editor.deleteWithIds([photo.id]);
                
                if (result.contains(photo.id)) {
                  onDelete();
                  Navigator.pop(context);
                } else {
                  showCupertinoDialog(
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: Text('Error'),
                      content: Text('Failed to delete photo. Please try again.'),
                      actions: [
                        CupertinoDialogAction(
                          child: Text('OK'),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                showCupertinoDialog(
                  context: context,
                  builder: (context) => CupertinoAlertDialog(
                    title: Text('Error'),
                    content: Text('An error occurred: ${e.toString()}'),
                    actions: [
                      CupertinoDialogAction(
                        child: Text('OK'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                );
              }
            }
          },
        ),
      ),
      child: SafeArea(
        child: Center(
          child: InteractiveViewer(
            child: FutureBuilder<File?>(
              future: photo.file,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Image.file(
                    snapshot.data!,
                    fit: BoxFit.contain,
                  );
                }
                return Container(
                  width: 200,
                  height: 200,
                  color: CupertinoColors.systemGrey5,
                  child: Icon(
                    CupertinoIcons.photo,
                    size: 64,
                    color: CupertinoColors.systemGrey,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}