import 'dart:convert';

// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:resumable_upload/src/upload_metadata.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class UploadCache {
  Future<void> set(UploadMetaData data);

  Future<UploadMetaData?> get(String fingerPrint);

  Future<void> delete(String fingerPrint);

  Future<void> clearAll();
}

class MemoryCache implements UploadCache {
  final _cache = <String, UploadMetaData>{};

  @override
  Future<void> set(UploadMetaData data) async {
    _cache[data.key] = data;
  }

  @override
  Future<UploadMetaData?> get(String key) async {
    return _cache[key];
  }

  @override
  Future<void> delete(String fingerprint) async {
    _cache.remove(fingerprint);
  }

  @override
  Future<void> clearAll() async {
    _cache.clear();
  }
}

// class LocalCache implements UploadCache {
//   late FlutterSecureStorage storage;
//   LocalCache() : storage = const FlutterSecureStorage();
//   @override
//   Future<void> set(UploadMetaData data) async {
//     await storage.write(key: data.key, value: data.toString());
//   }

//   @override
//   Future<UploadMetaData?> get(String key) async {
//     String? data = await storage.read(key: key);
//     if (data == null) return null;
//     print(jsonDecode(data));
//     return UploadMetaData.fromJson(jsonDecode(data));
//   }

//   @override
//   Future<void> delete(String key) async {
//     await storage.delete(key: key);
//   }

//   @override
//   Future<void> clearAll() async {
//     // await storage.clear();
//   }
// }
class LocalCache implements UploadCache {
  @override
  Future<void> set(UploadMetaData data) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.reload();
    await prefs.setString(data.key, data.toString());
  }

  @override
  Future<UploadMetaData?> get(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.reload();
    String? data = await prefs.getString(key);
    if (data == null) return null;
    print(jsonDecode(data));
    return UploadMetaData.fromJson(jsonDecode(data));
  }

  @override
  Future<void> delete(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.reload();
    await prefs.remove(key);
  }

  @override
  Future<void> clearAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.reload();
    await prefs.clear();
  }
}
