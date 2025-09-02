import 'package:flutter/material.dart';
import '../../main.dart';
import '../../models.dart';
import '../../widgets/empty_state.dart';
import '../slots/slots_screen.dart';

class ZoneLayoutScreen extends StatefulWidget {
  final Zone zone;
  const ZoneLayoutScreen({super.key, required this.zone});

  @override
  State<ZoneLayoutScreen> createState() => _ZoneLayoutScreenState();
}

class _ZoneLayoutScreenState extends State<ZoneLayoutScreen> {
  Future<ZoneLayout>? _layoutFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData({bool force = false}) {
    setState(() {
      _layoutFuture = api.getZoneLayout(widget.zone.id, force: force);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Зона: ${widget.zone.name}')),
      body: RefreshIndicator(
        onRefresh: () async => _loadData(force: true),
        child: FutureBuilder<ZoneLayout>(
          future: _layoutFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return EmptyState(message: snapshot.error.toString(), onRetry: () async => _loadData());
            }
            final layout = snapshot.data;
            if (layout == null || layout.rows.isEmpty) {
              return EmptyState(message: 'В этой зоне нет мест', onRetry: () async => _loadData());
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: layout.rows.map((row) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Wrap(spacing: 12, runSpacing: 12, children: [
                      for (final seat in row.seats) SeatChip(zone: widget.zone, seat: seat),
                    ]),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class SeatChip extends StatelessWidget {
  final Zone zone;
  final Seat seat;
  const SeatChip({super.key, required this.zone, required this.seat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVip = seat.seatType == 'vip';

    final chipColor = isVip ? theme.colorScheme.primary.withValues(alpha: 0.2) : theme.colorScheme.surface;
    final borderColor = isVip ? theme.colorScheme.primary : theme.colorScheme.surface.withValues(alpha: 0.5);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SlotsScreen(zone: zone, seat: seat),
        ));
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: isVip
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(seat.label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(seat.priceDisplay, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }
}
