import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // 預設視窗大小：工具列、編輯器與聊天面板並排需要比 800×600 寬
    self.setContentSize(NSSize(width: 1360, height: 860))
    self.contentMinSize = NSSize(width: 900, height: 600)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
