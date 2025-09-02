import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models.dart';
import '../ui/widgets.dart';
import '../ui/theme.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<Booking>? list;
  String? error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try { final l = await api.getMyBookings(); setState(() { list = l; error = null; }); }
    catch (e) { setState(() => error = e.toString()); }
  }

  Future<void> _cancel(Booking b) async {
    try {
      final res = await api.cancelBooking(b.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Отменено. Штраф: ${(res.penaltyCents/100).toStringAsFixed(0)} ₽')));
      _load();
    } catch (e) { setState(() => error = e.toString()); }
  }

  @override
  Widget build(BuildContext context) {
    final l = list;
    return Scaffold(
      appBar: AppBar(title: const Text('Мои брони')),
      body: l == null
          ? (error != null ? EmptyState(message: error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: _load,
              child: l.isEmpty
                  ? const EmptyState(message: 'Бронирований нет')
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: l.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final b = l[i];
                        final time = '${DateFormat('dd.MM.yyyy HH:mm').format(b.startTime.toLocal())} — ${DateFormat('HH:mm').format(b.endTime.toLocal())}';
                        final color = switch (b.status) {
                          'pending' => IUTheme.warn,
                          'paid' => IUTheme.success,
                          'completed' => Colors.white70,
                          'cancelled' => IUTheme.danger,
                          _ => Colors.white70
                        };

                        return NeuCard(
                          child: Row(
                            children: [
                              Container(
                                width: 8, height: 56, margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                              ),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('#${b.id} — ${b.status.toUpperCase()}',
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(time, style: const TextStyle(color: Colors.white70)),
                                  const SizedBox(height: 6),
                                  Text('Цена: ${(b.priceCents/100).toStringAsFixed(0)} ₽',
                                      style: const TextStyle(fontSize: 12, color: Colors.white70)),
                                ]),
                              ),
                              if (b.status == 'pending' || b.status == 'paid')
                                TextButton(onPressed: () => _cancel(b), child: const Text('Отменить')),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}