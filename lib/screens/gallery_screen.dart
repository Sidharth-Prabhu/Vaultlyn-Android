// lib/screens/gallery_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

import 'file_view_screen.dart';
import 'settings_screen.dart';
import 'lock_screen.dart';

class GalleryScreen extends StatefulWidget {
  final String password;

  const GalleryScreen({super.key, required this.password});

  @override
  _GalleryScreenState createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<Map<String, dynamic>> _decryptedFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAndDecryptFiles();
  }

  Future<Uint8List> _getSalt() async {
    final prefs = await SharedPreferences.getInstance();
    final salt = prefs.getString('salt') ?? 'fixed_salt';
    return base64Decode(salt);
  }

  Future<Uint8List> _deriveKey(Uint8List salt) async {
    final keyBytes = utf8.encode(widget.password);
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(salt);
    return Uint8List.fromList(digest.bytes.sublist(0, 32));
  }

  Future<void> _loadAndDecryptFiles() async {
    setState(() => _isLoading = true);

    final salt = await _getSalt();
    final key = await _deriveKey(salt);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(encrypt.Key(key), mode: encrypt.AESMode.cbc),
    );

    final appDir = await getApplicationDocumentsDirectory();
    final encryptedDir = Directory('${appDir.path}/encrypted_files');

    if (!await encryptedDir.exists()) {
      setState(() {
        _isLoading = false;
        _decryptedFiles = [];
      });
      return;
    }

    final files = encryptedDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.enc'))
        .toList();

    List<Map<String, dynamic>> decryptedFiles = [];
    for (var file in files) {
      try {
        Uint8List fileBytes = await file.readAsBytes();
        if (fileBytes.length < 16) continue;
        Uint8List ivBytes = fileBytes.sublist(fileBytes.length - 16);
        Uint8List encBytes = fileBytes.sublist(0, fileBytes.length - 16);
        final iv = encrypt.IV(ivBytes);
        final encrypted = encrypt.Encrypted(encBytes);
        final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
        final decryptedBytes = Uint8List.fromList(decrypted);
        final name = p.basename(file.path).replaceAll('.enc', '');
        final ext = p.extension(name).toLowerCase();
        final type = _getFileType(ext);
        decryptedFiles.add({
          'name': name,
          'bytes': decryptedBytes,
          'file': file,
          'type': type,
        });
      } catch (_) {
        // skip invalid
      }
    }

    setState(() {
      _decryptedFiles = decryptedFiles;
      _isLoading = false;
    });
  }

  String _getFileType(String ext) {
    if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(ext))
      return 'image';
    if (['.mp4', '.mov', '.avi', '.mkv', '.webm', '.flv'].contains(ext))
      return 'video';
    if (['.pdf'].contains(ext)) return 'pdf';
    if (['.txt', '.doc', '.docx', '.rtf'].contains(ext)) return 'document';
    return 'other';
  }

  Future<void> _pickAndEncryptFiles({bool isMedia = false}) async {
    setState(() => _isLoading = true);

    final salt = await _getSalt();
    final key = await _deriveKey(salt);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(encrypt.Key(key), mode: encrypt.AESMode.cbc),
    );

    final appDir = await getApplicationDocumentsDirectory();
    final encryptedDir = Directory('${appDir.path}/encrypted_files');
    if (!await encryptedDir.exists()) {
      await encryptedDir.create(recursive: true);
    }

    List<XFile> files = [];
    try {
      if (isMedia) {
        final picker = ImagePicker();
        final picked = await picker.pickMultipleMedia();
        files.addAll(picked);
      } else {
        final result = await FilePicker.platform.pickFiles(allowMultiple: true);
        if (result != null) {
          files.addAll(result.files.map((f) => XFile(f.path!)));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking files: $e')));
      setState(() => _isLoading = false);
      return;
    }

    if (files.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    for (var file in files) {
      Uint8List fileBytes = await file.readAsBytes();
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypted = encrypter.encryptBytes(fileBytes, iv: iv);
      final fileName = '${p.basename(file.path)}.enc';
      final File encryptedFile = File('${encryptedDir.path}/$fileName');
      await encryptedFile.writeAsBytes(encrypted.bytes);
      await encryptedFile.writeAsBytes(iv.bytes, mode: FileMode.append);
    }

    await _loadAndDecryptFiles();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Files encrypted')));
  }

  void _showFileOptions() {
    showModalBottomSheet(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      context: context,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.image, color: Colors.blue),
                title: Text(
                  'Select Media (Images/Videos)',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndEncryptFiles(isMedia: true);
                },
              ),
              ListTile(
                leading: Icon(Icons.file_present, color: Colors.green),
                title: Text(
                  'Select Files',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndEncryptFiles(isMedia: false);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _goToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsScreen()),
    ).then((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LockScreen()),
      );
    });
  }

  void _lockVault() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LockScreen()),
    );
  }

  void _showOptions(int index) {
    showModalBottomSheet(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      context: context,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text(
                  'Delete',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteFile(index);
                },
              ),
              ListTile(
                leading: Icon(Icons.share, color: Colors.blue),
                title: Text(
                  'Share',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _shareFile(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteFile(int index) async {
    setState(() => _isLoading = true);
    final fileData = _decryptedFiles[index];
    final file = fileData['file'] as File;
    await file.delete();
    await _loadAndDecryptFiles();
  }

  Future<void> _shareFile(int index) async {
    final fileData = _decryptedFiles[index];
    final bytes = fileData['bytes'] as Uint8List;
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/${fileData['name']}');
    await tempFile.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(tempFile.path)]);
  }

  Widget _buildFileThumbnail(Map<String, dynamic> fileData) {
    final type = fileData['type'];
    final bytes = fileData['bytes'] as Uint8List;

    if (type == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(bytes, fit: BoxFit.cover),
      );
    } else if (type == 'video') {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(Icons.videocam, size: 40, color: Colors.white),
        ),
      );
    } else if (type == 'pdf') {
      return Container(
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(Icons.picture_as_pdf, size: 40, color: Colors.red),
        ),
      );
    } else if (type == 'document') {
      return Container(
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(Icons.description, size: 40, color: Colors.blue),
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(Icons.insert_drive_file, size: 40, color: Colors.grey),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        title: Text(
          'My Vault',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.lock),
            onPressed: _lockVault,
            tooltip: 'Lock Vault',
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _goToSettings,
            tooltip: 'Settings',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAndDecryptFiles,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(height: 16),
                  Text(
                    'Decrypting files...',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : _decryptedFiles.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 80,
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                  SizedBox(height: 16),
                  Text('No files yet', style: theme.textTheme.titleMedium),
                  SizedBox(height: 8),
                  Text(
                    'Tap the + button to add files',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 600 ? 4 : 3;
                return GridView.builder(
                  padding: EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _decryptedFiles.length,
                  itemBuilder: (context, index) {
                    final fileData = _decryptedFiles[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FileViewScreen(
                              decryptedFiles: _decryptedFiles,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                      onLongPress: () => _showOptions(index),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            Expanded(child: _buildFileThumbnail(fileData)),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              child: Text(
                                fileData['name'],
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.colorScheme.primary,
        onPressed: _showFileOptions,
        label: Text('Add Files'),
        icon: Icon(Icons.add),
      ),
    );
  }
}
