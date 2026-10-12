import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'config.dart';
import 'estimator.dart';
import 'i18n/i18n.dart';
import 'json_repair.dart';
import 'models.dart';

/// 推論引擎狀態：網頁版是「WebGPU 是否可用」，桌面版是「本機 llama-server 是否可用」
class GpuInfo {
  final bool ok, f16;

  /// 原因：`@代碼` 或原始例外文字，顯示前請用 tx() 翻譯
  final String reason;
  const GpuInfo(this.ok, this.f16, this.reason);
  String get reasonText => tx(reason);
}

typedef ProgressFn = void Function(double progress, String text);

/// 系統提示詞固定用英文（小模型對英文指令最穩定），輸出語言由第 7 條指定。
String systemPrompt() => """You are a senior software architect and project manager who knows the Taiwan / Asia software outsourcing market.
Task: from the client's selected feature modules and plain-language notes, break every module down into concrete development sub-tasks and estimate hours.
Rules:
1. Output JSON only, no other text.
2. Use each module's baseline hours as a reference and adjust to between 0.7x and 1.8x according to the client's notes; the more complex the notes (installment payments, real-time sync, third-party integration, multi-role permissions), the higher.
3. Split every module into 2-4 sub-tasks; "kind" is "fe" (front end / client) or "be" (back end / API).
4. If the special requirements or project description mention features that are not in the module list, put them in "extras" (at most 3, each at most 120 hours).
5. Do not estimate prices; the system calculates prices.
6. Write 3-5 assumptions and 3-5 risks or exclusions (for example third-party API fees, server costs, content creation).
7. Write ALL task names, extra feature names, assumptions and risks in ${I18n.lang.aiName}.
8. "complexity" must be exactly one of: "low", "medium", "high".
Output format:
{"complexity":"low|medium|high",
 "assumptions":["..."],
 "risks":["..."],
 "modules":[{"id":"module id","tasks":[{"name":"sub-task","kind":"fe","hours":40}]}],
 "extras":[{"name":"feature name","tasks":[{"name":"sub-task","kind":"be","hours":30}]}]}""";

String buildUserPrompt(Quote q, Estimate baseline) {
  String orNone(String s) => s.isEmpty ? tr('ai.none') : s;
  return const JsonEncoder.withIndent(' ').convert({
    'project_type': byId(projectTypes, q.type, 1).name,
    'platforms': platforms.where((p) => q.platforms.contains(p.id)).map((p) => p.name).join(', '),
    'design_level': byId(designLevels, q.design, 1).name,
    'project_description': orNone(q.summary),
    'special_requirements': orNone(q.extra),
    'modules': [
      for (final m in baseline.modules)
        {
          'id': m.id,
          'name': m.name,
          'scope': m.desc,
          'client_notes': orNone(m.note),
          'baseline_frontend_hours': m.fe,
          'baseline_backend_hours': m.be,
        },
    ],
  });
}

/// 向模型提問並解析成估價結果；各平台只需提供 [ask]（送出提示、回傳模型原始文字）。
/// 小模型偶爾輸出有瑕疵的 JSON：先容錯解析（結尾逗號、截斷、括號配錯），仍失敗才重問一次。
Future<AiResult> runAIWith(Quote q, Future<String> Function(String system, String user) ask) async {
  final baseline = ruleEstimate(q);
  final system = systemPrompt(), user = buildUserPrompt(q, baseline);
  var text = await ask(system, user);
  var parsed = parseLooseJson(text);
  if (parsed == null) {
    debugPrint('AI output was not parseable, retrying once. Raw output:\n$text');
    text = await ask(system, user);
    parsed = parseLooseJson(text);
  }
  if (parsed == null) {
    debugPrint('AI output still not parseable. Raw output:\n$text');
    throw FormatException(tr('js.ai_not_json'));
  }
  return mergeAI(baseline, parsed, q);
}
