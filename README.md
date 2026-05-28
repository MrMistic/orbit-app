# Orbit

A local-first personal life-management Android app. Everything you need to consult for your life — todos, recipes, fitness, finance, relationship tracking, and more — in one place. All data lives on your device.

## Features

Orbit is organized into modules. The first three are surfaced as bottom-nav home tabs (rearrangeable); the rest live under "More" and can be promoted at any time.

| Module | Highlights |
|---|---|
| **Todos** | CRUD, due dates, sort by earliest/latest, edit in place |
| **Recipes** | Tags, photos, favorites, search, URL import (JSON-LD), share as text, cook timer, step-by-step mode, integrated shopping list |
| **Relationship** | Cycle tracker with prediction algorithm, date ideas, gifts, important dates, trip planner with packing lists, conversation prompts, preferences journal, cycle-aware reminders, love-language reminders |
| **Fitness** | Exercise tracker (groups + sets), personal records with Epley/Brzycki 1RM, body metrics with TDEE (Mifflin-St Jeor), goals & programming with progressive overload + Prilepin's chart |
| **Finance** | Bills & subscriptions, savings goals & wishlist, cashback card picker, card "worth-it" analyzer, bankroll tracker; calculators for tip/split, loans, credit-card payoff, taxes, arbitrage, vig, parlay |
| **Shopping** | Manual list + recipe-driven groceries |
| **Media** | Books, movies, shows, podcasts, games, articles |
| **Contacts** | Personal CRM with reach-out cadence and overdue badges |
| **Skills** | Practice logging with total-hours tracking |
| **Projects** | Task checklists with status tracking |
| **Maintenance** | Recurring upkeep with overdue alerts |
| **Sleep** | Bedtime/wake logging with weekly bar chart |
| **Bucket list** | Life goals organized by category |

### Home screen widgets

Four Android home screen widgets, all tap-to-open into the relevant module:
- **Next todo** — most urgent upcoming todo with due date
- **Next date** — countdown to nearest important date
- **Fitness** — today's recommended workout from your active goal
- **Sleep** — weekly average hours slept

## Tech stack

- **Flutter** — cross-platform UI (Android-only build target for now)
- **ObjectBox** — local NoSQL database
- **GetX** — state management and routing
- **Material 3** with dynamic color
- **flutter_local_notifications** for cycle/reminder notifications
- **fl_chart** for sleep visualizations
- Native Android **AppWidgets** in Kotlin

## Architecture

- `lib/app/` — UI shell, modules registry, tab pages
- `lib/controllers/` — GetX controllers per module
- `lib/database/` — ObjectBox entity models and store wrapper
- `lib/services/` — algorithms (cycle prediction, fitness math), notifications, photo storage, widget data bridge
- `lib/data/` — static data (exercise names, conversation prompts, love-language suggestions)
- `android/app/src/main/kotlin/com/life/orbit/` — native widget providers and intent routing

Adding a new module is one entry in `lib/app/modules.dart`. Submodules within Relationship and Fitness follow the same registry pattern.

## Building

```bash
flutter pub get
dart run build_runner build      # regenerate ObjectBox bindings if models change
flutter run -d <device-id>
```

Android only. Min SDK 21+. Requires core library desugaring (already configured) for `flutter_local_notifications`.

## Data privacy

All data stays on the device. No accounts, no sync, no telemetry. ObjectBox stores data in the app's private documents directory; recipe photos go to the same directory's `recipe_photos/` subfolder.

If you "Clear data" in Android settings, everything is wiped. Backup/restore is on the roadmap.
