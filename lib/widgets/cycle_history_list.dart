import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../models/mood_entry.dart';
import '../models/period_log.dart';
import '../utils/cycle_calculations.dart';

/// Scrollable list of past cycle logs, newest first.
class CycleHistoryList extends StatelessWidget {
  const CycleHistoryList({
    super.key,
    required this.logs,
    required this.onDelete,
  });

  final List<PeriodLog> logs;
  final void Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = [...logs]
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cycle History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sorted.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final log = sorted[index];
            final prevLog =
                index < sorted.length - 1 ? sorted[index + 1] : null;
            return _CycleLogTile(
              log: log,
              prevLog: prevLog,
              onDelete: () => onDelete(log.id),
            );
          },
        ),
      ],
    );
  }
}

class _CycleLogTile extends StatelessWidget {
  const _CycleLogTile({
    required this.log,
    required this.prevLog,
    required this.onDelete,
  });

  final PeriodLog log;
  final PeriodLog? prevLog;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final start = fromIsoDate(log.startDate);
    final end = log.endDate != null ? fromIsoDate(log.endDate!) : null;
    final duration = end != null ? daysBetween(start, end) + 1 : null;

    int? cycleGap;
    if (prevLog != null) {
      cycleGap = daysBetween(
        fromIsoDate(prevLog!.startDate),
        start,
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FaIcon(
                FontAwesomeIcons.droplet,
                size: 14,
                color: Color(0xFFE11D48),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _dateRange(start, end),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              if (log.isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFE11D48),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              _DeleteButton(onDelete: onDelete),
            ],
          ),

          const SizedBox(height: 8),

          // Stats chips
          Wrap(
            spacing: 8,
            children: [
              if (duration != null)
                _StatChip(
                  icon: FontAwesomeIcons.clock,
                  label: '$duration day${duration == 1 ? '' : 's'}',
                ),
              if (cycleGap != null)
                _StatChip(
                  icon: FontAwesomeIcons.arrowsRotate,
                  label: '$cycleGap-day cycle',
                ),
            ],
          ),

          // Mood entries
          if (log.moods.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: log.moods.map((m) => _MoodChip(entry: m)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _dateRange(DateTime start, DateTime? end) {
    final fmt = DateFormat('MMM d');
    if (end == null) return '${fmt.format(start)} → ongoing';
    if (start.year == end.year && start.month == end.month) {
      return '${DateFormat('MMM d').format(start)}–${DateFormat('d').format(end)}';
    }
    return '${fmt.format(start)} – ${fmt.format(end)}';
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FaIcon(icon, size: 11, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({required this.entry});
  final MoodEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(_moodIcon(entry.mood), size: 11, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            DateFormat('d MMM').format(fromIsoDate(entry.date)),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          if (entry.conditions.isNotEmpty) ...[
            Text(
              ' · ${entry.conditions.take(2).join(', ')}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }

  IconData _moodIcon(Mood mood) {
    switch (mood) {
      case Mood.great:
        return FontAwesomeIcons.faceGrinStars;
      case Mood.good:
        return FontAwesomeIcons.faceSmile;
      case Mood.okay:
        return FontAwesomeIcons.faceMeh;
      case Mood.low:
        return FontAwesomeIcons.faceFrown;
      case Mood.rough:
        return FontAwesomeIcons.faceSadTear;
    }
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onDelete});
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _confirm(context),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: FaIcon(
          FontAwesomeIcons.trashCan,
          size: 14,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }

  void _confirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This cycle log will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
