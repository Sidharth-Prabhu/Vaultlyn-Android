// lib/screens/scientific_calculator_screen.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

class ScientificCalculatorScreen extends StatefulWidget {
  final VoidCallback onUnlock;

  ScientificCalculatorScreen({required this.onUnlock});

  @override
  _ScientificCalculatorScreenState createState() =>
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
    'sin',
    'cos',
    'tan',
    'log',
    'C',
    '7',
    '8',
    '9',
    '/',
    '⌫',
    '4',
    '5',
    '6',
    '*',
    '(',
    '1',
    '2',
    '3',
    '-',
    ')',
    '0',
    '.',
    '=',
    '+',
    'π',
  ];

  @override
  void initState() {
    super.initState();
    _loadSecretCode();
  }

  Future<void> _loadSecretCode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _secretCode = prefs.getString('secret_code') ?? '1806'; // fallback
    });
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
        if (_enteredCode.isNotEmpty) {
          _enteredCode = _enteredCode.substring(0, _enteredCode.length - 1);
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

      // Track secret code input
      if (!_secretCodeEntered && RegExp(r'^[0-9]$').hasMatch(value)) {
        _enteredCode += value;

        if (_enteredCode.endsWith(_secretCode)) {
          _secretCodeEntered = true;
          _output = 'Press = to unlock';
          return;
        } else if (_enteredCode.length >= _secretCode.length) {
          _enteredCode = _enteredCode.substring(
            _enteredCode.length - (_secretCode.length - 1),
          );
        }
      }

      // Handle calculator input
      if (_isResultDisplayed && !_isOperator(value)) {
        _input = '';
        _isResultDisplayed = false;
      }

      if (['sin', 'cos', 'tan', 'log'].contains(value)) {
        _input += '$value(';
      } else {
        _input += value;
      }
    });
  }

  bool _isOperator(String value) {
    return ['+', '-', '*', '/', 'sin', 'cos', 'tan', 'log'].contains(value);
  }

  void _calculateResult() {
    try {
      if (_secretCodeEntered) return;

      String expression = _input
          .replaceAll('sin', 'math.sin')
          .replaceAll('cos', 'math.cos')
          .replaceAll('tan', 'math.tan')
          .replaceAll('log', 'math.log')
          .replaceAll('π', '${math.pi}')
          .replaceAll('e', '${math.e}');

      while (expression.contains('math.')) {
        final funcStart = expression.indexOf('math.');
        final parenStart = expression.indexOf('(', funcStart);
        int parenCount = 1;
        int parenEnd = parenStart + 1;

        while (parenCount > 0 && parenEnd < expression.length) {
          if (expression[parenEnd] == '(') parenCount++;
          if (expression[parenEnd] == ')') parenCount--;
          parenEnd++;
        }

        if (parenCount > 0) throw Exception('Mismatched parentheses');

        final funcName = expression.substring(funcStart + 5, parenStart);
        final argStr = expression.substring(parenStart + 1, parenEnd - 1);
        final arg = _evaluateSimpleExpression(argStr);

        double result;
        switch (funcName) {
          case 'sin':
            result = math.sin(arg);
            break;
          case 'cos':
            result = math.cos(arg);
            break;
          case 'tan':
            result = math.tan(arg);
            break;
          case 'log':
            result = math.log(arg);
            break;
          default:
            throw Exception('Unknown function: $funcName');
        }

        expression = expression.replaceRange(
          funcStart,
          parenEnd,
          result.toString(),
        );
      }

      final result = _evaluateSimpleExpression(expression);
      _output = result.toStringAsFixed(6).replaceAll(RegExp(r'\.?0+$'), '');
      _isResultDisplayed = true;
    } catch (e) {
      _output = 'Error';
    }
  }

  double _evaluateSimpleExpression(String expression) {
    expression = expression.replaceAll(' ', '');

    List<String> tokens = expression.split(RegExp(r'([\+\-])'));
    List<double> values = [];
    List<String> operators = [];

    for (String token in tokens) {
      if (token.contains('*') || token.contains('/')) {
        List<String> subTokens = token.split(RegExp(r'([\*\/])'));
        double value = double.parse(subTokens[0]);

        for (int i = 1; i < subTokens.length; i++) {
          String op = token[token.indexOf(subTokens[i]) - 1];
          double nextVal = double.parse(subTokens[i]);

          if (op == '*') {
            value *= nextVal;
          } else if (op == '/') {
            if (nextVal == 0) throw Exception('Division by zero');
            value /= nextVal;
          }
        }
        values.add(value);
      } else if (token.isNotEmpty) {
        values.add(double.parse(token));
      }
    }

    operators = RegExp(
      r'[\+\-]',
    ).allMatches(expression).map((match) => match.group(0)!).toList();

    double result = values[0];
    for (int i = 0; i < operators.length; i++) {
      if (operators[i] == '+') {
        result += values[i + 1];
      } else if (operators[i] == '-') {
        result -= values[i + 1];
      }
    }

    return result;
  }

  Widget _buildButton(String label) {
    Color? bgColor;
    Color textColor = Colors.black;

    if (label == 'C') {
      bgColor = Colors.red;
      textColor = Colors.white;
    } else if (label == '=') {
      bgColor = Colors.blue;
      textColor = Colors.white;
    } else {
      bgColor = Colors.grey[200];
    }

    return ElevatedButton(
      onPressed: () => _onButtonPressed(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        padding: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: TextStyle(fontSize: 20, color: textColor)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scientific Calculator'),
        backgroundColor: Colors.blueGrey[700],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              padding: EdgeInsets.all(16),
              alignment: Alignment.bottomRight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Text(
                      _input,
                      style: TextStyle(fontSize: 24, color: Colors.grey[600]),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    _output,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.all(8),
              child: GridView.count(
                crossAxisCount: 5,
                children: _buttons.map((b) => _buildButton(b)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
