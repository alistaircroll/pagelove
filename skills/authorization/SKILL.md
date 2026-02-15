---
name: authorization
description: "Use when creating or debugging authorization rules in authz.html — rule schema, matching model, common patterns, and troubleshooting silent 403s"
---

# Authorization System (`authz.html`)

Every HTTP method on every resource requires **explicit authorization**. Without rules, everything is denied by default. Rules live in `/authz.html`, a structured HTML file using microdata. The platform scans the entire site for AuthorizationRule microdata during message processing.

## Important Behaviors

- `authz.html` is **admin-only** — it returns 403 from the public URL. Edit only through the local file system (WebDAV mount, FTP, etc.).
- Without a **GET** rule, a page returns 403 to the public.
- Write rules (PUT, POST, DELETE) are **scoped to CSS selectors** — you authorize modification of *specific elements*, not whole pages.
- **HEAD requests return 403** regardless of rules. Always use GET to test access:
  ```bash
  curl -s -o /dev/null -w "%{http_code}" "https://your-site.pagelove.cloud/page.html"
  ```
- Rule changes take **3-8 seconds to propagate**. Wait before testing.

## AuthorizationRule Schema

Rules use the `https://pagelove.org/AuthorizationRule` microdata schema with five properties:

| Property | Type | Cardinality | Meaning |
|----------|------|-------------|---------|
| `actor` | Text | 1..n | Who may perform this action — a username, group name, or `*` (wildcard for everyone) |
| `resource` | Text | 1..n | File path patterns from root — supports **glob patterns** (e.g., `/admin/*`) |
| `method` | Text | 1..n | HTTP methods (GET, PUT, POST, DELETE, OPTIONS) |
| `selector` | Text | 0..1 | CSS selector scope — which elements may be affected; empty = whole page |
| `action` | Text | 1 | `allow` or `deny` |

**Multiple values:** `actor`, `resource`, and `method` all support multiple values (cardinality 1..n), enabling a single rule to cover multiple actors, paths, and methods.

## Matching Model

A rule matches a request when **all four conditions** are satisfied:
1. **Actor match** — the requesting actor matches one of the rule's `actor` values, or the rule uses `*`
2. **Path match** — the request path matches one of the rule's `resource` patterns (supports globs)
3. **Method match** — the HTTP method matches one of the rule's `method` values
4. **Selector match** — if a selector is specified, the request targets elements matching that selector

When all conditions match, the rule's `action` (allow/deny) applies.

## Rule Structure

Rules are `<tr>` elements inside `<tbody id="authrules">`:

```html
<tr itemscope="" itemtype="https://pagelove.org/AuthorizationRule">
    <td itemprop="actor">*</td>
    <td itemprop="resource">/mypage.html</td>
    <td>
        <ul>
            <li itemprop="method">GET</li>
        </ul>
    </td>
    <td itemprop="selector"></td>
    <td itemprop="action">allow</td>
</tr>
```

## Common Rule Patterns

**Make a page publicly readable:**
```html
<tr itemscope="" itemtype="https://pagelove.org/AuthorizationRule">
    <td itemprop="actor">*</td>
    <td itemprop="resource">/myapp/index.html</td>
    <td><ul><li itemprop="method">GET</li></ul></td>
    <td itemprop="selector"></td>
    <td itemprop="action">allow</td>
</tr>
```

**Allow anyone to add children to a container (POST):**
```html
<tr itemscope="" itemtype="https://pagelove.org/AuthorizationRule">
    <td itemprop="actor">*</td>
    <td itemprop="resource">/myapp/index.html</td>
    <td><ul><li itemprop="method">POST</li></ul></td>
    <td itemprop="selector">ul#items</td>
    <td itemprop="action">allow</td>
</tr>
```

**Allow anyone to update or delete specific elements (PUT + DELETE):**
```html
<tr itemscope="" itemtype="https://pagelove.org/AuthorizationRule">
    <td itemprop="actor">*</td>
    <td itemprop="resource">/myapp/index.html</td>
    <td><ul><li itemprop="method">PUT</li><li itemprop="method">DELETE</li></ul></td>
    <td itemprop="selector">li, input</td>
    <td itemprop="action">allow</td>
</tr>
```

