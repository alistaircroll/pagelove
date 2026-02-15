---
name: development-patterns
description: "Use when writing or reviewing Pagelove app code — DOM-as-state, polling patterns, debugging checklist, state machines, and the 'Instead of X, Do Y' rules"
---

# Development Patterns

## Instead of X, Do Y

These rules define how Pagelove apps should be built. Violating them produces apps that fight the platform.

### No JS state objects — the DOM is your state

**Instead of** `const gameState = {phase, turn, players: [...]}` and rendering from it,
**store all mutable state as `data-` attributes on DOM elements**: `el.dataset.phase = "battle"; el.PUT()`.

### Pre-author all structural UI — no createElement for layout

**Instead of** building UI in a JS render loop,
**write every structural element in the initial HTML with a stable ID**. 4 players = 4 `<button>` slots. 10x10 grid = 100 `<td>` elements. `createElement` is only for POST payloads (chat messages, log entries) — never for UI structure.

### Move DOM nodes — never duplicate them

**Instead of** cloning or recreating elements to show them in different containers,
**`appendChild` the original element** to move it. `container.appendChild(existingEl)` relocates the node — its attributes, children, and event listeners travel with it.

### Update in-place — never tear down and rebuild

**Instead of** `container.innerHTML = ''` followed by a `createElement` loop,
**update existing elements' attributes and text**: `el.dataset.status = "joined"; el.querySelector('.name').textContent = name`. Zero `innerHTML`. Zero `remove()`.

> **Why this matters:** When you rebuild a container with `innerHTML`, every element inside it is destroyed and replaced with new DOM nodes. These new nodes do **not** have Pagelove's `.PUT()`, `.POST()`, or `.DELETE()` methods attached — those were bound to the original elements by `OPTIONS()`. Result: buttons that silently fail, DELETEs that do nothing, PUTs that throw "not a function."
>
> If you must replace container contents (e.g., during polling), use DOMSubscriber to re-bind event handlers to newly created elements, and call `OPTIONS()` again or use `doc.createElement()` to re-attach HTTP methods.

### CSS drives visibility — not JS show/hide

**Instead of** `element.style.display = 'none'` toggled by JS,
**set a phase attribute on an ancestor** and let CSS handle visibility:
```css
body[data-phase="lobby"] .lobby-only { display: block; }
body[data-phase="lobby"] .battle-only { display: none; }
```

### POST creates server-side — never appendChild before POST

`container.POST(childElement)` handles DOM insertion automatically. Never `appendChild` before or after POST. See the `pagelove:building-apps` skill for the full explanation.

### PUT the changed element — not bulk state

PUT only the specific element that changed. One cell = PUT that cell. One player's status = PUT that slot.

### Never PUT large containers

PUTting a wrapper div that contains many children causes the server to empty it — all children lost. Use a separate, childless element for PUTable metadata: `<div id="game-state" data-phase="lobby" data-turn="0"></div>`.

### Level-triggered, not edge-triggered

**Instead of** `if (newPhase !== oldPhase) { doSetup(); }` (fires once, easy to miss),
**check desired state idempotently on every sync cycle**: `if (phase === 'setup' && board.parentElement !== container) { container.appendChild(board); }`. Polling is inherently level-triggered — lean into it.

### Cross-file reads for data enrichment — not just navigation

**Instead of** only linking to other files via `<a href>` and relying on URL parameters for all cross-file data,
**fetch the other file's HTML and parse it for display data**: `fetch('/app/other.html')` -> `DOMParser` -> `querySelectorAll('.record')` -> extract `data-*` attributes. See the `pagelove:multi-file-data` skill for the full pattern.

### Per-tab identity with sessionStorage

**Instead of** `localStorage` (shared across tabs — two players overwrite each other),
**use `sessionStorage`** (scoped per tab). Each tab is an independent session.

---

## Lessons Learned

Hard-won knowledge from building real apps on Pagelove.

### Data Visibility — Everyone Sees Everything

The HTML file is the database, and GET serves the whole file. Every `data-*` attribute is visible to anyone who loads the page. There is no per-user filtering.

- **You cannot store secrets in the DOM.** Any attribute is visible via View Source.
- **CSS-only hiding is not security.** The underlying HTML is always accessible.
- **For per-user private data**, split content across separate pages with different authz rules (e.g., `/app/player-1.html`, `/app/player-2.html`).

### No Server-Side Logic (With Exceptions)

There is no server-side validation, business logic, or transaction support for standard HTTP operations. The server stores and serves HTML — nothing more.

