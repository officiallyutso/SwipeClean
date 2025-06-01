import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/photo_service.dart';

class TrashBinScreen extends StatefulWidget {
  @override
  _TrashBinScreenState createState() => _TrashBinScreenState();
}

class _TrashBinScreenState extends State<TrashBinScreen> with TickerProviderStateMixin {
  final PhotoService _photoService = PhotoService();
  List<AssetEntity> _trashedPhotos = [];
  Map<String, int> _photoSizes = {}; // Store photo sizes in bytes
  Set<String> _selectedPhotos = Set<String>();
  bool _isLoading = true;
  bool _isSelectionMode = false;
  bool _isCalculatingSize = false;
  int _totalTrashSize = 0; // Total size in bytes
  late AnimationController _fabAnimationController;
  late AnimationController _selectionAnimationController;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _selectionAnimationController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    _loadTrashedPhotos();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _selectionAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadTrashedPhotos() async {
    try {
      await _photoService.cleanupTrashedPhotos();
      final photos = await _photoService.getTrashedPhotos();
      setState(() {
        _trashedPhotos = photos;
        _isLoading = false;
      });
      
      if (_trashedPhotos.isNotEmpty) {
        _fabAnimationController.forward();
        await _calculatePhotoSizes();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error loading trash: $e');
    }
  }

  Future<void> _calculatePhotoSizes() async {
    setState(() {
      _isCalculatingSize = true;
    });

    try {
      Map<String, int> sizes = {};
      int totalSize = 0;

      for (AssetEntity photo in _trashedPhotos) {
        try {
          final file = await photo.file;
          if (file != null) {
            final size = await file.length();
            sizes[photo.id] = size;
            totalSize += size;
          } else {
            // // Fallback: use size property if available
            // sizes[photo.id] = photo.size ?? 0;
            // totalSize += photo.size ?? 0;
          }
        } catch (e) {
          print('Error getting size for photo ${photo.id}: $e');
          sizes[photo.id] = 0;
        }
      }

      setState(() {
        _photoSizes = sizes;
        _totalTrashSize = totalSize;
        _isCalculatingSize = false;
      });
    } catch (e) {
      setState(() {
        _isCalculatingSize = false;
      });
      print('Error calculating photo sizes: $e');
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  int _getSelectedPhotosSize() {
    int selectedSize = 0;
    for (String photoId in _selectedPhotos) {
      selectedSize += _photoSizes[photoId] ?? 0;
    }
    return selectedSize;
  }

  Future<void> _restorePhoto(AssetEntity photo) async {
    await _photoService.restoreFromTrash(photo);
    await _loadTrashedPhotos();
    _showSuccessSnackBar('Photo restored successfully');
  }

  Future<void> _permanentlyDeletePhoto(AssetEntity photo) async {
    final confirmed = await _showDeleteConfirmation(single: true);
    if (confirmed) {
      _showLoadingDialog('Deleting photo...');

      try {
        final result = await _photoService.permanentlyDeletePhotoWithStatus(photo);
        Navigator.of(context).pop();
        await _loadTrashedPhotos();
        
        if (result['success']) {
          _showSuccessSnackBar(result['message']);
        } else {
          _showWarningSnackBar(result['message']);
        }
      } catch (e) {
        Navigator.of(context).pop();
        _showErrorSnackBar('Error deleting photo: $e');
      }
    }
  }

  Future<void> _emptyTrash() async {
    if (_trashedPhotos.isEmpty) return;
    
    final confirmed = await _showDeleteConfirmation(single: false);
    if (confirmed) {
      _showProgressDialog('Emptying trash...', 'This may take a while');

      int deletedCount = 0;
      int failedCount = 0;
      
      try {
        for (final photo in _trashedPhotos) {
          try {
            final result = await _photoService.permanentlyDeletePhotoWithStatus(photo);
            if (result['success']) {
              deletedCount++;
            } else {
              failedCount++;
            }
          } catch (e) {
            failedCount++;
          }
        }
        
        Navigator.of(context).pop();
        await _loadTrashedPhotos();
        
        if (failedCount == 0) {
          _showSuccessSnackBar('Trash emptied successfully ($deletedCount photos)');
        } else if (deletedCount == 0) {
          _showErrorSnackBar('Failed to delete photos ($failedCount failed)');
        } else {
          _showWarningSnackBar('Partially completed ($deletedCount deleted, $failedCount failed)');
        }
      } catch (e) {
        Navigator.of(context).pop();
        _showErrorSnackBar('Error emptying trash: $e');
      }
    }
  }

  Future<void> _deleteSelectedPhotos() async {
    if (_selectedPhotos.isEmpty) return;
    
    final confirmed = await _showDeleteConfirmation(single: false);
    if (confirmed) {
      _showProgressDialog('Deleting selected photos...', null);

      int deletedCount = 0;
      int failedCount = 0;
      
      try {
        final photosToDelete = _trashedPhotos
            .where((photo) => _selectedPhotos.contains(photo.id))
            .toList();
        
        for (final photo in photosToDelete) {
          try {
            final result = await _photoService.permanentlyDeletePhotoWithStatus(photo);
            if (result['success']) {
              deletedCount++;
            } else {
              failedCount++;
            }
          } catch (e) {
            failedCount++;
          }
        }
        
        _exitSelectionMode();
        Navigator.of(context).pop();
        await _loadTrashedPhotos();
        
        if (failedCount == 0) {
          _showSuccessSnackBar('Selected photos deleted ($deletedCount photos)');
        } else if (deletedCount == 0) {
          _showErrorSnackBar('Failed to delete selected photos');
        } else {
          _showWarningSnackBar('Partially completed ($deletedCount deleted, $failedCount failed)');
        }
      } catch (e) {
        Navigator.of(context).pop();
        _showErrorSnackBar('Error deleting photos: $e');
      }
    }
  }

  void _showLoadingDialog(String message) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(radius: 12),
            SizedBox(height: 16),
            Text(message, style: TextStyle(fontSize: 16, decoration: TextDecoration.none)),
          ],
        ),
      ),
    );
  }

  void _showProgressDialog(String title, String? subtitle) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(radius: 12),
            SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
            if (subtitle != null) ...[
              SizedBox(height: 8),
              Text(subtitle, style: TextStyle(fontSize: 14, color: CupertinoColors.secondaryLabel, decoration: TextDecoration.none)),
            ],
          ],
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation({required bool single}) async {
    final sizeToFree = single 
        ? (_selectedPhotos.isNotEmpty ? _getSelectedPhotosSize() : 0)
        : (_isSelectionMode ? _getSelectedPhotosSize() : _totalTrashSize);
    
    return await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Permanent Deletion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8),
            Text(
              single
                  ? 'This photo will be permanently deleted and cannot be recovered.'
                  : 'These photos will be permanently deleted and cannot be recovered.',
              style: TextStyle(fontSize: 14, decoration: TextDecoration.none),
            ),
            if (sizeToFree > 0) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(CupertinoIcons.arrow_up_circle, 
                         color: CupertinoColors.systemGreen, size: 20),
                    SizedBox(height: 4),
                    Text(
                      'Storage to be freed: ${_formatFileSize(sizeToFree)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.systemGreen,
                        decoration: TextDecoration.none
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemYellow.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Note: Some photos may not be deletable due to system restrictions, but will be removed from your trash.',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                  decoration: TextDecoration.none
                ),
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(true),
            isDestructiveAction: true,
            child: Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(CupertinoIcons.check_mark_circled_solid, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: CupertinoColors.systemGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: CupertinoColors.systemRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(CupertinoIcons.exclamationmark_triangle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: CupertinoColors.systemOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _toggleSelection(String photoId) {
    setState(() {
      if (_selectedPhotos.contains(photoId)) {
        _selectedPhotos.remove(photoId);
      } else {
        _selectedPhotos.add(photoId);
      }
      
      if (_selectedPhotos.isEmpty) {
        _exitSelectionMode();
      }
    });
  }

  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
    });
    _selectionAnimationController.forward();
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedPhotos.clear();
    });
    _selectionAnimationController.reverse();
  }

  Future<void> _cleanupTrash() async {
    _showLoadingDialog('Cleaning up trash...');

    try {
      await _photoService.cleanupTrashedPhotos();
      Navigator.of(context).pop();
      await _loadTrashedPhotos();
      _showSuccessSnackBar('Trash cleaned up successfully');
    } catch (e) {
      Navigator.of(context).pop();
      _showErrorSnackBar('Error cleaning up trash: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: _isSelectionMode 
            ? CupertinoColors.systemBlue.withOpacity(0.8)
            : CupertinoColors.systemRed.withOpacity(0.8),
        middle: Text(
          _isSelectionMode 
              ? '${_selectedPhotos.length} Selected'
              : 'Trash Bin',
          style: TextStyle(
            color: CupertinoColors.black,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none
          ),
        ),
        leading: _isSelectionMode
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _exitSelectionMode,
                child: Icon(
                  CupertinoIcons.clear,
                  color: CupertinoColors.black,
                ),
              )
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
                child: Icon(
                  CupertinoIcons.back,
                  color: CupertinoColors.black,
                ),
              ),
        trailing: _isSelectionMode
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _selectedPhotos.isEmpty ? null : _deleteSelectedPhotos,
                child: Icon(
                  CupertinoIcons.delete,
                  color: _selectedPhotos.isEmpty 
                      ? CupertinoColors.black.withOpacity(0.4)
                      : CupertinoColors.black,
                ),
              )
            : _trashedPhotos.isNotEmpty
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _showActionSheet(),
                    child: Icon(
                      CupertinoIcons.ellipsis_circle,
                      color: CupertinoColors.black,
                    ),
                  )
                : null,
      ),
      child: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoActivityIndicator(radius: 20),
                    SizedBox(height: 16),
                    Text(
                      'Loading trash...',
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel,
                        fontSize: 16,
                        decoration: TextDecoration.none
                      ),
                    ),
                  ],
                ),
              )
            : _trashedPhotos.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: [
                      _buildStorageInfo(),
                      Expanded(child: _buildPhotoGrid()),
                    ],
                  ),
      ),
    );
  }

  Widget _buildStorageInfo() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isSelectionMode 
                      ? CupertinoColors.systemBlue.withOpacity(0.1)
                      : CupertinoColors.systemRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _isSelectionMode 
                      ? CupertinoIcons.selection_pin_in_out
                      : CupertinoIcons.delete,
                  color: _isSelectionMode 
                      ? CupertinoColors.systemBlue
                      : CupertinoColors.systemRed,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSelectionMode
                          ? '${_selectedPhotos.length} photos selected'
                          : '${_trashedPhotos.length} photos in trash',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label,
                        decoration: TextDecoration.none
                      ),
                    ),
                    SizedBox(height: 2),
                    if (_isCalculatingSize)
                      Row(
                        children: [
                          CupertinoActivityIndicator(radius: 8),
                          SizedBox(width: 8),
                          Text(
                            'Calculating size...',
                            style: TextStyle(
                              fontSize: 14,
                              color: CupertinoColors.secondaryLabel,
                              decoration: TextDecoration.none
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        _isSelectionMode
                            ? 'Storage to free: ${_formatFileSize(_getSelectedPhotosSize())}'
                            : 'Total size: ${_formatFileSize(_totalTrashSize)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: _isSelectionMode
                              ? CupertinoColors.systemBlue
                              : CupertinoColors.secondaryLabel,
                          fontWeight: _isSelectionMode 
                              ? FontWeight.w600 
                              : FontWeight.normal,
                          decoration: TextDecoration.none
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (!_isCalculatingSize && _totalTrashSize > 0 && !_isSelectionMode) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.arrow_up_circle,
                    color: CupertinoColors.systemGreen,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Emptying trash will free ${_formatFileSize(_totalTrashSize)} of storage',
                      style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.systemGreen,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey5,
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.delete,
              size: 60,
              color: CupertinoColors.systemGrey2,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Trash is Empty',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.label,
              decoration: TextDecoration.none
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Photos you delete will appear here',
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.secondaryLabel,
              decoration: TextDecoration.none
            ),
          ),
          SizedBox(height: 32),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Photos are kept in trash for 30 days',
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel,
                decoration: TextDecoration.none
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return CustomScrollView(
      physics: BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildPhotoItem(_trashedPhotos[index], index),
              childCount: _trashedPhotos.length,
            ),
          ),
        ),
        SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  Widget _buildPhotoItem(AssetEntity photo, int index) {
    final isSelected = _selectedPhotos.contains(photo.id);
    final photoSize = _photoSizes[photo.id] ?? 0;
    
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
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: CupertinoColors.systemBlue, width: 3)
              : null,
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<Widget>(
                future: _buildPhotoThumbnail(photo),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return snapshot.data!;
                  }
                  return Container(
                    color: CupertinoColors.systemGrey5,
                    child: Center(
                      child: CupertinoActivityIndicator(),
                    ),
                  );
                },
              ),
              if (_isSelectionMode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: AnimatedScale(
                    scale: isSelected ? 1.0 : 0.8,
                    duration: Duration(milliseconds: 150),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? CupertinoColors.systemBlue 
                            : CupertinoColors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected 
                              ? CupertinoColors.systemBlue 
                              : CupertinoColors.systemGrey,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        CupertinoIcons.check_mark,
                        size: 14,
                        color: isSelected 
                            ? CupertinoColors.white 
                            : Colors.transparent,
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        CupertinoColors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (photoSize > 0)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: CupertinoColors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatFileSize(photoSize),
                              style: TextStyle(
                                fontSize: 10,
                                color: CupertinoColors.white,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.none
                              ),
                            ),
                          ),
                        SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              CupertinoIcons.delete,
                              size: 14,
                              color: CupertinoColors.white.withOpacity(0.8),
                            ),
                            Spacer(),
                            if (photo.type == AssetType.video)
                              Icon(
                                CupertinoIcons.play_circle,
                                size: 14,
                                color: CupertinoColors.white.withOpacity(0.8),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Widget> _buildPhotoThumbnail(AssetEntity photo) async {
    try {
      final thumbnail = await photo.thumbnailDataWithSize(ThumbnailSize(300, 300));
      
      if (thumbnail != null) {
        return Image.memory(
          thumbnail,
          fit: BoxFit.cover,
        );
      }
    } catch (e) {
      print('Error loading thumbnail: $e');
    }
    
    return Container(
      color: CupertinoColors.systemGrey5,
      child: Icon(
        CupertinoIcons.photo,
        color: CupertinoColors.systemGrey2,
        size: 40,
      ),
    );
  }

  void _showActionSheet() {
    showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(
          'Trash Options',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, decoration: TextDecoration.none),
        ),
        message: Text(
          _totalTrashSize > 0 
              ? 'Choose an action for your trash\nTotal size: ${_formatFileSize(_totalTrashSize)}'
              : 'Choose an action for your trash'
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _enterSelectionMode();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.selection_pin_in_out, size: 20),
                SizedBox(width: 8),
                Text('Select Photos'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _emptyTrash();
            },
            isDestructiveAction: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.delete_solid, size: 20),
                SizedBox(width: 8),
                Text('Empty Trash'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
      ),
    );
  }

  void _showPhotoOptions(AssetEntity photo) {
    final photoSize = _photoSizes[photo.id] ?? 0;
    
    showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('Photo Options'),
        message: photoSize > 0 ? Text('Size: ${_formatFileSize(photoSize)}') : null,
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _restorePhoto(photo);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.refresh_circled, color: CupertinoColors.systemGreen, size: 20),
                SizedBox(width: 8),
                Text('Restore Photo', style: TextStyle(color: CupertinoColors.systemGreen, decoration: TextDecoration.none)),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _permanentlyDeletePhoto(photo);
            },
            isDestructiveAction: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.delete_solid, size: 20),
                SizedBox(width: 8),
                Text('Delete Permanently'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
      ),
    );
  }
}