import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cycle_settings.dart';
import '../models/period_log.dart';
import '../models/sleep_entry.dart';
import '../models/temperature_entry.dart';

/// All Firestore operations for the shared couple tracker.
///
/// Data is stored under a shared "couple document" identified by [coupleId].
/// Both partners use the same coupleId — share it out-of-band (e.g. in-app
/// settings or QR code).
///
/// Document structure:
///   /couples/{coupleId}
///     settings:        { ... }
///     logs:            [ { ... }, ... ]
///     temperatures:    [ { ... }, ... ]
///     sleep:           [ { ... }, ... ]
///     waterIntake:     { "YYYY-MM-DD": ml, ... }
///     pendingEvents:   [ { type, createdAt }, ... ]  ← for cross-device push
///
/// All arrays / maps are stored as top-level fields on the couple document to
/// keep the data model flat and avoid subcollection complexity.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _coupleDoc(String coupleId) =>
      _db.collection('couples').doc(coupleId);

  // ── Real-time streams ─────────────────────────────────────────────────────

  /// Emits the current [PeriodLog] list every time Firestore updates.
  Stream<List<PeriodLog>> logsStream(String coupleId) {
    return _coupleDoc(coupleId).snapshots().map((snap) {
      if (!snap.exists) return [];
      final data = snap.data()!;
      final rawLogs = data['logs'] as List<dynamic>? ?? [];
      return rawLogs
          .map((e) => PeriodLog.fromFirestore(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));
    });
  }

  /// Emits the current [CycleSettings] every time Firestore updates.
  Stream<CycleSettings> settingsStream(String coupleId) {
    return _coupleDoc(coupleId).snapshots().map((snap) {
      if (!snap.exists) return const CycleSettings();
      final data = snap.data()!;
      final raw = data['settings'] as Map<String, dynamic>?;
      return raw != null ? CycleSettings.fromJson(raw) : const CycleSettings();
    });
  }

  /// Emits the current [TemperatureEntry] list every time Firestore updates.
  /// Entries are sorted oldest-first for chart rendering.
  Stream<List<TemperatureEntry>> temperatureStream(String coupleId) {
    return _coupleDoc(coupleId).snapshots().map((snap) {
      if (!snap.exists) return [];
      final data = snap.data()!;
      final rawTemps = data['temperatures'] as List<dynamic>? ?? [];
      return rawTemps
          .map((e) =>
              TemperatureEntry.fromFirestore(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.datetime.compareTo(b.datetime));
    });
  }

  /// Emits the current [SleepEntry] list every time Firestore updates.
  Stream<List<SleepEntry>> sleepStream(String coupleId) {
    return _coupleDoc(coupleId).snapshots().map((snap) {
      if (!snap.exists) return [];
      final data = snap.data()!;
      final rawSleep = data['sleep'] as List<dynamic>? ?? [];
      return rawSleep
          .map((e) => SleepEntry.fromFirestore(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    });
  }

  /// Emits water intake map {"YYYY-MM-DD": ml} every time Firestore updates.
  Stream<Map<String, int>> waterIntakeStream(String coupleId) {
    return _coupleDoc(coupleId).snapshots().map((snap) {
      if (!snap.exists) return {};
      final data = snap.data()!;
      final raw = data['waterIntake'] as Map<String, dynamic>? ?? {};
      return raw.map((k, v) => MapEntry(k, (v as num).toInt()));
    });
  }

  /// Emits pending push-notification events (cross-device FCM simulation).
  Stream<List<Map<String, dynamic>>> pendingEventsStream(String coupleId) {
    return _coupleDoc(coupleId).snapshots().map((snap) {
      if (!snap.exists) return [];
      final data = snap.data()!;
      final raw = data['pendingEvents'] as List<dynamic>? ?? [];
      return raw.cast<Map<String, dynamic>>();
    });
  }

  // ── Writes ────────────────────────────────────────────────────────────────

  Future<void> saveLogs(String coupleId, List<PeriodLog> logs) async {
    await _coupleDoc(coupleId).set(
      {'logs': logs.map((l) => l.toFirestore()).toList()},
      SetOptions(merge: true),
    );
  }

  Future<void> saveSettings(String coupleId, CycleSettings settings) async {
    await _coupleDoc(coupleId).set(
      {'settings': settings.toJson()},
      SetOptions(merge: true),
    );
  }

  Future<void> saveTemperatures(
    String coupleId,
    List<TemperatureEntry> temperatures,
  ) async {
    await _coupleDoc(coupleId).set(
      {'temperatures': temperatures.map((t) => t.toFirestore()).toList()},
      SetOptions(merge: true),
    );
  }

  Future<void> saveSleep(
    String coupleId,
    List<SleepEntry> entries,
  ) async {
    await _coupleDoc(coupleId).set(
      {'sleep': entries.map((e) => e.toFirestore()).toList()},
      SetOptions(merge: true),
    );
  }

  Future<void> saveWaterIntake(
    String coupleId,
    Map<String, int> intake,
  ) async {
    await _coupleDoc(coupleId).set(
      {'waterIntake': intake},
      SetOptions(merge: true),
    );
  }

  /// Appends a pending event (e.g. period_started) so the partner device
  /// can pick it up via [pendingEventsStream] and show a local notification.
  ///
  /// Each event is a map with at least `type` and `createdAt` fields.
  /// The partner clears it after consuming via [clearPendingEvents].
  Future<void> pushEvent(
    String coupleId,
    String type, {
    Map<String, dynamic> extra = const {},
  }) async {
    final event = {
      'type': type,
      'createdAt': DateTime.now().toIso8601String(),
      ...extra,
    };
    await _coupleDoc(coupleId).set(
      {
        'pendingEvents': FieldValue.arrayUnion([event]),
      },
      SetOptions(merge: true),
    );
  }

  /// Removes all pending events from the shared document.
  Future<void> clearPendingEvents(String coupleId) async {
    await _coupleDoc(coupleId).set(
      {'pendingEvents': []},
      SetOptions(merge: true),
    );
  }

  /// Creates the couple document with default data if it doesn't exist yet.
  Future<void> initCouple(String coupleId) async {
    final doc = await _coupleDoc(coupleId).get();
    if (!doc.exists) {
      await _coupleDoc(coupleId).set({
        'logs': [],
        'settings': const CycleSettings().toJson(),
        'temperatures': [],
        'sleep': [],
        'waterIntake': {},
        'pendingEvents': [],
      });
    }
  }
}
