# Public Boundary

## Included

- Xcode project and shared `App` scheme;
- App lifecycle and route bridge source;
- Share Extension source;
- local Capacitor package manifest;
- deterministic local web harness;
- native unit and UI tests;
- public-safe app icon, splash, storyboards, localization, and privacy manifest;
- CI, publication guards, security policy, and architecture documentation.

## Excluded

- Django backend, database models, migrations, workers, and APIs;
- full Vue frontend, stores, private design system, and authentication implementation;
- pricing, margin, rate, customer-readiness, and PDF engines;
- OMEN and VANTIS implementations;
- infrastructure, deployment workflows, production configuration, and runbooks;
- secrets, signing material, browser state, customer data, and private Git history.

Extraction is allowlist-first. CI rejects unexpected paths, signing/generated artifacts, symlinks, common secret formats, and any object in fresh Git history outside this boundary.

