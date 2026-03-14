import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cycle_settings.dart';
import '../models/period_log.dart';

/// All Firestore operations for the shared couple tracker.
///
/// Data is stored under a shared "couple document" identified by [coupleId].
/// Both partners use the same coupleId — share it out-of-band (e.g. in-app
/// settings or QR code).
///
/// Document structure:
///   /couples/{coupleId}
///     settings: { ... }
///     logs: [ { ... }, ... ]   ← stored as a single array field for simplicity
///
/// This keeps the data model flat and avoids subcollection complexity for
/// the small dataset sizes involved (~30–100 logs per couple).
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _coupleDoc(String coupleId) =>
      _db.collection('couples').doc(coupleId);

  // ── Real-time stream ──────────────────────────────────────────────────────

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

  /// Creates the couple document with default data if it doesn't exist yet.
  Future<void> initCouple(String coupleId) async {
    final doc = await _coupleDoc(coupleId).get();
    if (!doc.exists) {
      await _coupleDoc(coupleId).set({
        'logs': [],
        'settings': const CycleSettings().toJson(),
      });
    }
  }
}
