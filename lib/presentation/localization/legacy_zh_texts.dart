class LegacyZhTexts {
  LegacyZhTexts._();

  static const String refreshPage = '刷新页面';
  static const String syncingServerData = '正在同步服务器数据';

  static const String webUnsupportedKernelLog = 'Web 端暂不支持本机直连工作日志读取';
  static const String webUnsupportedToggleLed = 'Web 端暂不支持本机直连指示灯控制';
  static const String webUnsupportedClearRefine = 'Web 端暂不支持本机直连清除自适应';
  static const String webUnsupportedReboot = 'Web 端暂不支持本机直连重启矿机';
  static const String webUnsupportedPoolConfig = 'Web 端暂不支持本机直连矿池配置';

  static String serverLoadFailed(Object error) => '服务器数据加载失败：$error';
  static const String serverLoadSummary = '读取服务器摘要';
  static const String serverLoadDashboardSummary = '读取面板摘要';
  static const String serverLoadKnownMiners = '同步矿机与已知矿机';
  static const String serverWriteLocalCache = '写入本地缓存';
  static const String serverConnecting = '正在连接服务器';
  static const String serverSyncSuccess = '服务器数据同步成功';
  static const String serverSyncFailure = '服务器数据同步失败';
  static String serverSyncFailureWithError(Object error) => '服务器数据同步失败：$error';
  static const String knownMinerSyncing = '正在同步已知矿机数据';
  static const String settingsLoadFailedPrefix = '读取设置失败：';

  static const String dashboardOnline = '在线';
  static const String dashboardUnresponsive = '未响应';
  static const String dashboardOffline = '离线';
  static const String dashboardPendingRetire = '待下架';
  static const String dashboardAbnormal = '异常';
  static const String dashboardFault = '故障';
  static const String dashboardSelfCheckFailure = '自检失败';
  static const String dashboardUpdatedAt = '数据更新时间';
  static const String dashboardNextScan = '下次扫描时间';
  static const String settingsServerUrl = '服务器地址';
  static const String barcodeScannerWebTitle = '扫码记录';
  static const String barcodeScannerWebUnsupported =
      'Web 版本暂不支持本机扫码与文件导出，请使用服务器数据页面。';

  static const String knownMinerTitle = '已知矿机';
  static String knownMinerVisibleCount(int visible, int total) =>
      '当前显示 $visible / 共 $total 台';

  static const String minerFiveSecondHashrate = '5秒算力';
  static const String minerTemperature = '温度';
  static const String minerFan = '风扇';
  static const String minerRunningMode = '运行模式';
  static const String minerUpdatedAt = '更新时间';
  static const String minerInfo = '矿机信息';
  static const String rediagnoseWorking = '正在重新诊断矿机日志...';
  static const String rediagnoseDone = '已重新诊断矿机日志';
  static const String rediagnoseFailed = '重新诊断矿机日志失败';

  static const String segmentLastScan = '上次扫描';
  static const String segmentScope = 'IP 段';
  static const String segmentOnline = '在线';
  static const String segmentUnresponsive = '未响应';
  static const String segmentOffline = '离线';
  static const String segmentRetired = '待下架';
  static const String segmentLongPressHint = '长按单个矿机记录可进入批量选择模式。';

  static const String runningModeNormal = '正常模式';
  static const String runningModeOverclock = '超频模式';
  static const String runningModeCustom = '自定义电压/频率';
  static const String runningModeDebug = '调试模式';
  static const String runningModeLowPower = '低功耗模式';
  static const String runningModeSuperLowPower = '超级低功耗模式';
  static const String runningModeSleep = '睡眠模式';
  static const String celsiusSuffix = '°C';

  static String issueSnippetFans(String fans) => '风扇位置：$fans';
  static String issueSnippetChains(String chains) => '算力板 / 链路位置：$chains';
  static String issueSnippetLocationHint(String parts) => '辅助定位：$parts';
  static String issueFanNumber(String fan) => '$fan 号风扇';

  static String? issueShortBadge(String code) {
    return switch (code) {
      'POWER_SUPPLY_FAULT' => '电源损坏',
      'OVER_VOLTAGE' => '电压过高',
      'POWER_CONTROL_FAULT' => '供电异常',
      'FAN_ERROR' => '风扇异常',
      'CHAIN_BREAK' => '板链异常',
      'OVER_MAX_TEMP' => '温度过高',
      'AUTHEN_START_WAIT' => '重新认证',
      'ZERO_HASH_RESTARTING' => '零算力重启',
      'ZERO_HASH_RESTART_FAILED' => '零算力未恢复',
      'HASHBOARD_DROPPED_RESTARTING' => '掉板重启',
      'HASHBOARD_DROPPED_RESTART_FAILED' => '掉板未恢复',
      'HASHBOARD_ALL_FAILED_RESTARTING' => '全板重启',
      'HASHBOARD_ALL_FAILED_NEEDS_REPLACEMENT' => '全板损坏',
      'TEMP_FULL_SPEED_RECOVERING' => '高温观察',
      'TEMP_FULL_SPEED_PERSISTED' => '高温未恢复',
      'ERRORMSG' => '内核异常',
      'UNKNOWN_ZERO_HASH' => '未知异常',
      'SERVER_ALERT' => '服务器告警',
      _ => null,
    };
  }

  static String formatZhChainHint(String value) {
    if (value.startsWith('board')) {
      return '${value.substring(5)} 号算力板';
    }
    if (value.startsWith('chain')) {
      return 'chain ${value.substring(5)}';
    }
    if (value.startsWith('J')) {
      return 'J${value.substring(1)}';
    }
    return value;
  }
}
