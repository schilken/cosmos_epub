import 'package:drift/drift.dart';

DatabaseConnection openConnection() {
  throw UnsupportedError(
    'Cannot create a database connection on this platform.',
  );
}
