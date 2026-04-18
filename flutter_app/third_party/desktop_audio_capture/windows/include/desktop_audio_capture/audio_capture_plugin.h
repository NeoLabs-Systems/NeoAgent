#ifndef FLUTTER_PLUGIN_AUDIO_CAPTURE_PLUGIN_H_
#define FLUTTER_PLUGIN_AUDIO_CAPTURE_PLUGIN_H_

#include <flutter_plugin_registrar.h>

#include <memory>

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FLUTTER_PLUGIN_EXPORT __declspec(dllimport)
#endif

namespace audio_capture {

class AudioCapturePlugin;

}  // namespace audio_capture

// Wrapper function for plugin registration
FLUTTER_PLUGIN_EXPORT void AudioCapturePluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#endif  // FLUTTER_PLUGIN_AUDIO_CAPTURE_PLUGIN_H_

