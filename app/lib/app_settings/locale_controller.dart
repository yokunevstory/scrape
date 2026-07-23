import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Язык интерфейса (ru/lv/en). По умолчанию берётся из локали устройства, если
/// это один из поддерживаемых языков, иначе — латышский; после того как
/// пользователь явно выбрал язык в профиле, выбор сохраняется и применяется
/// при следующих запусках, независимо от локали устройства.
class LocaleController extends ChangeNotifier {
  static const _prefsKey = 'app_locale';
  static const supportedLocales = [Locale('ru'), Locale('lv'), Locale('en')];
  static const _defaultLocale = Locale('lv');

  Locale _locale = _defaultLocale;
  Locale get locale => _locale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null) {
      _locale = Locale(saved);
      return;
    }
    final deviceCode = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    _locale = supportedLocales.firstWhere(
      (l) => l.languageCode == deviceCode,
      orElse: () => _defaultLocale,
    );
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale.languageCode);
  }
}

/// Доступ к [LocaleController] из любого потомка в дереве виджетов —
/// например, переключатель языка в профиле вызывает
/// `LocaleScope.of(context).setLocale(...)`.
class LocaleScope extends InheritedNotifier<LocaleController> {
  const LocaleScope({super.key, required LocaleController controller, required super.child})
      : super(notifier: controller);

  static LocaleController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleScope>()!.notifier!;
}
