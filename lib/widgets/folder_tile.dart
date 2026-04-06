import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plinth/models/folder_node.dart';
import 'package:plinth/providers/theme_provider.dart';

class FolderTile extends StatelessWidget {
  final FolderNode folder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const FolderTile({
    super.key,
    required this.folder,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final accent = themeProvider.accentColor.color;
        return ListTile(
          leading: Icon(
            Icons.folder_rounded,
            color: accent,
            size: 32,
          ),
          title: Text(
            folder.name,
            style: Theme.of(context).textTheme.bodyLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${folder.totalTrackCount} tracks',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: const Color(0xFF8E8E93),
          ),
          onTap: onTap,
          onLongPress: onLongPress,
        );
      },
    );
  }
}
