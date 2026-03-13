import 'package:isar/isar.dart';

part 'scan_view_record.g.dart';

@collection
class ScanViewRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String viewId;

  late String name;
  late String cidr;
  late String startIp;
  late String endIp;
  late List<String> tags;
  late DateTime createdAt;
  late DateTime updatedAt;
}
