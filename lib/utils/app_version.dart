/// The app's version, shown at the foot of Settings ("Studio 3 · 1.0.0", `Settings`).
///
/// Kept by hand rather than read from the platform at run time, so it needs no plugin; a test
/// (`test/new_ui/settings_test.dart`) fails if it drifts from `version:` in pubspec.yaml.
const String kAppVersion = '1.0.0';
