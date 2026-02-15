---
name: multi-file-data
description: "Use when an app needs multiple HTML files acting as relational tables — foreign keys, URL parameter navigation, cross-file reads, pickers, and shape constraints"
---

# Multi-File Relational Data Pattern

When a single HTML file is not enough — when you need the equivalent of multiple database tables with foreign keys, one-to-many or many-to-many relationships — Pagelove supports a **multi-file relational data pattern** where each HTML file acts as a table, and URLs act as the query language.

> **SSPI note:** For some cross-file data needs, `<pagelove:include>` and Resource Binding may simplify or replace the client-side fetch + DOMParser pattern described below. Includes keep fragments writable at their origin. Resource Binding enables server-side site-wide queries. See the `pagelove:sspi` skill. Consider SSPI first for new apps.

## When to Use This Pattern

Use multi-file relational data when:

- Your data model has **two or more entity types** that reference each other (e.g., customers and orders, projects and tasks, deals and contacts)
- You need **foreign keys** — records in one file that point to records in another
- You want **bidirectional navigation** — clicking a linked record should open it in its own file
- A single file would become unwieldy with too many unrelated data types

## Architecture: One File Per Table

Each HTML file is a "table." Records are **childless hidden `<div>` elements** inside a container, with all data stored in `data-*` attributes:

```html
<!-- File 1: orders.html -->
<div id="orders" style="display:none">
  <div class="order-record" id="o-abc123"
    data-id="abc123"
    data-name="Widget order"
    data-customer-ids="cust1,cust2"
    data-customer-names="Jane Smith,Bob Lee"
    data-updated="1700000000000"></div>
</div>

<!-- File 2: customers.html -->
<div id="customers" style="display:none">
  <div class="customer-record" id="c-cust1"
    data-id="cust1"
    data-name="Jane Smith"
    data-order-ids="abc123"
    data-order-names="Widget order"
    data-updated="1700000000000"></div>
</div>
```

**Why childless divs?** PUT on elements with children causes the server to empty them. By storing all data in `data-*` attributes on childless elements, PUT is safe. The visible UI is rendered separately by JavaScript — the data layer and render layer are fully decoupled.

**Why `display:none`?** The data containers are hidden. JS reads the `data-*` attributes and renders a UI (cards, tables, detail panels) independently. This lets you redesign the UI without touching the data model.

## Foreign Keys via Comma-Separated IDs

Store relationships as comma-separated ID lists in `data-*` attributes:

```
data-customer-ids="cust1,cust2"    <!-- foreign keys (IDs) -->
data-customer-names="Jane,Bob"     <!-- denormalized names for display -->
```

Always store **both IDs and display names**. The IDs are the canonical references; the names are denormalized for rendering without cross-file fetches. Names may become stale if changed on the other page — this is acceptable for most applications.

## Cross-File Navigation via URL Parameters

Since you cannot write to two files simultaneously from one page, relationships propagate via **URL parameters**. The URL is the inter-file communication layer.

### The URL Parameter Protocol

Define a set of URL parameters that each file recognizes and processes on load:

| Parameter | Action |
|-----------|--------|
| `?id=X` | Navigate to and display record X |
| `?new=1&related_id=X&related_name=N` | Open new-record form, pre-linked to a record in another file |
| `?add_relation=X&relation_name=N&record_id=R` | Link record X to record R, then update the data |

After processing URL parameters, clean the URL with `history.replaceState(null, '', window.location.pathname)` to prevent re-execution on refresh.

### Example Flow: Linking Records Across Files

**Linking a customer to an order (initiated from orders.html):**

1. User edits an order, clicks "+ Link Customer"
2. A modal does a **read-only cross-fetch** of `customers.html`, parses the `#customers` container, shows a searchable picker
3. User selects a customer -> the order's `data-customer-ids` and `data-customer-names` are updated, PUT
4. The customer chip becomes a link: `customers.html?id=X&add_order=O&order_name=N`
5. When the user clicks through, `customers.html` processes the URL params, adds the order to the customer's `data-order-ids`, PUTs

**Creating a new record from the other file:**

1. User views a customer, clicks "Create Order"
2. Navigates to `orders.html?new=1&customer_id=X&customer_name=Jane`
3. `orders.html` opens the new-order form with the customer pre-filled
4. On save: POST the order, then redirect to `customers.html?add_order=NEW_ID&order_name=N&customer_id=X`

