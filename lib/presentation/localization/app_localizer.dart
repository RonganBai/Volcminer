import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volcminer/presentation/localization/app_language.dart';
import 'package:volcminer/presentation/providers/app_providers.dart';
import 'package:volcminer/presentation/localization/app_strings.dart';

class AppLocalizer {
  const AppLocalizer(this.ref);

  final WidgetRef ref;

  bool get isZh => ref.watch(appLanguageProvider) == AppLanguage.zh;

  String text(String en, String zh) {
    return isZh ? zh : en;
  }

  String t(String key, {Map<String, String> params = const {}}) {
    return AppStrings.value(ref.watch(appLanguageProvider), key, params: params);
  }
}
