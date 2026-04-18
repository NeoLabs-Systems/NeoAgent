#include "include/audio_capture/mic_capture_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <glib-object.h>
#include <glib.h>
#include <pulse/error.h>
#include <pulse/simple.h>
#include <pulse/pulseaudio.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace {

constexpr char kMethodChannelName[] = "com.mic_audio_transcriber/mic_capture";
constexpr char kEventChannelName[] = "com.mic_audio_transcriber/mic_stream";
constexpr char kStatusEventChannelName[] = "com.mic_audio_transcriber/mic_status";
constexpr char kDecibelEventChannelName[] = "com.mic_audio_transcriber/mic_decibel";

constexpr int kDefaultSampleRate = 16000;
constexpr int kDefaultChannels = 1;
constexpr int kDefaultBitsPerSample = 16;
constexpr float kDefaultGainBoost = 2.5f;
constexpr float kDefaultInputVolume = 1.0f;
constexpr size_t kBufferSizeFrames = 4096;

struct AudioChunkPayload {
  AudioChunkPayload(MicCapturePlugin* plugin, GBytes* bytes, double decibel)
      : plugin(plugin), bytes(bytes), decibel(decibel) {}

  MicCapturePlugin* plugin;
  GBytes* bytes;
  double decibel;
};

struct CaptureThreadContext {
  MicCapturePlugin* plugin;
  pa_simple* stream;
  size_t chunk_size;
  int sample_rate;
  int channels;
  int bits_per_sample;
  float gain_boost;
  float input_volume;
};

gboolean EmitAudioOnMainThread(gpointer user_data);
gpointer CaptureThread(gpointer user_data);
double CalculateDecibel(const int16_t* samples, size_t sample_count);
std::string GetCurrentDeviceName();
bool IsBluetoothDevice();
void CleanupExistingCapture(MicCapturePlugin* plugin);
bool OpenPulseStreamWithRetry(int sample_rate, int channels, int bits_per_sample,
                               size_t chunk_size, bool is_bluetooth,
                               pa_simple** out_stream, std::string* error_message);

}  // namespace

struct _MicCapturePlugin {
  GObject parent_instance;

  FlMethodChannel* method_channel;
  FlEventChannel* event_channel;
  FlEventChannel* status_event_channel;
  FlEventChannel* decibel_event_channel;
  GMainContext* main_context;

  GMutex lock;
  gint should_stop;
  gboolean is_capturing;
  gboolean has_listener;
  gboolean has_status_listener;
  gboolean has_decibel_listener;

  GThread* capture_thread;
  gchar* current_device_name;
};

G_DEFINE_TYPE(MicCapturePlugin, mic_capture_plugin, G_TYPE_OBJECT)

