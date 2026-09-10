import 'dart:math' as math;

class DistanceCache {
  static final Map<String, _CachedDistance> _cache = {};
  static final Map<String, Future<String?>> _pendingRequests = {};
  static const Duration ttl = Duration(days: 30);
  static const int _maxCacheSize = 1000;

  /// Two points within this distance are considered "the same".
  static const double _proximityMeters = 50;

  // ──────────────────────────────────────────────────────────────────────
  // Exact key (rounded to ~11m precision)
  // ──────────────────────────────────────────────────────────────────────
  static String _key(String lat1, String lng1, String lat2, String lng2) {
    String r(String v) => double.parse(v).toStringAsFixed(4);
    return '${r(lat1)},${r(lng1)}|${r(lat2)},${r(lng2)}';
  }

  // ──────────────────────────────────────────────────────────────────────
  // Lookup: exact match first, then proximity match
  // ──────────────────────────────────────────────────────────────────────
  static String? get(String lat1, String lng1, String lat2, String lng2) {
    // ── 1. Exact key match (fastest) ──────────────────────────────────
    final key = _key(lat1, lng1, lat2, lng2);
    final item = _cache[key];
    if (item != null) {
      if (DateTime.now().difference(item.savedAt) > ttl) {
        _cache.remove(key);
      } else {
        return item.value;
      }
    }

    // ── 2. Proximity match (slower, but saves API calls) ──────────────
    return _getByProximity(lat1, lng1, lat2, lng2);
  }

  static String? _getByProximity(
      String lat1, String lng1, String lat2, String lng2) {
    final oLat = double.parse(lat1);
    final oLng = double.parse(lng1);
    final dLat = double.parse(lat2);
    final dLng = double.parse(lng2);
    final now = DateTime.now();

    String? bestValue;
    double bestScore = double.infinity;
    final keysToDelete = <String>[];

    for (final entry in _cache.entries) {
      final cached = entry.value;

      // Skip expired entries
      if (now.difference(cached.savedAt) > ttl) {
        keysToDelete.add(entry.key);
        continue;
      }

      // Check if the ORIGIN (restaurant) is within proximity
      final originDist = _haversine(oLat, oLng, cached.lat1, cached.lng1);
      if (originDist > _proximityMeters) continue;

      // Check if the DESTINATION (customer) is within proximity
      final destDist = _haversine(dLat, dLng, cached.lat2, cached.lng2);
      if (destDist > _proximityMeters) continue;

      // Prefer the closest overall match
      final score = originDist + destDist;
      if (score < bestScore) {
        bestScore = score;
        bestValue = cached.value;
      }
    }

    // Clean up expired keys found during iteration
    for (final k in keysToDelete) {
      _cache.remove(k);
    }

    return bestValue;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Store a value (with its coordinates for future proximity checks)
  // ──────────────────────────────────────────────────────────────────────
  static void set(
      String lat1, String lng1, String lat2, String lng2, String value) {
    final key = _key(lat1, lng1, lat2, lng2);

    // Evict oldest entry if cache is full
    if (_cache.length >= _maxCacheSize && !_cache.containsKey(key)) {
      _cache.remove(_cache.keys.first);
    }

    _cache[key] = _CachedDistance(
      value,
      DateTime.now(),
      double.parse(lat1),
      double.parse(lng1),
      double.parse(lat2),
      double.parse(lng2),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Concurrency-safe fetch
  // ──────────────────────────────────────────────────────────────────────
  static Future<String?> getOrFetch(String lat1, String lng1, String lat2,
      String lng2, Future<String?> Function() fetchFunction) async {
    final key = _key(lat1, lng1, lat2, lng2);

    // 1. Cache hit (exact or proximity)
    final cached = get(lat1, lng1, lat2, lng2);
    if (cached != null) return cached;

    // 2. Request already in-flight
    if (_pendingRequests.containsKey(key)) {
      return _pendingRequests[key];
    }

    // 3. Call API
    final future = fetchFunction().then((value) {
      if (value != null) set(lat1, lng1, lat2, lng2, value);
      _pendingRequests.remove(key);
      return value;
    }).catchError((e) {
      _pendingRequests.remove(key);
      return null;
    });

    _pendingRequests[key] = future;
    return future;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Haversine distance (meters)
  // ──────────────────────────────────────────────────────────────────────
  static double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  static double _rad(double deg) => deg * math.pi / 180;
}

class _CachedDistance {
  final String value;
  final DateTime savedAt;
  final double lat1, lng1, lat2, lng2;

  _CachedDistance(
    this.value,
    this.savedAt,
    this.lat1,
    this.lng1,
    this.lat2,
    this.lng2,
  );
}
