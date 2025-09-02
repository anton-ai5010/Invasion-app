import 'package:flutter/material.dart';
import '../main.dart';
import '../models.dart';
import '../ui/widgets.dart';
import '../components/seat_map.dart';
import 'seat_slots.dart';

class ZoneLayoutScreen extends StatefulWidget {
  final Zone zone;
  const ZoneLayoutScreen({super.key, required this.zone});

  @override
  State<ZoneLayoutScreen> createState() => _ZoneLayoutScreenState();
}

class _ZoneLayoutScreenState extends State<ZoneLayoutScreen> {
  ZoneLayout? layout;
  String? error;
  bool loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load({bool force = false}) async {
    setState(() { loading = true; });
    try {
      final l = await api.getZoneLayout(widget.zone.id, force: force);
      setState(() { layout = l; error = null; });
    } catch (e) { setState(() => error = e.toString()); }
    finally { setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final l = layout;
    return Scaffold(
      appBar: AppBar(
        title: Text('Зона: ${widget.zone.name}'),
        actions: [ IconButton(onPressed: ()=>_load(force: true), icon: const Icon(Icons.refresh)) ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (l == null
              ? EmptyState(message: error ?? 'Не удалось загрузить', onRetry: _load)
              : RefreshIndicator(
                  onRefresh: () => _load(force: true),
                  child: SeatMap(
                    layout: l,
                    onSeatTap: (seat) => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SeatSlotsScreen(seat: seat))),
                  ),
                )),
    );
  }
}