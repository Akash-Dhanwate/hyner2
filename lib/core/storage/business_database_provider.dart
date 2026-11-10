import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_business_database.dart';

final businessDatabaseProvider = Provider<LocalBusinessDatabase>(
  (ref) => LocalBusinessDatabase.instance,
);
