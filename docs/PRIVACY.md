# Privacy Model

## Local harness

The committed harness contains synthetic presentation content, opens no network connections, stores no account state, and declares no collected data. Its privacy manifest reflects only the public harness and native code in this repository.

## Shared content

The Share Extension may receive a title, text, and one HTTP(S) URL selected by the user. Before persistence, the extension removes unsafe control characters, bounds field lengths, rejects credential-bearing URLs, and enforces a 65,536-byte encoded ceiling.

One payload is stored atomically in the shared App Group with data protection until first user authentication. It expires after 10 minutes and is deleted after consumption, expiry, corruption, or oversize rejection. Runtime code does not log shared content.

The app presents shared content for operator review in quote intake. It does not automatically generate, send, or finalize a quote.

## Hosted SaaS

Hosted mode can process account, freight, customer, and quote data under the private NexQuote SaaS privacy policy. Those production data flows are not represented by the empty public privacy manifest. App Store privacy labels must be completed from the hosted service's verified production inventory before release.

