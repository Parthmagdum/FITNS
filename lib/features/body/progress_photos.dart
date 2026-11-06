import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Progress photos on the Body tab: a strip of them, oldest to newest, and
/// a button to add one. Tapping a photo opens it beside the first one.
class ProgressPhotosSection extends ConsumerWidget {
  const ProgressPhotosSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final photos = ref.watch(progressPhotosProvider).valueOrNull ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          'Progress photos',
          trailing: TextButton.icon(
            onPressed: () => addProgressPhoto(context, ref),
            icon: const Icon(Icons.add_a_photo_outlined, size: 18),
            label: const Text('Add'),
          ),
        ),
        if (photos.isEmpty)
          SectionCard(
            child: Text(
              'Photos show change the scale can miss. Take one every few weeks '
              'in the same spot and light. They stay private on this phone — '
              'and are not in backups, so keep copies if you switch phones.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
            ),
          )
        else
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final p = photos[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          _PhotoCompare(first: photos.first, photo: p),
                    ),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _PhotoImage(p, width: 84, height: 112),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('d MMM').format(p.takenAt),
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Asks camera or gallery, saves the photo, records it.
Future<void> addProgressPhoto(BuildContext context, WidgetRef ref) async {
  final source = ref.read(photoSourceProvider);
  final db = ref.read(dbProvider);
  final messenger = ScaffoldMessenger.of(context);
  final canTake = await source.canTakePhoto();
  if (!context.mounted) return;
  final how = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canTake)
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, 'take'),
            ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(context, 'pick'),
          ),
        ],
      ),
    ),
  );
  if (how == null) return;
  try {
    final path = how == 'take' ? await source.take() : await source.pick();
    if (path != null) await db.addProgressPhoto(path);
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text("Couldn't save that photo.")),
    );
  }
}

class _PhotoImage extends StatelessWidget {
  const _PhotoImage(this.photo, {this.width, this.height});

  final ProgressPhotoRow photo;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final file = File(photo.path);
    final missing = Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.broken_image_outlined),
    );
    if (!file.existsSync()) return missing;
    return Image.file(
      file,
      width: width,
      height: height,
      fit: BoxFit.cover,
      // Thumbnails decode small; the full view decodes at screen size.
      cacheWidth: width == null ? null : (width! * 3).round(),
      errorBuilder: (_, _, _) => missing,
    );
  }
}

/// [photo] beside the first one ever taken — the change over time.
class _PhotoCompare extends ConsumerWidget {
  const _PhotoCompare({required this.first, required this.photo});

  final ProgressPhotoRow first;
  final ProgressPhotoRow photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final same = first.id == photo.id;
    Widget column(ProgressPhotoRow p, String label) => Expanded(
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.expand(child: _PhotoImage(p)),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.labelLarge),
          Text(
            DateFormat('d MMM yyyy').format(p.takenAt),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.muted),
          ),
        ],
      ),
    );
    final weeks = photo.takenAt.difference(first.takenAt).inDays ~/ 7;
    return Scaffold(
      appBar: AppBar(
        title: Text(same ? 'Progress photo' : '$weeks weeks apart'),
        actions: [
          IconButton(
            tooltip: 'Delete photo',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await confirm(
                context,
                title: 'Delete this photo?',
                action: 'Delete',
                destructive: true,
              );
              if (!ok || !context.mounted) return;
              Navigator.pop(context);
              await ref.read(dbProvider).deleteProgressPhoto(photo.id);
              try {
                await File(photo.path).delete();
              } on FileSystemException {
                // Already gone.
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (!same) ...[column(first, 'First'), const SizedBox(width: 12)],
            column(photo, same ? 'Your first photo' : 'This one'),
          ],
        ),
      ),
    );
  }
}
