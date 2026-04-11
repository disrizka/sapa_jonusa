// utils/image_cache_manager.dart

import 'dart:typed_data';

/// Simple in-memory image cache shared across widgets.
class AppImageCache {
  AppImageCache._();
  static final Map<String, Uint8List> _cache = {};

  static bool has(String url) => _cache.containsKey(url);
  static Uint8List? get(String url) => _cache[url];
  static void set(String url, Uint8List bytes) => _cache[url] = bytes;
  static void clear() => _cache.clear();
}
