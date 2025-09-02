import 'package:flutter/material.dart';
import '../models.dart';
import '../ui/theme.dart';

class SeatMap extends StatelessWidget {
  final ZoneLayout layout;
  final void Function(Seat seat) onSeatTap;

  const SeatMap({super.key, required this.layout, required this.onSeatTap});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: layout.rows.length,
      itemBuilder: (_, i) {
        final row = layout.rows[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ряд ${row.row}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: row.seats.map((s) => _SeatTile(seat: s, onTap: ()=>onSeatTap(s))).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SeatTile extends StatelessWidget {
  final Seat seat;
  final VoidCallback onTap;
  const _SeatTile({required this.seat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isVip = seat.seatType == 'vip';
    final bg = isVip ? const Color(0xFF22183B) : const Color(0xFF1B1F26);
    final border = isVip ? IUTheme.primary : const Color(0xFF303744);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 76, height: 64,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.2),
          boxShadow: isVip ? const [BoxShadow(color: Color(0x447A4DD8), blurRadius: 16, spreadRadius: 1)] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(seat.label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${(seat.hourlyPriceCents / 100).toStringAsFixed(0)} ₽/ч', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}