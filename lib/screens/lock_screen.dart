// lib/screens/lock_screen.dart (modernized UI)
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gallery_screen.dart';

class LockScreen extends StatefulWidget {
  @override
  _LockScreenState createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _passcode = '';
  String _confirmPasscode = '';
  bool _isSettingPasscode = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkIfPasscodeSet();
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
      setState(() {
        _errorMessage = 'Passcodes do not match';
      });
      return;
    }
    if (_passcode.length != 4 || !_passcode.contains(RegExp(r'^\d{4}$'))) {
      setState(() {
        _errorMessage = 'Enter a 4-digit passcode';
      });
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
      setState(() {
        _errorMessage = 'Enter a 4-digit passcode';
      });
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
      setState(() {
        _errorMessage = 'Incorrect passcode';
      });
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

  Widget _buildNumpad() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      padding: EdgeInsets.all(24),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        for (var i = 1; i <= 9; i++) _buildNumpadButton('$i'),
        _buildNumpadButton('Clear', onPressed: _clear),
        _buildNumpadButton('0'),
        _buildNumpadButton('⌫', onPressed: _backspace),
      ],
    );
  }

  Widget _buildNumpadButton(String label, {VoidCallback? onPressed}) {
    return ElevatedButton(
      onPressed: onPressed ?? () => _addDigit(label),
      style: ElevatedButton.styleFrom(
        shape: CircleBorder(),
        padding: EdgeInsets.all(24),
        backgroundColor: Colors.blue.shade50,
        foregroundColor: Colors.blue.shade800,
        elevation: 3,
        shadowColor: Colors.black26,
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDots(String code, {bool confirm = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        bool filled = index < code.length;
        return AnimatedContainer(
          duration: Duration(milliseconds: 200),
          margin: EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? Colors.blue : Colors.grey.shade400,
            boxShadow: filled
                ? [BoxShadow(color: Colors.blue.shade200, blurRadius: 6)]
                : [],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 60, color: Colors.blue.shade700),
              SizedBox(height: 16),
              Text(
                _isSettingPasscode
                    ? 'Set 4-Digit Passcode'
                    : 'Enter 4-Digit Passcode',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              if (_errorMessage != null) ...[
                SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red, fontSize: 14),
                ),
              ],
              SizedBox(height: 24),
              _buildDots(_passcode),
              if (_isSettingPasscode) ...[
                SizedBox(height: 32),
                Text(
                  'Confirm Passcode',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 16),
                _buildDots(_confirmPasscode, confirm: true),
              ],
              SizedBox(height: 40),
              _buildNumpad(),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSettingPasscode ? _setPasscode : _verifyPasscode,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.blue.shade600,
                ),
                child: Text(
                  _isSettingPasscode ? 'Set Passcode' : 'Unlock',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
