// lib/screens/change_passcode_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lock_screen.dart';

class ChangePasscodeScreen extends StatefulWidget {
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

    // ✅ Update both password_hash and secret_code so LockScreen & Calculator stay in sync
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

  Widget _buildNumpad() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      padding: EdgeInsets.all(16),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
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
      child: Text(label, style: TextStyle(fontSize: 20)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Change Passcode')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_errorMessage != null)
                Text(_errorMessage!, style: TextStyle(color: Colors.red)),
              Text('Old Passcode'),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 8),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _oldPasscode.length
                          ? Colors.blue
                          : Colors.grey,
                    ),
                  );
                }),
              ),
              SizedBox(height: 16),
              Text('New Passcode'),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 8),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _newPasscode.length
                          ? Colors.blue
                          : Colors.grey,
                    ),
                  );
                }),
              ),
              SizedBox(height: 16),
              Text('Confirm New Passcode'),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 8),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _confirmPasscode.length
                          ? Colors.blue
                          : Colors.grey,
                    ),
                  );
                }),
              ),
              SizedBox(height: 20),
              _buildNumpad(),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _changePasscode,
                child: Text('Change Passcode'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