namespace {

bool CheckMicSupport() {
  pa_simple* stream = nullptr;
  pa_sample_spec spec;
  spec.rate = kDefaultSampleRate;
  spec.channels = static_cast<uint8_t>(kDefaultChannels);
  spec.format = PA_SAMPLE_S16LE;

  pa_buffer_attr attr;
  attr.maxlength = static_cast<uint32_t>(-1);
  attr.tlength = static_cast<uint32_t>(-1);
  attr.prebuf = static_cast<uint32_t>(-1);
  attr.minreq = static_cast<uint32_t>(-1);
  attr.fragsize = static_cast<uint32_t>(-1);

  int error = 0;
  // Try to open default source (microphone)
  stream = pa_simple_new(nullptr, "Voxa", PA_STREAM_RECORD, nullptr,
                         "Mic Check", &spec, nullptr, &attr, &error);

  if (stream == nullptr) {
    return false;
  }

  pa_simple_free(stream);
  return true;
}

size_t CalculateChunkSize(int sample_rate, int channels, int bits_per_sample) {
  const int bytes_per_sample = std::max(bits_per_sample / 8, 1);
  const size_t frame_size = static_cast<size_t>(channels) * bytes_per_sample;
  return kBufferSizeFrames * frame_size;
}

bool OpenPulseStream(int sample_rate, int channels, int bits_per_sample,
                     size_t chunk_size, pa_simple** out_stream,
                     std::string* error_message) {
  pa_sample_spec spec;
  spec.rate = sample_rate;
  spec.channels = static_cast<uint8_t>(channels);
  if (bits_per_sample == 16) {
    spec.format = PA_SAMPLE_S16LE;
  } else {
    spec.format = PA_SAMPLE_S16LE;
  }

  pa_buffer_attr attr;
  attr.maxlength = static_cast<uint32_t>(chunk_size * 4);
  attr.tlength = static_cast<uint32_t>(-1);
  attr.prebuf = static_cast<uint32_t>(-1);
  attr.minreq = static_cast<uint32_t>(-1);
  attr.fragsize = static_cast<uint32_t>(chunk_size);

  int error = 0;
  // Use nullptr to get default source (microphone)
  pa_simple* stream = pa_simple_new(nullptr, "Voxa", PA_STREAM_RECORD, nullptr,
                                     "Mic Capture", &spec, nullptr, &attr, &error);

  if (stream == nullptr) {
    if (error_message != nullptr) {
      *error_message = pa_strerror(error);
    }
    return false;
  }

  *out_stream = stream;
  return true;
}

std::string GetCurrentDeviceName() {
  // Try to get device name from PulseAudio
  // For simplicity, we'll use a default name
  // In a full implementation, you could use pa_context to query source info
  return "Default Microphone";
}

bool IsBluetoothDevice() {
  // Check device name for Bluetooth keywords
  std::string device_name = GetCurrentDeviceName();
  std::transform(device_name.begin(), device_name.end(), device_name.begin(), ::tolower);
  
  const char* bluetooth_keywords[] = {
    "bluetooth", "airpods", "beats", "jabra", "sony", "bose", "jbl", "bluez"
  };
  
  for (size_t i = 0; i < sizeof(bluetooth_keywords) / sizeof(bluetooth_keywords[0]); ++i) {
    if (device_name.find(bluetooth_keywords[i]) != std::string::npos) {
      g_debug("🔵 Detected Bluetooth device via name: %s", device_name.c_str());
      return true;
    }
  }
  
  return false;
}

void CleanupExistingCapture(MicCapturePlugin* plugin) {
  g_mutex_lock(&plugin->lock);
  
  if (plugin->is_capturing && plugin->capture_thread != nullptr) {
    // Signal stop
    g_atomic_int_set(&plugin->should_stop, 1);
    GThread* thread = plugin->capture_thread;
    g_mutex_unlock(&plugin->lock);
    
    // Wait for thread to finish
    if (thread != nullptr) {
      g_thread_join(thread);
    }
    
    g_mutex_lock(&plugin->lock);
    plugin->capture_thread = nullptr;
    plugin->is_capturing = FALSE;
  }
  
  // Clear device name
  if (plugin->current_device_name != nullptr) {
    g_free(plugin->current_device_name);
    plugin->current_device_name = nullptr;
  }
  
  g_mutex_unlock(&plugin->lock);
  
  // Small delay for cleanup to complete
  g_usleep(500000);  // 0.5 seconds
}

bool OpenPulseStreamWithRetry(int sample_rate, int channels, int bits_per_sample,
                               size_t chunk_size, bool is_bluetooth,
                               pa_simple** out_stream, std::string* error_message) {
  const int max_retries = is_bluetooth ? 5 : 3;
  const double initial_wait = is_bluetooth ? 1.5 : 0.3;
  const double retry_delays_bluetooth[] = {0.5, 1.0, 1.5, 2.0, 2.5};
  const double retry_delays_normal[] = {0.3, 0.6, 1.0, 0.0, 0.0};
  const double* retry_delays = is_bluetooth ? retry_delays_bluetooth : retry_delays_normal;
  
  if (is_bluetooth) {
    g_debug("🔵 Bluetooth device detected - using extended wait times");
  }
  
  // Initial wait for device to be ready
  g_debug("⏳ Waiting %.1fs for device to be ready...", initial_wait);
  g_usleep(static_cast<guint64>(initial_wait * 1000000));
  
  for (int attempt = 1; attempt <= max_retries; ++attempt) {
    if (OpenPulseStream(sample_rate, channels, bits_per_sample, chunk_size,
                       out_stream, error_message)) {
      g_debug("✅ PulseAudio stream opened successfully on attempt %d", attempt);
      return true;
    }
    
    if (attempt < max_retries) {
      double wait_time = retry_delays[attempt - 1];
      if (wait_time > 0.0) {
        g_debug("⚠️ Attempt %d/%d failed: %s", attempt, max_retries,
                error_message != nullptr ? error_message->c_str() : "unknown error");
        g_debug("   ⏳ Waiting %.1fs before retry...", wait_time);
        g_usleep(static_cast<guint64>(wait_time * 1000000));
      }
    }
  }
  
  g_warning("❌ Failed to open PulseAudio stream after %d attempts", max_retries);
  return false;
}

void ApplyGainBoostAndConvertToMono(const int16_t* input, int16_t* output,
                                    size_t frame_count, int input_channels,
                                    float gain_boost) {
  const float max_value = 32767.0f;
  const float min_value = -32768.0f;

  if (input_channels == 1) {
    // Mono: just apply gain boost
    for (size_t i = 0; i < frame_count; ++i) {
      float sample = static_cast<float>(input[i]) * gain_boost;
      sample = std::max(min_value, std::min(max_value, sample));
      output[i] = static_cast<int16_t>(sample);
    }
  } else {
    // Stereo: convert to mono and apply gain boost
    for (size_t i = 0; i < frame_count; ++i) {
      float left = static_cast<float>(input[i * 2]);
      float right = static_cast<float>(input[i * 2 + 1]);
      float mono = (left + right) / 2.0f * gain_boost;
      mono = std::max(min_value, std::min(max_value, mono));
      output[i] = static_cast<int16_t>(mono);
    }
  }
}

double CalculateDecibel(const int16_t* samples, size_t sample_count) {
  if (sample_count == 0) {
    return -120.0;
  }

  // Calculate RMS (Root Mean Square)
  double sum_of_squares = 0.0;
  for (size_t i = 0; i < sample_count; ++i) {
    double value = static_cast<double>(samples[i]);
    sum_of_squares += value * value;
  }
  double mean_square = sum_of_squares / static_cast<double>(sample_count);
  double rms = sqrt(mean_square);

  // Calculate decibel: dB = 20 * log10(RMS / max_value)
  // For Int16, max_value is 32767.0
  const double max_value = 32767.0;
  if (rms <= 0.0) {
    return -120.0;  // Avoid log(0)
  }

  double decibel = 20.0 * log10(rms / max_value);

  // Clamp to reasonable range (-120 dB to 0 dB)
  return std::max(-120.0, std::min(0.0, decibel));
}

gboolean EmitAudioOnMainThread(gpointer user_data) {
  std::unique_ptr<AudioChunkPayload> payload(
      static_cast<AudioChunkPayload*>(user_data));
  MicCapturePlugin* plugin = payload->plugin;

  gsize length = 0;
  const guint8* data =
      static_cast<const guint8*>(g_bytes_get_data(payload->bytes, &length));

  g_mutex_lock(&plugin->lock);
  const gboolean can_emit =
      plugin->event_channel != nullptr && plugin->has_listener;
  const gboolean can_emit_decibel =
      plugin->decibel_event_channel != nullptr && plugin->has_decibel_listener;
  g_mutex_unlock(&plugin->lock);

  if (can_emit && length > 0) {
    g_autoptr(FlValue) value = fl_value_new_uint8_list(data, length);
    g_autoptr(GError) error = nullptr;

    if (!fl_event_channel_send(plugin->event_channel, value, nullptr, &error)) {
      g_warning("Failed to send audio chunk: %s",
                error != nullptr ? error->message : "unknown error");
    }
  }

  // Send decibel data
  if (can_emit_decibel) {
    g_autoptr(FlValue) decibel_map = fl_value_new_map();
    fl_value_set_string_take(decibel_map, "decibel", fl_value_new_float(payload->decibel));
    fl_value_set_string_take(decibel_map, "timestamp", fl_value_new_float(g_get_real_time() / 1000000.0));
    
    g_autoptr(GError) error = nullptr;
    if (!fl_event_channel_send(plugin->decibel_event_channel, decibel_map, nullptr, &error)) {
      g_warning("Failed to send decibel data: %s",
                error != nullptr ? error->message : "unknown error");
    }
  }

  g_bytes_unref(payload->bytes);
  g_object_unref(plugin);

  return G_SOURCE_REMOVE;
}

gpointer CaptureThread(gpointer user_data) {
  std::unique_ptr<CaptureThreadContext> context(
      static_cast<CaptureThreadContext*>(user_data));
  MicCapturePlugin* plugin = context->plugin;

  // Read raw audio from PulseAudio
  const size_t raw_chunk_size = CalculateChunkSize(
      context->sample_rate, context->channels, context->bits_per_sample);
  std::vector<uint8_t> raw_buffer(raw_chunk_size);

  // Output buffer for processed audio (mono)
  const size_t output_frame_count = kBufferSizeFrames;
  std::vector<int16_t> output_buffer(output_frame_count);

  while (!g_atomic_int_get(&plugin->should_stop)) {
    int error = 0;
    if (pa_simple_read(context->stream, raw_buffer.data(), raw_buffer.size(),
                       &error) < 0) {
      g_warning("PulseAudio read error: %s", pa_strerror(error));
      break;
    }

    if (g_atomic_int_get(&plugin->should_stop)) {
      break;
    }

    // Apply input volume
    if (context->input_volume < 1.0f) {
      int16_t* samples = reinterpret_cast<int16_t*>(raw_buffer.data());
      const size_t sample_count = raw_buffer.size() / sizeof(int16_t);
      for (size_t i = 0; i < sample_count; ++i) {
        samples[i] = static_cast<int16_t>(
            static_cast<float>(samples[i]) * context->input_volume);
      }
    }

    // Convert to mono and apply gain boost
    const int16_t* input_samples =
        reinterpret_cast<const int16_t*>(raw_buffer.data());
    const size_t input_frame_count =
        raw_buffer.size() / (sizeof(int16_t) * context->channels);
    const size_t frames_to_process =
        std::min(input_frame_count, output_frame_count);

    ApplyGainBoostAndConvertToMono(input_samples, output_buffer.data(),
                                    frames_to_process, context->channels,
                                    context->gain_boost);

    // Create output bytes
    const size_t output_bytes = frames_to_process * sizeof(int16_t);
    
    // Calculate decibel from output buffer
    double decibel = CalculateDecibel(output_buffer.data(), frames_to_process);
    
    GBytes* bytes = g_bytes_new(output_buffer.data(), output_bytes);
    auto* payload = new AudioChunkPayload(plugin, bytes, decibel);
    g_object_ref(plugin);

    g_main_context_invoke_full(plugin->main_context, G_PRIORITY_DEFAULT,
                               EmitAudioOnMainThread, payload, nullptr);
  }

  pa_simple_free(context->stream);

  g_mutex_lock(&plugin->lock);
  plugin->is_capturing = FALSE;
  plugin->capture_thread = nullptr;
  g_mutex_unlock(&plugin->lock);

  // Send status update
  g_mutex_lock(&plugin->lock);
  const gboolean has_status_listener = plugin->has_status_listener;
  g_mutex_unlock(&plugin->lock);
  
  if (has_status_listener && plugin->status_event_channel != nullptr) {
    g_autoptr(FlValue) status_map = fl_value_new_map();
    fl_value_set_string_take(status_map, "isActive", fl_value_new_bool(FALSE));
    fl_value_set_string_take(status_map, "timestamp", fl_value_new_float(g_get_real_time() / 1000000.0));
    
    g_autoptr(GError) error = nullptr;
    fl_event_channel_send(plugin->status_event_channel, status_map, nullptr, &error);
  }

  g_object_unref(plugin);
  return nullptr;
}

static FlMethodErrorResponse* OnListenHandler(FlEventChannel* channel,
                                              FlValue* arguments,
                                              gpointer user_data) {
  MicCapturePlugin* plugin = MIC_CAPTURE_PLUGIN(user_data);
  (void)channel;
  (void)arguments;
  g_mutex_lock(&plugin->lock);
  plugin->has_listener = TRUE;
  g_mutex_unlock(&plugin->lock);
  return nullptr;
}

static FlMethodErrorResponse* OnCancelHandler(FlEventChannel* channel,
                                              FlValue* arguments,
                                              gpointer user_data) {
  MicCapturePlugin* plugin = MIC_CAPTURE_PLUGIN(user_data);
  (void)channel;
  (void)arguments;
  g_mutex_lock(&plugin->lock);
  plugin->has_listener = FALSE;
  g_mutex_unlock(&plugin->lock);
  return nullptr;
}

static FlMethodErrorResponse* OnStatusListenHandler(FlEventChannel* channel,
                                                     FlValue* arguments,
                                                     gpointer user_data) {
  MicCapturePlugin* plugin = MIC_CAPTURE_PLUGIN(user_data);
  (void)channel;
  (void)arguments;
  g_mutex_lock(&plugin->lock);
  plugin->has_status_listener = TRUE;
  const gboolean is_active = plugin->is_capturing;
  g_mutex_unlock(&plugin->lock);

  // Send current status immediately
  g_autoptr(FlValue) status_map = fl_value_new_map();
  fl_value_set_string_take(status_map, "isActive", fl_value_new_bool(is_active));
  fl_value_set_string_take(status_map, "timestamp", fl_value_new_float(g_get_real_time() / 1000000.0));
  
  g_autoptr(GError) error = nullptr;
  fl_event_channel_send(plugin->status_event_channel, status_map, nullptr, &error);
  
  return nullptr;
}

static FlMethodErrorResponse* OnStatusCancelHandler(FlEventChannel* channel,
                                                    FlValue* arguments,
                                                    gpointer user_data) {
  MicCapturePlugin* plugin = MIC_CAPTURE_PLUGIN(user_data);
  (void)channel;
  (void)arguments;
  g_mutex_lock(&plugin->lock);
  plugin->has_status_listener = FALSE;
  g_mutex_unlock(&plugin->lock);
  return nullptr;
}

static FlMethodErrorResponse* OnDecibelListenHandler(FlEventChannel* channel,
                                                      FlValue* arguments,
                                                      gpointer user_data) {
  MicCapturePlugin* plugin = MIC_CAPTURE_PLUGIN(user_data);
  (void)channel;
  (void)arguments;
  g_mutex_lock(&plugin->lock);
  plugin->has_decibel_listener = TRUE;
  g_mutex_unlock(&plugin->lock);
  return nullptr;
}

static FlMethodErrorResponse* OnDecibelCancelHandler(FlEventChannel* channel,
                                                      FlValue* arguments,
                                                      gpointer user_data) {
  MicCapturePlugin* plugin = MIC_CAPTURE_PLUGIN(user_data);
  (void)channel;
  (void)arguments;
  g_mutex_lock(&plugin->lock);
  plugin->has_decibel_listener = FALSE;
  g_mutex_unlock(&plugin->lock);
  return nullptr;
}

bool StartCapture(MicCapturePlugin* plugin, FlValue* args) {
  // Always cleanup any existing capture first to ensure clean start
  // This is important even if isCapturing is false (state might be out of sync)
  CleanupExistingCapture(plugin);
  
  int sample_rate = kDefaultSampleRate;
  int channels = kDefaultChannels;
  int bits_per_sample = kDefaultBitsPerSample;
  float gain_boost = kDefaultGainBoost;
  float input_volume = kDefaultInputVolume;

  if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
    FlValue* value = nullptr;

    value = fl_value_lookup_string(args, "sampleRate");
    if (value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_INT) {
      sample_rate = fl_value_get_int(value);
    }

    value = fl_value_lookup_string(args, "channels");
    if (value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_INT) {
      channels = fl_value_get_int(value);
    }

    value = fl_value_lookup_string(args, "bitDepth");
    if (value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_INT) {
      bits_per_sample = fl_value_get_int(value);
    }

    value = fl_value_lookup_string(args, "gainBoost");
    if (value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_FLOAT) {
      gain_boost = fl_value_get_float(value);
      gain_boost = std::max(0.1f, std::min(10.0f, gain_boost));
    }

    value = fl_value_lookup_string(args, "inputVolume");
    if (value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_FLOAT) {
      input_volume = fl_value_get_float(value);
      input_volume = std::max(0.0f, std::min(1.0f, input_volume));
    }
  }

