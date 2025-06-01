import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/photo_service.dart';

class TrashBinScreen extends StatefulWidget {
  @override
  _TrashBinScreenState createState() => _TrashBinScreenState();
}

class _TrashBinScreenState extends State<TrashBinScreen> {
  final PhotoService _photoService = PhotoService();
  List<AssetEntity> _trashedPhotos = [];
  Set<String> _selectedPhotos = Set<String>();
  bool _isLoading = true;
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadTrashedPhotos();
  }

  Future<void> _loadTrashedPhotos() async {
    try {
      final photos = await _photoService.getTrashedPhotos();
      setState(() {
        _trashedPhotos = photos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading trash: $e')),
      );
    }
  }

  Future<void> _restorePhoto(AssetEntity photo) async {
    await _photoService.restoreFromTrash(photo);
    await _loadTrashedPhotos();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Photo restored'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _permanentlyDeletePhoto(AssetEntity photo) async {
    final confirmed = await _showDeleteConfirmation(single: true);
    if (confirmed) {
      try {
        await _photoService.permanentlyDeletePhoto(photo);
        await _loadTrashedPhotos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo permanently deleted'),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting photo: $e')),
        );
      }
    }
  }

  Future<void> _emptyTrash() async {
    if (_trashedPhotos.isEmpty) return;
    
    final confirmed = await _showDeleteConfirmation(single: false);
    if (confirmed) {
      try {
        for (final photo in _trashedPhotos) {
          await _photoService.permanentlyDeletePhoto(photo);
        }
        await _loadTrashedPhotos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trash emptied successfully'),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error emptying trash: $e')),
        );
      }
    }
  }

  Future<void> _deleteSelectedPhotos() async {
    if (_selectedPhotos.isEmpty) return;
    
    final confirmed = await _showDeleteConfirmation(single: false);
    if (confirmed) {
      try {
        final photosToDelete = _trashedPhotos
            .where((photo) => _selectedPhotos.contains(photo.id))
            .toList();
        
        for (final photo in photosToDelete) {
          await _photoService.permanentlyDeletePhoto(photo);
        }
        
        setState(() {
          _selectedPhotos.clear();
          _isSelectionMode = false;
        });
        
        await _loadTrashedPhotos();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected photos deleted permanently'),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting photos: $e')),
        );
      }
    }
  }

  Future<bool> _showDeleteConfirmation({required bool single}) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permanent Deletion'),
        content: Text(
          single
              ? 'This photo will be permanently deleted and cannot be recovered. Continue?'
              : 'These photos will be permanently deleted and cannot be recovered. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _toggleSelection(String photoId) {
    setState(() {
      if (_selectedPhotos.contains(photoId)) {
        _selectedPhotos.remove(photoId);
      } else {
        _selectedPhotos.add(photoId);
      }
      
      if (_selectedPhotos.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedPhotos.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode ? '${_selectedPhotos.length} selected' : 'Trash Bin'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              onPressed: _deleteSelectedPhotos,
              icon: Icon(Icons.delete_forever),
            ),
            IconButton(
              onPressed: _exitSelectionMode,
              icon: Icon(Icons.close),
            ),
          ] else ...[
            if (_trashedPhotos.isNotEmpty)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'empty') {
                    _emptyTrash();
                  } else if (value == 'select') {
                    _enterSelectionMode();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'select',
                    child: Row(
                      children: [
                        Icon(Icons.select_all),
                        SizedBox(width: 8),
                        Text('Select Photos'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'empty',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Empty Trash', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _trashedPhotos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Trash is empty',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Photos you delete will appear here',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: EdgeInsets.all(8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _trashedPhotos.length,
                  itemBuilder: (context, index) {
                    final photo = _trashedPhotos[index];
                    final isSelected = _selectedPhotos.contains(photo.id);
                    
                    return GestureDetector(
                      onTap: () {
                        if (_isSelectionMode) {
                          _toggleSelection(photo.id);
                        } else {
                          _showPhotoOptions(photo);
                        }
                      },
                      onLongPress: () {
                        if (!_isSelectionMode) {
                          _enterSelectionMode();
                          _toggleSelection(photo.id);
                        }
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: isSelected
                                  ? Border.all(color: Colors.blue, width: 3)
                                  : null,
                            ),
                            child: FutureBuilder<Widget>(
                              future: _buildPhotoThumbnail(photo),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  return snapshot.data!;
                                }
                                return Container(
                                  color: Colors.grey[300],
                                  child: Icon(
                                    Icons.image,
                                    color: Colors.grey[600],
                                  ),
                                );
                              },
                            ),
                          ),
                          if (_isSelectionMode)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.blue : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? Colors.blue : Colors.grey,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.check,
                                  size: 16,
                                  color: isSelected ? Colors.white : Colors.transparent,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Future<Widget> _buildPhotoThumbnail(AssetEntity photo) async {
    final thumbnail = await photo.thumbnailDataWithSize(
      ThumbnailSize(200, 200),
    );
    
    if (thumbnail != null) {
      return Image.memory(
        thumbnail,
        fit: BoxFit.cover,
      );
    }
    
    return Container(
      color: Colors.grey[300],
      child: Icon(
        Icons.image,
        color: Colors.grey[600],
      ),
    );
  }

  void _showPhotoOptions(AssetEntity photo) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.restore, color: Colors.green),
            title: Text('Restore Photo'),
            onTap: () {
              Navigator.pop(context);
              _restorePhoto(photo);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red),
            title: Text('Delete Permanently'),
            onTap: () {
              Navigator.pop(context);
              _permanentlyDeletePhoto(photo);
            },
          ),
          ListTile(
            leading: Icon(Icons.cancel),
            title: Text('Cancel'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}