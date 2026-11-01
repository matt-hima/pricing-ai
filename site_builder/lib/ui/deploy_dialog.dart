import 'dart:async';

import 'package:flutter/material.dart';

import '../model.dart';
import '../platform/deploy.dart';
import '../store.dart';

/// 桌面版：用本機 Firebase CLI 部署到使用者自己的 Hosting
class DeployDialog extends StatefulWidget {
  final Store store;

  /// 取得編輯器目前的完整網站 HTML
  final Future<String> Function() getHtml;
  const DeployDialog({super.key, required this.store, required this.getHtml});

  @override
  State<DeployDialog> createState() => _DeployDialogState();
}

class _DeployDialogState extends State<DeployDialog> {
  late final project = TextEditingController(text: widget.store.current.deployProject);
  late final hosting = TextEditingController(text: widget.store.current.deploySite);
  final log = <String>[];
  final scroll = ScrollController();
  bool busy = false;

  void _add(String l) {
    setState(() => log.add(l));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
    });
  }

  Future<void> _run(Stream<String> Function() job) async {
    setState(() => busy = true);
    try {
      await for (final l in job()) {
        _add(l);
      }
    } catch (e) {
      _add('Error: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _deploy() async {
    final p = project.text.trim().toLowerCase();
    final h = hosting.text.trim().toLowerCase();
    if (!firebaseIdRe.hasMatch(p)) {
      _add('Enter a valid Firebase project ID.');
      return;
    }
    final site = widget.store.current;
    site
      ..deployProject = p
      ..deploySite = h;
    widget.store.changed(notify: false);
    final String html;
    try {
      html = await widget.getHtml();
    } catch (e) {
      _add('Error: $e');
      return;
    }
    await _run(() => deploySite(html, project: p, hostingSite: h));
  }

  @override
  void dispose() {
    project.dispose();
    hosting.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Deploy to Firebase Hosting'),
      content: SizedBox(
        width: 520,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'Uses the Firebase CLI on this computer (npm install -g firebase-tools). '
            'Sign in once, then enter your project and Hosting site IDs.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(controller: project, decoration: const InputDecoration(labelText: 'Firebase project ID')),
          const SizedBox(height: 10),
          TextField(
            controller: hosting,
            decoration: const InputDecoration(labelText: 'Hosting site ID (optional)', helperText: 'Empty uses the project\'s default site'),
          ),
          const SizedBox(height: 12),
          Container(
            height: 180,
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(8)),
            child: ListView(
              controller: scroll,
              children: [for (final l in log) SelectableText(l, style: const TextStyle(color: Color(0xFFE5E7EB), fontFamily: 'monospace', fontSize: 12))],
            ),
          ),
          if (busy) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
        ]),
      ),
      actions: [
        TextButton(onPressed: busy ? null : () => _run(loginFirebase), child: const Text('Sign in with Google')),
        TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Close')),
        FilledButton(onPressed: busy ? null : _deploy, child: const Text('Deploy')),
      ],
    );
  }
}
