import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/place.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../providers/app_providers.dart';
import '../../services/location_service.dart';

/// Captures the current GPS position and lets the user name it.
///
/// When [place] is provided the screen edits that existing location instead of
/// capturing a new one.
class AddPlaceScreen extends ConsumerStatefulWidget {
  const AddPlaceScreen({super.key, this.place});

  final Place? place;

  @override
  ConsumerState<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends ConsumerState<AddPlaceScreen> {
  static const Uuid _uuid = Uuid();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;

  LocationResult? _location;
  bool _capturing = false;
  bool _saving = false;

  bool get _isEditing => widget.place != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.place?.name ?? '');
    _notesController = TextEditingController(text: widget.place?.notes ?? '');
    if (_isEditing) {
      final Place place = widget.place!;
      _location = LocationSuccess(
        latitude: place.latitude,
        longitude: place.longitude,
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _captureLocation();
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() => _capturing = true);
    final LocationService service = ref.read(locationServiceProvider);
    final LocationResult result = await service.determinePosition();
    if (!mounted) return;
    setState(() {
      _location = result;
      _capturing = false;
    });
  }

  Future<void> _save() async {
    if (_location is! LocationSuccess) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final AppLocalizations l10n = AppLocalizations.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);

    final Place? original = widget.place;
    final LocationSuccess success = _location! as LocationSuccess;
    final Place place = original == null
        ? Place(
            id: _uuid.v4(),
            name: _nameController.text.trim(),
            notes: _notesController.text.trim(),
            latitude: success.latitude,
            longitude: success.longitude,
            timestamp: DateTime.now().toUtc(),
          )
        : original.copyWith(
            name: _nameController.text.trim(),
            notes: _notesController.text.trim(),
          );

    setState(() => _saving = true);
    await ref.read(placesProvider.notifier).save(place);

    messenger.showSnackBar(SnackBar(content: Text(l10n.placeSaved)));
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editPlaceTitle : l10n.addPlaceTitle),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _buildLocationCard(l10n),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.fieldName,
                hintText: l10n.fieldNameHint,
                prefixIcon: const Icon(Icons.label_outline),
              ),
              validator: (String? value) =>
                  (value == null || value.trim().isEmpty)
                  ? l10n.nameRequired
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.fieldNotes,
                hintText: l10n.fieldNotesHint,
                prefixIcon: const Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed:
                  (_capturing || _saving || _location is! LocationSuccess)
                  ? null
                  : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(AppLocalizations l10n) {
    final ThemeData theme = Theme.of(context);

    if (_capturing) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(l10n.fetchingLocation)),
            ],
          ),
        ),
      );
    }

    switch (_location) {
      case null:
        return const SizedBox.shrink();
      case LocationSuccess(:final latitude, :final longitude, :final accuracy):
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.currentLocation, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                _CoordRow(
                  icon: Icons.pin_drop_outlined,
                  label: l10n.latitude,
                  value: latitude.toStringAsFixed(6),
                ),
                const SizedBox(height: 4),
                _CoordRow(
                  icon: Icons.pin_drop_outlined,
                  label: l10n.longitude,
                  value: longitude.toStringAsFixed(6),
                ),
                if (accuracy != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    '±${accuracy.toStringAsFixed(0)} m',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        );
      case LocationServiceDisabled():
        return _LocationMessageCard(
          icon: Icons.location_disabled_outlined,
          title: l10n.locationServicesDisabled,
          message: null,
          actionLabel: l10n.openAppSettings,
          onAction: () =>
              ref.read(locationServiceProvider).openLocationSettings(),
        );
      case LocationPermissionDenied(:final permanentlyDenied):
        return _LocationMessageCard(
          icon: Icons.location_off_outlined,
          title: l10n.locationPermissionTitle,
          message: l10n.locationPermissionMessage,
          actionLabel: permanentlyDenied ? l10n.openAppSettings : l10n.retry,
          onAction: permanentlyDenied
              ? () => ref.read(locationServiceProvider).openAppSettings()
              : _captureLocation,
        );
      case LocationFailure():
        return _LocationMessageCard(
          icon: Icons.error_outline,
          title: l10n.locationUnavailable,
          message: null,
          actionLabel: l10n.retry,
          onAction: _captureLocation,
        );
    }
  }
}

class _CoordRow extends StatelessWidget {
  const _CoordRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _LocationMessageCard extends StatelessWidget {
  const _LocationMessageCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: theme.colorScheme.error),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
              ],
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.open_in_new),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
