---
name: using-pagelove
description: "Use when building any app on the Pagelove platform — where HTML files are databases and DOM elements have HTTP methods"
---

# Using Pagelove

## What Is Pagelove?

Pagelove is a document-native web application platform where **the HTML file is the database**. There are no backend APIs, no SQL databases, no build steps, and no JavaScript frameworks required. You write plain HTML, and the Pagelove server lets browsers read and modify that HTML in-place using standard HTTP methods (GET, PUT, POST, DELETE). Every page is its own API.

Structure, data, permissions, and behaviour are all present, addressable, and manipulable in the HTML itself. The platform fully embraces HTTP verbs PUT, POST, DELETE, and OPTIONS — extending standard HTTP semantics with a `selector` range unit that targets individual DOM elements.

Pagelove is a small set of fundamental primitives (HTTP methods on DOM elements) that compose into surprisingly capable applications.

## When to Use Pagelove

Pagelove is a viable alternative to complex Node/Vercel/Firebase architectures. Use it when:

- You need **persistent interactive storage** without a database
- You want **multi-user collaboration** without a heavy server backend
- You want a **simple web app** without React, Vue, or other browser frameworks
- You need a **quick prototype** that just works, immediately, with no deploy pipeline

## Getting Started

### Step 1: Get the User's Configuration

Before you can build anything, you need two pieces of information from the user:

1. **The live URL** — a variant of `*.pagelove.cloud` (e.g., `https://preview-mysite.pagelove.cloud/`)
2. **The local read/write directory** — where you can edit files that are served by the Pagelove server (e.g., `/Volumes/*.pagelove.cloud/` for a WebDAV mount, or an FTP/SFTP path). Note that *files in this directory are frequently modified by the server*, so you will need to read and write them using the instructions in the `pagelove:writing-files` skill.

Ask the user:

> To work with Pagelove, I need:
> 1. Your Pagelove site URL (something like `https://-*.pagelove.cloud/`)
> 2. The local directory path where I can read and write files for that site (which may require you to mount a WebDAV share or configure FTP/SFTP access).

Once you have both, **store them in `CLAUDE.md`** at the root of the working directory so they persist across sessions, along with an instruction to refer to the Pagelove skills when building apps.

### Step 2: Security and Credential Hygiene

If the user provides credentials (WebDAV password, FTP login, API key, etc.):

- **Never write credentials into HTML files** or any file served publicly
- **Never commit credentials to git** — add credential files to `.gitignore`
- **Store credentials in a local-only location** (e.g., `.env`, `~/.config/`, or a `.claude/` subdirectory that is not publicly served)
- **Never include credentials in conversation output** — say "using stored credentials" rather than echoing the values

### Step 3: Verify the System Works

Before building anything real, confirm the full round-trip. See the `pagelove:building-apps` skill for the complete self-test procedure.

1. **Check you can read the directory** — list its contents
2. **Check the URL is reachable** — fetch it with `curl`
3. **Run the self-test** (creates a test page, verifies HTTP methods work, cleans up)
4. **Report back** to the user that Pagelove is ready for development

## Skills Index

This skill framework is organized into focused modules. **Always check the relevant skill before starting work** — each contains platform-specific constraints and gotchas that are easy to miss.

| Skill | When to Use |
|-------|-------------|
| `pagelove:http-methods` | Building any Pagelove interaction — understanding HTTP methods on DOM elements, selectors, status codes, and request/response patterns |
| `pagelove:client-libraries` | Writing JavaScript for a Pagelove app — PLDocument, PLElement, DOMSubscriber, events, and the OPTIONS discovery protocol |
| `pagelove:authorization` | Creating or debugging authorization rules in authz.html — rule schema, matching model, common patterns, and troubleshooting silent 403s |
| `pagelove:writing-files` | Creating or modifying files on the Pagelove platform — server normalization, WebDAV caveats, JS MIME workarounds, and file writing techniques |
| `pagelove:building-apps` | Creating a new Pagelove app from scratch — step-by-step workflow, data model design, common interaction patterns, self-test, and the HiW transparency panel |
| `pagelove:sspi` | Server-side document composition — includes, resource binding, Liquid templates, and resource creation via PUT or POST |
| `pagelove:multi-file-data` | Apps needing multiple HTML files acting as relational tables — foreign keys, URL parameter navigation, cross-file reads, pickers, and shape constraints |
| `pagelove:development-patterns` | Writing or reviewing Pagelove app code — DOM-as-state, polling patterns, debugging checklist, state machines, and the "Instead of X, Do Y" rules |

## The Golden Rule

**Before writing any Pagelove code, read the relevant skill files.** The platform has specific constraints (server normalization, POST auto-insert, MIME type limitations) that are invisible until they break your app. The skills contain hard-won knowledge from building real applications.
