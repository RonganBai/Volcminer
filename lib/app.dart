import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/presentation/pages/home_shell.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';

class VolcMinerApp extends ConsumerWidget {
  const VolcMinerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).settings;
    final textScaler = TextScaler.linear(settings.fontScale);
    return MaterialApp(
      title: 'VolcMiner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5E4E)),
        useMaterial3: true,
      ),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: textScaler),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const HomeShell(),
    );
  }
}