## Cross-File Read (The Picker Pattern)

To let users pick records from another file, fetch that file's HTML and parse it:

```javascript
async function openPicker() {
  const resp = await fetch('/app/other-table.html');
  const html = await resp.text();
  const doc = new DOMParser().parseFromString(html, 'text/html');
  const records = Array.from(doc.querySelectorAll('.record-class'));
  // Render a searchable list from records' data-* attributes
  // On selection, update the local record's foreign key attributes and PUT
}
```

This is a **read-only** operation — the picker fetches the other file's HTML, extracts record data from `data-*` attributes, and displays them. No write to the other file happens here.

## Cross-File Data Display (Beyond Pickers)

The cross-file fetch pattern is not limited to pickers. Any page can fetch any other page's HTML and extract data for **display, enrichment, or aggregation** — turning multiple HTML files into a queryable data layer.

**Practical uses:**

| Pattern | Example |
|---------|---------|
| **Unified timeline** | A deal detail view fetches `contacts.html`, extracts notes tagged with that deal's ID, and merges them chronologically with the deal's own notes |
| **Cross-file enrichment** | A contact list fetches `deals.html` to show each linked deal's current stage badge inline |
| **Dashboard aggregation** | A dashboard view fetches both files, parses their data containers, and computes cross-file metrics (total pipeline by contact org, etc.) |
| **Relationship validation** | When displaying a linked record, fetch the source file to check if the record still exists and show current data |

```javascript
// Example: Fetch notes from another file that reference a specific record
async function fetchCrossFileNotes(dealId) {
  const resp = await fetch('/app/contacts.html');
  const html = await resp.text();
  const doc = new DOMParser().parseFromString(html, 'text/html');
  const notes = Array.from(doc.querySelectorAll('.contact-note'));
  return notes.filter(n => n.dataset.dealId === dealId);
}

// Example: Enrich linked records with live data from another file
async function enrichLinkedDeals(contactEl) {
  const dealIds = (contactEl.dataset.deals || '').split(',').filter(Boolean);
  if (!dealIds.length) return [];
  const resp = await fetch('/app/deals.html');
  const doc = new DOMParser().parseFromString(await resp.text(), 'text/html');
  return dealIds.map(id => {
    const deal = doc.querySelector(`.deal-record[data-id="${id}"]`);
    return deal ? { id, name: deal.dataset.name, stage: deal.dataset.stage, value: deal.dataset.value } : null;
  }).filter(Boolean);
}
```

**Key constraint**: Cross-file fetches are always **read-only**. You cannot write to another file from JavaScript — writes happen only to the current page. To modify data in another file, use URL parameter navigation.

**Performance best practices:**
- **Fetch on demand**, not on every poll cycle. Trigger cross-file reads when a user opens a detail view or dashboard, not on the 2-4s polling interval.
- **Cache within the session.** Store parsed cross-file data in a variable and reuse it until the user takes an action that would invalidate it.
- **Parse once, query many.** Fetch the full HTML once, parse it with DOMParser, then run multiple `querySelectorAll` calls against the parsed document.
- **Don't poll multiple files simultaneously.** Each file should poll only its own data containers. Cross-file reads are event-driven (user clicks, view switches), not timer-driven.

## Bidirectional Relationship Propagation

The key challenge: when you link A->B in file 1, you also need B->A in file 2. Since you can only write to the current file, propagation happens via navigation:

1. **File 1** updates its own record (adds the foreign key, PUTs)
2. **File 1** generates a URL that carries the reverse-link command
3. **User navigates** (or is redirected) to file 2 with that URL
4. **File 2** processes the URL parameters, updates its own record, PUTs
5. **File 2** cleans the URL with `replaceState`

This is inherently **eventually consistent**. If the user does not follow the link, the reverse relationship will not be written. For most applications, this is acceptable.

## Denormalized Names and Staleness

Each record stores both the IDs and display names of linked records. If a name changes in one file, the denormalized copy in the other file becomes stale. Mitigation strategies:

- **Accept staleness.** Names rarely change, and they refresh whenever a user navigates between pages (the URL carries current names).
- **Refresh on view.** When displaying a detail view with linked records, optionally cross-fetch the other file and update names if they've changed.
- **No real-time cross-file sync.** Don't try to poll both files simultaneously.

