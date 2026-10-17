import 'package:flutter/material.dart';

import '../localization/app_translations.dart';
import '../services/cms_service.dart';
import 'cms_page_screen.dart';

/// About Vaaradhi — content comes from the CMS (GET /api/v1/cms/${CmsSlugs.about}/).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      CMSPageScreen(slug: CmsSlugs.about, initialTitle: tr('about_varadhi'));
}
