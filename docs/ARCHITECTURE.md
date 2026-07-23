# Architecture

## Decision

NexQuote iOS uses a hardened Capacitor shell with two explicit modes:

- `harness`: committed default. Loads local, deterministic, non-sensitive web resources. Network access is blocked by CSP.
- `hosted`: private release configuration. Loads exactly `https://nexquoteapp.com/app/dashboard` and keeps relative `/api/v1` calls on the same origin.

Hosted same-origin was chosen over bundling the private Vue SPA. It publishes less code and avoids adding a second CORS, CSRF, cookie, refresh-token, and API-origin contract.

## Native route bridge

The bridge accepts only:

- `/app/dashboard`
- `/app/quotes/new`
- `/app/rates/import`

Each route has a separate query-name and query-value allowlist. Duplicate query names, fragments, user information, nonstandard HTTPS ports, malformed URLs, and credential-like parameter names fail closed.

Native queues at most eight unique deliveries. The web consumer sends `ready`, native sends one delivery, then the web consumer sends an `ack` before the next delivery. No timer retries are used.

## Share Extension

The extension accepts plain text and one web URL. It sanitizes control characters and directional overrides, rejects credential-bearing or non-HTTP URLs, bounds fields and encoded payload size, then atomically writes one protected App Group file.

The app consumes and deletes that file, validates its age, emits `nq:native-share`, then opens allowlisted quote intake with `source=share-target`. Share data never travels in the route URL.

## Private SaaS boundary

This repository contains no pricing engine, tenant data, API implementation, production runtime configuration, complete Vue application, OMEN/VANTIS source, or deployment infrastructure. Hosted authentication and quote readiness remain authoritative in the private SaaS.

## App Store trade-off

The Share Extension, Quick Actions, deep-link validation, offline harness, and native lifecycle provide real native behavior. Hosted mode still presents a substantial web surface, so App Store Review Guideline 4.2 remains a release risk. See [App Store status](APP_STORE.md).

