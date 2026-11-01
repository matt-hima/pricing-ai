import 'package:flutter/material.dart';

import '../app_state.dart';
import '../i18n/i18n.dart';
import '../llm.dart';
import 'get_app.dart';
import 'brand_logo.dart';
import 'lang_menu.dart';

/// 首頁介紹：品牌、AI 本地模型測試性質聲明、估價流程、免責條款
class IntroPage extends StatefulWidget {
  final AppState state;
  const IntroPage({super.key, required this.state});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  late bool _agreed = widget.state.introAccepted;

  AppState get s => widget.state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLow,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _hero(context),
                const SizedBox(height: 16),
                if (!aiAvailable) ...[const GetAppCard(), const SizedBox(height: 16)],
                _notice(context),
                const SizedBox(height: 28),
                _sectionTitle(context, tr('intro.flow.title'), tr('intro.flow.sub')),
                const SizedBox(height: 12),
                _steps(context),
                const SizedBox(height: 28),
                _sectionTitle(context, tr('intro.out.title'), tr('intro.out.sub')),
                const SizedBox(height: 12),
                _outputs(context),
                const SizedBox(height: 28),
                _terms(context),
                const SizedBox(height: 20),
                if (aiAvailable) ...[_env(context), const SizedBox(height: 24)],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _agreed,
                        onChanged: (v) => setState(() => _agreed = v ?? false),
                        title: Text(tr('intro.ack')),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        if (s.introAccepted) TextButton(onPressed: s.startQuoting, child: Text(tr('intro.back'))),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _agreed ? s.startQuoting : null,
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(tr(s.introAccepted ? 'intro.continue' : 'intro.start')),
                        ),
                      ]),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Text(tr('intro.footer'), textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  /* ---------- 區塊 ---------- */

  Widget _hero(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 12, 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [Color(0xFF263C5C), Color(0xFF34507A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                _Pill(Icons.lock_outline, tr('intro.badge1')),
                if (aiAvailable) _Pill(Icons.memory, tr('intro.badge2')),
                _Pill(Icons.picture_as_pdf_outlined, tr('intro.badge3')),
              ]),
            ),
          ),
          LangMenu(state: s, color: Colors.white),
        ]),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: const BrandLogo(height: 64),
            ),
            const SizedBox(height: 6),
            Text(tr(aiAvailable ? 'intro.title' : 'web.intro.title'), style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(tr(aiAvailable ? 'intro.subtitle' : 'web.intro.subtitle'), style: t.titleMedium?.copyWith(color: Colors.white.withValues(alpha: .88), height: 1.5)),
          ]),
        ),
      ]),
    );
  }

  /// 首頁最醒目的聲明：這是 AI 本地模型的測試估算
  Widget _notice(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700, width: 2),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.science_outlined, color: Colors.amber.shade900, size: 30),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(aiAvailable ? 'intro.notice.title' : 'web.intro.noticeTitle'), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(tr(aiAvailable ? 'intro.notice.body' : 'web.intro.noticeBody'), style: t.bodyMedium?.copyWith(color: cs.onSurface, height: 1.55)),
          ]),
        ),
      ]),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, String sub) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      Text(sub, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
  }

  Widget _grid(BuildContext context, List<Widget> children, {double minWidth = 220}) {
    return LayoutBuilder(builder: (context, c) {
      final perRow = (c.maxWidth / minWidth).floor().clamp(1, children.length);
      final w = (c.maxWidth - 12 * (perRow - 1)) / perRow;
      return Wrap(spacing: 12, runSpacing: 12, children: [for (final x in children) SizedBox(width: w, child: x)]);
    });
  }

  Widget _steps(BuildContext context) {
    const icons = [Icons.business, Icons.checklist, Icons.auto_awesome, Icons.picture_as_pdf];
    return _grid(context, [
      for (var i = 0; i < 4; i++) _StepCard(index: i + 1, icon: icons[i], title: tr(i == 2 && !aiAvailable ? 'web.intro.step3.t' : 'intro.step${i + 1}.t'), body: tr(i == 2 && !aiAvailable ? 'web.intro.step3.b' : 'intro.step${i + 1}.b')),
    ], minWidth: 210);
  }

  Widget _outputs(BuildContext context) {
    const icons = [Icons.payments_outlined, Icons.groups_outlined, Icons.support_agent];
    return _grid(context, [
      for (var i = 0; i < 3; i++) _InfoCard(icon: icons[i], title: tr('intro.out${i + 1}.t'), body: tr('intro.out${i + 1}.b')),
    ], minWidth: 260);
  }

  /// 免責條款：六條，與報價單、PDF 內容一致
  Widget _terms(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final clauses = disclaimerClauses();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: Colors.amber.shade700, width: 5), top: BorderSide(color: cs.outlineVariant), right: BorderSide(color: cs.outlineVariant), bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.gavel, color: Colors.amber.shade800),
          const SizedBox(width: 8),
          Text(tr('terms.title'), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 14),
        for (var i = 0; i < clauses.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 26, child: Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.w700))),
              Expanded(
                child: Text.rich(TextSpan(style: t.bodyMedium?.copyWith(height: 1.5), children: [
                  TextSpan(text: '${clauses[i].title}  ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: clauses[i].body, style: TextStyle(color: cs.onSurface)),
                ])),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _env(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final t = Theme.of(context).textTheme;
        final ok = s.gpu.ok;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(!s.gpuChecked ? Icons.hourglass_empty : (ok ? Icons.check_circle : Icons.info_outline),
                  color: !s.gpuChecked ? cs.onSurfaceVariant : (ok ? Colors.teal : Colors.orange)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(!s.gpuChecked ? tr('env.checking') : tr(ok ? 'env.ok' : 'env.no'), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    ok ? tr('env.ok.body') : tr('env.no.body', {'reason': s.gpu.reasonText}),
                    style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pill(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ]),
      );
}

class _StepCard extends StatelessWidget {
  final int index;
  final IconData icon;
  final String title, body;
  const _StepCard({required this.index, required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 14, backgroundColor: cs.primary, child: Text('$index', style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w700))),
            const Spacer(),
            Icon(icon, color: cs.primary),
          ]),
          const SizedBox(height: 12),
          Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(body, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.5)),
        ]),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title, body;
  const _InfoCard({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: cs.primary, size: 28),
          const SizedBox(height: 10),
          Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(body, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.5)),
        ]),
      ),
    );
  }
}
