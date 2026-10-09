// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'RouteNote';

  @override
  String get placesTitle => 'My Places';

  @override
  String get searchHint => 'Search by name or notes';

  @override
  String get addPlace => 'Save current location';

  @override
  String get addPlaceTitle => 'Save Location';

  @override
  String get editPlaceTitle => 'Edit Location';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldNameHint => 'e.g. John\'s House';

  @override
  String get fieldNotes => 'Notes';

  @override
  String get fieldNotesHint => 'e.g. Gate 3, second floor';

  @override
  String get locationCoordinates => 'Coordinates';

  @override
  String get latitude => 'Latitude';

  @override
  String get longitude => 'Longitude';

  @override
  String get currentLocation => 'Current location';

  @override
  String get fetchingLocation => 'Getting your location…';

  @override
  String get nameRequired => 'Please enter a name';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get ok => 'OK';

  @override
  String get retry => 'Retry';

  @override
  String get navigate => 'Navigate';

  @override
  String get openInGoogleMaps => 'Open in Google Maps';

  @override
  String get openInWaze => 'Open in Waze';

  @override
  String get copyCoordinates => 'Copy coordinates';

  @override
  String get coordinatesCopied => 'Coordinates copied to clipboard';

  @override
  String get placeSaved => 'Location saved';

  @override
  String get placeDeleted => 'Location deleted';

  @override
  String get placeDetailsTitle => 'Place details';

  @override
  String get deletePlaceTitle => 'Delete place?';

  @override
  String deletePlaceMessage(String name) {
    return '\"$name\" will be removed from this device and from your next backup.';
  }

  @override
  String createdAt(String date) {
    return 'Saved $date';
  }

  @override
  String get emptyPlacesTitle => 'No saved places yet';

  @override
  String get emptyPlacesMessage =>
      'Tap the button below to save your current location.';

  @override
  String get noSearchResults => 'No places match your search.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get sectionLanguage => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageArabic => 'العربية';

  @override
  String get selectLanguage => 'Select language';

  @override
  String get sectionAccount => 'Google Account';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get signOut => 'Sign out';

  @override
  String signedInAs(String email) {
    return 'Signed in as $email';
  }

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get syncSignInRequired => 'Sign in with Google to sync';

  @override
  String get sectionSync => 'Backup & Sync';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncInProgress => 'Syncing…';

  @override
  String get syncComplete => 'Sync complete';

  @override
  String get syncSkipped => 'Sign in to sync';

  @override
  String syncFailed(String error) {
    return 'Sync failed: $error';
  }

  @override
  String lastSynced(String date) {
    return 'Last synced: $date';
  }

  @override
  String get neverSynced => 'Never synced';

  @override
  String get localOverridesCloud =>
      'Your device data always overwrites the Google Drive backup.';

  @override
  String get restoreFromDrive => 'Restore from Google Drive';

  @override
  String get restoreConfirmTitle => 'Restore from Google Drive?';

  @override
  String get restoreConfirmMessage =>
      'This replaces all places on this device with the backup from your Google Drive.';

  @override
  String get restoreComplete => 'Restore complete';

  @override
  String restoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String get locationPermissionTitle => 'Location permission needed';

  @override
  String get locationPermissionMessage =>
      'RouteNote needs access to your location to save places.';

  @override
  String get locationServicesDisabled =>
      'Please enable location services on your device.';

  @override
  String get locationUnavailable =>
      'Could not determine your location. Please try again.';

  @override
  String get openAppSettings => 'Open settings';

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get about => 'About';

  @override
  String get aboutDescription =>
      'RouteNote saves your favourite places offline and syncs them to your private Google Drive. Navigation opens in the maps app you already use.';
}
