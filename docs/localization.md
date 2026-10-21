# Client languages

The Flutter interface uses the SDK's `gen-l10n` workflow. English is the source
catalog (`lib/l10n/app_en.arb`). Russian, German, French, Spanish, and Simplified
Chinese use `app_ru.arb`, `app_de.arb`, `app_fr.arb`, `app_es.arb`, and `app_zh.arb`.
Modern Standard Arabic (`app_ar.arb`), Persian (`app_fa.arb`), and Hebrew
(`app_he.arb`) are separate
language options. Chinese currently uses Simplified characters; Traditional Chinese is not a
separate option. Generated
`app_localizations*.dart` files must not be edited manually.

Settings → Language provides System default and each language's native name. The choice
is saved separately in `settings/language.json`; connection settings and
subscriptions are unaffected. Unsupported device languages fall back to English.
Changing language rebuilds the interface while retaining the connection
controller. System default follows the device's supported locale preferences.

## Adding a language

1. Copy `app_en.arb` to `app_<locale>.arb`, set `@@locale`, and translate every
   message. Retain message keys, placeholder names, and ICU plural syntax.
   Translate full sentences; do not construct sentences by joining words.
2. Add the language's native name to `LocaleController.nativeName`. The Settings
   selector and Flutter supported locales are derived from generated catalogs.
3. For Android notification/tile text, add the eight native resources from
   `android/app/src/main/res/values/aora_language.xml` in the corresponding
   `values-<locale>` directory. Register the language in `AppLanguage.languages`.
   Windows tray labels use the Flutter catalog through the existing native channel.
4. Run `flutter gen-l10n`, `flutter analyze`, and `flutter test`. The catalog
   completeness test rejects missing/empty translations. Review
   `build/l10n-untranslated.json` when generating translations.
5. Check every page and dialog at 360 px and 420 px, including long labels,
   text scaling, dates, counts, and any right-to-left language. Build and check
   both platforms before distributing an update.

`context.l10n` exposes generated, typed messages in widgets. For dynamic text
outside widgets, keep a semantic state/value and format it with the current
`AppLocalizations` when presenting it (see update phases and connection checks).
`model_labels.dart` translates enum labels without changing serialized values.

Brand names, protocols, user-defined server/application names, subscription
provider descriptions, raw core logs, diagnostics, and low-level technical errors
remain as supplied. Routing validation and update-source validation have localized
messages; further typed errors can use `LocalizedFormatException`.

Android persists the native language choice so notification actions and the
Quick Settings tile remain translated when Flutter is closed. Updating the
language refreshes the notification/tile without restarting the VPN.

## Right-to-left layouts

Arabic, Persian, and Hebrew use Flutter's locale-driven right-to-left direction. Shared
controls use directional alignment and padding, so navigation, menus, and toggle
thumbs mirror with the interface. Selector overlays inherit the field's direction.
The Windows tray menu also requests right-to-left layout, and Android declares
native RTL support.

Connection links, routing values, package names, and raw logs retain left-to-right
display. Server and subscription names detect their own text direction. Technical
values embedded in translated sentences use LTR isolation through
`isolateTechnicalValue`; these controls are presentation-only and must never be
written into stored connection values, URLs, or configuration.

Language changes do not change the application version or automatically generate
new release installers. Bump the version and rebuild signed packages when ready
to publish a release containing the translations.
