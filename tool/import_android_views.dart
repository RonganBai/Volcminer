import 'dart:io';

import 'package:isar/isar.dart';
import 'package:volcminer/data/models/app_settings_record.dart';
import 'package:volcminer/data/models/pool_slot_record.dart';
import 'package:volcminer/data/models/scan_snapshot_record.dart';
import 'package:volcminer/data/models/scan_view_record.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln(
      'Usage: dart run tool/import_android_views.dart <android_db_dir> <windows_db_dir>',
    );
    exitCode = 64;
    return;
  }

  final sourceDir = Directory(args[0]);
  final targetDir = Directory(args[1]);
  if (!sourceDir.existsSync()) {
    stderr.writeln('Source directory not found: ${sourceDir.path}');
    exitCode = 66;
    return;
  }
  if (!targetDir.existsSync()) {
    stderr.writeln('Target directory not found: ${targetDir.path}');
    exitCode = 66;
    return;
  }

  final schemas = [
    ScanViewRecordSchema,
    PoolSlotRecordSchema,
    AppSettingsRecordSchema,
    ScanSnapshotRecordSchema,
  ];

  final source = await Isar.open(
    schemas,
    directory: sourceDir.path,
    name: 'volcminer',
  );

  try {
    final sourceViews = await source.scanViewRecords.where().findAll();
    if (sourceViews.isEmpty) {
      stdout.writeln('No scan views found in Android database.');
      return;
    }
    final detachedViews = sourceViews
        .map(
          (row) => ScanViewRecord()
            ..viewId = row.viewId
            ..name = row.name
            ..cidr = row.cidr
            ..startIp = row.startIp
            ..endIp = row.endIp
            ..tags = List<String>.from(row.tags)
            ..createdAt = row.createdAt
            ..updatedAt = row.updatedAt,
        )
        .toList(growable: false);
    await source.close();

    final target = await Isar.open(
      schemas,
      directory: targetDir.path,
      name: 'volcminer',
    );
    final existing = await target.scanViewRecords.where().findAll();
    final byCompositeKey = <String, ScanViewRecord>{
      for (final row in existing)
        '${row.cidr}|${row.startIp}|${row.endIp}': row,
    };

    var imported = 0;
    await target.writeTxn(() async {
      for (final row in detachedViews) {
        final key = '${row.cidr}|${row.startIp}|${row.endIp}';
        final existingRow = byCompositeKey[key];
        final next = ScanViewRecord()
          ..viewId = existingRow?.viewId ?? row.viewId
          ..name = row.name
          ..cidr = row.cidr
          ..startIp = row.startIp
          ..endIp = row.endIp
          ..tags = List<String>.from(row.tags)
          ..createdAt = row.createdAt
          ..updatedAt = row.updatedAt;
        await target.scanViewRecords.putByViewId(next);
        imported++;
      }
    });

    final finalCount = await target.scanViewRecords.count();
    stdout.writeln(
      'Imported $imported Android scan views into Windows database. Total views now: $finalCount',
    );
    await target.close();
  } finally {
    if (source.isOpen) {
      await source.close();
    }
  }
}
