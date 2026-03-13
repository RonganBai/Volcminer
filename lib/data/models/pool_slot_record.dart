import 'package:isar/isar.dart';

part 'pool_slot_record.g.dart';

@collection
class PoolSlotRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late int slotNo;

  late String poolUrl;
  late String workerCode;
}
