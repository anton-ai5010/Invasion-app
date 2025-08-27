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
  ZoneLayout? _layout;
  bool _isLoading = true;
  String? _error;
  Seat? _selectedSeat;

  @override
  void initState() {
    super.initState();
    _loadLayout();
  }

  Future<void> _loadLayout({bool force = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final layout = await api.getZoneLayout(widget.zone.id, force: force);
      if (!mounted) return;
      setState(() {
        _layout = layout;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.zone.name} - выберите место'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  message: _error!,
                  icon: Icons.error_outline,
                  onRetry: () => _loadLayout(force: true),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadLayout(force: true),
                  child: _layout!.seatsByRow.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.7,
                              child: const EmptyState(
                                message: 'В зоне пока нет мест',
                                icon: Icons.event_seat,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  // Легенда
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildLegendItem(
                                        Colors.green,
                                        'Доступно',
                                      ),
                                      const SizedBox(width: 24),
                                      _buildLegendItem(
                                        Theme.of(context).colorScheme.primary,
                                        'Выбрано',
                                      ),
                                      const SizedBox(width: 24),
                                      _buildLegendItem(
                                        Colors.grey,
                                        'Недоступно',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  // Схема зала
                                  ..._layout!.seatsByRow.entries.map((entry) {
                                    final row = entry.key;
                                    final seats = entry.value;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        children: [
                                          // Буква ряда
                                          SizedBox(
                                            width: 30,
                                            child: Text(
                                              row,
                                              style: Theme.of(context).textTheme.titleMedium,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Места
                                          Expanded(
                                            child: Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: seats.map((seat) {
                                                final isSelected = _selectedSeat?.id == seat.id;
                                                return InkWell(
                                                  onTap: seat.isActive
                                                      ? () {
                                                          setState(() {
                                                            _selectedSeat = seat;
                                                          });
                                                        }
                                                      : null,
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    width: 50,
                                                    height: 50,
                                                    decoration: BoxDecoration(
                                                      color: !seat.isActive
                                                          ? Colors.grey[300]
                                                          : isSelected
                                                              ? Theme.of(context)
                                                                  .colorScheme
                                                                  .primary
                                                              : Colors.green[300],
                                                      borderRadius:
                                                          BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: !seat.isActive
                                                            ? Colors.grey
                                                            : isSelected
                                                                ? Theme.of(context)
                                                                    .colorScheme
                                                                    .primary
                                                                : Colors.green,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.center,
                                                      children: [
                                                        Text(
                                                          seat.column ?? '',
                                                          style: TextStyle(
                                                            color: !seat.isActive
                                                                ? Colors.grey[600]
                                                                : isSelected
                                                                    ? Colors.white
                                                                    : Colors.black87,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                        Text(
                                                          seat.priceDisplay,
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: !seat.isActive
                                                                ? Colors.grey[600]
                                                                : isSelected
                                                                    ? Colors.white
                                                                    : Colors.black54,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                            ),
                            if (_selectedSeat != null)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
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
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Место ${_selectedSeat!.label}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                              Text(
                                                _selectedSeat!.priceDisplay,
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
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (context) => SlotsScreen(
                                                    zone: widget.zone,
                                                    seat: _selectedSeat!,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: const Text('Выбрать время'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
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
            color: color.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color, width: 2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}