**Use glob patterns for multiple resources:**
```html
<tr itemscope="" itemtype="https://pagelove.org/AuthorizationRule">
    <td itemprop="actor">*</td>
    <td itemprop="resource">/blog/*</td>
    <td><ul><li itemprop="method">GET</li></ul></td>
    <td itemprop="selector"></td>
    <td itemprop="action">allow</td>
</tr>
```

**Multiple actors in one rule:**
```html
<tr itemscope="" itemtype="https://pagelove.org/AuthorizationRule">
    <td itemprop="actor">editors</td>
    <td itemprop="actor">admin</td>
    <td itemprop="resource">/blog/*</td>
    <td><ul><li itemprop="method">PUT</li><li itemprop="method">DELETE</li></ul></td>
    <td itemprop="selector">article</td>
    <td itemprop="action">allow</td>
</tr>
```

## GroupMembership Schema

Assigns actors (users or groups) to named groups for use in AuthorizationRule `actor` fields.

```html
<div itemscope itemtype="https://pagelove.org/GroupMembership">
    The <span itemprop="actor">john@example.com</span> user is assigned to the following groups:
    <ul>
        <li itemprop="group">editors</li>
        <li itemprop="group">writers</li>
        <li itemprop="group">staff</li>
    </ul>
</div>
```

| Property | Type | Cardinality | Meaning |
|----------|------|-------------|---------|
| `actor` | Text | 0..1 | The user or group being assigned to groups |
| `group` | Text | 1..n | Group(s) to assign the actor to |

Once assigned, group names can be used as `actor` values in AuthorizationRule. This enables role-based access control — define groups once, reference them in rules.

## Selector Scope

CSS selectors in authz rules are broader than you might intend. A PUT rule scoped to `td` allows modification of *every* `<td>` on the page. Mitigations:

- Use **ID-scoped selectors** where possible (`#data-grid td` instead of bare `td`)
- Keep data elements and layout elements in **separate semantic structures**
- Prefer **more specific selectors** even if it means more rules

## Troubleshooting Authorization

**Rules fail silently.** Malformed microdata is ignored — no error, just a 403. The most common mistakes:

1. **Missing `itemscope`/`itemprop`.** Every `<tr>` needs `itemscope="" itemtype="https://pagelove.org/AuthorizationRule"` and every `<td>` needs its `itemprop`. Plain `<td>` without `itemprop` is invisible to the authorization engine.

2. **Methods not wrapped in `<ul><li>`.** Even a single method must be `<ul><li itemprop="method">GET</li></ul>`. Bare text won't be recognized.

3. **Wrong resource path.** Must start with `/` and match exactly (e.g., `/myapp/index.html`, not `myapp/index.html`). Glob patterns like `/app/*` are supported.

**Always copy from the documented template** rather than writing rules from memory.

**Debug approach for 403 errors:**
1. Read `authz.html` from the local mount (it always returns 403 publicly — that's normal)
2. Verify every `<tr>` has correct `itemscope`/`itemtype`
3. Verify every `<td>` has the right `itemprop`
4. Verify methods are inside `<ul><li itemprop="method">...</li></ul>`
5. Verify the resource path starts with `/`
6. Wait 8 seconds, then re-test with `curl`

## The `authz.html` Boilerplate

```html
<!DOCTYPE html>
<html lang="en" xmlns:pagelove="https://pagelove.org/1.0"><head>
    <meta charset="UTF-8">
    <meta content="width=device-width, initial-scale=1.0" name="viewport">
    <title>Authorization Details</title>
    <link href="https://page.love/css/blog.css" rel="stylesheet">
    <script src="https://unpkg.com/invokers-polyfill@latest/invoker.min.js" type="module"></script>
    <script src="/dom-forms/index.mjs" type="module"></script>
    <script src="/js/itemprop-editable.mjs" type="module"></script>
</head>
<body class="tool">
    <main>
        <h1>Authorization Rules</h1>
        <table>
            <thead>
                <tr>
                    <th>Actor</th>
                    <th>Resource</th>
                    <th>Method</th>
                    <th>Selector</th>
                    <th>Action</th>
                </tr>
            </thead>
            <tbody id="authrules">

                <!-- Your rules go here -->

            </tbody>
        </table>
    </main>
</body></html>
```