- **No atomic transactions.** A multi-step operation requires sequential PUTs. Design each PUT to be independently meaningful so partial updates leave the app in a recoverable state.
- **No enforced business rules.** Turn order, rate limiting, input validation — all client-side only.
- **ShapeConstraints are your best defense.** Use them to enforce element structure on write (see the `pagelove:multi-file-data` skill). They return `422 Unprocessable Content` on violation — the only server-side validation Pagelove offers.
- **Design for cooperative users.** Pagelove works best for collaboration, not adversarial competition.

> **SSPI exception:** Server-Side Processing Instructions (Includes, Templating, Resource Binding) do add server-side logic — but for **rendering**, not validation. Templates can reshape data before delivery but cannot enforce business rules on writes. See the `pagelove:sspi` skill.

### Multi-User Sync via Polling

Polling is currently the only sync mechanism. Change subscriptions (push-based updates) are planned but not yet in production.

**Full-page polling** (for broad updates):
1. `fetch(location.href)` on an interval (2-3 seconds)
2. Parse with `DOMParser`
3. Diff remote elements against local DOM (by ID, by attribute)
4. Apply changes

**Scoped GET polling** (preferred for targeted updates):
1. `await pld.createElement(element).GET()` to fetch a single element's state
2. Diff the returned element's attributes against the local DOM
3. Apply changes manually

This means ~2-3 second latency between users. Fine for collaborative apps; insufficient for real-time twitch interactions.

**Polling best practices:**
- **Prefer scoped GET over full-page fetch** when only a few elements change between polls. `pld.createElement(el).GET()` fetches a single element — far cheaper than parsing the entire page.
- **Skip polls when the user is active.** If the user just typed or clicked, defer the next poll by a few seconds to avoid overwriting their in-progress work.
- **Use attribute diffing, not count-based comparison.** Comparing `children.length` is fragile when DELETEs happen mid-poll. Diff by element ID or a unique `data-*` attribute instead.
- **Beware vote/counter race conditions.** When two users simultaneously read a count, increment, and PUT, the last writer wins. Design counters as POST-per-vote where possible, or accept eventual consistency.

**DOMSubscriber is underused in polling architectures.** Rather than manually re-rendering after each poll diff, use DOMSubscriber to react to specific DOM mutations. See the `pagelove:client-libraries` skill.

### Scoped GET for Efficient Polling

The `PLElement.GET()` method enables **element-level fetching** — retrieving just one element's state instead of the entire page. Use it for:

- Polling-heavy apps where most of the page is static
- Waiting/lobby phases where only a status attribute changes
- Dashboards where independent panels poll at different rates

```javascript
const plEl = await pld.createElement(document.getElementById('game-state'));
const remoteEl = await plEl.GET();

for (const attr of remoteEl.attributes) {
    const local = document.getElementById('game-state');
    if (local.getAttribute(attr.name) !== attr.value) {
        local.setAttribute(attr.name, attr.value);
    }
}
```

**Don't call GET on hundreds of individual elements.** For large grids, use full-page `fetch()` + `DOMParser`. Scoped GET is for small, high-value elements.

**Phase-adaptive polling** — combine both approaches:

```javascript
async function poll() {
    const remoteGS = await (await pld.createElement(gs())).GET();
    applyAttrs(remoteGS, gs());

    if (currentPhase() === 'battle') {
        const resp = await fetch(location.href);
        const doc = new DOMParser().parseFromString(await resp.text(), 'text/html');
        // Diff board cells from parsed doc...
    }
}
```

---

## Design Philosophy

Pagelove is intentionally simple. Before reaching for a complex solution, ask:

- **Do I need a database?** The HTML file *is* the database. Every element is a record.
- **Do I need a REST API?** Every page *is* a REST API. The same URL serves HTML and accepts PUT/POST/DELETE.
- **Do I need a framework?** Vanilla `<script type="module">` with PLDocument and DOMSubscriber handles most patterns.
- **Do I need a deploy pipeline?** Files go live the moment they are written. No build, no CI, no staging.
- **Do I need real-time sync?** Multiple users can POST, PUT, and DELETE on the same page. The server handles the HTML file as the source of truth.
- **Do I need cross-document data?** SSPI Includes and Resource Binding can pull data from other files server-side. For client-side, use `fetch()` + `DOMParser`.

Start simple. **Add complexity only when Pagelove's primitives genuinely can't solve the problem.**

---

## Debugging and Troubleshooting

### Systematic Debugging Checklist

When something does not work, check these **in this order**:

