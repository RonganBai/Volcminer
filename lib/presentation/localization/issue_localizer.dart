import 'package:volcminer/domain/entities/miner_issue_diagnosis.dart';
import 'package:volcminer/presentation/localization/app_language.dart';
import 'package:volcminer/presentation/localization/app_localizer.dart';
import 'package:volcminer/presentation/localization/app_strings.dart';

class IssueLocalizer {
  IssueLocalizer._();

  static String reason(AppLocalizer l10n, MinerIssueDiagnosis diagnosis) {
    final key = 'issue.reason.${diagnosis.code}';
    if (AppStrings.contains(_languageOf(l10n), key)) {
      return l10n.t(key);
    }
    return diagnosis.reason;
  }

  static String solution(AppLocalizer l10n, MinerIssueDiagnosis diagnosis) {
    final key = 'issue.solution.${diagnosis.code}';
    if (AppStrings.contains(_languageOf(l10n), key)) {
      return l10n.t(key);
    }
    return diagnosis.solution;
  }

  static String? secondaryReason(AppLocalizer l10n, MinerIssueDiagnosis diagnosis) {
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

  static String? snippetSummary(AppLocalizer l10n, MinerIssueDiagnosis diagnosis) {
    final fans = _extractFans(diagnosis.logSnippet);
    final chains = _extractChains(diagnosis.logSnippet);
    if (fans.isEmpty && chains.isEmpty) {
      return null;
    }
    if (l10n.isZh) {
      final parts = <String>[];
      if (fans.isNotEmpty) {
        parts.add('风扇位置：${fans.map((fan) => '$fan 号风扇').join('、')}');
      }
      if (chains.isNotEmpty) {
        parts.add('算力板/链路位置：${chains.join('、')}');
      }
      return '辅助定位：${parts.join('；')}';
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

  static AppLanguage _languageOf(AppLocalizer l10n) {
    return l10n.isZh ? AppLanguage.zh : AppLanguage.en;
  }

  static List<String> _extractFans(String snippet) {
    final text = snippet.toUpperCase();
    final matches = <String>{};
    for (final match in RegExp(r'FAN\s*([0-9]+)').allMatches(text)) {
      matches.add(match.group(1)!);
    }
    for (final match in RegExp(r'FAN([0-9]+)SPEED(?:CUR)?\s*[:=]\s*0').allMatches(text)) {
      matches.add(match.group(1)!);
    }
    final sorted = matches.toList(growable: false)..sort();
    return sorted;
  }

  static List<String> _extractChains(String snippet) {
    final text = snippet.toUpperCase();
    final matches = <String>{};
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
