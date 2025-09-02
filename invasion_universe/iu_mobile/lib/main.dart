import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/date_symbol_data_local.dart';
import 'api.dart';
import 'notify.dart';
import 'models.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/zones/zones_screen.dart';
import 'ui/theme.dart';

late Api api;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ru');
  await initializeDateFormatting('en');
  
  tz.initializeTimeZones();
  await Notifier.init();
  
  String baseUrl = 'http://localhost:8000';
  if (!kIsWeb) {
    if (Platform.isAndroid) {
      baseUrl = 'http://10.0.2.2:8000';
    } else if (Platform.isIOS || Platform.isMacOS) {
      baseUrl = 'http://127.0.0.1:8000';
    }
  }
  
  api = Api(baseUrl: baseUrl);
  await api.init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final hasToken = prefs.getString('auth_token') != null;
    if (hasToken && mounted) {
      try {
        final user = await api.getMe();
        setState(() => _user = user);
      } catch (_) {
        // Token invalid, clear it
        await api.setToken(null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Invasion Universe',
      theme: IUTheme.dark(),
      home: _user == null
          ? const AuthScreen()
          : const ZonesScreen(),
    );
  }
}
