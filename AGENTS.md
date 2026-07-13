# Repository Guidelines

## Project Structure & Module Organization

This repository is a multi-product workspace. Keep changes scoped to the relevant subproject.

- `README.md`: overall architecture and launch matrix.
- `VibeAdmin/`: operations backend; see `VibeAdmin/README.md`.
  - `VibeAdmin/vibe-admin-web/`: admin frontend.
  - `VibeAdmin/vibe-admin/`: FastAPI backend.
- `VibeBase/`: user-facing AI product.
  - `VibeBase/vibe-base/`: backend APIs, models, schemas.
  - `VibeBase/vibe-base-web/`: Vue user web app.
  - `VibeBase/ui/`: HTML design prototypes.
- `VibeApp/`: Flutter mobile app.
- `Vibe-Mp-H5/`: uni-app mini-program/H5 app.
- `docs/`: shared architecture and deployment docs.

## Build, Test, and Development Commands

Use the commands inside each subproject; they are not run from repo root.

```bash
# Admin backend
cd VibeAdmin/vibe-admin
python run_server.py

# Admin frontend
cd VibeAdmin/vibe-admin-web
corepack enable && pnpm install
pnpm dev              # http://localhost:5173
pnpm build            # vue-tsc + Vite production build
pnpm lint             # ESLint checks
```

```bash
# VibeBase backend
cd VibeBase/vibe-base
python main.py        # http://localhost:8081
```

```bash
# VibeBase web frontend
cd VibeBase/vibe-base-web
npm install
npm run dev           # http://localhost:5175
npm run build:prod    # Vite production build
npm run type-check    # vue-tsc
npm run format        # Prettier
```

```bash
# VibeApp
cd VibeApp
flutter pub get
flutter run
dart run build_runner build
```

```bash
# Vibe-Mp-H5
cd Vibe-Mp-H5
pnpm install
pnpm dev:h5           # H5 dev
pnpm dev:mp           # WeChat mini-program dev
pnpm build:h5         # H5 production build
pnpm test:run         # Vitest
pnpm lint             # ESLint
```

## Coding Style & Naming Conventions

- Frontend: TypeScript first; Vue components use `<script setup>` and Composition API.
- Naming: PascalCase for components, camelCase for variables/functions, kebab-case for file-based route directories.
- CSS/Styles: Tailwind utility classes first; keep local styles minimal.
- Admin frontend: 2-space indentation and `@antfu/eslint-config` rules.
- Mp-H5 frontend: Uni/Vue files with SFC block order `script`, `template`, `style`.
- Prettier is used in `VibeBase/vibe-base-web`.
- Flutter: analyze with `flutter analyze`; prefer small widgets under `lib/features/.../presentation/`.

## Testing Guidelines

- `VibeAdmin/vibe-admin-web/src/services/__tests__/*.test.ts`: Vitest + Vue Test Utils.
- `Vibe-Mp-H5/src/**/*.test.ts`: Vitest + jsdom.
- `VibeBase/vibe-base/tests/*.py`: FastAPI TestClient smoke/unit tests.
- `VibeApp/test/`: Flutter widget/unit tests.

Name tests with `<subject>.test.ts` or `<subject>_test.dart`. Run tests from the subproject that owns the code.

## Commit & Pull Request Guidelines

- Use Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`, `test:`.
- Keep PRs small and subproject-scoped.
- Include a clear description, affected paths, how to validate, and linked issues when available. Add screenshots or recordings for UI/admin changes.

## Security & Configuration Tips

- Do not commit `.env` files; copy `.env.example` where needed.
- The shared database is PostgreSQL; start middleware before dependent backends.
- Avoid changing schema or secrets without updating corresponding backend docs/tests.
