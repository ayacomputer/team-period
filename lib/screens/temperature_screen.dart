import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../models/cycle_settings.dart';
import '../models/period_log.dart';
import '../models/temperature_entry.dart';
import '../utils/cycle_calculations.dart';

/// BBT log screen: custom line chart + entry list + log sheet.
class TemperatureScreen extends StatefulWidget {
  const TemperatureScreen({
    super.key,
    required this.temperatures,
    required this.logs,
    required this.settings,
    required this.onSave,
    required this.onDelete,
  });

  final List<TemperatureEntry> temperatures;
  final List<PeriodLog> logs;
  final CycleSettings settings;
  final void Function(TemperatureEntry) onSave;
  final void Function(String id) onDelete;

  @override
  State<TemperatureScreen> createState() => _TemperatureScreenState();
}

class _TemperatureScreenState extends State<TemperatureScreen> {
  void _openLogSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LogTempSheet(
        onSave: (entry) {
          widget.onSave(entry);
          Navigator.pop(context);
        },
        t: AppLocalizations.of(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final summary = computeCycleSummary(widget.logs, widget.settings);

    // Newest-first for the list; chart widget handles its own ordering.
    final reversedTemps = [...widget.temperatures]
      ..sort((a, b) => b.datetime.compareTo(a.datetime));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(t.temperatureTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: t.logTemp,
            onPressed: _openLogSheet,
          ),
        ],
      ),
      body: widget.temperatures.isEmpty
          ? _EmptyTempState(t: t, onLog: _openLogSheet)
          : Column(
              children: [
                // Chart occupies roughly half the screen
                SizedBox(
                  height: 220,
                  child: _TempGraphWidget(
                    temperatures: widget.temperatures,
                    predictedOvulation: summary.ovulationDate,
                    t: t,
                  ),
                ),
                const Divider(height: 1),
                // Log list fills the rest
                Expanded(
                  child: _TempLogListWidget(
                    temperatures: reversedTemps,
                    onDelete: widget.onDelete,
                    t: t,
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyTempState extends StatelessWidget {
  const _EmptyTempState({required this.t, required this.onLog});
  final AppLocalizations t;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.thermostat_outlined,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(t.noTempData,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 8),
          Text(t.noTempSubtitle,
              style: TextStyle(
                  color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: Text(t.logTemp),
            onPressed: onLog,
          ),
        ],
      ),
    );
  }
}

// ── Temperature graph ─────────────────────────────────────────────────────────

class _TempGraphWidget extends StatelessWidget {
  const _TempGraphWidget({
    required this.temperatures,
    required this.predictedOvulation,
    required this.t,
  });

  final List<TemperatureEntry> temperatures;
  final DateTime predictedOvulation;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    // Show last 30 readings (or all if fewer).
    final sorted = [...temperatures]
      ..sort((a, b) => a.datetime.compareTo(b.datetime));
    final display = sorted.length > 30
        ? sorted.sublist(sorted.length - 30)
        : sorted;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart,
                  size: 14, color: Color(0xFFE11D48)),
              const SizedBox(width: 4),
              Text(
                t.temperatureTitle,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Spacer(),
              _LegendDot(
                color: const Color(0xFF86EFAC),
                label: t.normalRange,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: CustomPaint(
              painter: _TempChartPainter(
                entries: display,
                predictedOvulation: predictedOvulation,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
      ],
    );
  }
}

/// Custom painter for the BBT line chart.
class _TempChartPainter extends CustomPainter {
  const _TempChartPainter({
    required this.entries,
    required this.predictedOvulation,
  });

  final List<TemperatureEntry> entries;
  final DateTime predictedOvulation;

  static const _rose = Color(0xFFE11D48);
  static const _violet = Color(0xFF7C3AED);
  static const _normalMin = 36.1;
  static const _normalMax = 37.2;

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.isEmpty) return;

    final temps = entries.map((e) => e.celsius).toList();
    final minTemp = temps.reduce(min) - 0.3;
    final maxTemp = temps.reduce(max) + 0.3;
    final range = maxTemp - minTemp;

    // Helpers to convert to canvas coordinates.
    double xOf(int i) =>
        (entries.length == 1)
            ? size.width / 2
            : i * (size.width / (entries.length - 1));
    double yOf(double temp) =>
        size.height - ((temp - minTemp) / range * size.height);

    // ── Normal BBT band (36.1–37.2°C) ─────────────────────────────────
    final bandPaint = Paint()
      ..color = const Color(0xFFBBF7D0).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final bandTop = yOf(_normalMax.clamp(minTemp, maxTemp));
    final bandBottom = yOf(_normalMin.clamp(minTemp, maxTemp));
    if (bandBottom > bandTop) {
      canvas.drawRect(
        Rect.fromLTRB(0, bandTop, size.width, bandBottom),
        bandPaint,
      );
    }

    // ── Predicted ovulation vertical dashed line ───────────────────────
    if (entries.isNotEmpty) {
      final firstDate = fromIsoDate(entries.first.dateOnly);
      final lastDate = fromIsoDate(entries.last.dateOnly);
      final totalDays = daysBetween(firstDate, lastDate);
      final ovDays = daysBetween(firstDate, predictedOvulation);

      if (ovDays >= 0 && ovDays <= totalDays && totalDays > 0) {
        final ovX = ovDays / totalDays * size.width;
        _drawDashedVertical(canvas, size, ovX, _violet);
      }
    }

    // ── Grid lines (horizontal, every 0.5°C) ──────────────────────────
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..strokeWidth = 0.5;

    var gridTemp = (minTemp * 2).ceil() / 2.0; // round to nearest 0.5
    while (gridTemp <= maxTemp) {
      final y = yOf(gridTemp);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: gridTemp.toStringAsFixed(1),
          style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - 10));
      gridTemp += 0.5;
    }

    // ── Line + dots ────────────────────────────────────────────────────
    if (entries.length > 1) {
      final linePaint = Paint()
        ..color = _rose
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path();
      for (var i = 0; i < entries.length; i++) {
        final x = xOf(i);
        final y = yOf(entries[i].celsius);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, linePaint);
    }

    // Dots
    final dotPaint = Paint()
      ..color = _rose
      ..style = PaintingStyle.fill;
    final dotOutline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (var i = 0; i < entries.length; i++) {
      final x = xOf(i);
      final y = yOf(entries[i].celsius);
      canvas.drawCircle(Offset(x, y), 5, dotOutline);
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
    }
  }

  void _drawDashedVertical(
      Canvas canvas, Size size, double x, Color color) {
    const dashHeight = 6.0;
    const gapHeight = 4.0;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;

    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, min(y + dashHeight, size.height)),
        paint,
      );
      y += dashHeight + gapHeight;
    }
  }

  @override
  bool shouldRepaint(_TempChartPainter old) =>
      old.entries != entries ||
      old.predictedOvulation != predictedOvulation;
}

