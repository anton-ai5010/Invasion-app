import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../models.dart';
import '../../notify.dart';
import '../../widgets/empty_state.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<Booking>? _bookings;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bookings = await api.getMyBookings();
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
      
      // Обновляем напоминания для активных броней
      for (final booking in bookings) {
        if (booking.status == 'pending' || booking.status == 'paid') {
          await Notifier.scheduleBookingReminder(
            bookingId: booking.id,
            startUtc: booking.startTime,
            title: 'Скоро бронь',
            body: 'Начало в ${DateFormat('HH:mm').format(booking.startTime.toLocal())}',
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelBooking(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отмена брони'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Вы действительно хотите отменить бронь?'),
            const SizedBox(height: 16),
            Text('Место: ${booking.seat?.label ?? ""}'),
            Text(
              'Время: ${DateFormat('d MMMM, HH:mm', 'ru').format(booking.startTime.toLocal())} - '
              '${DateFormat('HH:mm', 'ru').format(booking.endTime.toLocal())}',
            ),
            const SizedBox(height: 16),
            const Text(
              'Внимание: при отмене может быть начислен штраф!',
              style: TextStyle(color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Отменить бронь'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final cancelled = await api.cancelBooking(booking.id);
        if (!mounted) return;

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Бронь отменена'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Бронь успешно отменена.'),
                if (cancelled.penaltyCents > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Штраф: ${cancelled.penaltyDisplay}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );

        _loadBookings();
      } catch (e) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ошибка'),
            content: Text('Не удалось отменить бронь: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'paid':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Ожидает оплаты';
      case 'paid':
        return 'Оплачено';
      case 'completed':
        return 'Завершено';
      case 'cancelled':
        return 'Отменено';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои брони'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  message: _error!,
                  onRetry: _loadBookings,
                )
              : RefreshIndicator(
                  onRefresh: _loadBookings,
                  child: _bookings!.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.7,
                              child: const EmptyState(
                                message: 'У вас пока нет броней',
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _bookings!.length,
                        itemBuilder: (context, index) {
                          final booking = _bookings![index];
                          final dateFormat =
                              DateFormat('d MMMM yyyy, HH:mm', 'ru');
                          final isUpcoming = booking.startTime
                              .isAfter(DateTime.now());

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              children: [
                                ListTile(
                                  title: Text(
                                    '${booking.zone?.name ?? ""} - ${booking.seat?.label ?? ""}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        '${dateFormat.format(booking.startTime.toLocal())} - '
                                        '${DateFormat('HH:mm', 'ru').format(booking.endTime.toLocal())}',
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(
                                                      booking.status)
                                                  .withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              _getStatusText(booking.status),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _getStatusColor(
                                                    booking.status),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            booking.priceDisplay,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                          ),
                                        ],
                                      ),
                                      if (booking.status == 'cancelled' &&
                                          booking.penaltyCents > 0) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Штраф: ${booking.penaltyDisplay}',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: booking.canCancel && isUpcoming
                                      ? IconButton(
                                          icon: const Icon(Icons.cancel),
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                          onPressed: () =>
                                              _cancelBooking(booking),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}