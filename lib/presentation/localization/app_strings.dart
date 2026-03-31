import 'package:volcminer/presentation/localization/app_language.dart';
import 'package:volcminer/presentation/localization/app_strings_en.dart';
import 'package:volcminer/presentation/localization/app_strings_zh.dart';

class AppStrings {
  AppStrings._();

  static String value(
    AppLanguage language,
    String key, {
    Map<String, String> params = const {},
  }) {
    final table = language == AppLanguage.zh ? appStringsZh : appStringsEn;
    final fallback = appStringsEn[key] ?? key;
    final template = table[key] ?? fallback;
    return _replaceParams(template, params);
  }

  static String english(String key, {Map<String, String> params = const {}}) {
    final template = appStringsEn[key] ?? key;
    return _replaceParams(template, params);
  }

  static bool contains(AppLanguage language, String key) {
    final table = language == AppLanguage.zh ? appStringsZh : appStringsEn;
    return table.containsKey(key) || appStringsEn.containsKey(key);
  }

  static String _replaceParams(String template, Map<String, String> params) {
    var output = template;
    for (final entry in params.entries) {
      output = output.replaceAll('{${entry.key}}', entry.value);
    }
    return output;
  }
}
