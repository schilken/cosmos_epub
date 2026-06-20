import 'package:get_storage/get_storage.dart';

/// Manages the persistent list of EPUB file paths shown in the shelf UI.
///
/// GetStorage is initialised by CosmosEpub.initialize() in main() before
/// runApp(), so GetStorage is always ready when this class is used.
class ShelfService {
  static const _key = 'seven_epubs_shelf_v1';

  static GetStorage get _storage => GetStorage();

  /// Returns the list of saved EPUB file paths. Empty list if not yet set.
  static List<String> getShelf() {
    final raw = _storage.read<List>(_key);
    if (raw == null) return [];
    return raw.cast<String>();
  }

  /// Appends [path] to the shelf if not already present.
  static Future<void> addBook(String path) async {
    final shelf = getShelf();
    if (!shelf.contains(path)) {
      shelf.add(path);
      await _storage.write(_key, shelf);
    }
  }

  /// Removes [path] from the shelf.
  static Future<void> removeBook(String path) async {
    final shelf = getShelf();
    shelf.remove(path);
    await _storage.write(_key, shelf);
  }

  /// Clears all entries from the shelf.
  static Future<void> clearShelf() async {
    await _storage.write(_key, <String>[]);
  }
}
