// lib/screens/image_view_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';

class ImageViewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> decryptedImages;
  final int initialIndex;

  ImageViewScreen({required this.decryptedImages, required this.initialIndex});

  @override
  _ImageViewScreenState createState() => _ImageViewScreenState();
}

class _ImageViewScreenState extends State<ImageViewScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.decryptedImages;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: Text(
          images[_currentIndex]['name'],
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: images.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final imageData = images[index];
          final bytes = imageData['bytes'] as Uint8List;

          return Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 1.0,
              maxScale: 4.0,
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}
