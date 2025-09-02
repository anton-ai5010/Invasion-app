import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import '../api.dart';
import '../models.dart';
import '../ui/theme.dart';
import 'zone_pricing.dart';

class AdminDashboard extends StatefulWidget {
  final Api api;
  final VoidCallback? onLogout;

  const AdminDashboard({super.key, required this.api, this.onLogout});

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
      _zones = await widget.api.getZones();
      await _loadToday();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadToday() async {
    _items = await widget.api.adminBookingsToday(zoneId: _selectedZoneId);
    setState(() {});
  }

  Future<void> _act(String action, AdminBooking b) async {
    try {
      switch (action) {
        case 'paid':
          await widget.api.adminMarkPaid(b.id);
          break;
        case 'complete':
          await widget.api.adminComplete(b.id);
          break;
        case 'no_show':
          await widget.api.adminNoShow(b.id);
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
                          : DataTable2(
                              headingRowHeight: 44,
                              dataRowHeight: 48,
                              columnSpacing: 12,
                              fixedTopRows: 1,
                              columns: const [
                                DataColumn2(label: Text('ID'), size: ColumnSize.S),
                                DataColumn2(label: Text('Статус'), size: ColumnSize.S),
                                DataColumn2(label: Text('Время'), size: ColumnSize.M),
                                DataColumn2(label: Text('Место'), size: ColumnSize.S),
                                DataColumn2(label: Text('Email'), size: ColumnSize.L),
                                DataColumn2(label: Text('Действия'), size: ColumnSize.M),
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
                    )
                  ],
                )),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return IUTheme.warn;
      case 'paid':
        return IUTheme.success;
      case 'completed':
        return IUTheme.secondary;
      case 'no_show':
        return IUTheme.danger;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}