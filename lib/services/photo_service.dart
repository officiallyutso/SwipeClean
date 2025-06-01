import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PhotoService {
  static const String _trashedPhotosKey = 'trashed_photos';

  Future<List<AssetEntity>> getAllPhotos() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );

    if (albums.isEmpty) return [];

    final recentAlbum = albums.first;
    final photos = await recentAlbum.getAssetListPaged(
      page: 0,
      size: 10000, // Get a large number of photos
    );

    return photos;
  }

  // NEW METHOD: Get photo size in bytes
  Future<double> getPhotoSize(AssetEntity photo) async {
    try {
      // Method 1: Get file and check its size
      final file = await photo.file;
      if (file != null && await file.exists()) {
        final fileSize = await file.length();
        return fileSize.toDouble();
      }

      // Method 2: Try original file
      final originalFile = await photo.originFile;
      if (originalFile != null && await originalFile.exists()) {
        final fileSize = await originalFile.length();
        return fileSize.toDouble();
      }

      // If all methods fail, return 0
      return 0.0;
    } catch (e) {
      print('Error getting photo size for ${photo.id}: $e');
      return 0.0;
    }
  }

  // NEW METHOD: Get total size of multiple photos
  Future<double> getTotalPhotosSize(List<AssetEntity> photos) async {
    double totalSize = 0.0;
    
    for (final photo in photos) {
      totalSize += await getPhotoSize(photo);
    }
    
    return totalSize;
  }

  Future<void> moveToTrash(AssetEntity photo) async {
    final prefs = await SharedPreferences.getInstance();
    final trashedIds = prefs.getStringList(_trashedPhotosKey) ?? [];
    
    if (!trashedIds.contains(photo.id)) {
      trashedIds.add(photo.id);
      await prefs.setStringList(_trashedPhotosKey, trashedIds);
    }
  }

  Future<void> restoreFromTrash(AssetEntity photo) async {
    final prefs = await SharedPreferences.getInstance();
    final trashedIds = prefs.getStringList(_trashedPhotosKey) ?? [];
    
    trashedIds.remove(photo.id);
    await prefs.setStringList(_trashedPhotosKey, trashedIds);
  }

  Future<List<String>> getTrashedPhotoIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_trashedPhotosKey) ?? [];
  }

  Future<List<AssetEntity>> getTrashedPhotos() async {
    final trashedIds = await getTrashedPhotoIds();
    if (trashedIds.isEmpty) return [];

    final allPhotos = await getAllPhotos();
    return allPhotos.where((photo) => trashedIds.contains(photo.id)).toList();
  }

  Future<bool> permanentlyDeletePhoto(AssetEntity photo) async {
    try {
      // Method 1: Try using PhotoManager's delete method first (recommended)
      final List<String> result = await PhotoManager.editor.deleteWithIds([photo.id]);
      
      if (result.contains(photo.id)) {
        // Successfully deleted, remove from trash list
        await restoreFromTrash(photo);
        return true;
      } else {
        // PhotoManager deletion failed, try alternative methods
        return await _alternativeDelete(photo);
      }
    } catch (e) {
      print('PhotoManager deletion failed: $e');
      // Try alternative deletion method
      return await _alternativeDelete(photo);
    }
  }

  Future<bool> _alternativeDelete(AssetEntity photo) async {
    try {
      // Method 2: Try to get the file and delete it directly
      final file = await photo.file;
      if (file != null && await file.exists()) {
        await file.delete();
        await restoreFromTrash(photo);
        return true;
      } else {
        // File doesn't exist anymore, just remove from trash list
        await restoreFromTrash(photo);
        return true; // Consider it successful since the file is already gone
      }
    } catch (e) {
      print('Direct file deletion failed: $e');
      
      // Method 3: If all else fails, try using the original file path
      try {
        final originalFile = await photo.originFile;
        if (originalFile != null && await originalFile.exists()) {
          await originalFile.delete();
          await restoreFromTrash(photo);
          return true;
        } else {
          // File doesn't exist, just remove from our tracking
          await restoreFromTrash(photo);
          return true;
        }
      } catch (e2) {
        print('Origin file deletion failed: $e2');
        
        // Method 4: Last resort - just remove from our trash tracking
        // The file might have been deleted by another app or moved
        await restoreFromTrash(photo);
        return false; // Return false to indicate we couldn't actually delete the file
      }
    }
  }

  // Enhanced method with better error handling
  Future<Map<String, dynamic>> permanentlyDeletePhotoWithStatus(AssetEntity photo) async {
    try {
      // First check if the asset still exists
      final exists = await photo.exists;
      if (!exists) {
        // Asset no longer exists, just remove from trash
        await restoreFromTrash(photo);
        return {
          'success': true,
          'message': 'Photo was already deleted',
          'actuallyDeleted': false
        };
      }

      // Try PhotoManager deletion first
      final List<String> result = await PhotoManager.editor.deleteWithIds([photo.id]);
      
      if (result.contains(photo.id)) {
        await restoreFromTrash(photo);
        return {
          'success': true,
          'message': 'Photo deleted successfully',
          'actuallyDeleted': true
        };
      }

      // If PhotoManager fails, try direct file deletion
      final file = await photo.file;
      if (file != null && await file.exists()) {
        await file.delete();
        await restoreFromTrash(photo);
        return {
          'success': true,
          'message': 'Photo deleted via file system',
          'actuallyDeleted': true
        };
      }

      // File doesn't exist, remove from tracking
      await restoreFromTrash(photo);
      return {
        'success': true,
        'message': 'Photo was already deleted from device',
        'actuallyDeleted': false
      };

    } catch (e) {
      // Last resort - remove from tracking even if deletion failed
      await restoreFromTrash(photo);
      return {
        'success': false,
        'message': 'Could not delete photo: ${e.toString()}',
        'actuallyDeleted': false
      };
    }
  }

  Future<void> clearTrash() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_trashedPhotosKey);
  }

  // Helper method to clean up non-existent photos from trash
  Future<void> cleanupTrashedPhotos() async {
    final trashedIds = await getTrashedPhotoIds();
    final validIds = <String>[];
    
    for (final id in trashedIds) {
      try {
        final asset = await AssetEntity.fromId(id);
        if (asset != null && await asset.exists) {
          validIds.add(id);
        }
      } catch (e) {
        // Asset no longer exists, don't add to valid list
        print('Removing non-existent photo from trash: $id');
      }
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_trashedPhotosKey, validIds);
  }
}