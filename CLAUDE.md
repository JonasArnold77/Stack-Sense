# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Flutter (frontend)

```bash
flutter pub get            # Install dependencies
flutter run                # Run on connected device/emulator
flutter analyze            # Static analysis (dart analyze also works)
flutter test               # Run all tests
flutter test test/foo_test.dart   # Run a single test file
```

### Backend (Python / FastAPI)

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000   # Dev server (hot reload)
python populate_db.py                   # Seed supplement database
python setup_db.py                      # Initialize DB tables manually
```

Backend env vars live in `backend/.env`. Flutter reads its own `.env` at the project root (loaded via `flutter_dotenv`, referenced in `pubspec.yaml` assets).

### Local dev workflow (Windows)

`start.ps1` starts the FastAPI backend. `sync.ps1` copies files during development. `deploy_backend.ps1` pushes to the cloud.

---

## Architecture

### Flutter — Feature-first, Riverpod

The app is organized as `lib/features/<name>/{data,domain,presentation}`. Each feature follows the same layering:

- **domain/models/** — pure Dart data classes, no framework code
- **domain/repositories/** — abstract interfaces
- **data/repositories/...impl.dart** — concrete implementations (currently all `SharedPreferences`-backed, offline-first)
- **data/..._provider.dart** — Riverpod providers + `StateNotifier` business logic
- **presentation/screens/** — full screens
- **presentation/widgets/** — extracted sub-widgets (screens are typically split once they exceed ~300 lines)

State management is **Riverpod** throughout. `ProviderScope` wraps the whole app in `main.dart`. Providers are either `StateNotifierProvider` (mutable state), `Provider` (derived/computed), or `Provider.family` (parameterized). Never use `ref` directly in widgets outside of `ConsumerWidget`/`ConsumerStatefulWidget`.

**`ApiService`** (`lib/core/services/api_service.dart`) is a singleton that owns all HTTP calls. Never call `http` directly from widgets or providers.

**`AppFailure`** (`lib/core/error/failures.dart`) is a sealed class hierarchy. Throw subtypes (`NetworkFailure`, `StorageFailure`, …) from repositories; catch them in providers or UI.

### Navigation

`go_router` with a single `ShellRoute` for the main bottom-nav shell (`HomeScreen`). Routes are defined as constants in `AppRoutes`. Auth redirect logic lives in the `routerProvider` — it reads `authProvider` and `onboardingProvider` to decide where to send the user on startup.

Public routes (no auth required): login, register, confirm-email, forgot-password, onboarding.

### Two check-in systems (important!)

There are **two separate check-in models** that must not be confused:

| Model | Provider | Key | Purpose |
|-------|----------|-----|---------|
| `CheckinEntry` | `checkinProvider` | `checkins_v2` | Legacy 4-dimension daily score (energy/sleep/focus/mood 1–5) |
| `ProblemCheckinEntry` | `problemCheckinProvider` | `problem_checkins_v1` | New per-question ratings per problem field (e.g. "Schlaf", "Fokus") |

The `insightsProvider` reads both. Score chart data for dim-mapped fields (Schlaf→sleep, Fokus→focus) comes from `scoreHistory[dim.key]` (fed by `CheckinEntry`). Score chart data for unmapped problem fields (e.g. Herzgesundheit) comes from `problemCheckinHistoryProvider`.

### Supplement evidence model

Supplements have an `EvidenceLevel` (green/yellow/red). The main card is `EvidenceCard` in `lib/features/recommendations/presentation/widgets/evidence_card.dart`. It receives an optional `CommunityInsight` (aggregated community data: `userCount`, `improvementPercent`, `dimensionLabel`).

`_RelevanceBar` renders the fit-percentage bar (0–100). The `_CommunityRow` widget appears directly beneath it to show community effectiveness data.

### Insights screen

`InsightsDim` enum maps problem fields to chart dimensions (sleep/energy/focus/mood/all). The helper `_problemFieldToDim()` does the mapping; unmapped fields return `InsightsDim.all`. Chart point source logic:

- `effectiveFieldId != null && chartDim == InsightsDim.all` → use `problemCheckinHistoryProvider` (only real check-ins, no sim data)
- All other cases → use `data.scoreHistory[chartDim.key]`

### Backend

FastAPI app in `backend/main.py`. Four routers:

- `routers/recommendations.py` — Claude-powered supplement recommendations (cached in-memory, 6h TTL)
- `routers/users.py` — Cognito JWT auth, user persistence
- `routers/insights.py` — community insight aggregation
- `routers/checkin.py` — problem check-in persistence

`services/claude_service.py` wraps the Anthropic SDK. Recommendations use RAG: `PubMedService` fetches recent studies, `vector_service` searches local embeddings (fastembed), both are injected into the Claude prompt as context.

Auth is AWS Cognito (Amplify on Flutter side, `python-jose` JWT verification on backend). `amplifyconfiguration.dart` holds the Cognito pool config.

### Theme / design tokens

All colors: `lib/core/theme/app_colors.dart`. Evidence traffic-light colors use the `AppColors.evidence*` family. Typography: `AppTextStyles`. Spacing/radius constants: `AppConstants` in `lib/core/constants/app_constants.dart`. The header gradient used across all main screens is `GradientScreenHeader` in `lib/core/widgets/`.
