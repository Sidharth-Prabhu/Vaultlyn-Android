// lib/screens/file_view_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class FileViewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> decryptedFiles;
  final int initialIndex;

  FileViewScreen({required this.decryptedFiles, required this.initialIndex});

  @override
  _FileViewScreenState createState() => _FileViewScreenState();
}

class _FileViewScreenState extends State<FileViewScreen> {
  late PageController _pageController;
  late int _currentIndex;
  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  bool _isBuffering = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _initializeVideoPlayer();
  }

  void _initializeVideoPlayer() async {
    final fileData = widget.decryptedFiles[_currentIndex];
    if (fileData['type'] == 'video') {
      setState(() => _isBuffering = true);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${fileData['name']}');
      await tempFile.writeAsBytes(fileData['bytes']);
      _videoController = VideoPlayerController.file(tempFile)
        ..initialize().then((_) {
          setState(() {
            _isBuffering = false;
            _isPlaying = true;
            _videoController?.setLooping(true);
            _videoController?.play();
          });
        });
    }
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _isPlaying = false;
      } else {
        _videoController!.play();
        _isPlaying = true;
      }
    });
  }

  void _rewind() {
    if (_videoController == null) return;
    final currentPosition = _videoController!.value.position;
    final newPosition = currentPosition - Duration(seconds: 10);
    _videoController!.seekTo(
      newPosition < Duration.zero ? Duration.zero : newPosition,
    );
  }

  void _fastForward() {
    if (_videoController == null) return;
    final currentPosition = _videoController!.value.position;
    final duration = _videoController!.value.duration;
    final newPosition = currentPosition + Duration(seconds: 10);
    _videoController!.seekTo(newPosition > duration ? duration : newPosition);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fileData = widget.decryptedFiles[_currentIndex];
    return Scaffold(
      appBar: AppBar(title: Text(fileData['name'])),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.decryptedFiles.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
            _videoController?.dispose();
            _videoController = null;
            _isPlaying = false;
            _initializeVideoPlayer();
          });
        },
        itemBuilder: (context, index) {
          final fileData = widget.decryptedFiles[index];
          final type = fileData['type'];
          final bytes = fileData['bytes'] as Uint8List;

          if (type == 'image') {
            return Center(
              child: InteractiveViewer(
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            );
          } else if (type == 'video') {
            if (_isBuffering ||
                _videoController == null ||
                !_videoController!.value.isInitialized) {
              return Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                  ),
                ),
                VideoProgressIndicator(
                  _videoController!,
                  allowScrubbing: true,
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.replay_10),
                      onPressed: _rewind,
                      tooltip: 'Rewind 10s',
                    ),
                    IconButton(
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: _togglePlayPause,
                      tooltip: _isPlaying ? 'Pause' : 'Play',
                    ),
                    IconButton(
                      icon: Icon(Icons.forward_10),
                      onPressed: _fastForward,
                      tooltip: 'Fast Forward 10s',
                    ),
                  ],
                ),
              ],
            );
          } else {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.insert_drive_file, size: 80, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Unsupported file type', style: TextStyle(fontSize: 16)),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: Icon(Icons.open_in_new),
                    label: Text('Open with another app'),
                    onPressed: () async {
                      final tempDir = await getTemporaryDirectory();
                      final tempFile = File(
                        '${tempDir.path}/${fileData['name']}',
                      );
                      await tempFile.writeAsBytes(bytes);
                      final result = await OpenFilex.open(tempFile.path);
                      if (result.type != ResultType.done) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not open file')),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
