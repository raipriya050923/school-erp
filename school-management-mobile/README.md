# School Portal — Flutter mobile app

A student-facing mobile app built from the feature set of the companion React web
app in [`../school-management-web`](../school-management-web). Every screen runs on
**static, hard-coded data** — there is no API layer, no HTTP client and no
persistence.

## Running it

```bash
flutter pub get
flutter run                # attached device or emulator
flutter run -d chrome      # quick look in a browser
```

The login screen is pre-filled with the demo account; any input signs you in.

## What's in it

| Screen | Highlights |
| --- | --- |
| **Login** | Branded sign-in, validation, demo-build notice |
| **Dashboard** | Greeting, gradient snapshot card, quick actions, today's timeline, at-a-glance stats, announcement digest |
| **Timetable** | Day strip with per-day class counts, colour-coded period cards, break banners, period detail sheet |
| **Attendance** | Animated overall ring, month calendar with status legend, subject-wise meters, recent check-in records |
| **Results** | Exam switcher, score hero, rank/grade tiles, subject breakdown, animated trend chart, grading scale |
| **Assignments** | Status summary strip, filter chips, subject-accented cards, detail sheet with attachments and teacher feedback |
| **Fees** | Outstanding balance card, Overview / History / Structure tabs, pending payments, receipts, fee breakdown |
| **Notifications** | Unread badge, type and priority filters, mark-one / mark-all read |
| **Profile** | Gradient header, stat tiles, Personal / Academic / Family / Awards sections, menu, logout |
| **Settings** | Dark mode, language picker, notification channels and topics, security options, change-password sheet |

Dark mode is a real second theme, toggled from **Settings → Appearance**.

## Layout

```
lib/
  main.dart                     app entry + MaterialApp
  core/
    app_state.dart              in-memory session state (theme, read receipts, preferences)
    theme/app_colors.dart       palette, subject accents, gradients
    theme/app_theme.dart        Material 3 light & dark themes, radius/spacing tokens
    utils/formatters.dart       currency / percent formatting (no intl dependency)
    widgets/                    AppCard, SoftIcon, StatTile, MeterRow, StatusPill, FilterChipsRow, …
  data/
    models.dart                 immutable domain models
    static_data.dart            all sample content — the only file to replace when wiring an API
  features/
    auth/ shell/ dashboard/ timetable/ attendance/
    results/ assignments/ fees/ notifications/ profile/ settings/
```

`SchoolData` in `lib/data/static_data.dart` is the single source of content. Swapping
it for a repository backed by a real API is the only structural change needed to make
the app live.

## Dependencies

None beyond the Flutter SDK and `cupertino_icons`. The app builds and runs offline.

## Screenshots

Twenty captures of the app at 390×844 @2x live in [`screenshots/`](screenshots) —
every screen in light theme, plus dark-theme captures of the dashboard, timetable,
results, assignments and profile.

They are rendered off-screen rather than grabbed from a device, so they can be
regenerated on any machine without an emulator:

```bash
flutter test --run-skipped --tags screenshots --update-goldens
```

The harness (`test/screenshots_test.dart`) loads real system fonts and re-enables
shadow blur first, because the test environment otherwise draws text as boxes and
shadows as hard rectangles.

## Tests

```bash
flutter test
```

- `test/widget_test.dart` — sign-in flow, dashboard content, tab navigation.
- `test/screens_render_test.dart` — pumps every screen at 360×690, 390×844 and
  430×932 in both themes and asserts no layout overflow (64 cases).
- `test/screenshots_test.dart` — the capture harness above; skipped by default
  since it compares rendered pixels.
