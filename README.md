# Pagelove Skills for Claude Code

A skills framework for building apps on [Pagelove](https://pagelove.org) — the platform where **HTML files are databases** and **DOM elements have HTTP methods**.

## What is Pagelove?

Pagelove is a document-native web application platform. You write plain HTML, and the server lets browsers read and modify that HTML in-place using standard HTTP methods (GET, PUT, POST, DELETE). Every page is its own API. No backend, no database, no build steps, no frameworks.

## What This Repo Provides

A structured set of **skills** (knowledge files) for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) that teach it how to build Pagelove applications correctly. Each skill covers a specific aspect of the platform, from HTTP methods to authorization to multi-file data patterns.

## Installation

Install as a Claude Code plugin:

```bash
claude plugin add alistaircroll/pagelove
```

Or clone and reference locally:

```bash
git clone https://github.com/alistaircroll/pagelove.git
```

## Skills

| Skill | Description |
|-------|-------------|
| **using-pagelove** | Root skill — what Pagelove is, getting started, and skill index |
| **http-methods** | HTTP methods on DOM elements, selectors, status codes, request/response patterns |
| **client-libraries** | PLDocument, PLElement, DOMSubscriber, events, and the OPTIONS discovery protocol |
| **authorization** | Authorization rules in authz.html — schema, matching model, patterns, troubleshooting |
| **writing-files** | Creating/modifying files — server normalization, WebDAV, JS MIME workarounds |
| **building-apps** | Building a new app from scratch — workflow, data model, interaction patterns, self-test |
| **sspi** | Server-side document composition — includes, resource binding, Liquid templates |
| **multi-file-data** | Multiple HTML files as relational tables — foreign keys, cross-file reads, shape constraints |
| **development-patterns** | DOM-as-state, polling, debugging, state machines, "Instead of X, Do Y" rules |

## License

MIT
