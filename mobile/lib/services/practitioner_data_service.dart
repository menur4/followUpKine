import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/practitioner_data.dart';

class PractitionerDataService {
  static const String _storageKey = 'practitioner_data';

  Map<String, PractitionerData> _cache = {};
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await load();
    _initialized = true;
  }

  Future<Map<String, PractitionerData>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);

    if (jsonString != null && jsonString.isNotEmpty) {
      _cache = PractitionerData.mapFromJsonString(jsonString);
    } else {
      _cache = {};
    }

    return _cache;
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = PractitionerData.mapToJsonString(_cache);
    await prefs.setString(_storageKey, jsonString);
  }

  Future<PractitionerData?> get(String practitionerName) async {
    await _ensureInitialized();
    return _cache[practitionerName];
  }

  Future<void> update(PractitionerData data) async {
    await _ensureInitialized();
    _cache[data.name] = data;
    await save();
  }

  Future<void> delete(String practitionerName) async {
    await _ensureInitialized();

    // Supprimer la photo si elle existe
    final data = _cache[practitionerName];
    if (data?.photoPath != null) {
      final file = File(data!.photoPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    _cache.remove(practitionerName);
    await save();
  }

  Future<String> getPhotosDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${appDir.path}/practitioner_photos');

    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    return photosDir.path;
  }

  Future<String> savePhoto(String practitionerName, File sourceFile) async {
    final photosDir = await getPhotosDirectory();
    final extension = sourceFile.path.split('.').last;
    final sanitizedName = practitionerName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newPath = '$photosDir/${sanitizedName}_$timestamp.$extension';

    // Supprimer l'ancienne photo si elle existe
    final existingData = await get(practitionerName);
    if (existingData?.photoPath != null) {
      final oldFile = File(existingData!.photoPath!);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }
    }

    // Copier la nouvelle photo
    await sourceFile.copy(newPath);

    return newPath;
  }

  Future<void> deletePhoto(String practitionerName) async {
    await _ensureInitialized();

    final data = _cache[practitionerName];
    if (data?.photoPath != null) {
      final file = File(data!.photoPath!);
      if (await file.exists()) {
        await file.delete();
      }

      // Mettre à jour les données sans la photo
      _cache[practitionerName] = data.copyWith(clearPhoto: true);
      await save();
    }
  }
}
