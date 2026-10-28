# dt_ex_gen

Generate asset path constants and Flutter localization code from `build.yaml`.
Each configured entry writes a standalone Dart file to its own output path.
No annotations, placeholder classes, source library, or `part` directive is required.

## Installation

Add the generator to the consuming application's `pubspec.yaml`.

Adjust the path for your project. The generator currently requires Dart
`^3.13.4` and is not published to pub.dev.

Asset-only output contains Dart constants. Localization output also requires
Flutter and `intl` in the consuming application's dependencies. For Flutter's
built-in widget translations, add `flutter_localizations` as well:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: ^0.20.3

dev_dependencies:
  dt_ex_gen:
    git:
      url: https://github.com/exbraiin/dt_ex_gen.git
  build_runner: ^2.17.1
```

or

```bash
# dependencies
flutter pub add "flutter_localizations@{sdk: flutter}" intl
# dev dependencies
flutter pub add "dev:dt_ex_gen@{git: https://github.com/exbraiin/dt_ex_gen.git}" dev:build_runner
```

## Configuration

Create `build.yaml` beside the application's `pubspec.yaml`:

```yaml
targets:
  $default:
    builders:
      dt_ex_gen:
        options:
          assets:
            MyImages:
              output: lib/generated/my_images.g.dart
              directories:
                - assets/image/backgrounds
                - assets/image/placeholders
            MyLanguages:
              output: lib/generated/my_languages.g.dart
              directories:
                - assets/lang
              recursive: false
          localizations:
            MyLocalization:
              defaults: false
              output: lib/generated/my_localization.g.dart
              asset: assets/lang/en.json
```

Both sections are optional. Add multiple entries to generate multiple files.
The builder runs once per package; no `generate_for` setting is needed.

The builder uses the package name, so `dt_ex_gen:` is the short form of
`dt_ex_gen:dt_ex_gen:`. Replace the previous `dt_ex_gen:dt_ex:` key in existing
configurations with `dt_ex_gen:`.

| Setting | Meaning |
| --- | --- |
| Entry name | Public class name, starting with an uppercase letter and containing only ASCII letters, digits, or underscores. |
| `output` | Required, unique package-relative `.dart` path under `lib/`. Use forward slashes without empty, `.` or `..` path segments. |
| `directories` | Required for assets. List of directories relative to the package root. |
| `recursive` | Asset scanning includes subdirectories by default. Set to `false` to scan only direct children. |
| `asset` | Required for localization. Package-relative path to the JSON file used to generate keys and method signatures. |
| `defaults` | Optional for localization. If true creates a delegate with default values scanned from 'asset' directory. |

Each entry owns its output file; two entries cannot share an output path. Keep
output paths outside scanned asset directories and use distinct generated class
names across entries.

The localization entry name also determines the generated service, delegate,
keys, methods, and extension names. For example, `AppTranslations` generates
`AppTranslations`, `AppTranslationsKeys`, and `AppTranslationsMethods`.

## Generate files

Run from the consuming application's directory:

```sh
flutter pub get
dart run build_runner build
```

For a Dart project generating only asset constants, use `dart pub get` instead.
To regenerate while editing:

```sh
dart run build_runner watch
```

The example configuration produces:

```text
lib/generated/my_images.g.dart
lib/generated/my_languages.g.dart
lib/generated/my_localization.g.dart
```

Import these files directly:

```dart
import 'generated/my_images.g.dart';
import 'generated/my_languages.g.dart';
import 'generated/my_localization.g.dart';
```

Alternatively, create a library that exports them:

```dart
export 'generated/my_images.g.dart';
export 'generated/my_languages.g.dart';
export 'generated/my_localization.g.dart';
```

Generated files include a generated-code header and are formatted automatically.
Edit the configuration or source assets rather than the generated files.

## Asset constants

An asset such as `assets/image/backgrounds/banner.png` produces a constant like:

```dart
abstract final class MyImages {
  static const banner = 'assets/image/backgrounds/banner.png';
}
```

Use it normally:

```dart
Image.asset(MyImages.banner);
```

Names are derived from filenames and normalized to camel case. Leading digits
and reserved keywords receive an `asset` prefix. Collisions are resolved using
extensions, parent directory names, and numeric suffixes, so the final field name
can change when conflicting files are added.

Paths are sorted and deduplicated across overlapping directories. Single-digit
Flutter resolution directories matching paths such as `/2.0x/` are excluded.

Register runtime assets separately in Flutter's `pubspec.yaml`; generation does
not update asset registrations:

```yaml
flutter:
  assets:
    - assets/image/backgrounds/
    - assets/lang/
