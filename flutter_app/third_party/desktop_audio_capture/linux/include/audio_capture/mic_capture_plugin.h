#ifndef FLUTTER_PLUGIN_MIC_CAPTURE_PLUGIN_H_
#define FLUTTER_PLUGIN_MIC_CAPTURE_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

// Forward declarations
typedef struct _MicCapturePlugin MicCapturePlugin;
typedef struct {
  GObjectClass parent_class;
} MicCapturePluginClass;

// Type macros
FLUTTER_PLUGIN_EXPORT GType mic_capture_plugin_get_type();

#define MIC_CAPTURE_PLUGIN_TYPE (mic_capture_plugin_get_type())
#define MIC_CAPTURE_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), MIC_CAPTURE_PLUGIN_TYPE, MicCapturePlugin))

// Public API
FLUTTER_PLUGIN_EXPORT void mic_capture_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);
FLUTTER_PLUGIN_EXPORT void mic_capture_plugin_register_with_messenger(
    FlBinaryMessenger* messenger);

G_END_DECLS

#endif  // FLUTTER_PLUGIN_MIC_CAPTURE_PLUGIN_H_

