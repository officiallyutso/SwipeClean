import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:typed_data';
import 'dart:io';
import '../services/photo_service.dart';

class GalleryScreen extends StatefulWidget {
  @override
  _GalleryScreenState createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final PhotoService _photoService = PhotoService();
  Map<String, List<AssetEntity>> _albumPhotos = {};
  bool _isLoading = true;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get all albums instead of individual photos
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: false,
      );
      
      final albumMap = <String, List<AssetEntity>>{};
      
      // Get photos from each album
      for (var album in albums) {
        final assetCount = await album.assetCountAsync;
        final photos = await album.getAssetListRange(start: 0, end: assetCount);
        if (photos.isNotEmpty) {
          albumMap[album.name] = photos;
        }
      }
      
      setState(() {
        _albumPhotos = albumMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deletePhoto(AssetEntity photo, String albumName) async {
    bool? confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Delete Photo'),
        content: Text('Are you sure you want to move this photo to trash?'),
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
      await _photoService.moveToTrash(photo);
      setState(() {
        _albumPhotos[albumName]?.remove(photo);
        if (_albumPhotos[albumName]?.isEmpty == true) {
          _albumPhotos.remove(albumName);
        }
      });
    }
  }

  void _viewPhoto(AssetEntity photo, String albumName) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => PhotoViewScreen(
          photo: photo,
          onDelete: () => _deletePhoto(photo, albumName),
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
          'Photo Library',
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
                  if (_albumPhotos.isEmpty)
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
                    ..._albumPhotos.entries.map((entry) {
                      return SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _buildAlbumSection(entry.key, entry.value),
                          ]),
                        ),
                      );
                    }).toList(),
                ],
              ),
      ),
    );
  }

  Widget _buildAlbumSection(String albumName, List<AssetEntity> photos) {
    return Container(
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
                Text(
                  '${photos.length} photos',
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel,
            decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          _isGridView
              ? _buildPhotoGrid(photos, albumName)
              : _buildPhotoList(photos, albumName),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(List<AssetEntity> photos, String albumName) {
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          final photo = photos[index];
          return GestureDetector(
            onTap: () => _viewPhoto(photo, albumName),
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
      ),
    );
  }

  Widget _buildPhotoList(List<AssetEntity> photos, String albumName) {
    return Column(
      children: photos.map((photo) {
        return Container(
          margin: EdgeInsets.only(left: 16, right: 16, bottom: 8),
          child: GestureDetector(
            onTap: () => _viewPhoto(photo, albumName),
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
                    onPressed: () => _deletePhoto(photo, albumName),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
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
          onPressed: () {
            onDelete();
            Navigator.pop(context);
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