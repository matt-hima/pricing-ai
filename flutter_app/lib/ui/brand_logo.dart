import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../i18n/i18n.dart';

/// Pricing AI 標誌（徽章 + 字樣，橫式）。有 [onTap] 時可點擊，用來回到首頁（說明頁）。
class BrandLogo extends StatelessWidget {
  final double height;
  final VoidCallback? onTap;
  const BrandLogo({super.key, this.height = 40, this.onTap});

  @override
  Widget build(BuildContext context) {
    final logo = Semantics(
      label: tr('app.title'),
      image: true,
      child: SvgPicture.asset('assets/logo/pricing-ai-logo.svg', height: height, fit: BoxFit.contain),
    );
    if (onTap == null) return logo;
    return Tooltip(
      message: tr('nav.home'),
      child: Semantics(
        button: true,
        label: tr('nav.home'),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: logo,
        ),
      ),
    );
  }
}