  // Clamp values
  sample_rate = std::max(sample_rate, 8000);
  channels = std::max(1, std::min(channels, 2));
  bits_per_sample = 16;  // Force 16-bit
  gain_boost = std::max(0.1f, std::min(10.0f, gain_boost));
  input_volume = std::max(0.0f, std::min(1.0f, input_volume));

  size_t chunk_size =
      CalculateChunkSize(sample_rate, channels, bits_per_sample);

  // Detect if device is Bluetooth and adjust wait times accordingly
  bool is_bluetooth = IsBluetoothDevice();
  
  g_debug("🎤 Starting capture with config:");
  g_debug("  Sample Rate: %d Hz", sample_rate);
  g_debug("  Channels: %d", channels);
  g_debug("  Bits Per Sample: %d", bits_per_sample);
  g_debug("  Gain Boost: %.2fx", gain_boost);
  g_debug("  Input Volume: %.2f", input_volume);
  g_debug("  Is Bluetooth: %s", is_bluetooth ? "yes" : "no");

  pa_simple* stream = nullptr;
  std::string error_message;

  // Open stream with retry mechanism
  if (!OpenPulseStreamWithRetry(sample_rate, channels, bits_per_sample, chunk_size,
                                 is_bluetooth, &stream, &error_message)) {
    g_warning("Failed to open PulseAudio stream: %s", error_message.c_str());
    return false;
  }

