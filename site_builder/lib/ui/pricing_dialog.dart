import 'package:flutter/material.dart';

import 'pricing_view.dart';

/// 開啟 Pricing AI 產生報價，按「套用到網站」後把結果交回（Navigator.pop 的值）
class PricingAiDialog extends StatelessWidget {
  final String url;
  const PricingAiDialog({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 1180,
        height: 820,
        child: Column(children: [
          Container(
            color: const Color(0xFF263C5C),
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
            child: Row(children: [
              const Expanded(child: Text('AI pricing — generate a quote, then press “Apply to website”', style: TextStyle(color: Colors.white))),
              IconButton(tooltip: 'Close', icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Expanded(child: PricingAiView(url: url, onResult: (r) => Navigator.pop(context, r))),
        ]),
      ),
    );
  }
}
