import Cocoa
import FlutterMacOS

/// The window of the app. It opens at the size of the desktop layout and keeps the room that the sidebar
/// and the content need.
///
/// The window shows no title bar, after the System Settings of macOS: the content runs up to the top edge, and the
/// window buttons float over the top of the sidebar. The empty unified toolbar gives the buttons the place they
/// have in System Settings, and makes the top strip of the window a handle that moves it. That strip takes no
/// clicks, so the app keeps its controls below it.
class MainFlutterWindow: NSWindow {
  private let initialSize = NSSize(width: 1200, height: 800)
  private let minimumSize = NSSize(width: 980, height: 680)

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.setContentSize(initialSize)
    self.contentMinSize = minimumSize
    self.center()

    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.titlebarSeparatorStyle = .none
    self.styleMask.insert(.fullSizeContentView)
    self.toolbar = NSToolbar(identifier: "KranoxWindowBar")
    self.toolbarStyle = .unified

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