  // Get device name
  std::string device_name = GetCurrentDeviceName();
  
  g_mutex_lock(&plugin->lock);
  if (plugin->is_capturing) {
    g_mutex_unlock(&plugin->lock);
    pa_simple_free(stream);
    g_warning("⚠️ State mismatch: isCapturing=true after cleanup, aborting");
    return false;
  }

  g_atomic_int_set(&plugin->should_stop, 0);
  plugin->is_capturing = TRUE;
  
  // Store device name
  if (plugin->current_device_name != nullptr) {
    g_free(plugin->current_device_name);
  }
  plugin->current_device_name = g_strdup(device_name.c_str());

  auto* context = new CaptureThreadContext{
      plugin, stream, chunk_size, sample_rate, channels,
      bits_per_sample, gain_boost, input_volume};

  g_object_ref(plugin);
  plugin->capture_thread =
      g_thread_new("voxa-mic-capture", CaptureThread, context);
  g_mutex_unlock(&plugin->lock);

  if (plugin->capture_thread == nullptr) {
    g_warning("Failed to create capture thread");
    g_mutex_lock(&plugin->lock);
    plugin->is_capturing = FALSE;
    if (plugin->current_device_name != nullptr) {
      g_free(plugin->current_device_name);
      plugin->current_device_name = nullptr;
    }
    g_mutex_unlock(&plugin->lock);
    pa_simple_free(stream);
    g_object_unref(plugin);
    delete context;
    return false;
  }

