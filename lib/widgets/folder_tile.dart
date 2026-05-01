import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:plinth/models/folder_node.dart';
import 'package:plinth/providers/theme_provider.dart';

class FolderTile extends StatelessWidget {
  final FolderNode folder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isPinned;

  const FolderTile({
    super.key,
    required this.folder,
    required this.onTap,
    this.onLongPress,
    this.isPinned = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final accent = themeProvider.accentColor.color;
        return ListTile(
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.folder_rounded,
                color: accent,
                size: 32,
              ),
              if (isPinned)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.push_pin_rounded,
                      color: Colors.black,
                      size: 9,
                    ),
                  ),
                ),
            ],
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
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF8E8E93),
          ),
          onTap: onTap,
          onLongPress: onLongPress,
        );
      },
    );
  }
}
