import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/app.dart';
import 'package:volcminer/data/isar_factory.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';
import 'package:volcminer/services/background_scan_service.dart';

const String kVolcMinerBuildStamp = '2026-03-10-1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final buildLine = '[VolcMinerBuild] $kVolcMinerBuildStamp';
  // ignore: avoid_print
  print(buildLine);
  debugPrint(buildLine);
  await BackgroundScanService.initialize();
  final isar = await openVolcMinerIsar();

  runApp(
    ProviderScope(
      overrides: [isarProvider.overrideWithValue(isar)],
      child: const VolcMinerApp(),
    ),
  );
}