  // Wait a bit to ensure thread has started
  g_usleep(200000);  // 0.2 seconds

  // Send status update with device name
  g_mutex_lock(&plugin->lock);
  const gboolean has_status_listener = plugin->has_status_listener;
  const gchar* device_name_cstr = plugin->current_device_name;
  g_mutex_unlock(&plugin->lock);
  
  if (has_status_listener && plugin->status_event_channel != nullptr) {
    g_autoptr(FlValue) status_map = fl_value_new_map();
    fl_value_set_string_take(status_map, "isActive", fl_value_new_bool(TRUE));
    fl_value_set_string_take(status_map, "timestamp", fl_value_new_float(g_get_real_time() / 1000000.0));
    if (device_name_cstr != nullptr) {
      fl_value_set_string_take(status_map, "deviceName", fl_value_new_string(device_name_cstr));
    }
    
    g_autoptr(GError) error = nullptr;
    fl_event_channel_send(plugin->status_event_channel, status_map, nullptr, &error);
  }

  g_debug("✅ Microphone capture started successfully!");
  if (device_name_cstr != nullptr) {
    g_debug("  Device: %s", device_name_cstr);
  }

  return true;
}

bool StopCapture(MicCapturePlugin* plugin) {
  g_mutex_lock(&plugin->lock);
  if (!plugin->is_capturing) {
    g_mutex_unlock(&plugin->lock);
    return false;
  }
  g_atomic_int_set(&plugin->should_stop, 1);
  GThread* thread = plugin->capture_thread;
  g_mutex_unlock(&plugin->lock);

  if (thread != nullptr) {
    g_thread_join(thread);
  }

  g_mutex_lock(&plugin->lock);
  plugin->capture_thread = nullptr;
  plugin->is_capturing = FALSE;
  const gboolean has_status_listener = plugin->has_status_listener;
  g_mutex_unlock(&plugin->lock);

  // Wait a bit to ensure thread has fully stopped
  g_usleep(100000);  // 0.1 seconds

  // Send status update
  g_mutex_lock(&plugin->lock);
  if (plugin->current_device_name != nullptr) {
    g_free(plugin->current_device_name);
    plugin->current_device_name = nullptr;
  }
  g_mutex_unlock(&plugin->lock);
  
  if (has_status_listener && plugin->status_event_channel != nullptr) {
    g_autoptr(FlValue) status_map = fl_value_new_map();
    fl_value_set_string_take(status_map, "isActive", fl_value_new_bool(FALSE));
    fl_value_set_string_take(status_map, "timestamp", fl_value_new_float(g_get_real_time() / 1000000.0));
    
    g_autoptr(GError) error = nullptr;
    fl_event_channel_send(plugin->status_event_channel, status_map, nullptr, &error);
  }

  return true;
}

