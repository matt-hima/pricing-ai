import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'i18n/i18n.dart';
import 'llm.dart';
import 'site/site_store.dart';
import 'site/ui/popup_observer.dart';
import 'ui/app_shell.dart';
import 'ui/pdf_surface.dart';

final popupObserver = PopupObserver();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerPdfPreview();
  final state = AppState();
  final siteStore = Store(aiAvailable: aiAvailable);
  await siteStore.init();
  runApp(SelfQuoteApp(state: state, siteStore: siteStore));
  state.init();
}

/// Dolibarr Eldy 主題的深藍色作為 Material 3 種子色
const seed = Color(0xFF263C5C);

class SelfQuoteApp extends StatelessWidget {
  final AppState state;
  final Store siteStore;
  const SelfQuoteApp({super.key, required this.state, required this.siteStore});

  ThemeData _theme(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.compact,
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), isDense: true),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 語言切換時重建 MaterialApp，讓日期選擇器、對話框等內建元件也換成對應語言
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (_) => tr('app.title'),
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        locale: I18n.lang.locale,
        supportedLocales: [for (final l in Lang.values) l.locale],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        navigatorObservers: [popupObserver],
        home: AppShell(state: state, siteStore: siteStore, popups: popupObserver),
      ),
    );
  }
}
