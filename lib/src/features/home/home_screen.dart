import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/place.dart';
import '../../data/remote/auth_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../providers/app_providers.dart';
import '../../services/navigation_service.dart';
import '../add_place/add_place_screen.dart';
import '../place_detail/place_detail_screen.dart';
import '../settings/settings_screen.dart';
import 'widgets/place_card.dart';

/// The main screen: search, list, FAB capture, sync + settings actions.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddPlace(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AddPlaceScreen()));
  }

  void _openPlace(BuildContext context, Place place) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlaceDetailScreen(placeId: place.id),
      ),
    );
  }

  Future<void> _navigateToPlace(Place place) async {
    final NavigationService nav = ref.read(navigationServiceProvider);
    final bool launched = await nav.navigate(place.latitude, place.longitude);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).locationUnavailable),
        ),
      );
    }
  }

  /// Manual "Sync" action (AppBar): when signed out, triggers Google sign-in
  /// first — on success the [authProvider] listener below runs the backup
  /// automatically; when already signed in, syncs immediately.
  Future<void> _handleSyncTap() async {
    final AuthUser? user = ref.read(authProvider).value;
    if (user != null) {
      await ref.read(syncControllerProvider.notifier).syncNow();
      return;
    }

    await ref.read(authProvider.notifier).signIn();
    if (!mounted) return;
    if (ref.read(authProvider).value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).syncSignInRequired),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    // When a Google session is restored or a new one is signed in, back up the
    // local database automatically ("sync on open").
    ref.listen<AsyncValue<AuthUser?>>(authProvider, (prev, next) {
      if (next.isLoading) return;
      final AuthUser? user = next.value;
      if (user != null && prev?.value == null) {
        ref.read(syncControllerProvider.notifier).syncNow();
      }
    });

    final AsyncValue<List<Place>> placesAsync = ref.watch(placesProvider);
    final SyncState sync = ref.watch(syncControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.placesTitle),
        actions: <Widget>[
          if (sync.isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            tooltip: l10n.syncNow,
            onPressed: sync.isSyncing ? null : _handleSyncTap,
            icon: const Icon(Icons.cloud_sync_outlined),
          ),
          IconButton(
            tooltip: l10n.settingsTitle,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddPlace(context),
        icon: const Icon(Icons.my_location),
        label: Text(l10n.addPlace),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (String value) {
                setState(() => _query = value.trim().toLowerCase());
              },
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
          Expanded(child: _buildBody(placesAsync, l10n)),
        ],
      ),
    );
  }

  Widget _buildBody(
    AsyncValue<List<Place>> placesAsync,
    AppLocalizations l10n,
  ) {
    return placesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => _MessageView(
        icon: Icons.error_outline,
        title: l10n.errorGeneric,
        message: '$error',
      ),
      data: (List<Place> places) {
        if (places.isEmpty && _query.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: _MessageView(
              icon: Icons.place_outlined,
              title: l10n.emptyPlacesTitle,
              message: l10n.emptyPlacesMessage,
            ),
          );
        }

        final List<Place> filtered = _query.isEmpty
            ? places
            : places
                  .where(
                    (Place p) =>
                        p.name.toLowerCase().contains(_query) ||
                        p.notes.toLowerCase().contains(_query),
                  )
                  .toList();

        if (filtered.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: _MessageView(
              icon: Icons.search_off,
              title: l10n.noSearchResults,
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            itemCount: filtered.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: 8),
            itemBuilder: (BuildContext context, int index) {
              final Place place = filtered[index];
              return PlaceCard(
                place: place,
                onTap: () => _openPlace(context, place),
                onNavigate: () => _navigateToPlace(place),
              );
            },
          ),
        );
      },
    );
  }

  /// Pull-to-refresh performs a sync, then the places list is reloaded.
  Future<void> _refresh() =>
      ref.read(syncControllerProvider.notifier).syncNow();
}

/// Centered icon + text state, scrollable so it works inside a
/// [RefreshIndicator].
class _MessageView extends StatelessWidget {
  const _MessageView({required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(icon, size: 56, color: theme.colorScheme.outline),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (message != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