bool HasInputDevice() {
  return CheckMicSupport();
}

FlValue* GetAvailableInputDevices() {
  // For now, return a simple list with default device
  // In a full implementation, you could use pa_context to query all sources
  g_autoptr(FlValue) device_list = fl_value_new_list();
  
  // Get default device info
  std::string device_name = GetCurrentDeviceName();
  bool is_bluetooth = IsBluetoothDevice();
  
  g_autoptr(FlValue) device_map = fl_value_new_map();
  fl_value_set_string_take(device_map, "id", fl_value_new_string("default"));
  fl_value_set_string_take(device_map, "name", fl_value_new_string(device_name.c_str()));
  fl_value_set_string_take(device_map, "type", fl_value_new_string(is_bluetooth ? "bluetooth" : "external"));
  fl_value_set_string_take(device_map, "channelCount", fl_value_new_int(1));
  fl_value_set_string_take(device_map, "isDefault", fl_value_new_bool(TRUE));
  
  fl_value_append_take(device_list, device_map);
  
  return g_steal_pointer(&device_list);
}

void HandleMethodCall(MicCapturePlugin* plugin, FlMethodCall* method_call) {
  const gchar* method = fl_method_call_get_name(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (strcmp(method, "requestPermissions") == 0) {
    // On Linux, permissions are typically handled by the system
    // PulseAudio will handle access automatically
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "hasInputDevice") == 0) {
    const bool has_device = HasInputDevice();
    g_autoptr(FlValue) result = fl_value_new_bool(has_device);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "getAvailableInputDevices") == 0) {
    g_autoptr(FlValue) devices = GetAvailableInputDevices();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(devices));
  } else if (strcmp(method, "startCapture") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    const bool started = StartCapture(plugin, args);
    g_autoptr(FlValue) result = fl_value_new_bool(started);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "stopCapture") == 0) {
    const bool stopped = StopCapture(plugin);
    g_autoptr(FlValue) result = fl_value_new_bool(stopped);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to send method call response: %s", error->message);
  }
}

