# Contributing

Keep changes small, native, and dependency-free unless a dependency has a clear
benefit. Use Swift 6 concurrency checks. Keep captures off disk and avoid network
services in the recognition path.

Before opening a pull request, run:

```sh
swift build -Xswiftc -warnings-as-errors
swift test
./scripts/build.sh
```

For UI changes, also check the installed app: global shortcut from another app,
selection in each drag direction, Escape, right-click, no-text selection, screen
permission denial, clipboard output, and a second display if available. Include
your macOS version and actual checks in the pull request. Do not claim a manual
check you did not perform.

Report bugs with reproduction steps, macOS version, and selected OCR language.
Avoid posting private screen captures or recognized secrets in public issues.
