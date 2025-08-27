import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:timezone/data/latest.dart' as tz;
import 'api.dart';
import 'notify.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/zones/zones_screen.dart';

late Api api;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализация timezone
  tz.initializeTimeZones();
  
  // Инициализация локальных уведомлений
  await Notifier.init();
  
  // Определяем базовый URL в зависимости от платформы
  String baseUrl = 'http://localhost:8000';
  if (!kIsWeb && Platform.isAndroid) {
    baseUrl = 'http://10.0.2.2:8000'; // Android эмулятор
  }
  
  api = Api(baseUrl: baseUrl);
  await api.init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Invasion Universe',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: FutureBuilder<bool>(
        future: _checkAuth(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data == true ? const ZonesScreen() : const AuthScreen();
        },
      ),
    );
  }

  Future<bool> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token') != null;
  }
}