static void MethodCallHandler(FlMethodChannel* channel,
                               FlMethodCall* method_call,
                               gpointer user_data) {
  MicCapturePlugin* plugin = MIC_CAPTURE_PLUGIN(user_data);
  HandleMethodCall(plugin, method_call);
}

}  // namespace

static void mic_capture_plugin_dispose(GObject* object) {
  MicCapturePlugin* plugin = MIC_CAPTURE_PLUGIN(object);

  StopCapture(plugin);

  if (plugin->method_channel != nullptr) {
    g_clear_object(&plugin->method_channel);
  }

  if (plugin->event_channel != nullptr) {
    g_clear_object(&plugin->event_channel);
  }

  if (plugin->status_event_channel != nullptr) {
    g_clear_object(&plugin->status_event_channel);
  }

  if (plugin->decibel_event_channel != nullptr) {
    g_clear_object(&plugin->decibel_event_channel);
  }

  if (plugin->current_device_name != nullptr) {
    g_free(plugin->current_device_name);
    plugin->current_device_name = nullptr;
  }

  if (plugin->main_context != nullptr) {
    g_main_context_unref(plugin->main_context);
    plugin->main_context = nullptr;
  }

  g_mutex_clear(&plugin->lock);

  G_OBJECT_CLASS(mic_capture_plugin_parent_class)->dispose(object);
}

