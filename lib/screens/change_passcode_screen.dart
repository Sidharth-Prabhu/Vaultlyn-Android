// lib/screens/change_passcode_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lock_screen.dart';

class ChangePasscodeScreen extends StatefulWidget {
  const ChangePasscodeScreen({super.key});

  @override
  _ChangePasscodeScreenState createState() => _ChangePasscodeScreenState();
}

class _ChangePasscodeScreenState extends State<ChangePasscodeScreen> {
  String _oldPasscode = '';
  String _newPasscode = '';
  String _confirmPasscode = '';
  String? _errorMessage;

  Future<void> _changePasscode() async {
    if (_newPasscode != _confirmPasscode) {
      setState(() {
        _errorMessage = 'New passcodes do not match';
      });
      return;
    }
    if (_newPasscode.length != 4 ||
        !_newPasscode.contains(RegExp(r'^\d{4}$'))) {
      setState(() {
        _errorMessage = 'Enter a 4-digit new passcode';
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString('password_hash');
    final salt = prefs.getString('salt');
    if (storedHash == null || salt == null) return;

    final saltBytes = base64Decode(salt);
    final oldHash = _hashPasscode(_oldPasscode, saltBytes);

    if (oldHash != storedHash) {
      setState(() {
        _errorMessage = 'Incorrect old passcode';
      });
      return;
    }

    // Update password_hash and secret_code so LockScreen & Calculator stay in sync
    final newHash = _hashPasscode(_newPasscode, saltBytes);
    await prefs.setString('password_hash', newHash);
    await prefs.setString('secret_code', _newPasscode);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Passcode changed')));

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LockScreen()),
      (route) => false,
    );
  }

  String _hashPasscode(String passcode, Uint8List salt) {
    final keyBytes = utf8.encode(passcode);
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(salt);
    return digest.toString();
  }

  void _addDigit(String digit) {
    setState(() {
      if (_oldPasscode.length < 4) {
        _oldPasscode += digit;
      } else if (_newPasscode.length < 4) {
        _newPasscode += digit;
      } else if (_confirmPasscode.length < 4) {
        _confirmPasscode += digit;
      }
    });
  }

  void _clear() {
    setState(() {
      _oldPasscode = '';
      _newPasscode = '';
      _confirmPasscode = '';
      _errorMessage = null;
    });
  }

  void _backspace() {
    setState(() {
      if (_confirmPasscode.isNotEmpty) {
        _confirmPasscode = _confirmPasscode.substring(
          0,
          _confirmPasscode.length - 1,
        );
      } else if (_newPasscode.isNotEmpty) {
        _newPasscode = _newPasscode.substring(0, _newPasscode.length - 1);
      } else if (_oldPasscode.isNotEmpty) {
        _oldPasscode = _oldPasscode.substring(0, _oldPasscode.length - 1);
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

  Widget _buildDots(String code) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        bool filled = index < code.length;
        return AnimatedContainer(
          duration: Duration(milliseconds: 200),
          margin: EdgeInsets.symmetric(horizontal: 6),
          width: 14,
          height: 14,
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
    return Scaffold(
      appBar: AppBar(title: Text('Change Passcode')),
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_errorMessage != null) ...[
                  Text(_errorMessage!, style: TextStyle(color: Colors.red)),
                  SizedBox(height: 12),
                ],
                Text(
                  'Old Passcode',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue.shade800,
                  ),
                ),
                SizedBox(height: 12),
                _buildDots(_oldPasscode),
                SizedBox(height: 24),
                Text(
                  'New Passcode',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue.shade800,
                  ),
                ),
                SizedBox(height: 12),
                _buildDots(_newPasscode),
                SizedBox(height: 24),
                Text(
                  'Confirm New Passcode',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue.shade800,
                  ),
                ),
                SizedBox(height: 12),
                _buildDots(_confirmPasscode),
                SizedBox(height: 24),
                _buildNumpad(),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _changePasscode,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 44),
                    backgroundColor: Colors.blue.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Change Passcode',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
