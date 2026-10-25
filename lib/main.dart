import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const RotasBusApp());
}

class RotasBusApp extends StatelessWidget {
  const RotasBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rotas Bus',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
