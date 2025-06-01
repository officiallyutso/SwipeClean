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

  Future<void> permanentlyDeletePhoto(AssetEntity photo) async {
    try {
      // Remove from trash list
      await restoreFromTrash(photo);
      
      // Attempt to delete the actual file
      // Note: On some platforms, this might not work due to permission restrictions
      final file = await photo.file;
      if (file != null && await file.exists()) {
        await file.delete();
      }
      
      // Alternative: Use PhotoManager to delete (requires additional permissions)
      final result = await PhotoManager.editor.deleteWithIds([photo.id]);
      if (!result.isNotEmpty) {
        throw Exception('Failed to delete photo from gallery');
      }
    } catch (e) {
      // If direct deletion fails, just remove from our trash tracking
      await restoreFromTrash(photo);
      rethrow;
    }
  }

  Future<void> clearTrash() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_trashedPhotosKey);
  }
}