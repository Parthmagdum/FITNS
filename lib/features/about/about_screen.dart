import 'package:flutter/material.dart';

import '../../core/branding/app_info.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.muted);
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            AppInfo.name,
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          Text(AppInfo.tagline, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Text(AppInfo.description, style: muted),
          const SizedBox(height: 24),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StatTile(label: 'Version', value: AppInfo.versionLabel),
                const SizedBox(height: 16),
                const StatTile(
                  label: 'Family',
                  value:
                      'A ${AppInfo.studio} app, alongside '
                      '${AppInfo.siblingApp}',
                ),
                const SizedBox(height: 16),
                StatTile(
                  label: 'License',
                  value: '${AppInfo.licenseName} · ${AppInfo.copyright}',
                ),
                const SizedBox(height: 16),
                Text('Source', style: muted),
                const SelectableText(AppInfo.repoUrl),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Open-source licences'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLicensePage(
                context: context,
                applicationName: AppInfo.name,
                applicationVersion: AppInfo.versionLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
