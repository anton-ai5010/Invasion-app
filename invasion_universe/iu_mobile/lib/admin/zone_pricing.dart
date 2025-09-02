import 'package:flutter/material.dart';
import '../main.dart';
import '../models.dart';

class ZonePricingScreen extends StatefulWidget {
  final List<Zone> zones;

  const ZonePricingScreen({super.key, required this.zones});

  @override
  State<ZonePricingScreen> createState() => _ZonePricingScreenState();
}

class _ZonePricingScreenState extends State<ZonePricingScreen> {
  int? _zoneId;
  final _rowController = TextEditingController(text: 'A');
  final _priceController = TextEditingController(text: '300');
  String _seatType = 'keep';
  bool? _isActive;
  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    if (widget.zones.isNotEmpty) _zoneId = widget.zones.first.id;
  }

  @override
  void dispose() {
    _rowController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    if (_zoneId == null) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final rub = int.tryParse(_priceController.text.trim());
      final type = (_seatType == 'keep') ? null : _seatType;
      final res = await api.adminUpdateRowPrice(
        zoneId: _zoneId!,
        row: _rowController.text.trim().toUpperCase(),
        hourlyPriceRub: rub,
        seatType: type,
        isActive: _isActive,
      );
      setState(() => _msg = 'Обновлено: ${res.updated} мест');
    } catch (e) {
      setState(() => _msg = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Цены по ряду')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Зона: '),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      value: _zoneId,
                      items: widget.zones
                          .map((z) => DropdownMenuItem(
                                value: z.id,
                                child: Text('${z.name} (${z.code})'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _zoneId = v),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Ряд:'),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: _rowController,
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Цена ₽/ч:'),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Тип:'),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _seatType,
                      items: const [
                        DropdownMenuItem(
                          value: 'keep',
                          child: Text('не менять'),
                        ),
                        DropdownMenuItem(
                          value: 'standard',
                          child: Text('standard'),
                        ),
                        DropdownMenuItem(
                          value: 'vip',
                          child: Text('vip'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _seatType = v ?? 'keep'),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Активно:'),
                    const SizedBox(width: 8),
                    DropdownButton<bool?>(
                      value: _isActive,
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('не менять'),
                        ),
                        DropdownMenuItem(
                          value: true,
                          child: Text('вкл'),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Text('выкл'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _busy ? null : _apply,
                  child: const Text('Применить'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_msg != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _msg!.contains('Обновлено')
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _msg!.contains('Обновлено')
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                child: Text(_msg!),
              ),
          ],
        ),
      ),
    );
  }
}