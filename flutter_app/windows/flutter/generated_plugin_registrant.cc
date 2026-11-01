//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <auto_updater_windows/auto_updater_windows_plugin_c_api.h>
#include <file_selector_windows/file_selector_windows.h>
#include <flutter_inappwebview_windows/flutter_inappwebview_windows_plugin_c_api.h>
#include <pasteboard/pasteboard_plugin.h>
#include <url_launcher_windows/url_launcher_windows.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  AutoUpdaterWindowsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AutoUpdaterWindowsPluginCApi"));
  FileSelectorWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FileSelectorWindows"));
  FlutterInappwebviewWindowsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterInappwebviewWindowsPluginCApi"));
  PasteboardPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("PasteboardPlugin"));
  UrlLauncherWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("UrlLauncherWindows"));
}
