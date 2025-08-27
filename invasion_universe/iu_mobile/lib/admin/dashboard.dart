import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models.dart';
import 'zone_pricing.dart';

class AdminDashboard extends StatefulWidget {
  final VoidCallback? onLogout;

  const AdminDashboard({super.key, this.onLogout});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Zone>? _zones;
  int? _selectedZoneId;
  List<AdminBooking>? _items;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _zones = await api.getZones();
      await _loadToday();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadToday() async {
    _items = await api.adminBookingsToday(zoneId: _selectedZoneId);
    setState(() {});
  }

  Future<void> _act(String action, AdminBooking b) async {
    try {
      switch (action) {
        case 'paid':
          await api.adminMarkPaid(b.id);
          break;
        case 'complete':
          await api.adminComplete(b.id);
          break;
        case 'no_show':
          await api.adminNoShow(b.id);
          break;
      }
      await _loadToday();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OK: $action')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final z = _zones;
    final list = _items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invasion Admin'),
        actions: [
          IconButton(
            tooltip: 'Изменить цены по ряду',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ZonePricingScreen(zones: z ?? []),
              ),
            ),
            icon: const Icon(Icons.price_change),
          ),
          IconButton(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh),
          ),
          if (widget.onLogout != null)
            IconButton(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
              tooltip: 'Выход',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Text('Зона:'),
                          const SizedBox(width: 8),
                          DropdownButton<int?>(
                            value: _selectedZoneId,
                            hint: const Text('Все'),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Все'),
                              ),
                              ...?z?.map((e) => DropdownMenuItem(
                                    value: e.id,
                                    child: Text('${e.name} (${e.code})'),
                                  ))
                            ],
                            onChanged: (v) {
                              setState(() => _selectedZoneId = v);
                              _loadToday();
                            },
                          ),
                          const Spacer(),
                          Text(
                            DateFormat('dd.MM.yyyy').format(DateTime.now()),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: list == null
                          ? const Center(child: CircularProgressIndicator())
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('ID')),
                                  DataColumn(label: Text('Статус')),
                                  DataColumn(label: Text('Время')),
                                  DataColumn(label: Text('Место')),
                                  DataColumn(label: Text('Email')),
                                  DataColumn(label: Text('Действия')),
                                ],
                                rows: list.map((b) {
                                  final t =
                                      '${DateFormat('HH:mm').format(b.startTime.toLocal())}-${DateFormat('HH:mm').format(b.endTime.toLocal())}';
                                  return DataRow(cells: [
                                    DataCell(Text('#${b.id}')),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(b.status)
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          b.status,
                                          style: TextStyle(
                                            color: _getStatusColor(b.status),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(t)),
                                    DataCell(Text('${b.seatLabel} (Z${b.zoneId})')),
                                    DataCell(Text(b.userEmail)),
                                    DataCell(Row(
                                      children: [
                                        if (b.status == 'pending') ...[
                                          TextButton(
                                            onPressed: () => _act('paid', b),
                                            child: const Text('paid'),
                                          ),
                                          const SizedBox(width: 4),
                                          TextButton(
                                            onPressed: () => _act('no_show', b),
                                            child: const Text('no_show'),
                                          ),
                                        ],
                                        if (b.status == 'paid')
                                          TextButton(
                                            onPressed: () => _act('complete', b),
                                            child: const Text('complete'),
                                          ),
                                      ],
                                    )),
                                  ]);
                                }).toList(),
                              ),
                            ),
                    )
                  ],
                )),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'paid':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'no_show':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}