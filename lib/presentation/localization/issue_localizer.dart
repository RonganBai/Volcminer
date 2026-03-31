import 'package:volcminer/domain/entities/miner_issue_diagnosis.dart';
import 'package:volcminer/presentation/localization/app_language.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/localization/app_strings.dart';
import 'package:volcminer/presentation/localization/legacy_zh_texts.dart';

class IssueLocalizer {
  IssueLocalizer._();

  static String reason(AppLocalizer l10n, MinerIssueDiagnosis diagnosis) {
    if (diagnosis.code == 'MULTI_RESTART') {
      return l10n.isZh
          ? '1小时内 3 次以上出现 Authen Start !!!!!，矿机疑似多次重启。'
          : 'Authen Start !!!!! appeared 3 or more times within 1 hour, suggesting repeated reboot behavior.';
    }
    final key = 'issue.reason.${diagnosis.code}';
    if (AppStrings.contains(_languageOf(l10n), key)) {
      return l10n.t(key);
    }
    return diagnosis.reason;
  }

  static String solution(AppLocalizer l10n, MinerIssueDiagnosis diagnosis) {
    if (diagnosis.code == 'MULTI_RESTART') {
      return l10n.isZh
          ? '请重点检查电源、启动稳定性和内核日志，确认矿机是否反复进入认证等待。'
          : 'Check the power supply, startup stability, and kernel log. Confirm whether the miner keeps entering authentication wait.';
    }
    final key = 'issue.solution.${diagnosis.code}';
    if (AppStrings.contains(_languageOf(l10n), key)) {
      return l10n.t(key);
    }
    return diagnosis.solution;
  }

  static String? secondaryReason(
    AppLocalizer l10n,
    MinerIssueDiagnosis diagnosis,
  ) {
    final code = diagnosis.secondaryCode;
    final raw = diagnosis.secondaryReason;
    if (code == null && raw == null) {
      return null;
    }
    if (code != null) {
      final key = 'issue.reason.$code';
      if (AppStrings.contains(_languageOf(l10n), key)) {
        return l10n.t(key);
      }
    }
    return raw;
  }

  static String? snippetSummary(
    AppLocalizer l10n,
    MinerIssueDiagnosis diagnosis,
  ) {
    final fans = _extractFans(diagnosis.logSnippet);
    final chains = _extractChains(diagnosis.logSnippet);
    if (fans.isEmpty && chains.isEmpty) {
      return null;
    }
    if (l10n.isZh) {
      final parts = <String>[];
      if (fans.isNotEmpty) {
        parts.add(
          LegacyZhTexts.issueSnippetFans(
            fans.map(LegacyZhTexts.issueFanNumber).join('、'),
          ),
        );
      }
      if (chains.isNotEmpty) {
        parts.add(
          LegacyZhTexts.issueSnippetChains(
            chains.map(LegacyZhTexts.formatZhChainHint).join('、'),
          ),
        );
      }
      return LegacyZhTexts.issueSnippetLocationHint(parts.join('；'));
    }
    final parts = <String>[];
    if (fans.isNotEmpty) {
      parts.add('Fan: ${fans.map((fan) => 'Fan $fan').join(', ')}');
    }
    if (chains.isNotEmpty) {
      parts.add('Hash board / chain: ${chains.join(', ')}');
    }
    return 'Location hint: ${parts.join('; ')}';
  }

  static String? shortBadge(AppLocalizer l10n, MinerIssueDiagnosis diagnosis) {
    if (diagnosis.code == 'MULTI_RESTART') {
      return l10n.isZh ? '多次重启' : 'Multi-restart';
    }
    if (l10n.isZh) {
      return LegacyZhTexts.issueShortBadge(diagnosis.code);
    }
    return null;
  }

  static AppLanguage _languageOf(AppLocalizer l10n) {
    return l10n.isZh ? AppLanguage.zh : AppLanguage.en;
  }

  static List<String> _extractFans(String snippet) {
    final text = snippet.toUpperCase();
    final matches = <String>{};
    for (final match in RegExp(r'FAN\s*([0-9]+)').allMatches(text)) {
      matches.add(match.group(1)!);
    }
    for (final match in RegExp(
      r'FAN([0-9]+)SPEED(?:CUR)?\s*[:=]\s*0',
    ).allMatches(text)) {
      matches.add(match.group(1)!);
    }
    final sorted = matches.toList(growable: false)..sort();
    return sorted;
  }

  static List<String> _extractChains(String snippet) {
    final text = snippet.toUpperCase();
    final matches = <String>{};
    for (final match in RegExp(r'BOARD_INDEX:([0-9, ]+)').allMatches(text)) {
      final raw = match.group(1) ?? '';
      for (final token in raw.split(',')) {
        final value = token.trim();
        if (value.isNotEmpty) {
          matches.add('board$value');
        }
      }
    }
    for (final match in RegExp(r'CHAIN[- ]?([0-9]+)').allMatches(text)) {
      matches.add('chain${match.group(1)}');
    }
    for (final match in RegExp(r'CHAIN J([0-9]+)').allMatches(text)) {
      matches.add('J${match.group(1)}');
    }
    final sorted = matches.toList(growable: false)..sort();
    return sorted;
  }
}
