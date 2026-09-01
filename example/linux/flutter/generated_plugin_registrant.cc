//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <web_view_master/web_view_master_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) web_view_master_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "WebViewMasterPlugin");
  web_view_master_plugin_register_with_registrar(web_view_master_registrar);
}