## Authorization Rules for Multi-File Apps

Each file needs its own set of authz rules. For a two-file app:

```
File 1 (e.g., /app/orders.html):
  GET  — public read
  PUT  — .order-record (update records)
  POST — #orders, #activity-log (create records, log actions)
  DELETE — .order-record, .log-entry (remove records)

File 2 (e.g., /app/customers.html):
  GET  — public read
  PUT  — .customer-record
  POST — #customers, #activity-log
  DELETE — .customer-record, .log-entry
```

## Activity Log Pattern

Include an `#activity-log` container in each file for POST-only append logging:

```html
<div id="activity-log" style="display:none"></div>
```

Log entries are childless `<div class="log-entry">` elements with `data-time`, `data-text`, `data-ts` attributes. POST new entries to record who did what. Display them in the UI by reading and rendering the container contents.

## Shared Navigation Bar

Multi-file apps should share a consistent navigation bar:

```html
<nav class="app-nav">
  <a href="/app/orders.html" class="logo">App<span>Name</span></a>
  <a href="/app/orders.html" class="tab active">Orders</a>
  <a href="/app/customers.html" class="tab">Customers</a>
</nav>
```

Highlight the active tab based on the current page.

## Key Constraints and Trade-offs

1. **No atomic cross-file writes.** You can only write to the file you are currently viewing. Relationship propagation requires user navigation.
2. **Eventual consistency between files.** Denormalized names may lag. Design around it.
3. **Polling is per-file.** Each file polls its own `#records` container independently. No cross-file polling needed.
4. **Cross-file fetch is read-only.** The picker pattern reads the other file's HTML but never writes to it directly.
5. **URL params are the RPC layer.** Treat URL parameters like API calls — define a clear protocol, validate inputs, clean URLs after processing.
6. **ID generation must be globally unique.** Use `Date.now().toString(36) + Math.random().toString(36).slice(2,7)` or similar. Prefix IDs with a type marker (e.g., `d-` for deals, `c-` for contacts) to disambiguate across files.

## Scaling Beyond Two Files

This pattern extends to three or more files. Each file defines its URL parameter protocol, and any file can cross-fetch any other file for read-only picker operations. The constraint remains: writes only happen to the current file, with propagation via URL-parameter navigation.

For complex multi-file apps, consider a **hub-and-spoke** model: one central file (e.g., a dashboard) that links to entity-specific files, each of which can cross-reference the others.

---

## Shape Constraints

Shape Constraints enable **structural validation of document modifications using CSS selectors**. They answer: "When something is modified, what structure must exist for that modification to be accepted?"

### ShapeConstraint Schema

```html
<div hidden="" itemscope="" itemtype="https://pagelove.org/ShapeConstraint">
    <span itemprop="resource">/app/*</span>
    <span itemprop="selector">#items li</span>
    <span itemprop="constraint">:has([itemprop=name])</span>
    <span itemprop="constraint">:has(button.delete)</span>
</div>
```

| Property | Type | Cardinality | Meaning |
|----------|------|-------------|---------|
| `resource` | Text | 0..n | Resource path patterns to scope the constraint; omission = global (all files) |
| `selector` | Text | 0..n | CSS selector for elements to constrain; defaults to `:root` if omitted |
| `constraint` | Text | 1..n | CSS selectors that **must match** within the modified element's subtree |

### Validation Process

1. Identify matching ShapeConstraint declarations by resource path (glob patterns supported)
2. Check if the request target matches the constraint's `selector`
3. Evaluate all `constraint` selectors against the proposed DOM state
4. Reject if any constraint selector fails to match

### Error Responses

- **`422 Unprocessable Content`** — returned when a POST or PUT violates a constraint. No partial modifications are applied.
- **`409 Conflict`** — returned when a DELETE operation would cause the closest matching ancestor to fail its constraints.

### Practical Example

Require that user list items always contain both `username` and `email`:

```html
<div hidden="" itemscope="" itemtype="https://pagelove.org/ShapeConstraint">
    <span itemprop="selector">li[itemtype*=User]</span>
    <span itemprop="constraint">:has([itemprop="username"])</span>
    <span itemprop="constraint">:has([itemprop="email"])</span>
</div>
```

ShapeConstraints are the **only server-side validation** Pagelove offers. Use them to prevent malformed elements from being persisted. Define constraints for every POST target to ensure children have required attributes.
