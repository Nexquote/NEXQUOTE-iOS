# App Store Status

## Current status

- Simulator build and automated UI proof: supported.
- Apple Developer signing and App Group provisioning: not included.
- Universal Links entitlement and associated-domain file: not included.
- TestFlight distribution: not available.
- App Store submission: not available.

The repository must not be described as App Store-ready until device signing, Share Extension device proof, privacy metadata, support/privacy URLs, screenshots, review notes, and TestFlight acceptance are complete.

## Guideline 4.2

Hosted mode depends on the NexQuote SaaS web application. Native value currently includes Share Extension intake, Quick Actions, secure deep-link routing, bounded delivery state, App Group protection, and native lifecycle handling. An App Store reviewer may still consider the product too close to a website wrapper.

Before submission, validate that the native flows materially improve the freight workflow, remain functional through offline/degraded states, and are clearly demonstrated in review notes.

## Release checklist

1. Provision `com.nexquote.app`, `com.nexquote.app.ShareExtension`, and `group.com.nexquote.app` under the same Apple team.
2. Add Associated Domains only after `apple-app-site-association` is deployed and verified.
3. Run unit/UI tests plus physical-device Share Extension handoff in VI and EN.
4. Confirm portrait-only iPhone metadata matches the binary.
5. Complete App Privacy labels from the production SaaS data inventory, not from the empty local harness.
6. Confirm `ITSAppUsesNonExemptEncryption` remains accurate.
7. Provide verified support and privacy URLs.
8. Submit through TestFlight before claiming public availability.

