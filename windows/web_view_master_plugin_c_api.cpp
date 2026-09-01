#include "include/web_view_master/web_view_master_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "web_view_master_plugin.h"

void WebViewMasterPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  web_view_master::WebViewMasterPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
