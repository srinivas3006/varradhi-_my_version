import 'package:flutter/material.dart';

import '../localization/app_translations.dart';
import '../services/cms_service.dart';
import 'cms_page_screen.dart';

/// Privacy Policy — content comes from the CMS (GET /api/v1/cms/${CmsSlugs.privacy}/).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      CMSPageScreen(slug: CmsSlugs.privacy, initialTitle: tr('privacy_policy'));
}
