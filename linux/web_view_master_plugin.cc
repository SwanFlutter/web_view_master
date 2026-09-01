#include "include/web_view_master/web_view_master_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <webkit2/webkit2.h>
#include <sys/utsname.h>

#include <cstring>
#include <map>

#include "web_view_master_plugin_private.h"

#define WEB_VIEW_MASTER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), web_view_master_plugin_get_type(), \
                              WebViewMasterPlugin))

struct _WebViewMasterPlugin {
  GObject parent_instance;
  FlMethodChannel* channel;
  std::map<int64_t, GtkWidget*>* web_views;
  int64_t next_web_view_id;
};

G_DEFINE_TYPE(WebViewMasterPlugin, web_view_master_plugin, g_object_get_type())

static void web_view_master_plugin_handle_method_call(
    WebViewMasterPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    struct utsname uname_data = {};
    uname(&uname_data);
    g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
    g_autoptr(FlValue) result = fl_value_new_string(version);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "createWebView") == 0) {
    int64_t id = self->next_web_view_id++;
    GtkWidget* web_view = webkit_web_view_new();
    gtk_widget_show(web_view);
    (*self->web_views)[id] = web_view;

    FlValue* initial_url_val = fl_value_lookup_string(args, "initialUrl");
    if (initial_url_val && fl_value_get_type(initial_url_val) == FL_VALUE_TYPE_STRING) {
        webkit_web_view_load_uri(WEBKIT_WEB_VIEW(web_view), fl_value_get_string(initial_url_val));
    }

    response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_int(id)));
  } else if (strcmp(method, "loadUrl") == 0) {
    FlValue* id_val = fl_value_lookup_string(args, "webViewId");
    FlValue* url_val = fl_value_lookup_string(args, "url");
    int64_t id = fl_value_get_int(id_val);

    auto it = self->web_views->find(id);
    if (it != self->web_views->end()) {
        webkit_web_view_load_uri(WEBKIT_WEB_VIEW(it->second), fl_value_get_string(url_val));
        response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    } else {
        response = FL_METHOD_RESPONSE(fl_method_error_response_new("WEBVIEW_NOT_FOUND", "WebView not found", nullptr));
    }
  } else if (strcmp(method, "evaluateJavaScript") == 0) {
    FlValue* id_val = fl_value_lookup_string(args, "webViewId");
    FlValue* script_val = fl_value_lookup_string(args, "script");
    int64_t id = fl_value_get_int(id_val);

    auto it = self->web_views->find(id);
    if (it != self->web_views->end()) {
        webkit_web_view_run_javascript(WEBKIT_WEB_VIEW(it->second), fl_value_get_string(script_val), nullptr, nullptr, nullptr);
        response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    } else {
        response = FL_METHOD_RESPONSE(fl_method_error_response_new("WEBVIEW_NOT_FOUND", "WebView not found", nullptr));
    }
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void web_view_master_plugin_dispose(GObject* object) {
  WebViewMasterPlugin* self = WEB_VIEW_MASTER_PLUGIN(object);
  delete self->web_views;
  G_OBJECT_CLASS(web_view_master_plugin_parent_class)->dispose(object);
}

static void web_view_master_plugin_class_init(WebViewMasterPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = web_view_master_plugin_dispose;
}

static void web_view_master_plugin_init(WebViewMasterPlugin* self) {
    self->web_views = new std::map<int64_t, GtkWidget*>();
    self->next_web_view_id = 1;
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  WebViewMasterPlugin* plugin = WEB_VIEW_MASTER_PLUGIN(user_data);
  web_view_master_plugin_handle_method_call(plugin, method_call);
}

void web_view_master_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  WebViewMasterPlugin* plugin = WEB_VIEW_MASTER_PLUGIN(
      g_object_new(web_view_master_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  plugin->channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "web_view_master",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(plugin->channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
