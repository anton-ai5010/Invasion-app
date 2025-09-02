import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../main.dart';
import '../models.dart';
import '../ui/widgets.dart';
import '../ui/theme.dart';
import 'zone_layout.dart';
import 'bookings.dart';

class ZonesScreen extends StatefulWidget {
  const ZonesScreen({super.key});

  @override
  State<ZonesScreen> createState() => _ZonesScreenState();
}

class _ZonesScreenState extends State<ZonesScreen> {
  List<Zone>? _zones;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState(); _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() { _loading = true; });
    try {
      final z = await api.getZones(force: force);
      setState(() { _zones = z; _error = null; });
    } catch (e) { setState(() => _error = e.toString()); }
    finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final zones = _zones;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Залы'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookingsScreen())),
            icon: const Icon(Icons.event),
            tooltip: 'Мои брони',
          ),
          IconButton(onPressed: ()=>_load(force: true), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (zones == null
              ? EmptyState(message: _error ?? 'Неизвестная ошибка', onRetry: _load)
              : (zones.isEmpty
                  ? const EmptyState(message: 'Зон пока нет')
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, childAspectRatio: 1.4, crossAxisSpacing: 14, mainAxisSpacing: 14),
                      itemCount: zones.length,
                      itemBuilder: (_, i) {
                        final z = zones[i];
                        return NeuCard(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ZoneLayoutScreen(zone: z))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(z.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: const Color(0xFF2F3642)),
                                  color: const Color(0xFF1B2027),
                                ),
                                child: Text('Код: ${z.code}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                              ),
                              const Spacer(),
                              Row(children: const [
                                Icon(Icons.grid_view, size: 18, color: IUTheme.secondary),
                                SizedBox(width: 6),
                                Text('Открыть сетку', style: TextStyle(color: IUTheme.secondary)),
                              ])
                            ],
                          ),
                        ).animate().fadeIn(duration: 300.ms, delay: (i * 50).ms).moveY(begin: 10, end: 0, duration: 300.ms);
                      },
                    ))),
    );
  }
}