import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/lock_screen.dart';
import 'screens/scientific_calculator_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _isDisguiseApp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('disguise_app') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vaultlyn',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: FutureBuilder<bool>(
        future: _isDisguiseApp(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.data == true) {
            return ScientificCalculatorScreen(
              onUnlock: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => LockScreen()),
                );
              },
            );
          } else {
            return LockScreen();
          }
        },
      ),
    );
  }
}
