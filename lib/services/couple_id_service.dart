import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Manages the shared coupleId stored locally on the device.
///
/// Both partners must use the same coupleId to share data via Firestore.
/// The first person to open the app generates a new UUID; they share it
/// with their partner via Settings → Share Couple ID.
class CoupleIdService {
  CoupleIdService._();
  static final CoupleIdService instance = CoupleIdService._();

  static const _key = 'couple_id';
  final _uuid = const Uuid();

  String? _cachedId;

  /// Returns the stored coupleId, generating one if none exists.
  Future<String> getOrCreate() async {
    if (_cachedId != null) return _cachedId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id == null || id.isEmpty) {
      id = _uuid.v4();
      await prefs.setString(_key, id);
    }
    _cachedId = id;
    return id;
  }

  /// Saves a partner-provided coupleId (replaces any existing one).
  Future<void> setId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, id);
    _cachedId = id;
  }

  /// Returns the coupleId if already loaded (null before [getOrCreate] is called).
  String? get cached => _cachedId;
}
