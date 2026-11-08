import AppKit

signal(SIGPIPE, SIG_IGN)

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate(prefs: .shared, hub: .shared)
    app.delegate = delegate
    app.run()
}
