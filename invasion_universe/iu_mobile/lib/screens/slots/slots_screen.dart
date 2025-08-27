import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../models.dart';
import '../../notify.dart';

class SlotsScreen extends StatefulWidget {
  final Zone zone;
  final Seat seat;

  const SlotsScreen({super.key, required this.zone, required this.seat});

  @override
  State<SlotsScreen> createState() => _SlotsScreenState();
}

class _SlotsScreenState extends State<SlotsScreen> {
  DateTime _selectedDate = DateTime.now();
  List<SeatAvailability>? _availability;
  bool _isLoading = true;
  String? _error;
  final Set<TimeSlot> _selectedSlots = {};

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final availability = await api.getSeatAvailability(
        _selectedDate,
        seatId: widget.seat.id,
      );
      if (!mounted) return;
      setState(() {
        _availability = availability;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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

    final sortedSlots = [..._selectedSlots, slot]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    for (int i = 1; i < sortedSlots.length; i++) {
      if (sortedSlots[i].startTime != sortedSlots[i - 1].endTime) {
        return false;
      }
    }

    return true;
  }

  Future<void> _book() async {
    if (_selectedSlots.isEmpty) return;

    final sortedSlots = _selectedSlots.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final startTime = sortedSlots.first.startTime;
    final hours = sortedSlots.length;

    setState(() {
      _isLoading = true;
    });

    try {
      final booking = await api.createBooking(
        widget.seat.id,
        startTime,
        hours,
      );

      // Планируем локальное напоминание
      await Notifier.scheduleBookingReminder(
        bookingId: booking.id,
        startUtc: booking.startTime,
        title: 'Скоро бронь',
        body: 'Место ${widget.seat.label} в ${TimeOfDay.fromDateTime(booking.startTime.toLocal()).format(context)}',
      );

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Успешно забронировано!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Зона: ${widget.zone.name}'),
              Text('Место: ${widget.seat.label}'),
              Text(
                'Время: ${DateFormat('d MMMM, HH:mm', 'ru').format(booking.startTime.toLocal())} - '
                '${DateFormat('HH:mm', 'ru').format(booking.endTime.toLocal())}',
              ),
              Text('Стоимость: ${booking.priceDisplay}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ошибка бронирования'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMMM yyyy', 'ru');

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.seat.label} - выберите время'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Ошибка: $_error',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAvailability,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Выбор даты
                    InkWell(
                      onTap: _selectDate,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calendar_today),
                            const SizedBox(width: 8),
                            Text(
                              dateFormat.format(_selectedDate),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    // Слоты времени
                    Expanded(
                      child: _availability!.isEmpty
                          ? const Center(
                              child: Text('Нет доступных слотов'),
                            )
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                // Легенда
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildLegendItem(
                                      Colors.green,
                                      'Свободно',
                                    ),
                                    const SizedBox(width: 24),
                                    _buildLegendItem(
                                      Theme.of(context).colorScheme.primary,
                                      'Выбрано',
                                    ),
                                    const SizedBox(width: 24),
                                    _buildLegendItem(
                                      Colors.red,
                                      'Занято',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                // Сетка слотов
                                ..._availability!.map((availability) {
                                  return Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: availability.slots.map((slot) {
                                      final isSelected =
                                          _selectedSlots.contains(slot);
                                      final canSelect = _canSelectSlot(slot);

                                      return InkWell(
                                        onTap: slot.isFree
                                            ? () {
                                                setState(() {
                                                  if (isSelected) {
                                                    _selectedSlots.remove(slot);
                                                  } else if (canSelect) {
                                                    _selectedSlots.add(slot);
                                                  } else {
                                                    // Если нельзя добавить к текущему выбору,
                                                    // начинаем новый выбор
                                                    _selectedSlots.clear();
                                                    _selectedSlots.add(slot);
                                                  }
                                                });
                                              }
                                            : null,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: 80,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                            horizontal: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: !slot.isFree
                                                ? Colors.red[100]
                                                : isSelected
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .primaryContainer
                                                    : Colors.green[100],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: !slot.isFree
                                                  ? Colors.red
                                                  : isSelected
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                      : Colors.green,
                                              width: isSelected ? 2 : 1,
                                            ),
                                          ),
                                          child: Text(
                                            slot.timeRange,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: !slot.isFree
                                                  ? Colors.red[900]
                                                  : isSelected
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                      : Colors.green[900],
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                }).toList(),
                              ],
                            ),
                    ),
                    // Кнопка бронирования
                    if (_selectedSlots.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Выбрано ${_selectedSlots.length} ч.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      Text(
                                        'Стоимость: ${(_selectedSlots.length * widget.seat.hourlyPriceCents / 100).toStringAsFixed(0)} ₽',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                      ),
                                    ],
                                  ),
                                  ElevatedButton(
                                    onPressed: _book,
                                    child: const Text('Забронировать'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color, width: 1),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}