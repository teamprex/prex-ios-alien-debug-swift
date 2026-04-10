---
name: upstream-sync
description: 'Sync this repo with upstream DebugSwift/DebugSwift while preserving Prex customizations. Use when: (1) the user says "sync with upstream", "update from DebugSwift", or "check upstream", (2) fixing build errors that upstream has already resolved, (3) comparing local files with upstream versions, (4) pulling in new features from upstream DebugSwift.'
disable-model-invocation: true
argument-hint: '[file-or-feature-to-sync]'
---

# Upstream Sync

Sync this fork of DebugSwift/DebugSwift with the upstream repo while preserving Prex-specific customizations.

## Workflow Decision Tree

### 1) Sync a specific file
- Use `mcp__prex-mcp-server__code_read` to read the upstream version from `DebugSwift/DebugSwift` repo (branch: `main`)
- Read the local version with the Read tool
- Diff the two and apply upstream changes, skipping any Prex custom sections

### 2) Check for upstream fixes to a build error
- Identify the file(s) with errors locally
- Read the upstream version of those files using MCP tools
- Compare the relevant methods/sections to find the fix
- Apply the fix pattern while keeping local customizations

### 3) Full sync audit
- Use `mcp__prex-mcp-server__code_tree` to get the upstream directory structure
- Compare with local structure using Glob
- Identify new files in upstream that are missing locally
- Identify files that have diverged
- Report findings before making changes

### 4) Add a new upstream feature
- Read the upstream files for that feature using MCP tools
- Add the new files to the local repo
- Wire them into existing code as needed

## Prex Custom Code (never overwrite)

These files contain Prex-specific modifications — preserve them during any sync:
- `DebugSwift/Resources/PrivacyInfo.xcprivacy` — Privacy manifest
- `DebugSwift/Sources/Base/TabBarController.swift` — DDD2 device touch area fix
- `DebugSwift/Sources/Settings/DebugSwift.swift` — Instance method API with method chaining
- `DebugSwift/Sources/Helpers/Tools/UserDefaultsAccess.swift` — Debugger toggle support
- `Package.swift` — iOS 14+ platform target (upstream uses iOS 13+)

## MCP Tools for Reading Upstream

- `mcp__prex-mcp-server__code_tree` — get directory structure of upstream repo
- `mcp__prex-mcp-server__code_read` — read a specific file from upstream
- `mcp__prex-mcp-server__code_grep` — search upstream code for patterns
- `mcp__prex-mcp-server__code_search` — semantic search in upstream repo

Always specify repo as `DebugSwift/DebugSwift` and branch as `main` when using these tools.

## Rules

- Always read both local and upstream versions before making changes
- Create a feature branch for sync changes
- If a file is in the Prex custom list above, merge carefully — apply only non-conflicting upstream changes
- If upstream introduces new dependencies or platform changes, flag to the developer before applying
- Never run xcodebuild — ask the developer to verify the build in Xcode
