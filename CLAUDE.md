# prex-ios-alien-debug-swift

Fork of [DebugSwift/DebugSwift](https://github.com/DebugSwift/DebugSwift) with Prex-specific customizations.

## Stack
- Swift 6 strict concurrency mode (`swiftLanguageModes: [.v6]`)
- iOS 14+ (upstream uses iOS 13+)
- Swift Package Manager, no external dependencies

## Prex Custom Code (preserve when syncing with upstream)
- `DebugSwift/Resources/PrivacyInfo.xcprivacy` — Privacy manifest
- `DebugSwift/Sources/Base/TabBarController.swift` — DDD2 device touch area fix
- `DebugSwift/Sources/Settings/DebugSwift.swift` — Instance method API with method chaining
- `DebugSwift/Sources/Helpers/Tools/UserDefaultsAccess.swift` — Debugger toggle support
- `Package.swift` — iOS 14+ platform target

## Upstream Sync
- Upstream: https://github.com/DebugSwift/DebugSwift (branch: `main`)
- Use MCP tools (`mcp__prex-mcp-server__code_*`) to read upstream code
- When syncing: apply upstream fixes to shared code, never overwrite Prex customizations listed above

## Relevant Skills
- `/upstream-sync` — sync files with upstream DebugSwift/DebugSwift (local skill)
- `/swift6-migration` — Swift 6 concurrency patterns (from prex-ios)
- `/git-workflow` — branch, PR, commit, cherry-pick workflows (from prex-ios)
- `/coding-standards` — Swift formatting conventions (from prex-ios)

## Testing
- Do NOT run `xcodebuild` — ask the developer to test in Xcode instead
- Tests are in `Example/ExampleTests/Tests/`
