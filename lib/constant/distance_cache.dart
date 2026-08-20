class DistanceCache {
  static final Map<String, _CachedDistance> _cache = {};
  static const Duration ttl = Duration(minutes: 30);

  /// Round so tiny GPS changes don't create new keys
  static String _key(String lat1, String lng1, String lat2, String lng2) {
    String r(String v) => double.parse(v).toStringAsFixed(4);
    return '${r(lat1)},${r(lng1)}|${r(lat2)},${r(lng2)}';
  }

  static String? get(String lat1, String lng1, String lat2, String lng2) {
    final key = _key(lat1, lng1, lat2, lng2);
    final item = _cache[key];
    if (item == null) return null;
    if (DateTime.now().difference(item.savedAt) > ttl) {
      _cache.remove(key);
      return null;
    }
    return item.value;
  }

  static void set(
    String lat1,
    String lng1,
    String lat2,
    String lng2,
    String value,
  ) {
    final key = _key(lat1, lng1, lat2, lng2);
    _cache[key] = _CachedDistance(value, DateTime.now());
  }
}

class _CachedDistance {
  final String value;
  final DateTime savedAt;
  _CachedDistance(this.value, this.savedAt);
}
