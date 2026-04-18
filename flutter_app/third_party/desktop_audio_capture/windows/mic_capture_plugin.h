#ifndef FLUTTER_PLUGIN_MIC_CAPTURE_PLUGIN_H_
#define FLUTTER_PLUGIN_MIC_CAPTURE_PLUGIN_H_

#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <mutex>
#include <thread>
#include <atomic>
#include <vector>
#include <string>
// After existing includes, add:
#include <queue>
#include <chrono>

// Include Windows headers for WAVEFORMATEX
#include <mmsystem.h>

// Forward declarations for WASAPI interfaces
struct IAudioClient;
struct IAudioCaptureClient;
struct IMMDevice;

namespace audio_capture {

struct AudioDataPacket {
  std::vector<uint8_t> data;
  double decibel;
  std::chrono::steady_clock::time_point timestamp;
};

class MicCapturePlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  MicCapturePlugin(flutter::PluginRegistrarWindows *registrar);
  ~MicCapturePlugin();

  // Disallow copy and assign.
  MicCapturePlugin(const MicCapturePlugin&) = delete;
  MicCapturePlugin& operator=(const MicCapturePlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  bool StartCapture(const flutter::EncodableMap* args);
  bool StopCapture();
  void CaptureThread();
  void ProcessQueue();
  double CalculateDecibel(const int16_t* samples, size_t sample_count);
  void ApplyGainBoostAndConvertToMono(const int16_t* input, int16_t* output,
                                     size_t frame_count, int input_channels,
                                     float gain_boost);
  void ResampleAudio(const int16_t* input, size_t input_frames,
                     int16_t* output, size_t output_frames,
                     int input_sample_rate, int output_sample_rate);
  void SendStatusUpdate(bool is_active, const std::string& device_name = "");
  void SendDecibelUpdate(double decibel);
  void QueueAudioData(std::vector<uint8_t> data, double decibel);
  bool HasInputDevice();
  std::vector<flutter::EncodableValue> GetAvailableInputDevices();
  std::string GetCurrentDeviceName();
  bool IsBluetoothDevice();
  void CleanupExistingCapture();
  void SetThreadPriority();
  bool OpenWASAPIStreamWithRetry(int sample_rate, int channels, int bits_per_sample,
                                 bool is_bluetooth, void** out_audio_client,
                                 void** out_capture_client, std::string* error_message);

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
  std::string current_device_name_;

  // NEW: Queue cho audio data
  std::queue<AudioDataPacket> audio_queue_;
  std::mutex queue_mutex_;
  static constexpr size_t kMaxQueueSize = 50;  // Limit queue size
  
  // Audio configuration
  int sample_rate_;
  int channels_;
  int bits_per_sample_;
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

#endif  // FLUTTER_PLUGIN_MIC_CAPTURE_PLUGIN_H_

