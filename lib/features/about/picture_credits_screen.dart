import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/pictures.dart';

/// Who took the photos FITNS ships with, and under which licence. The
/// licences (CC BY and CC BY-SA) ask for this; it's also only fair.
class PictureCreditsScreen extends StatelessWidget {
  const PictureCreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.muted);
    return Scaffold(
      appBar: AppBar(title: const Text('Picture credits')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Every photo in FITNS is freely licensed and stored in the app, '
            'so it works offline. Thank you to everyone who shared them.',
            style: muted,
          ),
          const SizedBox(height: 16),
          Text('Exercise photos', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Card(
            child: ListTile(
              title: Text(exercisePhotoSource.name),
              subtitle: Text(
                '${exercisePhotoSource.author}\n'
                '${exercisePhotoSource.license}\n'
                '${exercisePhotoSource.url}',
              ),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 16),
          Text('Food photos', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'From Wikimedia Commons, resized and cropped to a square.',
            style: muted,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final c in foodPhotoCredits)
                  ListTile(
                    dense: true,
                    title: Text(c.subject),
                    subtitle: SelectableText(
                      '${c.author} · ${c.license}\n${c.source}',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
