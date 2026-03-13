import 'package:isar/isar.dart';

part 'app_settings_record.g.dart';

@collection
class AppSettingsRecord {
  Id id = 1;
  late double fontScale;
  late bool autoRefreshEnabled;
  late bool showOfflineEnabled;
  late bool collectLogsEnabled;
  late int refreshIntervalSec;
  late int scanConcurrency;
  late String poolSearchUsername;
  late String minerUsername;
}
