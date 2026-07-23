# Native Bridge Contract

## Web to native

Messages use the `nqBridge` WebKit message handler.

Native also emits `nq:native-bridge-available` after installing the handler. The consumer responds with `ready`; the normal startup `ready` remains required so either initialization order completes the handshake without timer retries.

```json
{ "type": "ready", "version": 1 }
```

```json
{ "type": "ack", "id": "delivery-id", "status": "accepted" }
```

The local harness alone may request a synthetic route:

```json
{ "type": "harness-route", "path": "/app/quotes/new?source=shortcut" }
```

## Native to web

Routes arrive through `nq:native-route`:

```json
{ "id": "delivery-id", "path": "/app/rates/import?source=deep-link" }
```

Sanitized share data arrives first through `nq:native-share` with the same delivery ID:

```json
{
  "routeId": "delivery-id",
  "payload": { "title": "Optional", "text": "Optional", "url": "https://example.com" }
}
```

Consumers must register both event listeners before sending `ready`. A route must be acknowledged only after it is accepted for navigation or safely preserved through authentication redirect. Share payloads must stay outside URLs, logs, analytics, and customer-facing output until the operator reviews them.
