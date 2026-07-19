---
name: [api-name]
description: [One sentence: what this API does and when to load this file — scanned cheaply across docs/api/ before the full body is loaded]
---

# [API Name]
_Copy this file to docs/api/[api-name].md when documenting a new API_
_Load this file when working on this API_

## Overview
[What this API does and who consumes it. One sentence.]

## Base URL
[Base URL or path prefix]

## Authentication
[How callers authenticate — token type, header name, where to get credentials]

## Endpoints

### [METHOD] /path
**Purpose:** [What this endpoint does]
**Request:** `{ "field": "type" }`
**Response:** `{ "field": "type" }`
**Errors:** 400 [when] | 422 [when]

## Rate limiting
[Limits, windows, headers returned]

## Known quirks
[Anything unexpected about this API that callers need to know]
