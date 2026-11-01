import 'dart:io';

String browserLanguage() => Platform.localeName.replaceAll('_', '-');

String? queryLanguage() => null;

void applyPageLanguage(String code, String title) {}
