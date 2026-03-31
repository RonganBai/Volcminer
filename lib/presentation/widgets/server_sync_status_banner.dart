import 'dart:async';

import 'package:flutter/material.dart';
import 'package:volcminer/presentation/controllers/scan_controller.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/localization/legacy_zh_texts.dart';

class ServerSyncStatusBanner extends StatefulWidget {
  const ServerSyncStatusBanner({
    super.key,
    required this.scanState,
    required this.l10n,
    this.compact = false,
  });

  final ScanState scanState;
  final AppLocalizer l10n;
  final bool compact;

  @override
  State<ServerSyncStatusBanner> createState() => _ServerSyncStatusBannerState();
}

class _ServerSyncStatusBannerState extends State<ServerSyncStatusBanner> {
  Timer? _ticker;
  double _displayProgress = 0;
  double _targetProgress = 0;
  String? _label;
  String? _status;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _syncState(widget.scanState, animate: false);
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted || !_visible) {
        return;
      }
      if ((_displayProgress - _targetProgress).abs() < 0.002) {
        return;
      }
      setState(() {
        final step = (_targetProgress - _displayProgress) * 0.18;
        if (step.abs() < 0.001) {
          _displayProgress = _targetProgress;
        } else {
          _displayProgress += step;
        }
      });
    });
  }

  @override
  void didUpdateWidget(covariant ServerSyncStatusBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_hasMeaningfulChange(oldWidget.scanState, widget.scanState)) {
      _syncState(widget.scanState, animate: true);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  bool _hasMeaningfulChange(ScanState oldState, ScanState newState) {
    return oldState.isServerSyncing != newState.isServerSyncing ||
        oldState.serverSyncLabel != newState.serverSyncLabel ||
        oldState.serverSyncStatus != newState.serverSyncStatus ||
        oldState.serverSyncCurrent != newState.serverSyncCurrent ||
        oldState.serverSyncTotal != newState.serverSyncTotal;
  }

  void _syncState(ScanState scanState, {required bool animate}) {
    final bool active =
        scanState.isServerSyncing ||
        scanState.serverSyncLabel != null ||
        scanState.serverSyncStatus != null;
    final String? label = scanState.serverSyncLabel;
    final String status =
        scanState.serverSyncStatus ?? ServerSyncStatus.progress;
    final double nextTarget = _resolveTarget(scanState);

    if (!mounted) {
      _visible = active;
      _displayProgress = nextTarget;
      _targetProgress = nextTarget;
      _label = label;
      _status = status;
      return;
    }

    setState(() {
      _visible = active;
      _label = label;
      _status = status;
      if (!animate) {
        _displayProgress = nextTarget;
        _targetProgress = nextTarget;
        return;
      }
      _targetProgress = nextTarget;
      if (_displayProgress > _targetProgress) {
        _displayProgress = _targetProgress;
      }
    });
  }

  double _resolveTarget(ScanState scanState) {
    if (scanState.serverSyncStatus != null &&
        scanState.serverSyncStatus != ServerSyncStatus.progress &&
        !scanState.isServerSyncing) {
      return 1;
    }
    if (scanState.serverSyncTotal <= 0) {
      return 0;
    }
    return (scanState.serverSyncCurrent / scanState.serverSyncTotal)
        .clamp(0, 1)
        .toDouble();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox.shrink();
    }

    final bool isSuccess = _status == ServerSyncStatus.success;
    final bool isError = _status == ServerSyncStatus.error;
    final Color accentColor = isSuccess
        ? Colors.green.shade700
        : isError
        ? Colors.red.shade700
        : Theme.of(context).colorScheme.primary;
    final Color backgroundColor = isSuccess
        ? Colors.green.withValues(alpha: 0.14)
        : isError
        ? Colors.red.withValues(alpha: 0.14)
        : Theme.of(
            context,
          ).colorScheme.primaryContainer.withValues(alpha: 0.74);
    final String label = (_label == null || _label!.trim().isEmpty)
        ? LegacyZhTexts.syncingServerData
        : _label!;
    final double progress = _displayProgress.clamp(0, 1);
    final String percentText = '${(progress * 100).round()}%';

    if (widget.compact) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSuccess
                        ? Icons.check_circle_outline
                        : isError
                        ? Icons.error_outline
                        : Icons.cloud_sync_outlined,
                    size: 18,
                    color: accentColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ),
                  Text(
                    percentText,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: accentColor.withValues(alpha: 0.14),
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isSuccess
                    ? Icons.check_circle_outline
                    : isError
                    ? Icons.error_outline
                    : Icons.cloud_sync_outlined,
                size: 18,
                color: accentColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                  ),
                ),
              ),
              Text(
                percentText,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: accentColor.withValues(alpha: 0.14),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ],
      ),
    );
  }
}
