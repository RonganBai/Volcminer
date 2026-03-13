import 'package:isar/isar.dart';

part 'scan_snapshot_record.g.dart';

@collection
class ScanSnapshotRecord {
  Id id = 1;
  late DateTime updatedAt;
  late String payloadJson;
}
