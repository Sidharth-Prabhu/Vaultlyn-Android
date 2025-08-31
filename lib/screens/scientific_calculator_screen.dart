import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

class ScientificCalculatorScreen extends StatefulWidget {
  final VoidCallback onUnlock;

  const ScientificCalculatorScreen({super.key, required this.onUnlock});

  @override
  State<ScientificCalculatorScreen> createState() =>
      _ScientificCalculatorScreenState();
}

class _ScientificCalculatorScreenState
    extends State<ScientificCalculatorScreen> {
  String _input = '';
  String _output = '0';
  late String _secretCode;
  String _enteredCode = '';
  bool _secretCodeEntered = false;
  bool _isResultDisplayed = false;

  final List<String> _buttons = [
    'C',
    '⌫',
    '(',
    ')',
    'sin',
    'cos',
    'tan',
    '÷',
    '7',
    '8',
    '9',
    '×',
    '4',
    '5',
    '6',
    '-',
    '1',
    '2',
    '3',
    '+',
    '0',
    '.',
    '=',
    '^',
    'π',
    'e',
    '√',
    'x²',
    'log',
    'ln',
    'exp',
    '±',
  ];

  @override
  void initState() {
    super.initState();
    _loadSecretCode();
  }

  Future<void> _loadSecretCode() async {
    final prefs = await SharedPreferences.getInstance();
    _secretCode = prefs.getString('secret_code') ?? '1806';
  }

  void _onButtonPressed(String value) {
    setState(() {
      if (value == 'C') {
        _input = '';
        _output = '0';
        _enteredCode = '';
        _secretCodeEntered = false;
        _isResultDisplayed = false;
        return;
      }

      if (value == '⌫') {
        if (_input.isNotEmpty) {
          _input = _input.substring(0, _input.length - 1);
        }
        return;
      }

      if (value == '±') {
        if (_output.startsWith('-')) {
          _output = _output.substring(1);
        } else if (_output != '0') {
          _output = '-$_output';
        }
        return;
      }

      if (value == '=') {
        if (_secretCodeEntered) {
          widget.onUnlock();
          return;
        }
        _calculateResult();
        return;
      }

      if (!_secretCodeEntered && RegExp(r'^[0-9]$').hasMatch(value)) {
        _enteredCode += value;
        if (_enteredCode.endsWith(_secretCode)) {
          _secretCodeEntered = true;
          _output = '🔓 Press = to unlock';
          return;
        } else if (_enteredCode.length >= _secretCode.length) {
          _enteredCode = _enteredCode.substring(
            _enteredCode.length - (_secretCode.length - 1),
          );
        }
      }

      if (_isResultDisplayed && !_isOperator(value)) {
        _input = '';
        _isResultDisplayed = false;
      }

      _input += value;
    });
  }

  bool _isOperator(String value) =>
      ['+', '-', '×', '÷', '^', '='].contains(value);

  void _calculateResult() {
    try {
      if (_secretCodeEntered) return;

      String expression = _input
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('π', math.pi.toString())
          .replaceAll('e', math.e.toString())
          .replaceAll('√', 'sqrt')
          .replaceAll('x²', '^2');

      double result = _evaluateExpression(expression);
      _output = result.toString();
      _isResultDisplayed = true;
    } catch (_) {
      _output = 'Error';
    }
  }

  double _safeEval(String expr) {
    try {
      return _evaluateExpression(expr);
    } catch (_) {
      return double.nan;
    }
  }

  double _evaluateExpression(String expr) {
    expr = expr.replaceAll(' ', '');

    expr = expr.replaceAllMapped(
      RegExp(r'sin\(([^()]+)\)'),
      (m) => math.sin(_safeEval(m.group(1)!)).toString(),
    );
    expr = expr.replaceAllMapped(
      RegExp(r'cos\(([^()]+)\)'),
      (m) => math.cos(_safeEval(m.group(1)!)).toString(),
    );
    expr = expr.replaceAllMapped(
      RegExp(r'tan\(([^()]+)\)'),
      (m) => math.tan(_safeEval(m.group(1)!)).toString(),
    );
    expr = expr.replaceAllMapped(
      RegExp(r'asin\(([^()]+)\)'),
      (m) => math.asin(_safeEval(m.group(1)!)).toString(),
    );
    expr = expr.replaceAllMapped(
      RegExp(r'acos\(([^()]+)\)'),
      (m) => math.acos(_safeEval(m.group(1)!)).toString(),
    );
    expr = expr.replaceAllMapped(
      RegExp(r'atan\(([^()]+)\)'),
      (m) => math.atan(_safeEval(m.group(1)!)).toString(),
    );
    expr = expr.replaceAllMapped(
      RegExp(r'log\(([^()]+)\)'),
      (m) => (math.log(_safeEval(m.group(1)!)) / math.ln10).toString(),
    );
    expr = expr.replaceAllMapped(
      RegExp(r'ln\(([^()]+)\)'),
      (m) => math.log(_safeEval(m.group(1)!)).toString(),
    );
    expr = expr.replaceAllMapped(
      RegExp(r'exp\(([^()]+)\)'),
      (m) => math.exp(_safeEval(m.group(1)!)).toString(),
    );
    expr = expr.replaceAllMapped(
      RegExp(r'sqrt\(([^()]+)\)'),
      (m) => math.sqrt(_safeEval(m.group(1)!)).toString(),
    );

    if (expr.contains('^')) {
      final parts = expr.split('^');
      return math.pow(_safeEval(parts[0]), _safeEval(parts[1])).toDouble();
    }

    return _basicEval(expr);
  }

  double _basicEval(String expr) {
    try {
      return double.parse(expr);
    } catch (_) {
      List<String> tokens = expr.split(RegExp(r'([+\-])'));
      List<double> values = [];
      List<String> operators = [];

      for (String token in tokens) {
        if (token.contains('*') || token.contains('/')) {
          List<String> subTokens = token.split(RegExp(r'([*/])'));
          double value = double.parse(subTokens[0]);
          int idx = subTokens[0].length;
          for (int i = 1; i < subTokens.length; i++) {
            String op = token[idx];
            double nextVal = double.parse(subTokens[i]);
            if (op == '*') value *= nextVal;
            if (op == '/') value /= nextVal;
            idx += subTokens[i].length + 1;
          }
          values.add(value);
        } else if (token.isNotEmpty) {
          values.add(double.parse(token));
        }
      }

      operators = RegExp(
        r'[+\-]',
      ).allMatches(expr).map((m) => m.group(0)!).toList();

      double result = values[0];
      for (int i = 0; i < operators.length; i++) {
        if (operators[i] == '+') result += values[i + 1];
        if (operators[i] == '-') result -= values[i + 1];
      }

      return result;
    }
  }

  Widget _buildButton(String label) {
    final isOperator = _isOperator(label);
    final isUtility = ['C', '⌫', '±'].contains(label);

    Color bgColor = isOperator
        ? Colors.deepPurpleAccent
        : isUtility
        ? Colors.grey[700]!
        : Colors.grey[850]!;

    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: ElevatedButton(
        onPressed: () => _onButtonPressed(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          padding: const EdgeInsets.symmetric(vertical: 20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Text(
                      _input,
                      style: TextStyle(
                        fontSize: 28,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _output,
                      key: ValueKey(_output),
                      style: TextStyle(
                        fontSize: _secretCodeEntered ? 32 : 48,
                        fontWeight: FontWeight.bold,
                        color: _secretCodeEntered
                            ? Colors.greenAccent
                            : Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 8,
                            color: Colors.deepPurpleAccent,
                            offset: const Offset(0, 0),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: GridView.builder(
                  itemCount: _buttons.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 1.2,
                  ),
                  itemBuilder: (context, index) {
                    return _buildButton(_buttons[index]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
