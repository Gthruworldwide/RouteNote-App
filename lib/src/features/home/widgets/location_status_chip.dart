import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../providers/app_providers.dart';
import '../../../services/location_service.dart';

/// A compact, tappable indicator shown while location access is missing.
///
/// Tapping it takes the user straight to the relevant OS surface: the system
/// location settings (GPS off), this app's settings (permission blocked), or
/// the runtime permission dialog. It renders nothing while location is ready.
class LocationStatusChip extends ConsumerWidget {
  const LocationStatusChip({super.key, this.padding});

  /// Optional outer padding. Defaults to the list gutter used on the home tab.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LocationStatus? status = ref.watch(locationStatusProvider).value;
    if (status == null || !status.needsAction) {
      return const SizedBox.shrink();
    }

    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final (IconData icon, String label) = _describe(l10n, status);

    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: ActionChip(
          avatar: Icon(icon, size: 18, color: scheme.onErrorContainer),
          label: Text(label),
          backgroundColor: scheme.errorContainer,
          labelStyle: theme.textTheme.labelLarge?.copyWith(
            color: scheme.onErrorContainer,
          ),
          side: BorderSide.none,
          onPressed: () =>
              ref.read(locationStatusProvider.notifier).requestAccessFromUser(),
        ),
      ),
    );
  }

  (IconData, String) _describe(AppLocalizations l10n, LocationStatus status) {
    if (!status.serviceEnabled) {
      return (Icons.location_disabled_outlined, l10n.locationChipServiceOff);
    }
    if (status.permission == LocationPermission.deniedForever) {
      return (Icons.block_outlined, l10n.locationChipDeniedForever);
    }
    return (Icons.location_off_outlined, l10n.locationChipPermissionDenied);
  }
}
