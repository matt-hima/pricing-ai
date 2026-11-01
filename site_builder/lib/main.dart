import 'package:flutter/material.dart';

import 'store.dart';
import 'ui/editor_page.dart';
import 'ui/popup_observer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store();
  await store.init();
  runApp(SiteBuilderApp(store: store));
}

final popupObserver = PopupObserver();

class SiteBuilderApp extends StatelessWidget {
  final Store store;
  const SiteBuilderApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Site Builder · Pricing AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF263C5C)),
        visualDensity: VisualDensity.compact,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), isDense: true),
      ),
      navigatorObservers: [popupObserver],
      home: EditorPage(store: store, popups: popupObserver),
    );
  }
}
