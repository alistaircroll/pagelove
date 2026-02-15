---
name: sspi
description: "Use when you need server-side document composition — includes, resource binding, Liquid templates, and resource creation via PUT or POST"
---

# Server-Side Processing Instructions (SSPI)

SSPI is a capability of the Pagelove platform that allows documents to be manipulated by the server **before** they are sent to the client. The server treats a site as an integrated system rather than isolated files, enabling:

- Projecting data into templates using site-wide information
- Including fragments from other documents
- Altering data presentation before client delivery

## Namespace Declaration

To activate SSPI features, declare the Pagelove namespace on the `<html>` element:

```html
<html xmlns:p="https://pagelove.org/1.0"
      xmlns:resource="https://pagelove.org/1.0/Resource">
```

**All recognized Pagelove namespace declarations, tags, and attributes are stripped before the page is delivered to the client.** Clients never see SSPI markup — only the processed result.

## Includes (`<pagelove:include>`)

Declarative cross-document fragment inclusion. Allows one document to include a fragment from another while keeping it addressable, authorisable, and writable.

```html
<pagelove:include selector="header#nav" resource="/partials.html" />
```

**Attributes:**
- **`selector`** (required) — CSS selector identifying which fragment to include
- **`resource`** (optional) — constrains which resources the selector searches. Supports glob-style wildcards (`*`, `**`, `?`). If omitted, the selector evaluates across the **entire site graph**

**Cardinality:** Resolution must yield **exactly one element**:
- Zero matches -> `404 Not Found`
- Multiple matches -> `500 Internal Server Error`

**Mutation behavior:** When clients PUT, POST, or DELETE included fragments, modifications apply to the **origin resource**, not the including document. Authorization rules and ETag concurrency control evaluate in the origin context.

**Examples:**
```html
<!-- Include a specific element from a specific file -->
<pagelove:include resource="/partials.html" selector="header#nav" />

<!-- Search the entire site for a unique element -->
<pagelove:include selector="#partials header#nav" />

<!-- INVALID: resource without selector -->
<pagelove:include resource="/partials.html" />
```

## Resource Binding (`resource:name`)

Site-wide CSS selector queries bound to named variables. Data lives in HTML, queries use CSS selectors, and integration happens inside documents.

```html
<div resource:users="[id][itemtype='http://example.com/TeamMember']"
     pagelove:template="text/liquid">
  <!-- users variable is now available in the template -->
</div>
```

**Syntax:** `resource:<name>="<css-selector>"` — the `<name>` becomes the variable name, the CSS selector is evaluated across the **entire site graph**.

**Properties:**
- **Site-wide** — selectors span all documents in the site
- **Structural** — results are HTML elements, not deserialized data
- **Live** — evaluation occurs at render time (every request)
- **Read-only** — for rendering only; modifications use HTTP methods

Requires the Resource namespace: `xmlns:resource="https://pagelove.org/1.0/Resource"`

Multiple bindings can coexist on a single element. Invalid selectors cause document processing failures.

## Resource Creation

Two modes for creating new resources (HTML files):

### Mode 1: Direct Creation via PUT

Send `PUT` to a new path with a complete HTML body. The resource name is client-determined, no templating occurs.

```
PUT /new-page.html HTTP/2
Content-Type: text/html

<!DOCTYPE html>
<html>...</html>
```

Requires one authz check: PUT permission for the new path.

### Mode 2: Templated Creation via POST

POST to a template file triggers server-side processing. The template generates a new resource.

**Process:**
1. Client sends `POST /templates/thing.html`
2. Server verifies POST permission for the template
3. Template processes with request data (body, query params, headers, actor identity)
4. Generated document must contain `<base href="/final/path.html">` declaring the storage location
5. Server verifies PUT permission for the `<base href>` location (second authz check)
6. Document is written to the specified path
7. Server responds with `301 Moved Permanently` + `Location: <base.href>`

**Two authorization checks required:** POST to the template AND PUT to the final location.

| Aspect | PUT | POST + Template |
|--------|-----|-----------------|
| Name determination | Client | Template via `<base>` |
| Server logic | None | Full templating |
| Authorization checks | 1 | 2 |
| Response | Standard | `301` redirect |

## Templating (`pagelove:template`)

Server-side rendering using the Liquid template engine, scoped to individual HTML elements.

```html
<div resource:users="[itemtype*=TeamMember]"
     pagelove:template="text/liquid">
  <ul>
    {% for user in users %}
    <li>{{ user | microdata: "name" }}</li>
    {% endfor %}
  </ul>
</div>
```

**Activation:** Add `pagelove:template="text/liquid"` to any element. Only the subtree rooted at that element is processed.

**Data sources:**
1. **Bound resources** — variables from `resource:name` attributes
2. **HTTP request** — accessible via `{{ request }}` (includes body, query params, headers, actor)
3. **Template-local variables** — standard Liquid variables

**Constraints — templates are:**
- **Scoped** — only the annotated element's subtree
- **Side-effect free** — cannot mutate documents or create resources
- **Deterministic** — cannot perform I/O or issue HTTP requests

**Composition:** Use `<pagelove:include>` for structural composition (pulling in fragments) and `pagelove:template` for data-driven rendering. They work together.