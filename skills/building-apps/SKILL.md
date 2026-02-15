---
name: building-apps
description: "Use when creating a new Pagelove app from scratch — step-by-step workflow, data model design, common interaction patterns, and the HiW transparency panel"
---

# Building a Pagelove App

This skill covers the end-to-end process of creating a new Pagelove application. Read this before starting any new app. For editing and file-writing specifics, see the `pagelove:writing-files` skill.

## Step-by-Step Workflow

### 1. Plan the Data Model

**The HTML is the database.** Before writing any code, decide:

- **What elements store state?** Each piece of mutable data needs a DOM element with a stable `id` and `data-*` attributes.
- **What methods does each element need?** PUT for updates, POST for appending children, DELETE for removal.
- **What's the container structure?** Lists (chat logs, leaderboards) use a container + POST. Single-state objects use a `<div>` + PUT.

**Critical rule:** Never PUT a container with children. The server empties children on PUT. Use a childless `<div>` for PUTable state:

```html
<!-- RIGHT: childless div for PUTable game state -->
<div id="game-state" data-phase="lobby" data-turn="" data-players="0"></div>

<!-- RIGHT: container for POSTable items -->
<ul id="chat-log"></ul>

<!-- WRONG: don't PUT this — children will be lost -->
<div id="board">
    <div class="cell" id="c1">X</div>
    <div class="cell" id="c2">O</div>
</div>
```

### 2. Write the HTML Structure

Pre-author **all structural UI** in the HTML. No `createElement` for layout — only for POST payloads.

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>My App</title>
    <style>
        /* All styles inline — .css files work but .js files don't,
           so keeping everything in one file is the convention */
    </style>
</head>
<body>
    <!-- Home link (standard across all apps) -->
    <a href="/" style="position: absolute; top: 12px; left: 12px; z-index: 10;
       text-decoration: none; font-size: 1.2em;">&#x1F3E0;</a>

    <h1>My App</h1>

    <!-- Game state: childless, PUTable -->
    <div id="game-state" data-phase="lobby" data-turn="" data-players="0"></div>

    <!-- Player slots: pre-authored, one per possible player -->
    <div id="players">
        <div id="p1" class="player" data-name="" data-status="empty"></div>
        <div id="p2" class="player" data-name="" data-status="empty"></div>
    </div>

    <!-- Chat/log: container for POST -->
    <ul id="log"></ul>

    <script type="module">
        import { PLDocument } from "https://cdn.pagelove.net/js/pagelove-primitives/1a5a161/index.mjs";

        const doc = new PLDocument();
        await doc.OPTIONS();

        // App logic here...
    </script>
</body>
</html>
```

### 3. Set Up Authorization Rules

Add rules in `authz.html` for your new app. At minimum you need:

- **GET** rule so the page is publicly accessible
- **PUT/POST/DELETE** rules scoped to the elements users should modify

See the `pagelove:authorization` skill for full schema and patterns.

### 4. Implement the App Logic

Standard app initialization pattern:

```javascript
import { PLDocument } from "https://cdn.pagelove.net/js/pagelove-primitives/1a5a161/index.mjs";

const doc = new PLDocument();
await doc.OPTIONS();

// Cache DOM references
const state = document.querySelector("#game-state");
const players = document.querySelectorAll(".player");
const log = document.querySelector("#log");

// Render function — reads DOM state, updates visual UI
function render() {
    const phase = state.dataset.phase;
    // Update UI based on current state...
}

// Polling — refresh state from server
async function poll() {
    const plEl = await doc.createElement(state);
    await plEl.GET();
    render();
}
setInterval(poll, 3000);

// Initial render
render();
```

### 5. Self-Test Procedure

After deploying your app:

1. Open the URL in a browser — confirm it loads without console errors
2. Open a second browser tab/window — confirm multiplayer interactions work
3. Verify state persists: reload the page — data should survive
4. Check authorization: test that unauthorized actions return 403
5. Verify polling: change state in one tab, wait for it to appear in the other

## Common Interaction Patterns

### Player Join (PUT)

```javascript
// Find an empty slot
const emptySlot = [...document.querySelectorAll(".player")]
    .find(p => p.dataset.status === "empty");

