// lib/screens/lock_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'gallery_screen.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  _LockScreenState createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _passcode = '';
  String _confirmPasscode = '';
  bool _isSettingPasscode = false;
  String? _errorMessage;
  bool _biometricAvailable = false;
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _initAsync();
  }

  Future<void> _initAsync() async {
    await _checkIfPasscodeSet();
    await _checkBiometricAvailability();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showFirstTimeDialog();
    });
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      final enrolledBiometrics = await _auth.getAvailableBiometrics();
      setState(() {
        _biometricAvailable =
            isAvailable && isDeviceSupported && enrolledBiometrics.isNotEmpty;
      });
    } catch (e) {
      setState(() => _biometricAvailable = false);
    }
  }

  Future<void> _showFirstTimeDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

    if (isFirstLaunch) {
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Encryption Notice'),
          content: Text(
            'Encryption and decryption are performed locally on your device. '
            'Processing speed may vary depending on the file size and your device performance.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
      await prefs.setBool('is_first_launch', false);
    }
  }

  Future<void> _checkIfPasscodeSet() async {
    final prefs = await SharedPreferences.getInstance();
    final hash = prefs.getString('password_hash');
    setState(() {
      _isSettingPasscode = hash == null;
    });
  }

  Future<void> _setPasscode() async {
    if (_passcode != _confirmPasscode) {
      setState(() => _errorMessage = 'Passcodes do not match');
      return;
    }
    if (_passcode.length != 4 || !_passcode.contains(RegExp(r'^\d{4}$'))) {
      setState(() => _errorMessage = 'Enter a 4-digit passcode');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final saltBytes = Uint8List(16)
      ..setAll(
        0,
        List.generate(16, (i) => DateTime.now().millisecondsSinceEpoch % 256),
      );
    final salt = base64Encode(saltBytes);
    await prefs.setString('salt', salt);

    final hash = _hashPasscode(_passcode, saltBytes);
    await prefs.setString('password_hash', hash);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GalleryScreen(password: _passcode),
      ),
    );
  }

  Future<void> _verifyPasscode() async {
    if (_passcode.length != 4 || !_passcode.contains(RegExp(r'^\d{4}$'))) {
      setState(() => _errorMessage = 'Enter a 4-digit passcode');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString('password_hash');
    final salt = prefs.getString('salt');
    if (storedHash == null || salt == null) return;

    final saltBytes = base64Decode(salt);
    final hash = _hashPasscode(_passcode, saltBytes);

    if (hash == storedHash) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GalleryScreen(password: _passcode),
        ),
      );
    } else {
      setState(() => _errorMessage = 'Incorrect passcode');
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Authenticate to unlock your vault',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      if (didAuthenticate) {
        final prefs = await SharedPreferences.getInstance();
        final storedHash = prefs.getString('password_hash');
        final salt = prefs.getString('salt');

        if (storedHash == null || salt == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No passcode set. Please set a passcode first.'),
            ),
          );
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                GalleryScreen(password: 'biometric_authenticated'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Biometric authentication failed. Try entering your passcode.',
            ),
          ),
        );
      }
    } on PlatformException catch (e) {
      String errorMsg = 'Biometric authentication failed';
      switch (e.code) {
        case 'NotAvailable':
          errorMsg = 'Biometric authentication is not available on this device';
          break;
        case 'NotEnrolled':
          errorMsg =
              'No biometrics enrolled. Please set up biometrics in your device settings';
          break;
        case 'LockedOut':
          errorMsg =
              'Biometric authentication temporarily locked out. Try again later';
          break;
        case 'PermanentlyLockedOut':
          errorMsg =
              'Biometric authentication permanently locked out. Use passcode instead';
          break;
        default:
          errorMsg = 'Biometric error: ${e.message}';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMsg)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unexpected error during biometric authentication'),
        ),
      );
    }
  }

  String _hashPasscode(String passcode, Uint8List salt) {
    final keyBytes = utf8.encode(passcode);
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(salt);
    return digest.toString();
  }

  void _addDigit(String digit) {
    setState(() {
      if (_isSettingPasscode) {
        if (_passcode.length < 4) {
          _passcode += digit;
        } else if (_confirmPasscode.length < 4) {
          _confirmPasscode += digit;
        }
      } else {
        if (_passcode.length < 4) {
          _passcode += digit;
        }
      }
    });
  }

  void _clear() {
    setState(() {
      _passcode = '';
      _confirmPasscode = '';
      _errorMessage = null;
    });
  }

  void _backspace() {
    setState(() {
      if (_isSettingPasscode && _confirmPasscode.isNotEmpty) {
        _confirmPasscode = _confirmPasscode.substring(
          0,
          _confirmPasscode.length - 1,
        );
      } else if (_passcode.isNotEmpty) {
        _passcode = _passcode.substring(0, _passcode.length - 1);
      }
    });
  }

  Widget _buildNumpadButton(String label, {VoidCallback? onPressed}) {
    return GestureDetector(
      onTap: onPressed ?? () => _addDigit(label),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        padding: EdgeInsets.all(20),
        child: label == '⌫'
            ? Icon(
                Icons.backspace_outlined,
                color: Colors.blue.shade700,
                size: 24,
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
      ),
    );
  }

  Widget _buildNumpad() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      mainAxisSpacing: 20,
      crossAxisSpacing: 20,
      children: [
        for (var i = 1; i <= 9; i++) _buildNumpadButton('$i'),
        _buildNumpadButton('Clear', onPressed: _clear),
        _buildNumpadButton('0'),
        _buildNumpadButton('⌫', onPressed: _backspace),
      ],
    );
  }

  Widget _buildDots(String code, {bool confirm = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        bool filled = index < code.length;
        return AnimatedContainer(
          duration: Duration(milliseconds: 200),
          margin: EdgeInsets.symmetric(horizontal: 4),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? Colors.blue : Colors.grey.shade400,
            boxShadow: filled
                ? [BoxShadow(color: Colors.blue.shade200, blurRadius: 3)]
                : [],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isSettingPasscode
                      ? (_confirmPasscode.isEmpty
                            ? 'Set a 4-digit Passcode'
                            : 'Confirm your Passcode')
                      : 'Enter Passcode',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDots(
                  _isSettingPasscode
                      ? (_confirmPasscode.isEmpty
                            ? _passcode
                            : _confirmPasscode)
                      : _passcode,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorMessage!, style: TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                _buildNumpad(),
                const SizedBox(height: 24),
                if (!_isSettingPasscode && _biometricAvailable)
                  ElevatedButton.icon(
                    onPressed: _authenticateWithBiometrics,
                    icon: Icon(Icons.fingerprint),
                    label: Text('Use Biometrics'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_isSettingPasscode) {
                      if (_passcode.length == 4 &&
                          _confirmPasscode.length == 4) {
                        _setPasscode();
                      } else {
                        setState(
                          () => _errorMessage =
                              'Enter and confirm 4-digit passcode',
                        );
                      }
                    } else {
                      if (_passcode.length == 4) {
                        _verifyPasscode();
                      } else {
                        setState(
                          () => _errorMessage = 'Enter a 4-digit passcode',
                        );
                      }
                    }
                  },
                  child: Text(_isSettingPasscode ? 'Set Passcode' : 'Unlock'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
