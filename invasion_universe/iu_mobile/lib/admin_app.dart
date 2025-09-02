import 'package:flutter/material.dart';
import 'api.dart';
import 'models.dart';
import 'admin/dashboard.dart';
import 'ui/theme.dart';

late Api api;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Для веб-админки всегда используем localhost
  api = Api(baseUrl: 'http://localhost:8000');
  await api.init();
  
  runApp(const AdminApp());
}

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  User? _user;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _tryMe();
  }

  Future<void> _tryMe() async {
    try {
      final me = await api.getMe();
      setState(() {
        _user = me;
        _checking = false;
      });
    } catch (_) {
      setState(() {
        _checking = false;
      });
    }
  }

  void _onAuthed() {
    _tryMe();
  }

  void _onLogout() {
    api.logout();
    setState(() {
      _user = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Invasion Admin',
      theme: IUTheme.dark(),
      home: _checking
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _user == null || _user!.role != 'admin'
              ? AuthScreen(onAuthed: _onAuthed)
              : AdminDashboard(api: api, onLogout: _onLogout),
    );
  }
}

// Специальная версия экрана авторизации для админки
class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthed;

  const AuthScreen({super.key, required this.onAuthed});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await api.login(_emailController.text, _passwordController.text);
      final user = await api.getMe();
      
      if (user.role != 'admin') {
        throw Exception('Доступ только для администраторов');
      }
      
      widget.onAuthed();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          elevation: 8,
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Invasion Admin',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email администратора',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Пароль',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  onSubmitted: (_) => _login(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Войти'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}