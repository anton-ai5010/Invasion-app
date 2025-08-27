import 'package:flutter/material.dart';
import '../../main.dart';
import '../../models.dart';
import '../../widgets/empty_state.dart';
import '../auth/auth_screen.dart';
import '../zone_layout/zone_layout_screen.dart';
import '../bookings/bookings_screen.dart';

class ZonesScreen extends StatefulWidget {
  const ZonesScreen({super.key});

  @override
  State<ZonesScreen> createState() => _ZonesScreenState();
}

class _ZonesScreenState extends State<ZonesScreen> {
  User? _user;
  List<Zone>? _zones;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool force = false}) async {
    if (!force && _zones != null) {
      setState(() {
        _isLoading = false;
      });
    }
    
    try {
      final user = await api.getMe();
      final zones = await api.getZones(force: force);
      if (!mounted) return;
      setState(() {
        _user = user;
        _zones = zones;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы действительно хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await api.logout();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Выберите зону'),
        actions: [
          if (_user != null)
            PopupMenuButton<String>(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'profile',
                  child: ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(_user!.email),
                    subtitle: Text('Роль: ${_user!.role}'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'bookings',
                  child: ListTile(
                    leading: Icon(Icons.bookmark),
                    title: Text('Мои брони'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Выход'),
                  ),
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'bookings':
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const BookingsScreen(),
                      ),
                    );
                    break;
                  case 'logout':
                    _logout();
                    break;
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  message: _error!,
                  icon: Icons.error_outline,
                  onRetry: () => _loadData(force: true),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadData(force: true),
                  child: _zones!.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.7,
                              child: const EmptyState(
                                message: 'Зоны пока не созданы',
                                icon: Icons.meeting_room,
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _zones!.length,
                          itemBuilder: (context, index) {
                            final zone = _zones![index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: zone.isActive
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey,
                                  child: Text(
                                    zone.code.substring(0, 1),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(zone.name),
                                subtitle: Text('Код: ${zone.code}'),
                                trailing: zone.isActive
                                    ? const Icon(Icons.arrow_forward_ios)
                                    : const Icon(Icons.lock, color: Colors.grey),
                                enabled: zone.isActive,
                                onTap: zone.isActive
                                    ? () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ZoneLayoutScreen(zone: zone),
                                          ),
                                        );
                                      }
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}