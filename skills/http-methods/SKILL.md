---
name: http-methods
description: "Use when building any Pagelove interaction — understanding HTTP methods on DOM elements, selectors, status codes, and request/response patterns"
---

# HTTP Methods on DOM Elements

In Pagelove, every HTML file is its own API. The server grants browsers the ability to **read and modify HTML in-place** using standard HTTP methods. There is no separate backend or database — the HTML document _is_ the data store.

## How It Works

1. The page loads normally in the browser
2. JavaScript calls `doc.OPTIONS()` (see the `pagelove:client-libraries` skill)
3. The server responds with **capabilities** — which CSS selectors may use which HTTP methods
4. The client library attaches `.GET()`, `.PUT()`, `.POST()`, `.DELETE()` directly onto matching DOM elements
5. Calling these methods sends real HTTP requests; the server modifies the HTML file on disk

## The Four Methods

### GET — Read

Retrieves the current server-side state of an element.

```javascript
const plEl = await doc.createElement(domElement);
const response = await plEl.GET();
// response.status === 206 (Partial Content)
// The element's innerHTML is replaced with the server's version
```

- Returns `206 Partial Content` with `Content-Range` header
- Used for **polling** — periodically fetch fresh state from the server
- Does NOT require an authorization rule (GET on the page itself does)
- Scoped GET is more efficient than full-page fetch — transfers only the targeted element

### PUT — Replace

Replaces the element's representation on the server with the client's current state.

```javascript
element.dataset.status = "active";
element.dataset.score = "42";
await element.PUT();
// response.status === 206 (Partial Content)
```

- Returns `206 Partial Content` with `Content-Range` and `ETag`
- Sends the element's **current outerHTML** to the server
- The server replaces that element in the file on disk
- **Critical rule**: Never PUT a container with children you want to keep — the server will empty it. Use childless elements (e.g., `<div id="state" data-phase="lobby">`) for PUTable state.

### POST — Append

Appends a new child element inside a container.

```javascript
const newItem = document.createElement("li");
newItem.textContent = "Hello";
await container.POST(newItem);
// response.status === 206 (Partial Content)
```

Or with an HTML string:

```javascript
await container.POST("<li>Hello</li>");
```

- Returns `206 Partial Content` with `Content-Range` and `ETag`
- The server appends the new element as the **last child** of the container
- **Critical rule**: Never `appendChild()` before or after `POST()`. POST handles insertion automatically. Manually appending causes duplicates. This is the #1 Pagelove bug.
- The response includes the server-assigned markup of the new element

### DELETE — Remove

Removes the element from the server-side document.

```javascript
await element.DELETE();
// response.status === 204 (No Content)
```

- Returns `204 No Content` with `Content-Range`
- The element is removed from the HTML file on disk
- After deletion, the element should be removed from the client DOM as well

## Selector Range Unit

Pagelove uses **CSS selectors** as the addressing mechanism for partial document operations, exposed via the `Content-Range` header:

```
Content-Range: selector #my-element
```

- The `selector` range unit tells the server which element to target
- Valid CSS selectors: `#id`, `.class`, `tag`, `[attribute]`, compound selectors
- The server matches the selector against the document and operates on the first match
- `416 Range Not Satisfiable` is returned if the selector matches nothing

## Response Headers

| Header | Methods | Meaning |
|--------|---------|---------|
| `Content-Range` | GET, PUT, POST, DELETE | `selector <css-selector>` — which element was affected |
| `ETag` | GET, PUT, POST | Version identifier for the element's state |
| `Content-Type` | GET, PUT, POST | `text/html` |

## Status Codes

| Code | Meaning | When |
|------|---------|------|
| `200 OK` | Full document returned | GET on the whole page |
| `206 Partial Content` | Element returned | GET, PUT, POST on a specific element |
| `204 No Content` | Element removed | DELETE |
| `403 Forbidden` | Not authorized | Missing or incorrect authorization rule |
| `404 Not Found` | Resource doesn't exist | File not found |
| `409 Conflict` | Constraint violation | DELETE blocked by a ShapeConstraint (see `pagelove:multi-file-data`) |
| `416 Range Not Satisfiable` | Selector matches nothing | Invalid or non-matching CSS selector |
| `422 Unprocessable Content` | Shape violation | PUT/POST violates a ShapeConstraint |

## OPTIONS — Capability Discovery

The `OPTIONS` method is special — it doesn't modify anything. It returns a **capability map** telling the client which selectors support which methods.

```
OPTIONS /app.html HTTP/1.1
Accept: multipart/mixed
Prefer: return=representation
```

Response: `207 Multi-Status` with multipart body containing capability entries.

Each capability is received as a `PLCapability` event on the matching DOM element:

```javascript
element.addEventListener("PLCapability", (e) => {
    console.log(e.detail.selector);  // "#my-element"
    console.log(e.detail.allow);     // ["PUT", "DELETE"]
});
```

See the `pagelove:client-libraries` skill for the full OPTIONS protocol.

## Practical Examples

### Polling for updates (scoped GET)

```javascript
async function poll() {
    const plEl = await doc.createElement(document.querySelector("#game-state"));
    const response = await plEl.GET();
    // Element is now refreshed with server state
    render();
}
setInterval(poll, 3000);
```

### Updating game state (PUT)

```javascript
const state = document.querySelector("#game-state");
state.dataset.turn = "player2";
state.dataset.phase = "battle";
await state.PUT();
```

### Adding a chat message (POST)

```javascript
const chatLog = document.querySelector("#chat-log");
await chatLog.POST(`<li data-author="${escHtml(name)}">${escHtml(message)}</li>`);
```

### Removing an item (DELETE)

```javascript
await item.DELETE();
item.remove();  // Also remove from client DOM
```

## Key Rules

1. **Every method needs authorization** — see the `pagelove:authorization` skill
2. **PUT replaces the whole element** — never PUT containers with children you need
3. **POST auto-inserts** — never manually appendChild before/after POST
4. **Scoped GET > full-page fetch** — poll individual elements, not entire pages
5. **The DOM is the database** — there is no separate data layer
