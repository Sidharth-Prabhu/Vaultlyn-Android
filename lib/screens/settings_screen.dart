// lib/screens/settings_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

import 'change_passcode_screen.dart';
import 'lock_screen.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _disguiseApp = false;
  bool _isLoading = false;
  static const platform = MethodChannel('app.channel.shared.data');

  @override
  void initState() {
    super.initState();
    _loadDisguiseSetting();
  }

  Future<void> _loadDisguiseSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _disguiseApp = prefs.getBool('disguise_app') ?? false;
    });
  }

  Future<void> _toggleDisguiseApp(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('disguise_app', value);
    setState(() => _disguiseApp = value);

    if (Theme.of(context).platform == TargetPlatform.android) {
      try {
        await platform.invokeMethod('setDisguiseApp', {'enabled': value});
      } on PlatformException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to disguise app: ${e.message}")),
        );
      }
    }
  }

  Future<void> _backupData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final salt = prefs.getString('salt');
      final hash = prefs.getString('password_hash');
      if (salt == null || hash == null) throw "No password data found";

      final appDir = await getApplicationDocumentsDirectory();
      final encryptedDir = Directory('${appDir.path}/encrypted_files');
      if (!await encryptedDir.exists()) throw "No encrypted files to backup";

      final archive = Archive();
      final files = encryptedDir.listSync(recursive: true, followLinks: false);
      for (var entity in files) {
        if (entity is File) {
          final bytes = await entity.readAsBytes();
          final relativePath = p.relative(entity.path, from: encryptedDir.path);
          archive.addFile(
            ArchiveFile('encrypted_files/$relativePath', bytes.length, bytes),
          );
        }
      }

      final metadata = json.encode({'salt': salt, 'password_hash': hash});
      archive.addFile(
        ArchiveFile('metadata.json', metadata.length, utf8.encode(metadata)),
      );

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) throw "Failed to create backup archive";

      final tempDir = await getTemporaryDirectory();
      final zipFile = File('${tempDir.path}/backup.zip');
      await zipFile.writeAsBytes(zipBytes);

      await Share.shareXFiles([XFile(zipFile.path)]);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Backup failed: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result == null || result.files.isEmpty) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Restore Data"),
          content: Text(
            "Restoring will overwrite your existing encrypted files. Continue?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text("Restore"),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      setState(() => _isLoading = true);

      final zipPath = result.files.single.path!;
      final zipBytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      final appDir = await getApplicationDocumentsDirectory();
      final encryptedDir = Directory('${appDir.path}/encrypted_files');
      if (await encryptedDir.exists()) {
        await encryptedDir.delete(recursive: true);
      }
      await encryptedDir.create(recursive: true);

      ArchiveFile? metadataFile;
      for (var file in archive) {
        if (file.isFile) {
          if (file.name == 'metadata.json') {
            metadataFile = file;
          } else if (file.name.startsWith('encrypted_files/')) {
            final path =
                '${encryptedDir.path}/${file.name.replaceFirst('encrypted_files/', '')}';
            final outFile = File(path);
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
          }
        }
      }

      if (metadataFile != null) {
        final metadataJson = utf8.decode(metadataFile.content as List<int>);
        final metadata = json.decode(metadataJson);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('salt', metadata['salt']);
        await prefs.setString('password_hash', metadata['password_hash']);
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Data restored successfully')));

      // Optional: lock the app after restore
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => LockScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error restoring data: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _goToChangePasscode() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChangePasscodeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.all(16),
            children: [
              SwitchListTile(
                title: Text('Disguise app'),
                value: _disguiseApp,
                onChanged: _toggleDisguiseApp,
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.lock),
                title: Text('Change Passcode'),
                onTap: _goToChangePasscode,
              ),
              ListTile(
                leading: Icon(Icons.backup),
                title: Text('Backup and Share'),
                onTap: _backupData,
              ),
              ListTile(
                leading: Icon(Icons.restore),
                title: Text('Restore Data'),
                onTap: _restoreData,
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
