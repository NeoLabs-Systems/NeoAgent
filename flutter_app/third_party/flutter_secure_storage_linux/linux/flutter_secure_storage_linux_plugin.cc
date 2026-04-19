#include "include/flutter_secure_storage_linux/flutter_secure_storage_linux_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <glib.h>
#include <gtk/gtk.h>

#include <cstdio>
#include <string>

#define flutter_secure_storage_linux_plugin(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), \
                              flutter_secure_storage_linux_plugin_get_type(), \
                              FlutterSecureStorageLinuxPlugin))

namespace {

constexpr const char *kChannelName =
    "plugins.it_nomads.com/flutter_secure_storage";
constexpr const char *kGroupName = "secure_storage";

std::string GetStoragePath() {
  const gchar *config_dir = g_get_user_config_dir();
  gchar *directory = g_build_filename(config_dir, APPLICATION_ID, nullptr);
  g_mkdir_with_parents(directory, 0700);
  gchar *path = g_build_filename(directory, "flutter_secure_storage.ini", nullptr);
  std::string result(path);
  g_free(path);
  g_free(directory);
  return result;
}

GKeyFile *LoadKeyFile() {
  GKeyFile *key_file = g_key_file_new();
  const std::string path = GetStoragePath();
  GError *error = nullptr;
  g_key_file_load_from_file(
      key_file,
      path.c_str(),
      static_cast<GKeyFileFlags>(G_KEY_FILE_KEEP_COMMENTS |
                                 G_KEY_FILE_KEEP_TRANSLATIONS),
      &error);
  if (error != nullptr) {
    g_error_free(error);
  }
  return key_file;
}

bool SaveKeyFile(GKeyFile *key_file, gchar **error_message) {
  gsize length = 0;
  GError *error = nullptr;
  gchar *data = g_key_file_to_data(key_file, &length, &error);
  if (error != nullptr) {
    *error_message = g_strdup(error->message);
    g_error_free(error);
    return false;
  }

  const std::string path = GetStoragePath();
  if (!g_file_set_contents(path.c_str(), data, static_cast<gssize>(length), &error)) {
    *error_message = g_strdup(error->message);
    g_error_free(error);
    g_free(data);
    return false;
  }

  g_free(data);
  return true;
}

FlMethodResponse *BuildErrorResponse(const gchar *code, const gchar *message) {
  return FL_METHOD_RESPONSE(
      fl_method_error_response_new(code, message, nullptr));
}

}  // namespace

struct _FlutterSecureStorageLinuxPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(FlutterSecureStorageLinuxPlugin,
              flutter_secure_storage_linux_plugin,
              g_object_get_type())

static void flutter_secure_storage_linux_plugin_handle_method_call(
    FlutterSecureStorageLinuxPlugin *self,
    FlMethodCall *method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar *method = fl_method_call_get_name(method_call);
  FlValue *args = fl_method_call_get_args(method_call);

  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    response = BuildErrorResponse("Bad arguments",
                                  "args given to function is not a map");
    fl_method_call_respond(method_call, response, nullptr);
    return;
  }

  FlValue *key = fl_value_lookup_string(args, "key");
  FlValue *value = fl_value_lookup_string(args, "value");
  const gchar *key_string = key == nullptr ? nullptr : fl_value_get_string(key);
  const gchar *value_string =
      value == nullptr ? nullptr : fl_value_get_string(value);

  g_autoptr(GKeyFile) key_file = LoadKeyFile();

  if (strcmp(method, "write") == 0) {
    if (key_string == nullptr || value_string == nullptr) {
      response = BuildErrorResponse("Bad arguments", "Key or Value was null");
    } else {
      g_key_file_set_string(key_file, kGroupName, key_string, value_string);
      gchar *error_message = nullptr;
      if (!SaveKeyFile(key_file, &error_message)) {
        response = BuildErrorResponse("Storage error", error_message);
        g_free(error_message);
      } else {
        response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
      }
    }
  } else if (strcmp(method, "read") == 0) {
    if (key_string == nullptr) {
      response = BuildErrorResponse("Bad arguments", "Key is null");
    } else if (!g_key_file_has_key(key_file, kGroupName, key_string, nullptr)) {
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    } else {
      gchar *stored_value = g_key_file_get_string(key_file, kGroupName, key_string, nullptr);
      g_autoptr(FlValue) result = fl_value_new_string(stored_value);
      g_free(stored_value);
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
    }
  } else if (strcmp(method, "readAll") == 0) {
    gsize key_count = 0;
    g_auto(GStrv) keys = g_key_file_get_keys(key_file, kGroupName, &key_count, nullptr);
    g_autoptr(FlValue) result = fl_value_new_map();
    for (gsize i = 0; i < key_count; ++i) {
      gchar *stored_value = g_key_file_get_string(key_file, kGroupName, keys[i], nullptr);
      fl_value_set_string_take(result, keys[i], fl_value_new_string(stored_value));
      g_free(stored_value);
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "delete") == 0) {
    if (key_string == nullptr) {
      response = BuildErrorResponse("Bad arguments", "Key is null");
    } else {
      g_key_file_remove_key(key_file, kGroupName, key_string, nullptr);
      gchar *error_message = nullptr;
      if (!SaveKeyFile(key_file, &error_message)) {
        response = BuildErrorResponse("Storage error", error_message);
        g_free(error_message);
      } else {
        response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
      }
    }
  } else if (strcmp(method, "deleteAll") == 0) {
    g_key_file_remove_group(key_file, kGroupName, nullptr);
    gchar *error_message = nullptr;
    if (!SaveKeyFile(key_file, &error_message)) {
      response = BuildErrorResponse("Storage error", error_message);
      g_free(error_message);
    } else {
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
    }
  } else if (strcmp(method, "containsKey") == 0) {
    if (key_string == nullptr) {
      response = BuildErrorResponse("Bad arguments", "Key is null");
    } else {
      g_autoptr(FlValue) result =
          fl_value_new_bool(g_key_file_has_key(key_file, kGroupName, key_string, nullptr));
      response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
    }
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void flutter_secure_storage_linux_plugin_dispose(GObject *object) {
  G_OBJECT_CLASS(flutter_secure_storage_linux_plugin_parent_class)
      ->dispose(object);
}

static void flutter_secure_storage_linux_plugin_class_init(
    FlutterSecureStorageLinuxPluginClass *klass) {
  G_OBJECT_CLASS(klass)->dispose =
      flutter_secure_storage_linux_plugin_dispose;
}

static void flutter_secure_storage_linux_plugin_init(
    FlutterSecureStorageLinuxPlugin *self) {}

static void method_call_cb(FlMethodChannel *channel,
                           FlMethodCall *method_call,
                           gpointer user_data) {
  FlutterSecureStorageLinuxPlugin *plugin =
      flutter_secure_storage_linux_plugin(user_data);
  flutter_secure_storage_linux_plugin_handle_method_call(plugin, method_call);
}

void flutter_secure_storage_linux_plugin_register_with_registrar(
    FlPluginRegistrar *registrar) {
  FlutterSecureStorageLinuxPlugin *plugin =
      flutter_secure_storage_linux_plugin(
          g_object_new(flutter_secure_storage_linux_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      kChannelName,
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      channel, method_call_cb, g_object_ref(plugin), g_object_unref);
  g_object_unref(plugin);
}
