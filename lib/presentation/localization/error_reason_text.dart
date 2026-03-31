class ErrorReasonText {
  ErrorReasonText._();

  static String format(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) {
      return '未知错误';
    }

    final normalized = raw.toLowerCase();
    if (normalized.contains('network is unreachable') ||
        normalized.contains('errno = 101')) {
      return '网络不可达（Network is unreachable）';
    }
    if (normalized.contains('connection reset by peer')) {
      return '连接被对端重置（Connection reset by peer）';
    }
    if (normalized.contains('connection refused')) {
      return '连接被拒绝（Connection refused）';
    }
    if (normalized.contains('connection failed')) {
      return '连接失败（Connection failed）';
    }
    if (normalized.contains('timed out') || normalized.contains('timeout')) {
      return '请求超时（timeout）';
    }
    if (normalized.contains('vm service')) {
      return '调试服务连接已断开（VM service disconnected）';
    }
    if (normalized.contains('service connection disposed')) {
      return '服务连接已释放（service connection disposed）';
    }
    if (normalized.contains('clientexception')) {
      return 'HTTP 客户端请求异常';
    }
    if (normalized.contains('socketexception')) {
      return '网络套接字异常';
    }
    if (normalized.startsWith('exception:')) {
      return format(raw.substring('Exception:'.length).trim());
    }
    return raw;
  }

  static String serverLoadFailed(Object error) => '服务器数据加载失败：${format(error)}';

  static String serverSyncFailure(Object error) => '服务器数据同步失败：${format(error)}';

  static String settingsLoadFailed(Object error) => '读取设置失败：${format(error)}';

  static String scanViewLoadFailed(Object error) => '读取视图失败：${format(error)}';

  static String scanViewSyncFailed(Object error) => '视图同步失败：${format(error)}';

  static String poolCheckFailed(Object error) => '矿池检查失败：${format(error)}';

  static String scanFailed(Object error) => '扫描失败：${format(error)}';

  static String repeatedOfflineLoadFailed(Object error) =>
      '读取多次离线IP失败：${format(error)}';

  static String repeatedOfflineSegmentLoadFailed(
    String segment,
    Object error,
  ) => '读取 $segment 明细失败：${format(error)}';
}