static void mic_capture_plugin_class_init(MicCapturePluginClass* klass) {
  GObjectClass* object_class = G_OBJECT_CLASS(klass);
  object_class->dispose = mic_capture_plugin_dispose;
}

static void mic_capture_plugin_init(MicCapturePlugin* plugin) {
  g_mutex_init(&plugin->lock);
  plugin->main_context = g_main_context_ref_thread_default();
  plugin->is_capturing = FALSE;
  plugin->has_listener = FALSE;
  plugin->has_status_listener = FALSE;
  plugin->has_decibel_listener = FALSE;
  plugin->method_channel = nullptr;
  plugin->event_channel = nullptr;
  plugin->status_event_channel = nullptr;
  plugin->decibel_event_channel = nullptr;
  plugin->capture_thread = nullptr;
  plugin->current_device_name = nullptr;
  g_atomic_int_set(&plugin->should_stop, 0);
}

void mic_capture_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  FlBinaryMessenger* messenger = fl_plugin_registrar_get_messenger(registrar);
  mic_capture_plugin_register_with_messenger(messenger);
}

void mic_capture_plugin_register_with_messenger(FlBinaryMessenger* messenger) {
  MicCapturePlugin* plugin = MIC_CAPTURE_PLUGIN(
      g_object_new(mic_capture_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

  plugin->method_channel = fl_method_channel_new(
      messenger, kMethodChannelName, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(plugin->method_channel,
                                            MethodCallHandler, g_object_ref(plugin),
                                            g_object_unref);

  plugin->event_channel = fl_event_channel_new(messenger, kEventChannelName,
                                                 FL_METHOD_CODEC(codec));

  fl_event_channel_set_stream_handlers(plugin->event_channel, OnListenHandler,
                                        OnCancelHandler, g_object_ref(plugin),
                                        g_object_unref);

  // Register status event channel
  plugin->status_event_channel = fl_event_channel_new(
      messenger, kStatusEventChannelName, FL_METHOD_CODEC(codec));
  fl_event_channel_set_stream_handlers(
      plugin->status_event_channel,
      OnStatusListenHandler,
      OnStatusCancelHandler,
      g_object_ref(plugin),
      g_object_unref);

  // Register decibel event channel
  plugin->decibel_event_channel = fl_event_channel_new(
      messenger, kDecibelEventChannelName, FL_METHOD_CODEC(codec));
  fl_event_channel_set_stream_handlers(
      plugin->decibel_event_channel,
      OnDecibelListenHandler,
      OnDecibelCancelHandler,
      g_object_ref(plugin),
      g_object_unref);

  g_object_unref(plugin);
}

