import 'package:flutter/material.dart';

import '../app_state.dart';
import '../i18n/i18n.dart';

/// 語言選單：繁體中文 / 日本語 / English / Português / Español
class LangMenu extends StatelessWidget {
  final AppState state;
  final Color? color;
  const LangMenu({super.key, required this.state, this.color});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Lang>(
      tooltip: tr('lang.tooltip'),
      initialValue: state.lang,
      onSelected: state.setLang,
      icon: Icon(Icons.translate, color: color),
      itemBuilder: (_) => [
        for (final l in Lang.values)
          PopupMenuItem(
            value: l,
            child: Row(children: [
              SizedBox(width: 24, child: l == state.lang ? const Icon(Icons.check, size: 18) : null),
              Text(l.native),
            ]),
          ),
      ],
    );
  }
}