```

Add entries for any additional asset subdirectories your application uses.

## Localization

The source JSON must be a flat object with string values. For example,
`assets/lang/en.json`:

```json
{
  "greeting": "Hello {name}",
  "chars": "Characters {n}",
  "chars.one": "Character {n}"
}
```

With the entry name `MyLocalization`, the output contains:

| Declaration | Purpose |
| --- | --- |
| `MyLocalizationKeys` | Static constants for localization keys. |
| `MyLocalizationMethods` | Typed methods that call a translation provider. |
| `MyLocalization` | Runtime JSON loading, lookup, parameter substitution, and delegate creation. |
| `MyLocalizationExt` | A `BuildContext.labels` extension for typed translations. |

The runtime delegate is generated in the same file. Its imports include Flutter,
`dart:convert`, and `intl`; it does not import another localization runtime package.

Configure your `MaterialApp` with the generated delegate:

```dart
final languageAssets = <Locale, String>{
  const Locale('en'): MyLanguages.en,
  const Locale('pt'): MyLanguages.pt,
};

MaterialApp(
  supportedLocales: languageAssets.keys,
  // or if 'defaults' is true:
  supportedLocales: MyLocalization.supportedLocales,  
  localizationsDelegates: [
    ...GlobalMaterialLocalizations.delegates,
    MyLocalization.createDelegate(
      assets: languageAssets,
      fallback: const Locale('en'),
    ),
    // or if 'defaults' is true:
    MyLocalization.delegate,
  ],
  home: const HomePage(),
);
```

This example assumes both `en.json` and `pt.json` exist and are registered as
Flutter assets. From a widget below `MaterialApp`, use:

```dart
Text(context.labels.greeting('Alex'));
Text(context.labels.chars(2, howMany: 2));
```

You can also access the service or keys directly:

```dart
final localization = MyLocalization.of(context);
final text = localization.valueOf(MyLocalizationKeys.greeting,
    params: {'name': 'Alex'});
```

Placeholders such as `{name}` become positional `Object?` arguments. Repeated
placeholders produce one argument. Double-braced placeholders are not converted
to method parameters.

The unsuffixed key supplies the default plural value. Supported plural suffixes
are `.zero`, `.one`, `.two`, `.few`, and `.many`; these variants do not create
separate methods or key constants. A base key with any of these variants receives
a required named `howMany` argument. Method parameters come from the base value,
so use consistent placeholders across its plural variants.

The delegate loads the selected locale's JSON asset, or the configured fallback
asset when no locale entry exists. Missing translation keys return an empty
string; fallback is applied to the asset selection, not individual keys.

Only the JSON file configured by `asset` defines generated keys and signatures.
Other language files are loaded at runtime and should use matching keys.

## Regeneration

Asset discovery and source JSON reads are tracked build inputs. Adding or removing
scanned assets, changing source translations, or editing builder options is picked
up by subsequent builds. Runtime-only translation files do not define generated
method signatures.

If an output is missing, check that the builder options are under
`dt_ex_gen`, each entry has an `output`, and all input paths are relative to
the consuming package root. After changing paths or names, rerun generation and
update imports to the new output files.
