import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/cycle_settings.dart';
import '../models/flow_entry.dart';
import '../models/mood_entry.dart';
import '../models/period_log.dart';
import '../models/sleep_entry.dart';
import '../models/temperature_entry.dart';
import '../services/couple_id_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/widget_data_service.dart';
import '../utils/cycle_calculations.dart';
import 'calendar_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'temperature_screen.dart';

/// Top-level navigation shell.
///
/// Owns all Firestore streams so data stays live across tab switches.
/// Uses [IndexedStack] to preserve scroll position per tab.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _firestore = FirestoreService();

  String? _coupleId;
  List<PeriodLog> _logs = [];
  CycleSettings _settings = const CycleSettings();
  List<TemperatureEntry> _temperatures = [];
  List<SleepEntry> _sleep = [];
  Map<String, int> _waterIntake = {};
  bool _loading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final id = await CoupleIdService.instance.getOrCreate();
    await _firestore.initCouple(id);
    if (!mounted) return;
    setState(() => _coupleId = id);

    _firestore.logsStream(id).listen((logs) {
      if (mounted) {
        setState(() => _logs = logs);
        _updateWidget(logs: logs, settings: _settings);
      }
    });
    _firestore.settingsStream(id).listen((s) {
      if (mounted) {
        setState(() {
          _settings = s;
          _loading = false;
        });
        _updateWidget(logs: _logs, settings: s);
      }
    });
    _firestore.temperatureStream(id).listen((temps) {
      if (mounted) setState(() => _temperatures = temps);
    });
    _firestore.sleepStream(id).listen((sleep) {
      if (mounted) setState(() => _sleep = sleep);
    });
    _firestore.waterIntakeStream(id).listen((intake) {
      if (mounted) setState(() => _waterIntake = intake);
    });

    // Listen for cross-device push events from the partner's device.
    _firestore.pendingEventsStream(id).listen((events) async {
      if (events.isEmpty || !mounted) return;
      for (final event in events) {
        await NotificationService.instance
            .handleRemoteEvent(event, _settings.partnerName);
      }
      // Clear after consuming so notifications don't repeat.
      await _firestore.clearPendingEvents(id);
    });

    await NotificationService.instance.init();
  }

  // ── Write helpers ──────────────────────────────────────────────────────────

  Future<void> _logPeriodStart() async {
    if (_coupleId == null) return;
    final today = toIsoDate(DateTime.now());
    if (_logs.any((l) => l.startDate == today)) return;

    final newLog = PeriodLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startDate: today,
    );
    await _firestore.saveLogs(_coupleId!, [newLog, ..._logs]);

    if (_settings.notificationsEnabled) {
      await NotificationService.instance
          .notifyPeriodStarted(_settings.partnerName);
      // Push event for partner's device.
      await _firestore.pushEvent(_coupleId!, 'period_started');
    }
  }

  Future<void> _logPeriodEnd() async {
    if (_coupleId == null) return;
    final active = _activePeriod;
    if (active == null) return;

    final today = toIsoDate(DateTime.now());
    final updated =
        _logs.map((l) => l.id == active.id ? l.copyWith(endDate: today) : l).toList();
    await _firestore.saveLogs(_coupleId!, updated);

    if (_settings.notificationsEnabled) {
      await NotificationService.instance
          .notifyPeriodEnded(_settings.partnerName);
      // Push event for partner's device.
      await _firestore.pushEvent(_coupleId!, 'period_ended');
    }
  }

  Future<void> _saveMood(MoodEntry entry) async {
    if (_coupleId == null) return;
    final active = _activePeriod;
    if (active == null) return;

    final updatedMoods = [
      ...active.moods.where((m) => m.date != entry.date),
      entry,
    ];
    final updated = _logs
        .map((l) => l.id == active.id ? l.copyWith(moods: updatedMoods) : l)
        .toList();
    await _firestore.saveLogs(_coupleId!, updated);
  }

  Future<void> _saveFlow(FlowEntry entry) async {
    if (_coupleId == null) return;
    final active = _activePeriod;
    if (active == null) return;

    final updatedFlows = [
      ...active.flows.where((f) => f.date != entry.date),
      entry,
    ];
    final updated = _logs
        .map((l) => l.id == active.id ? l.copyWith(flows: updatedFlows) : l)
        .toList();
    await _firestore.saveLogs(_coupleId!, updated);
  }

  Future<void> _deleteLog(String id) async {
    if (_coupleId == null) return;
    await _firestore.saveLogs(
        _coupleId!, _logs.where((l) => l.id != id).toList());
  }

  Future<void> _saveSettings(CycleSettings settings) async {
    if (_coupleId == null) return;
    await _firestore.saveSettings(_coupleId!, settings);

    if (settings.notificationsEnabled) {
      final summary = computeCycleSummary(_logs, settings);
      await NotificationService.instance
          .schedulePeriodSoonReminder(summary.nextPeriodDate);
      await NotificationService.instance
          .scheduleFertileWindowReminder(summary.fertileWindowStart);
    }

    // Schedule or cancel pill reminder based on updated settings.
    if (settings.pillReminderEnabled) {
      await NotificationService.instance.schedulePillReminder(
        settings.pillReminderHour,
        settings.pillReminderMinute,
      );
    } else {
      await NotificationService.instance.cancelPillReminder();
    }
  }

  Future<void> _saveTemperature(TemperatureEntry entry) async {
    if (_coupleId == null) return;
    final existing = _temperatures.any((t) => t.id == entry.id);
    final updated = existing
        ? _temperatures.map((t) => t.id == entry.id ? entry : t).toList()
        : [entry, ..._temperatures];
    await _firestore.saveTemperatures(_coupleId!, updated);
  }

  Future<void> _deleteTemperature(String id) async {
    if (_coupleId == null) return;
    await _firestore.saveTemperatures(
        _coupleId!, _temperatures.where((t) => t.id != id).toList());
  }

  Future<void> _saveSleep(SleepEntry entry) async {
    if (_coupleId == null) return;
    final existing = _sleep.any((s) => s.date == entry.date);
    final updated = existing
        ? _sleep.map((s) => s.date == entry.date ? entry : s).toList()
        : [entry, ..._sleep];
    await _firestore.saveSleep(_coupleId!, updated);
  }

  Future<void> _saveWaterIntake(String date, int ml) async {
    if (_coupleId == null) return;
    final updated = Map<String, int>.from(_waterIntake)..[date] = ml;
    await _firestore.saveWaterIntake(_coupleId!, updated);
  }

  // ── Widget data ────────────────────────────────────────────────────────────

  /// Writes a fresh snapshot to SharedPreferences for the native home-screen
  /// widget.  Called whenever logs or settings change from the Firestore stream.
  void _updateWidget({
    required List<PeriodLog> logs,
    required CycleSettings settings,
  }) {
    final summary = computeCycleSummary(logs, settings);
    final active = _activePeriod;
    final today = DateTime.now();

    int cycleDay = 0;
    if (active != null) {
      final start = DateTime.parse(active.startDate);
      cycleDay = today.difference(start).inDays + 1;
    }

    WidgetDataService.instance.update(
      nextPeriodDate: summary.nextPeriodDate,
      periodActive: active != null,
      currentCycleDay: cycleDay,
      avgCycleLength: settings.averageCycleLength,
      avgPeriodLength: computeAveragePeriodLength(logs),
    );
  }

  // ── Derived state ──────────────────────────────────────────────────────────

  PeriodLog? get _activePeriod {
    try {
      return _logs.firstWhere((l) => l.isActive);
    } catch (_) {
      return null;
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Wrap the entire shell in a locale override driven by saved settings.
    // This lets users switch between English and Japanese without restarting.
    return Localizations.override(
      context: context,
      locale: Locale(_settings.languageCode),
      delegates: const [AppLocalizations.delegate],
      child: _buildShell(context),
    );
  }

  Widget _buildShell(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(
            logs: _logs,
            settings: _settings,
            temperatures: _temperatures,
            sleep: _sleep,
            waterIntake: _waterIntake,
            coupleId: _coupleId ?? '',
            activePeriod: _activePeriod,
            onPeriodStart: _logPeriodStart,
            onPeriodEnd: _logPeriodEnd,
            onMoodSaved: _saveMood,
            onFlowSaved: _saveFlow,
            onDeleteLog: _deleteLog,
            onSaveSettings: _saveSettings,
            onSaveSleep: _saveSleep,
            onWaterIntakeChanged: _saveWaterIntake,
          ),
          CalendarScreen(logs: _logs, settings: _settings),
          TemperatureScreen(
            temperatures: _temperatures,
            logs: _logs,
            settings: _settings,
            onSave: _saveTemperature,
            onDelete: _deleteTemperature,
          ),
          HistoryScreen(
            logs: _logs,
            settings: _settings,
            sleep: _sleep,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: t.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: t.navCalendar,
          ),
          NavigationDestination(
            icon: const Icon(Icons.thermostat_outlined),
            selectedIcon: const Icon(Icons.thermostat),
            label: t.navTemperature,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: t.navHistory,
          ),
        ],
      ),
    );
  }
}
