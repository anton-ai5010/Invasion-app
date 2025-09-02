import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models.dart';
import '../ui/widgets.dart';
import '../ui/theme.dart';

class SeatSlotsScreen extends StatefulWidget {
  final Seat seat;
  const SeatSlotsScreen({super.key, required this.seat});

  @override
  State<SeatSlotsScreen> createState() => _SeatSlotsScreenState();
}

class _SeatSlotsScreenState extends State<SeatSlotsScreen> {
  DateTime date = DateTime.now();
  List<SeatAvailability>? availability;
  String? error;
  bool booking = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context, firstDate: now, lastDate: now.add(const Duration(days: 30)), initialDate: now);
    if (d != null) { setState(() => date = d); _load(); }
  }

  Future<void> _load() async {
    try {
      final a = await api.getSeatAvailability(date, seatId: widget.seat.id);
      setState(() { availability = a; error = null; });
    } catch (e) { setState(() => error = e.toString()); }
  }

  Future<void> _book(TimeSlot slot) async {
    setState(() { booking = true; error = null; });
    try {
      final b = await api.createBooking(widget.seat.id, slot.startTime, 1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Бронь #${b.id} создана')));
      _load();
    } catch (e) { setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => booking = false); }
  }

  @override
  Widget build(BuildContext context) {
    final seatAvail = availability?.firstWhere((e) => e.seatId == widget.seat.id,
      orElse: () => SeatAvailability(seatId: widget.seat.id, label: widget.seat.label, slots: []));
    return Scaffold(
      appBar: AppBar(
        title: Text('Место ${widget.seat.label} • ${(widget.seat.hourlyPriceCents/100).toStringAsFixed(0)} ₽/ч'),
        actions: [ IconButton(onPressed: _pickDate, icon: const Icon(Icons.calendar_today)) ],
      ),
      body: availability == null
          ? (error != null ? EmptyState(message: error!, onRetry: _load) : const Center(child: CircularProgressIndicator()))
          : (seatAvail!.slots.isEmpty
              ? const EmptyState(message: 'На эту дату слотов нет')
              : ListView.separated(
                  itemCount: seatAvail.slots.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final s = seatAvail.slots[i];
                    final startLocal = s.startTime.toLocal();
                    final endLocal = s.endTime.toLocal();
                    final hh = DateFormat('HH:mm').format(startLocal);
                    final hh2 = DateFormat('HH:mm').format(endLocal);

                    return ListTile(
                      leading: Icon(s.isFree ? Icons.check_circle : Icons.cancel,
                          color: s.isFree ? IUTheme.success : IUTheme.danger),
                      title: Text('$hh — $hh2'),
                      subtitle: Text(s.isFree ? 'Свободно' : 'Занято',
                          style: TextStyle(color: s.isFree ? IUTheme.success : IUTheme.danger)),
                      trailing: s.isFree
                          ? ElevatedButton(
                              onPressed: booking ? null : () => _book(s),
                              child: const Text('Забронировать'),
                            )
                          : null,
                    );
                  },
                )),
    );
  }
}