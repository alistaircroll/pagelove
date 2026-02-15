---
name: writing-files
description: "Use when creating or modifying files on the Pagelove platform — server normalization, WebDAV caveats, JS MIME workarounds, and file creation techniques"
---

# Writing and Modifying Files

Pagelove sites are mounted as WebDAV volumes. Files can be created and modified through the local filesystem mount, but there are important caveats about server normalization and tool compatibility.

## Server Normalization

When you write an HTML file to the Pagelove mount, the server **normalizes** it before storing:

- Attribute order may change
- Whitespace may be adjusted
- Self-closing tags may be expanded (e.g., `<br/>` → `<br>`)
- Quotes may be normalized

This means the file you read back will not be byte-identical to what you wrote. This has critical implications for editing tools.

## Writing HTML Files

### Use `cat >` or Python `open().write()`

The Claude Code `Write` and `Edit` tools **will fail** on the WebDAV mount because server normalization breaks their string-matching and verification logic. This also affects `.md` files on the mount.

**Always use Bash to write files on the WebDAV mount:**

```bash
cat > "/Volumes/dav-preview-alistair.pagelove.cloud/app/index.html" << 'ENDOFFILE'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>My App</title>
</head>
<body>
    <h1>Hello</h1>
</body>
</html>
ENDOFFILE
```

Or with Python for complex content:

```bash
python3 -c "
content = '''<!DOCTYPE html>
<html lang=\"en\">
...
</html>'''
with open('/Volumes/dav-preview-alistair.pagelove.cloud/app/index.html', 'w') as f:
    f.write(content)
"
```

### Verify with `curl`, Not `WebFetch`

After writing a file, always verify it's accessible using `curl`:

```bash
curl -s -o /dev/null -w "%{http_code}" "https://your-site.pagelove.cloud/app/index.html"
```

**Do not use WebFetch** to verify — it has a 15-minute cache and may show stale content.

### Use HEAD to Check File Existence

**Important:** HEAD requests return 403 on Pagelove regardless of authorization rules. Always use GET to check both existence and access:

```bash
curl -s -o /dev/null -w "%{http_code}" "https://your-site.pagelove.cloud/path/file.html"
```

- `200` = exists and accessible
- `403` = exists but not authorized (or using HEAD)
- `404` = doesn't exist

## JavaScript and the MIME Type Problem

The Pagelove server serves `.js` files as `application/octet-stream` instead of `application/javascript`. Browsers refuse to execute scripts with the wrong MIME type.

**Solution: Always inline JavaScript into HTML files.**

```html
<!-- WRONG — will fail with MIME error -->
<script type="module" src="app.js"></script>

<!-- RIGHT — inline the JavaScript -->
<script type="module">
    import { PLDocument } from "https://cdn.pagelove.net/js/pagelove-primitives/1a5a161/index.mjs";
    // ... all app code here ...
</script>
```

This means:
- No external `.js` files for app logic
- All JavaScript goes inside `<script type="module">` tags in the HTML
- CDN imports (like PLDocument) work fine because they're served with correct MIME types
- The HiW (How it Works) panel code must be duplicated in every app

## Creating Directories

Create directories by simply writing a file into the path — the WebDAV server creates intermediate directories automatically:

```bash
cat > "/Volumes/dav-preview-alistair.pagelove.cloud/newapp/index.html" << 'ENDOFFILE'
<!DOCTYPE html>
<html>...</html>
ENDOFFILE
```

## File Types That Work

| Type | Works? | Notes |
|------|--------|-------|
| `.html` | Yes | Primary file type. Server normalizes on save. |
| `.md` | Yes | Served as-is. Edit tools may fail due to normalization. |
| `.css` | Yes | Served with correct MIME type. |
| `.js` | No | Served as `application/octet-stream`. Inline into HTML instead. |
| `.json` | Yes | Served as-is. |
| Images | Yes | Served with correct MIME types. |

## Normalized HTML Breaks String Matching

Because the server normalizes HTML, **never construct match strings from memory** when editing files. The actual file on disk may differ from what you expect.

Best practices:
- **Read actual file bytes** before attempting edits
- **Prefer full file rewrites** over partial edits
- **Use short regex matches** if you must do partial matching
- **Never match more than 3 lines** — longer matches are almost guaranteed to fail due to normalization differences

## Authorization for New Files

When creating a new file, you must also add authorization rules in `authz.html` for it to be publicly accessible. Without a GET rule, the file returns 403.

See the `pagelove:authorization` skill for rule schema and examples.

## Self-Test After Writing

After creating or modifying a file:

1. **Verify the file exists** on the mount: `ls /Volumes/.../path/file.html`
2. **Check HTTP access**: `curl -s -o /dev/null -w "%{http_code}" https://site/path/file.html`
3. **If 403**: Add GET rule to `authz.html`, wait 3-8 seconds, retry
4. **View in browser**: Open the URL and check for rendering or JavaScript errors
