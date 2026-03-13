import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:volcminer/app.dart';
import 'package:volcminer/data/models/app_settings_record.dart';
import 'package:volcminer/data/models/pool_slot_record.dart';
import 'package:volcminer/data/models/scan_snapshot_record.dart';
import 'package:volcminer/data/models/scan_view_record.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

const String kVolcMinerBuildStamp = '2026-03-10-1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final buildLine = '[VolcMinerBuild] $kVolcMinerBuildStamp';
  // ignore: avoid_print
  print(buildLine);
  debugPrint(buildLine);
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [
      ScanViewRecordSchema,
      PoolSlotRecordSchema,
      AppSettingsRecordSchema,
      ScanSnapshotRecordSchema,
    ],
    directory: dir.path,
    name: 'volcminer',
  );

  runApp(
    ProviderScope(
      overrides: [isarProvider.overrideWithValue(isar)],
      child: const VolcMinerApp(),
    ),
  );
}