// ── Log list ──────────────────────────────────────────────────────────────────

class _TempLogListWidget extends StatelessWidget {
  const _TempLogListWidget({
    required this.temperatures,
    required this.onDelete,
    required this.t,
  });

  final List<TemperatureEntry> temperatures;
  final void Function(String) onDelete;
  final AppLocalizations t;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: temperatures.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.grey.shade100),
      itemBuilder: (_, i) {
        final entry = temperatures[i];
        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.thermostat,
                color: Color(0xFFE11D48), size: 20),
          ),
          title: Text(
            '${entry.celsius.toStringAsFixed(1)} °C',
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15),
          ),
          subtitle: Text(
            '${entry.dateOnly}  ${entry.timeOnly}'
            '${entry.note != null ? '  •  ${entry.note}' : ''}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          trailing: IconButton(
            icon: Icon(Icons.delete_outline,
                size: 18, color: Colors.grey.shade400),
            tooltip: t.deleteEntry,
            onPressed: () => _confirmDelete(context, entry.id),
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).deleteEntry),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete(id);
            },
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFE11D48))),
          ),
        ],
      ),
    );
  }
}

// ── Log temperature sheet ─────────────────────────────────────────────────────

class _LogTempSheet extends StatefulWidget {
  const _LogTempSheet({required this.onSave, required this.t});
  final void Function(TemperatureEntry) onSave;
  final AppLocalizations t;

  @override
  State<_LogTempSheet> createState() => _LogTempSheetState();
}

class _LogTempSheetState extends State<_LogTempSheet> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  final _tempController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedTime = TimeOfDay.fromDateTime(now);
  }

  @override
  void dispose() {
    _tempController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  void _save() {
    final raw = _tempController.text.trim().replaceAll(',', '.');
    final celsius = double.tryParse(raw);
    if (celsius == null || celsius < 30 || celsius > 42) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid temperature (30–42 °C)')),
      );
      return;
    }

    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
    final datetime = '${dateStr}T$timeStr';

    widget.onSave(
      TemperatureEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        datetime: datetime,
        celsius: celsius,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final dateStr =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final timeStr =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),

            Text(
              t.logTemp,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),

            // Date + time row
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    label: t.dateLabel,
                    value: dateStr,
                    icon: Icons.calendar_today_outlined,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickerTile(
                    label: t.timeLabel,
                    value: timeStr,
                    icon: Icons.access_time_outlined,
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Temperature field
            Text(t.tempCelsius,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _tempController,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                hintText: '36.4',
                suffixText: '°C',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Note field
            Text(t.tempNote,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: t.tempNotePlaceholder,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(t.saveButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade500),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500)),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
