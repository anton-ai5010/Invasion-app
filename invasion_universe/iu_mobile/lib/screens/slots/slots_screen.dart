import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../models.dart';
import '../../notify.dart';
import '../../widgets/empty_state.dart';

class SlotsScreen extends StatefulWidget {
  final Zone zone;
  final Seat seat;

  const SlotsScreen({super.key, required this.zone, required this.seat});

  @override
  State<SlotsScreen> createState() => _SlotsScreenState();
}

class _SlotsScreenState extends State<SlotsScreen> {
  DateTime _selectedDate = DateTime.now();
  Future<List<SeatAvailability>>? _availabilityFuture;
  final Set<TimeSlot> _selectedSlots = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  void _loadAvailability({bool force = false}) {
    setState(() {
      _isLoading = true;
    });
    final future = api.getSeatAvailability(
      _selectedDate,
      seatId: widget.seat.id,
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
    setState(() {
      _availabilityFuture = future;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedSlots.clear();
      });
      _loadAvailability();
    }
  }

  bool _canSelectSlot(TimeSlot slot) {
    if (!slot.isFree) return false;
    if (_selectedSlots.isEmpty) return true;
    final sortedSlots = [..._selectedSlots, slot]..sort((a, b) => a.startTime.compareTo(b.startTime));
    for (int i = 1; i < sortedSlots.length; i++) {
      if (sortedSlots[i].startTime != sortedSlots[i - 1].endTime) return false;
    }
    return true;
  }

  void _onSlotTap(TimeSlot slot) {
    if (!slot.isFree) return;
    setState(() {
      if (_selectedSlots.contains(slot)) {
        _selectedSlots.remove(slot);
      } else if (_canSelectSlot(slot)) {
        _selectedSlots.add(slot);
      } else {
        _selectedSlots.clear();
        _selectedSlots.add(slot);
      }
    });
  }

  Future<void> _book() async {
    if (_selectedSlots.isEmpty) return;
    final sortedSlots = _selectedSlots.toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
    final startTime = sortedSlots.first.startTime;
    final hours = sortedSlots.length;

    setState(() => _isLoading = true);

    try {
      final booking = await api.createBooking(widget.seat.id, startTime, hours);
      if (!mounted) return;

      final timeText = TimeOfDay.fromDateTime(booking.startTime.toLocal()).format(context);
      await Notifier.scheduleBookingReminder(
        bookingId: booking.id,
        startUtc: booking.startTime,
        title: 'Скоро бронь',
        body: 'Место ${widget.seat.label} в $timeText',
      );

      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Успешно забронировано!'),
          content: Text('Место ${widget.seat.label} забронировано на ${DateFormat('d MMMM, HH:mm', 'ru').format(booking.startTime.toLocal())}'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst), child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Место ${widget.seat.label}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Выберите время:', style: theme.textTheme.titleMedium),
              TextButton.icon(
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(DateFormat('dd.MM.yyyy').format(_selectedDate.toLocal())),
              ),
            ]),
          ),
          Expanded(
            child: FutureBuilder<List<SeatAvailability>>(
              future: _availabilityFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return EmptyState(message: snapshot.error.toString(), onRetry: () async => _loadAvailability());
                }
                final availability = snapshot.data;
                if (availability == null || availability.isEmpty || availability.first.slots.isEmpty) {
                  return EmptyState(message: 'Нет слотов на эту дату', onRetry: () async => _loadAvailability());
                }
                return RefreshIndicator(
                  onRefresh: () async => _loadAvailability(force: true),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 120,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.8,
                    ),
                    itemCount: availability.first.slots.length,
                    itemBuilder: (context, index) {
                      final slot = availability.first.slots[index];
                      final isSelected = _selectedSlots.contains(slot);
                      return SlotChip(
                        slot: slot,
                        isSelected: isSelected,
                        onTap: () => _onSlotTap(slot),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          if (_selectedSlots.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16).copyWith(bottom: 32),
              decoration: BoxDecoration(color: theme.colorScheme.surface, boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, -5)),
              ]),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Выбрано: ${_selectedSlots.length} ч.', style: theme.textTheme.titleMedium),
                  Text('Цена: ${(_selectedSlots.length * widget.seat.hourlyPriceCents / 100).toStringAsFixed(0)} ₽', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
                ]),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _book,
                  icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.check),
                  label: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)) : const Text('Забронировать'),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

class SlotChip extends StatelessWidget {
  final TimeSlot slot;
  final bool isSelected;
  final VoidCallback onTap;

  const SlotChip({super.key, required this.slot, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canTap = slot.isFree;

    Color fgColor = Colors.grey.shade600;
    Color bgColor = Colors.grey.withValues(alpha: 0.1);
    Color borderColor = Colors.grey.withValues(alpha: 0.3);

    if (canTap) {
      fgColor = isSelected ? Colors.white : theme.colorScheme.onSurface;
      bgColor = isSelected ? theme.colorScheme.primary : theme.colorScheme.surface;
      borderColor = isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.3);
    }

    return InkWell(
      onTap: canTap ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Center(
          child: Text(
            slot.timeRange,
            style: theme.textTheme.bodyMedium?.copyWith(color: fgColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ),
    );
  }
}
