import 'package:flutter/material.dart';

import '../../../data/models/place.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// A single saved location shown in the home list.
class PlaceCard extends StatelessWidget {
  const PlaceCard({
    super.key,
    required this.place,
    required this.onTap,
    required this.onNavigate,
    this.onLongPress,
  });

  final Place place;
  final VoidCallback onTap;
  final VoidCallback onNavigate;

  /// Opens the context menu (bottom sheet) with privacy + quick actions.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final String? notes = place.notes.trim().isEmpty ? null : place.notes;

    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: const Icon(Icons.place_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        if (place.isPinned) ...<Widget>[
                          Icon(
                            Icons.push_pin,
                            size: 16,
                            color: theme.colorScheme.primary,
                            semanticLabel: l10n.pinnedLabel,
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (place.isLocked) ...<Widget>[
                          Icon(
                            Icons.lock,
                            size: 16,
                            color: theme.colorScheme.primary,
                            semanticLabel: l10n.lockedLabel,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            place.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    if (notes != null)
                      Text(
                        notes,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    Text(
                      place.formattedCoordinates,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.navigate,
                onPressed: onNavigate,
                icon: const Icon(Icons.directions),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
