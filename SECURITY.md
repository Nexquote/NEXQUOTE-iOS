# Security Policy

## Supported version

Security fixes target the latest commit on `main`. No App Store or TestFlight binary is currently distributed from this repository.

## Report a vulnerability

Use [GitHub private vulnerability reporting](https://github.com/Nexquote/NEXQUOTE-iOS/security/advisories/new). Do not open a public issue for route-bypass, data-exposure, authentication, App Group, or Share Extension findings.

Include the affected commit, reproduction steps using synthetic data, and expected impact. Never include production credentials, customer content, browser cookies, or authentication state.

## Scope

In scope:

- native route and query validation;
- ready/acknowledge bridge behavior;
- App Group file protection and expiry;
- Share Extension sanitation and lifecycle;
- local harness CSP and offline behavior;
- repository history or publication-boundary leakage.

The private NexQuote SaaS, production infrastructure, OMEN, and VANTIS are not published here. Report findings against those systems through their private owner channels.

