import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/cycle_settings.dart';
import '../models/cycle_summary.dart';
import '../models/mood_entry.dart';
import '../models/period_log.dart';
import '../services/couple_id_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../utils/cycle_calculations.dart';
import '../widgets/cycle_calendar_card.dart';
import '../widgets/cycle_history_list.dart';
import '../widgets/empty_state.dart';
import '../widgets/kindness_card.dart';
import '../widgets/period_logger_card.dart';
import '../widgets/settings_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestore = FirestoreService();

  String? _coupleId;
  List<PeriodLog> _logs = [];
  CycleSettings _settings = const CycleSettings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final id = await CoupleIdService.instance.getOrCreate();
    await _firestore.initCouple(id);

    setState(() => _coupleId = id);

    // Listen to live Firestore streams
    _firestore.logsStream(id).listen((logs) {
      if (mounted) setState(() => _logs = logs);
    });
    _firestore.settingsStream(id).listen((s) {
      if (mounted) {
        setState(() {
          _settings = s;
          _loading = false;
        });
      }
    });

    await NotificationService.instance.init();
  }

  // ── Write helpers ─────────────────────────────────────────────────────────

  Future<void> _logPeriodStart() async {
    if (_coupleId == null) return;
    final today = toIsoDate(DateTime.now());

    // Dedup: don't create a duplicate for the same start date
    if (_logs.any((l) => l.startDate == today)) return;

    final newLog = PeriodLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startDate: today,
    );
    final updated = [newLog, ..._logs];
    await _firestore.saveLogs(_coupleId!, updated);

    // Notify partner
    if (_settings.notificationsEnabled) {
      await NotificationService.instance
          .notifyPeriodStarted(_settings.partnerName);
    }
  }

  Future<void> _logPeriodEnd() async {
    if (_coupleId == null) return;
    final activeLog = _activePeriod;
    if (activeLog == null) return;

    final today = toIsoDate(DateTime.now());
    final updated = _logs
        .map((l) => l.id == activeLog.id ? l.copyWith(endDate: today) : l)
        .toList();
    await _firestore.saveLogs(_coupleId!, updated);

    if (_settings.notificationsEnabled) {
      await NotificationService.instance
          .notifyPeriodEnded(_settings.partnerName);
    }
  }

  Future<void> _saveMood(MoodEntry entry) async {
    if (_coupleId == null) return;
    final activeLog = _activePeriod;
    if (activeLog == null) return;

    final updatedMoods = [
      ...activeLog.moods.where((m) => m.date != entry.date),
      entry,
    ];
    final updated = _logs
        .map((l) =>
            l.id == activeLog.id ? l.copyWith(moods: updatedMoods) : l)
        .toList();
    await _firestore.saveLogs(_coupleId!, updated);
  }

  Future<void> _deleteLog(String id) async {
    if (_coupleId == null) return;
    final updated = _logs.where((l) => l.id != id).toList();
    await _firestore.saveLogs(_coupleId!, updated);
  }

  Future<void> _saveSettings(CycleSettings settings) async {
    if (_coupleId == null) return;
    await _firestore.saveSettings(_coupleId!, settings);

    // Schedule upcoming notifications
    if (settings.notificationsEnabled) {
      final summary = computeCycleSummary(_logs, settings);
      await NotificationService.instance
          .schedulePeriodSoonReminder(summary.nextPeriodDate);
      await NotificationService.instance
          .scheduleFertileWindowReminder(summary.fertileWindowStart);
    }
  }

  // ── Derived state ─────────────────────────────────────────────────────────

  PeriodLog? get _activePeriod {
    try {
      return _logs.firstWhere((l) => l.isActive);
    } catch (_) {
      return null;
    }
  }

  CycleSummary get _summary => computeCycleSummary(_logs, _settings);

  // ── UI ────────────────────────────────────────────────────────────────────

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SettingsPanel(
        settings: _settings,
        coupleId: _coupleId ?? '',
        onSave: _saveSettings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final summary = _summary;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App bar
            SliverAppBar(
              backgroundColor: const Color(0xFFF9FAFB),
              floating: true,
              pinned: false,
              elevation: 0,
              title: const Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.heartPulse,
                    size: 18,
                    color: Color(0xFFE11D48),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'teamPeriod',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.gear, size: 18),
                  onPressed: _openSettings,
                  tooltip: 'Settings',
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Hero calendar card
                  CycleCalendarCard(summary: summary),
                  const SizedBox(height: 16),

                  // Kindness card for partner
                  KindnessCard(
                    summary: summary,
                    activePeriod: _activePeriod,
                    partnerName: _settings.partnerName,
                  ),
                  const SizedBox(height: 16),

                  // Period logger (start/end + mood)
                  PeriodLoggerCard(
                    activePeriod: _activePeriod,
                    onPeriodStart: _logPeriodStart,
                    onPeriodEnd: _logPeriodEnd,
                    onMoodSaved: _saveMood,
                  ),
                  const SizedBox(height: 24),

                  // History
                  if (_logs.isEmpty)
                    const EmptyState(
                      icon: Icons.calendar_month_outlined,
                      title: 'No cycles logged yet',
                      subtitle: 'Tap "Period Started" to begin tracking',
                    )
                  else
                    CycleHistoryList(
                      logs: _logs,
                      onDelete: _deleteLog,
                    ),

                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
