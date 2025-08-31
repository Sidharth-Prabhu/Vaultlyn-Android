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
  const SettingsScreen({super.key});

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
      if (salt == null || hash == null) {
        throw "No password data found. Please set a passcode first.";
      }

      final appDir = await getApplicationDocumentsDirectory();
      final encryptedDir = Directory('${appDir.path}/encrypted_files');
      if (!await encryptedDir.exists()) {
        throw "No encrypted files to backup.";
      }

      final archive = Archive();
      // Add encrypted files
      final files = encryptedDir
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) => file.path.endsWith('.enc'));
      for (var file in files) {
        final bytes = await file.readAsBytes();
        final relativePath = p.relative(file.path, from: appDir.path);
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
      }

      // Add metadata
      final metadata = json.encode({'salt': salt, 'password_hash': hash});
      archive.addFile(
        ArchiveFile('metadata.json', metadata.length, utf8.encode(metadata)),
      );

      // Create ZIP file
      final zipBytes = ZipEncoder().encode(archive)!;
      final tempDir = await getTemporaryDirectory();
      final zipFile = File(
        '${tempDir.path}/vaultlyn_backup_${DateTime.now().millisecondsSinceEpoch}.zip',
      );
      await zipFile.writeAsBytes(zipBytes);

      // Share ZIP file
      await Share.shareXFiles([XFile(zipFile.path)], text: 'Vaultlyn Backup');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup created and shared successfully')),
      );
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
      // Pick ZIP file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result == null || result.files.isEmpty) return;

      // Confirm restore
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Restore Data"),
          content: Text(
            "Restoring will overwrite existing encrypted files. The passcode will not be changed unless you choose to update it. Continue?",
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

      // Read and decode ZIP
      final zipPath = result.files.single.path!;
      final zipBytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      // Prepare directories
      final appDir = await getApplicationDocumentsDirectory();
      final encryptedDir = Directory('${appDir.path}/encrypted_files');
      if (await encryptedDir.exists()) {
        await encryptedDir.delete(recursive: true);
      }
      await encryptedDir.create(recursive: true);

      // Extract files
      bool hasMetadata = false;
      for (var file in archive) {
        if (file.isFile) {
          if (file.name == 'metadata.json') {
            hasMetadata = true;
            // Optionally handle metadata later if user confirms passcode restore
          } else if (file.name.endsWith('.enc')) {
            final path = '${appDir.path}/${file.name}';
            final outFile = File(path);
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(file.content as List<int>);
          }
        }
      }

      // Prompt for passcode restore
      if (hasMetadata) {
        final restorePasscode = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Restore Passcode"),
            content: Text(
              "The backup contains passcode data. Would you like to restore the passcode? This will overwrite your current passcode.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text("Keep Current Passcode"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text("Restore Passcode"),
              ),
            ],
          ),
        );

        if (restorePasscode == true) {
          final metadataFile = archive.findFile('metadata.json');
          if (metadataFile != null) {
            final metadataJson = utf8.decode(metadataFile.content as List<int>);
            final metadata = json.decode(metadataJson);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('salt', metadata['salt']);
            await prefs.setString('password_hash', metadata['password_hash']);
          }
        }
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Data restored successfully')));

      // Navigate to LockScreen
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        elevation: 2,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                child: SwitchListTile(
                  title: Text(
                    'Disguise App',
                    style: theme.textTheme.titleMedium,
                  ),
                  subtitle: Text('Hide app appearance for privacy'),
                  value: _disguiseApp,
                  onChanged: _toggleDisguiseApp,
                  secondary: Icon(Icons.visibility_off),
                ),
              ),
              SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                child: ListTile(
                  leading: Icon(Icons.lock, color: theme.colorScheme.primary),
                  title: Text(
                    'Change Passcode',
                    style: theme.textTheme.titleMedium,
                  ),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _goToChangePasscode,
                ),
              ),
              SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                child: ListTile(
                  leading: Icon(Icons.backup, color: theme.colorScheme.primary),
                  title: Text(
                    'Backup and Share',
                    style: theme.textTheme.titleMedium,
                  ),
                  subtitle: Text('Export encrypted files securely'),
                  trailing: Icon(Icons.arrow_upward, size: 16),
                  onTap: _backupData,
                ),
              ),
              SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                child: ListTile(
                  leading: Icon(
                    Icons.restore,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    'Restore Data',
                    style: theme.textTheme.titleMedium,
                  ),
                  subtitle: Text('Import backup and overwrite existing data'),
                  trailing: Icon(Icons.arrow_downward, size: 16),
                  onTap: _restoreData,
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
