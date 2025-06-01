import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class FullScreenPhotoViewer extends StatelessWidget {
  final AssetEntity photo;

  const FullScreenPhotoViewer({Key? key, required this.photo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: FutureBuilder<Widget>(
            future: _buildFullPhoto(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return snapshot.data!;
              }
              return CircularProgressIndicator(color: Colors.white);
            },
          ),
        ),
      ),
    );
  }

  Future<Widget> _buildFullPhoto() async {
    try {
      final file = await photo.file;
      if (file != null) {
        return Image.file(file, fit: BoxFit.contain);
      }
    } catch (e) {
      print('Error: $e');
    }
    
    final thumbnail = await photo.thumbnailDataWithSize(ThumbnailSize(1920, 1920));
    if (thumbnail != null) {
      return Image.memory(thumbnail, fit: BoxFit.contain);
    }
    
    return Icon(Icons.broken_image, color: Colors.white, size: 100);
  }
}