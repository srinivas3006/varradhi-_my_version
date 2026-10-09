import 'package:flutter/material.dart';

import '../localization/app_translations.dart';
import '../services/cms_service.dart';
import 'cms_page_screen.dart';

/// Terms & Conditions — content comes from the CMS (GET /api/v1/cms/${CmsSlugs.terms}/).
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      CMSPageScreen(slug: CmsSlugs.terms, initialTitle: tr('terms_of_service'));
}
