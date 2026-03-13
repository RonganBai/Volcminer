import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:volcminer/data/models/app_settings_record.dart';
import 'package:volcminer/data/models/pool_slot_record.dart';
import 'package:volcminer/data/models/scan_snapshot_record.dart';
import 'package:volcminer/data/models/scan_view_record.dart';

Future<Isar> openVolcMinerIsar() async {
  final dir = await getApplicationDocumentsDirectory();
  return Isar.open(
    [
      ScanViewRecordSchema,
      PoolSlotRecordSchema,
      AppSettingsRecordSchema,
      ScanSnapshotRecordSchema,
    ],
    directory: dir.path,
    name: 'volcminer',
  );
}