1. **Is the file on disk?** `ls /path/to/mount/myapp/`
2. **Does it return 200?** `curl -s -o /dev/null -w "%{http_code}" URL` (never use HEAD)
3. **Is the content correct on disk?** Read from the local mount
4. **Is the content correct live?** `curl -s URL` and compare
5. **Is there a browser console error?** Check DevTools
6. **Is the authz rule well-formed?** See the `pagelove:authorization` skill

### Debugging Duplicate Entries

If items appear twice when created, the cause is almost always:

**Pattern 1: Manual DOM insertion + POST**
```javascript
// BUG: appendChild + POST = double insertion
container.appendChild(newItem);
container.POST(newItem);
```
**Fix:** Remove the `appendChild`.

**Pattern 2: Polling re-inserts items POST already added**
```javascript
// BUG: no dedup check
for (let i = localCount; i < remoteCount; i++) {
    localContainer.appendChild(remoteItems[i].cloneNode(true));
}
```
**Fix:** Check by ID before appending:
```javascript
if (!localContainer.querySelector(`[data-id="${remoteItem.dataset.id}"]`)) {
    localContainer.appendChild(remoteItem.cloneNode(true));
}
```

### Debugging Browser Console Errors

**"Expected a JavaScript module script but the server responded with a MIME type of application/octet-stream"**
- A `<script type="module" src="file.js">` is loading a `.js` file from Pagelove.
- **Fix:** Inline all JavaScript into the HTML. See the `pagelove:writing-files` skill.

**"Identifier 'X' has already been declared"**
- Variable declarations conflict when inlining JS from multiple sources into one `<script>` block.
- **Fix:** Use aliased imports or wrap in an `initApp()` function.

**"element.PUT is not a function"**
- The element does not have HTTP methods attached. Either `OPTIONS()` has not finished, or no authz rule covers this element.
- **Fix:** Ensure `await pld.OPTIONS()` completes first. Check authz rules.
- **Subtle variant:** Dynamically created elements do not automatically get methods. Only elements in the DOM when `OPTIONS()` runs (or matching capability selectors) get methods. Call OPTIONS again if needed.

### CSS Data-Attribute Selector Pitfalls

When using `data-*` attributes for state, CSS selectors must match **exact string values**. No type checking, no error on mismatch.

- **Copy-paste errors** — Two rules targeting the same value produce no error; the later rule wins.
- **Initial vs. modified values** — If JS changes `data-state="water"` to `"hit"`, CSS must target `"hit"`.
- **Empty vs. absent** — `[data-ship]` matches even `data-ship=""`, while `[data-ship]:not([data-ship=""])` matches only non-empty values.

### State Machine Design Patterns

1. **Always provide a reset mechanism from every non-initial phase.** Users will get stuck without one.
2. **Store the current phase in a PUTable element** so all users see transitions via polling.
3. **Make each phase transition idempotent.** Two simultaneous triggers should produce the same result.
4. **Use `data-*` attributes for mutable state, not element presence/absence.**
5. **Each PUT should leave the app in a valid state.** Interrupted sequences must leave coherent state.

### Modifying Live State Directly

Since the HTML file is the database, you can edit it directly on the local mount to fix broken state — the Pagelove equivalent of running SQL against production.

```python
python3 << 'PYEOF'
import re
path = '/path/to/mount/myapp/index.html'
with open(path, 'r') as f:
    content = f.read()
content = re.sub(r'data-phase="[^"]*"', 'data-phase="lobby"', content)
with open(path, 'w') as f:
    f.write(content)
PYEOF
```

Use this when users are stuck in broken state, or when you need to reset without redeploying.

---

## Test-Driven Development

### The Feedback Loop

1. **Write** a file on the local mount (`cat >` for HTML, Python for large files)
2. **Wait** if you changed `authz.html` (propagation takes a few seconds)
3. **Verify** the live URL:
   - `curl -s -o /dev/null -w "%{http_code}" URL` — check status code
   - `curl -s URL` — inspect content
4. **Iterate**

### Browser Test Framework

Pagelove projects can include a minimal browser-based test runner:

```javascript
import { TestRunner, assert, assertEqual, assertIncludes, assertMatch } from '../tests/test-runner.js';

const runner = new TestRunner();

runner.test('my test', async () => {
    assertEqual(1 + 1, 2, 'math should work');
});

runner.run();  // Renders pass/fail results into #test-output
```

Test harness HTML pages need a `<div id="test-output">Loading...</div>` and a `<script type="module">` that imports the test file. Every test file and test page needs a **GET** authz rule.
