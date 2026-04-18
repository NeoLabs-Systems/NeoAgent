#include "audio_capture_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

#include "system_audio_capture_plugin.h"
#include "mic_capture_plugin.h"

// Include the public header for the wrapper function declaration
#include "include/desktop_audio_capture/audio_capture_plugin.h"

namespace audio_capture {

// static
void AudioCapturePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "audio_capture",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<AudioCapturePlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));

  // Register system audio capture plugin
  SystemAudioCapturePlugin::RegisterWithRegistrar(registrar);

  // Register microphone capture plugin
  MicCapturePlugin::RegisterWithRegistrar(registrar);
}

AudioCapturePlugin::AudioCapturePlugin() {}

AudioCapturePlugin::~AudioCapturePlugin() {}

void AudioCapturePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("getPlatformVersion") == 0) {
    std::ostringstream version_stream;
    version_stream << "Windows ";
    if (IsWindows10OrGreater()) {
      version_stream << "10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
  } else {
    result->NotImplemented();
  }
}

}  // namespace audio_capture

// Wrapper function for plugin registration (used by generated_plugin_registrant.cc)
// Export the function from the DLL
__declspec(dllexport) void AudioCapturePluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  audio_capture::AudioCapturePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
