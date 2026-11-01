import 'package:flutter/material.dart';

import '../app_state.dart';
import '../i18n/i18n.dart';

/// 語言選單：跟隨系統語言（自動）/ 繁體中文 / 日本語 / English / Português / Español。
/// [labelled]：按鈕上直接顯示目前的語言名稱（頂端列用），否則只有圖示。
class LangMenu extends StatelessWidget {
  final AppState state;
  final Color? color;
  final bool labelled;
  const LangMenu({super.key, required this.state, this.color, this.labelled = false});

  static const _system = 'system';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget check(bool on) => SizedBox(width: 24, child: on ? const Icon(Icons.check, size: 18) : null);
    return PopupMenuButton<Object>(
      tooltip: tr('lang.tooltip'),
      onSelected: (v) => v == _system ? state.useSystemLang() : state.setLang(v as Lang),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _system,
          child: Row(children: [check(state.followSystem), const Icon(Icons.computer, size: 18), const SizedBox(width: 8), Text(tr('lang.system'))]),
        ),
        const PopupMenuDivider(),
        for (final l in Lang.values)
          PopupMenuItem(
            value: l,
            child: Row(children: [check(!state.followSystem && l == state.lang), Text(l.native)]),
          ),
      ],
      child: labelled
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.translate, color: color, size: 20),
                const SizedBox(width: 6),
                Text(state.lang.native, style: t.labelLarge?.copyWith(color: color)),
                Icon(Icons.arrow_drop_down, color: color, size: 20),
              ]),
            )
          : Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.translate, color: color)),
    );
  }
}
