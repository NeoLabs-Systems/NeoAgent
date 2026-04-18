#include "include/audio_capture/audio_capture_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "audio_capture_plugin.h"

void AudioCapturePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  audio_capture::AudioCapturePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
