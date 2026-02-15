---
name: client-libraries
description: "Use when writing JavaScript for a Pagelove app — PLDocument, PLElement, DOMSubscriber, events, and the OPTIONS discovery protocol"
---

# Client Libraries

Two ES modules, loaded from the Pagelove CDN:

```html
<script type="module">
    import { PLDocument } from "https://cdn.pagelove.net/js/pagelove-primitives/1a5a161/index.mjs";
    import { DOMSubscriber } from "https://cdn.pagelove.net/js/dom-subscriber/cde4007/index.mjs";

    const doc = new PLDocument();
    doc.OPTIONS();  // Fetches capabilities, attaches HTTP methods to DOM elements
</script>
```

> **CDN version note:** The official docs reference hash `1a5a161` for pagelove-primitives. Some existing apps use `278bb6d`. Both appear to work. When creating new apps, use the official `1a5a161` hash. Don't update working apps unless a specific fix is needed.

## PLDocument

- `new PLDocument(url?)` — represents the page; defaults to `window.location.href`
- `doc.OPTIONS()` — discovers capabilities from the server, then attaches `.PUT()`, `.POST()`, `.DELETE()` onto matching DOM elements via PLCapability events
- `doc.createElement(domElement)` — (async) creates a PLElement wrapping the given DOM element, enabling scoped HTTP methods like `.GET()` on that element

## PLElement (attached to DOM elements automatically by OPTIONS)

After `doc.OPTIONS()` resolves, matching DOM elements gain these methods:

- `element.PUT(body?)` — replaces the element on the server; defaults to sending `element.outerHTML`
- `element.POST(htmlString)` — sends an HTML string to the server, which appends it as a child; the server's response HTML is parsed and the single resulting node is appended to the DOM
- `element.DELETE()` — removes the element from both the DOM and the server-stored HTML
- `element.selector` — the auto-generated CSS selector used in the `Range` header

PLElements created via `doc.createElement()` additionally support:

- `plElement.GET()` — (async) sends a scoped GET request for just this element; returns a **new DOM element** parsed from the server response. Does NOT modify the local DOM — the caller must diff or apply changes manually

## POST Accepts HTML Strings

The official docs clarify that `POST()` accepts an **HTML string** (not just a DOM element). The response body is parsed and a single node is appended:

```javascript
// Both work:
container.POST("<li>New item</li>");           // HTML string
container.POST(document.createElement('li'));   // DOM element (serialized to outerHTML)
```

## Selector Generation

The library generates CSS selectors for elements by:
1. Using the element's `id` attribute if present (e.g., `#my-element`)
2. Building `:nth-child()` paths anchored to the nearest parent with an ID

## Multipart OPTIONS Protocol

For comprehensive capability discovery, the library sends:
```
OPTIONS /index.html HTTP/2
Accept: multipart/mixed
Prefer: return=representation
```

The server responds with `207 Multi-Status` and `multipart/mixed` content type. Each boundary-separated part contains:
- `Content-Range` header with a CSS selector
- `Allow` header listing permitted methods for that selector

This enables the library to discover capabilities for all elements in a single round-trip.

## Events

Two custom events are dispatched during operation:

**PLCapability** — emitted during OPTIONS discovery for each capability found:
```javascript
document.addEventListener('PLCapability', (e) => {
    console.log(e.detail.selector);  // CSS selector
    console.log(e.detail.allow);     // ["GET", "PUT", ...]
});
```
PLCapability events **bubble** and are **composed** (cross shadow DOM boundaries).

**PLMethodCompleted** — emitted after any HTTP method request completes:
```javascript
document.addEventListener('PLMethodCompleted', (e) => {
    console.log(e.detail.method);    // "PUT", "POST", "DELETE", etc.
    console.log(e.detail.response);  // Response object
});
```

## DOMSubscriber

A MutationObserver wrapper that fires a callback whenever elements matching a CSS selector appear in (or are removed from) the DOM. Essential for binding event handlers to dynamically created elements.

```javascript
DOMSubscriber.subscribe(rootElement, 'css-selector', (matchedElement) => {
    // Fires immediately for existing matches
    // Fires again whenever a new match appears in the DOM
});
```

**When to use DOMSubscriber:**
- Any app that uses POST (new elements arrive via server response and need event handlers)
- Any app that polls and replaces container contents (new DOM nodes need binding)
- Any app where elements can be created by other users (they appear during polling)

If your app uses POST or polls a container that holds interactive elements, **import DOMSubscriber alongside PLDocument** — it is not optional.
