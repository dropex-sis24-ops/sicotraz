import 'package:flutter/material.dart';

void main() {
  runApp(const SicotrazApp());
}

class SicotrazApp extends StatelessWidget {
  const SicotrazApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'SICOTRAZ',
      home: TechnicalPreparationScreen(),
    );
  }
}

class TechnicalPreparationScreen extends StatelessWidget {
  const TechnicalPreparationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SICOTRAZ',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text('Preparación técnica', style: TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }
}
