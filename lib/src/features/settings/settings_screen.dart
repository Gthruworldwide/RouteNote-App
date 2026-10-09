import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/date_formats.dart';
import '../../data/remote/auth_service.dart';
import '../../data/repositories/sync_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../providers/app_providers.dart';

/// Settings: language, Google account, and backup/sync controls.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AsyncValue<AuthUser?> auth = ref.watch(authProvider);
    final SyncState sync = ref.watch(syncControllerProvider);
    final Locale? locale = ref.watch(localeControllerProvider);

    ref.listen<SyncState>(syncControllerProvider, (prev, next) {
      if (prev?.status != SyncStatus.syncing) return;
      final SnackBar snackBar = switch (next.status) {
        SyncStatus.success => SnackBar(
          content: Text(
            next.outcome == SyncOutcome.restored
                ? l10n.restoreComplete
                : l10n.syncComplete,
          ),
        ),
        SyncStatus.error => SnackBar(
          content: Text(l10n.syncFailed(next.error ?? l10n.errorGeneric)),
        ),
        SyncStatus.skipped => SnackBar(content: Text(l10n.syncSignInRequired)),
        _ => const SnackBar(content: SizedBox.shrink()),
      };
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        }
      });
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _SectionHeader(title: l10n.sectionLanguage),
          const SizedBox(height: 4),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.selectLanguage),
              trailing: DropdownButton<Locale?>(
                value: locale,
                underline: const SizedBox.shrink(),
                items: <DropdownMenuItem<Locale?>>[
                  DropdownMenuItem<Locale?>(
                    value: null,
                    child: Text(l10n.languageSystem),
                  ),
                  DropdownMenuItem<Locale?>(
                    value: const Locale('en'),
                    child: Text(l10n.languageEnglish),
                  ),
                  DropdownMenuItem<Locale?>(
                    value: const Locale('ar'),
                    child: Text(l10n.languageArabic),
                  ),
                ],
                onChanged: (Locale? value) => ref
                    .read(localeControllerProvider.notifier)
                    .setLocale(value),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: l10n.sectionAccount),
          const SizedBox(height: 4),
          Card(child: _buildAccountSection(context, ref, l10n, auth)),
          const SizedBox(height: 24),
          _SectionHeader(title: l10n.sectionSync),
          const SizedBox(height: 4),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.cloud_done_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          sync.lastSynced == null
                              ? l10n.neverSynced
                              : l10n.lastSynced(
                                  formatDateTime(
                                    sync.lastSynced!,
                                    Localizations.localeOf(context).toString(),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.localOverridesCloud,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: sync.isSyncing
                        ? null
                        : () => ref
                              .read(syncControllerProvider.notifier)
                              .syncNow(),
                    icon: sync.isSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      sync.isSyncing ? l10n.syncInProgress : l10n.syncNow,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: sync.isSyncing
                        ? null
                        : () => _confirmRestore(context, ref, l10n),
                    icon: const Icon(Icons.settings_backup_restore_outlined),
                    label: Text(l10n.restoreFromDrive),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: l10n.about),
          const SizedBox(height: 4),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.aboutDescription,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildAccountSection(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AsyncValue<AuthUser?> auth,
  ) {
    return auth.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace stackTrace) => ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text(l10n.errorGeneric),
      ),
      data: (AuthUser? user) {
        if (user == null) {
          return Column(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(l10n.notSignedIn),
                subtitle: Text(l10n.syncSignInRequired),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton.tonalIcon(
                  onPressed: () => _signIn(context, ref, l10n),
                  icon: const Icon(Icons.login),
                  label: Text(l10n.signInWithGoogle),
                ),
              ),
            ],
          );
        }
        return Column(
          children: <Widget>[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.person),
              ),
              title: Text(user.displayName ?? user.email),
              subtitle: Text(user.email),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton.icon(
                onPressed: () => _signOut(context, ref, l10n),
                icon: const Icon(Icons.logout),
                label: Text(l10n.signOut),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signIn(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authProvider.notifier).signIn();
      await ref.read(syncControllerProvider.notifier).syncNow();
    } on AuthException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${l10n.syncFailed} ${e.message}')),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    }
  }

  Future<void> _signOut(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    await ref.read(authProvider.notifier).signOut();
  }

  Future<void> _confirmRestore(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.restoreConfirmTitle),
        content: Text(l10n.restoreConfirmMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.restoreFromDrive),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(syncControllerProvider.notifier).restoreFromDrive();
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
