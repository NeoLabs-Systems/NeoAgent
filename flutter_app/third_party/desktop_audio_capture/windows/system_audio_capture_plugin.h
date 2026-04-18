#ifndef FLUTTER_PLUGIN_SYSTEM_AUDIO_CAPTURE_PLUGIN_H_
#define FLUTTER_PLUGIN_SYSTEM_AUDIO_CAPTURE_PLUGIN_H_

#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <mutex>
#include <thread>
#include <atomic>
#include <vector>

// Include Windows headers for WAVEFORMATEX
#include <mmsystem.h>

// Forward declarations for WASAPI interfaces
struct IAudioClient;
struct IAudioCaptureClient;
struct IMMDevice;

namespace audio_capture {

class SystemAudioCapturePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  SystemAudioCapturePlugin(flutter::PluginRegistrarWindows *registrar);
  ~SystemAudioCapturePlugin();

  // Disallow copy and assign.
  SystemAudioCapturePlugin(const SystemAudioCapturePlugin&) = delete;
  SystemAudioCapturePlugin& operator=(const SystemAudioCapturePlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  bool StartCapture(const flutter::EncodableMap* args);
  bool StopCapture();
  void CaptureThread();
  void SetThreadPriority();
  double CalculateDecibel(const int16_t* samples, size_t sample_count);
  void ApplyGainBoostAndConvertToMono(const int16_t* input, int16_t* output,
                                      size_t frame_count, int input_channels,
                                      float gain_boost);
  void SendStatusUpdate(bool is_active);
  void SendDecibelUpdate(double decibel);

  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> event_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> status_event_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> decibel_event_channel_;
  
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> status_event_sink_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> decibel_event_sink_;

  std::mutex mutex_;
  std::atomic<bool> is_capturing_;
  std::atomic<bool> should_stop_;
  std::thread capture_thread_;
  
  // Audio configuration
  int sample_rate_;
  int channels_;
  int bits_per_sample_;
  int chunk_duration_ms_;
  float gain_boost_;
  float input_volume_;
  
  // WASAPI interfaces
  IAudioClient* audio_client_;
  IAudioCaptureClient* capture_client_;
  IMMDevice* device_;
  WAVEFORMATEX* mix_format_;
  UINT32 buffer_frame_count_;
  bool com_initialized_;  // Track if we initialized COM
};

}  // namespace audio_capture

#endif  // FLUTTER_PLUGIN_SYSTEM_AUDIO_CAPTURE_PLUGIN_H_

