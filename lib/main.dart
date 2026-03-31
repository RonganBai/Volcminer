import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/app.dart';

const String kVolcMinerBuildStamp = '2026-03-10-1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final buildLine = '[VolcMinerBuild] $kVolcMinerBuildStamp';
  // ignore: avoid_print
  print(buildLine);
  debugPrint(buildLine);
  runApp(const ProviderScope(child: VolcMinerApp()));
}