if (emptySlot) {
    emptySlot.dataset.name = playerName;
    emptySlot.dataset.status = "joined";
    await emptySlot.PUT();
}
```

### Add to Log (POST)

```javascript
await log.POST(`<li data-time="${Date.now()}" data-author="${escHtml(name)}">${escHtml(message)}</li>`);
```

**Never** `appendChild` before or after `POST()`. POST handles insertion automatically.

### Update State (PUT)

```javascript
state.dataset.phase = "playing";
state.dataset.turn = "p1";
await state.PUT();
```

### Remove Item (DELETE)

```javascript
await item.DELETE();
item.remove();  // Remove from client DOM after server confirms
```

### Scoped Polling (GET)

```javascript
async function pollElement(selector) {
    const el = document.querySelector(selector);
    const plEl = await doc.createElement(el);
    await plEl.GET();
}

// Poll multiple elements independently
setInterval(() => pollElement("#game-state"), 3000);
setInterval(() => pollElement("#log"), 2000);
```

## Polling Best Practices

- **Use scoped GET**, not full-page fetch — transfers only the targeted element
- **Skip render when user is typing** — if `document.activeElement` is inside the polled container, skip the UI rebuild to avoid destroying their input focus
- **2-4 second intervals** are standard across all apps
- **Adaptive polling**: increase interval when idle, decrease on activity

```javascript
// Skip rebuild if user is focused on an input inside the container
function render() {
    const container = document.querySelector("#main");
    if (container.contains(document.activeElement)) return;
    // ... rebuild UI
}
```

## Use sessionStorage, Not localStorage

`localStorage` is shared across all tabs on the same domain. Since all Pagelove apps share a domain, use `sessionStorage` to keep per-tab state (like the current player's name):

```javascript
sessionStorage.setItem("playerName", name);
const name = sessionStorage.getItem("playerName");
```

## Never Use prompt/confirm/alert

System dialogs (`prompt()`, `confirm()`, `alert()`) block browser automation and break testing. **Always use inline UI** — name-entry panels, confirmation modals with explicit buttons. This is mandatory.

```javascript
// WRONG
const name = prompt("Enter your name");

// RIGHT — show an inline name-entry panel
document.querySelector("#name-panel").hidden = false;
document.querySelector("#join-btn").addEventListener("click", () => {
    const name = document.querySelector("#name-input").value;
    // ...
});
```

## The HiW (How it Works) Panel

Every app includes a ~150-line "How it Works" transparency panel — a fetch interceptor that logs all HTTP requests in a slide-out side panel. This lets users see the actual HTTP methods firing as they interact with the app.

Because `.js` files are served with the wrong MIME type, this code must be **duplicated** in every app's HTML file. It cannot be shared as an external module.

The HiW panel pattern:
1. Intercepts `fetch()` globally
2. Logs method, URL, status, headers, and body
3. Renders in a slide-out panel toggled by a button
4. Uses a fixed-position UI that doesn't interfere with the app

## XSS Protection

When displaying user-generated text (names, chat messages, etc.), always escape HTML:

```javascript
function escHtml(str) {
    return str.replace(/&/g, "&amp;")
              .replace(/</g, "&lt;")
              .replace(/>/g, "&gt;")
              .replace(/"/g, "&quot;");
}
```

Use `escHtml()` in all POST payloads and text insertions that include user input.

## App Structure Checklist

- [ ] Single HTML file (all CSS and JS inline)
- [ ] Home link in top-left corner
- [ ] `<div id="game-state">` (or similar) — childless, PUTable
- [ ] Pre-authored player slots / structural UI
- [ ] Container elements for POSTable items
- [ ] PLDocument import + `doc.OPTIONS()` on load
- [ ] Polling with scoped GET (2-4 second intervals)
- [ ] `render()` function that reads DOM state
- [ ] `sessionStorage` for per-tab state
- [ ] `escHtml()` for user text
- [ ] HiW panel for transparency
- [ ] Authorization rules in `authz.html`
- [ ] No `prompt()`/`confirm()`/`alert()`
