#include "include/audio_capture/audio_capture_plugin.h"
#include "include/audio_capture/mic_capture_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <glib-object.h>
#include <glib.h>
#include <pulse/error.h>
#include <pulse/simple.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace {

constexpr char kMethodChannelName[] = "com.system_audio_transcriber/audio_capture";
constexpr char kEventChannelName[] = "com.system_audio_transcriber/audio_stream";
constexpr char kStatusEventChannelName[] = "com.system_audio_transcriber/audio_status";
constexpr char kDecibelEventChannelName[] = "com.system_audio_transcriber/audio_decibel";

constexpr int kDefaultSampleRate = 16000;
constexpr int kDefaultChannels = 1;
constexpr int kDefaultBitsPerSample = 16;
constexpr int kDefaultChunkDurationMs = 1000;
constexpr float kDefaultGainBoost = 2.5f;
constexpr float kDefaultInputVolume = 1.0f;

struct AudioChunkPayload {
  AudioChunkPayload(AudioCapturePlugin* plugin, GBytes* bytes, double decibel)
      : plugin(plugin), bytes(bytes), decibel(decibel) {}

  AudioCapturePlugin* plugin;
  GBytes* bytes;
  double decibel;
};

struct CaptureThreadContext {
  AudioCapturePlugin* plugin;
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

}  // namespace

struct _AudioCapturePlugin {
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
};

G_DEFINE_TYPE(AudioCapturePlugin, audio_capture_plugin, G_TYPE_OBJECT)

namespace {

bool OpenPulseStream(int sample_rate, int channels, int bits_per_sample,
                     size_t chunk_size, pa_simple** out_stream, std::string* error_message) {
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
  attr.tlength = (uint32_t)-1;
  attr.prebuf = (uint32_t)-1;
  attr.minreq = (uint32_t)-1;
  attr.fragsize = static_cast<uint32_t>(chunk_size);

  int error = 0;

  pa_simple* stream =
      pa_simple_new(nullptr, "Voxa", PA_STREAM_RECORD, "@DEFAULT_MONITOR@",
                    "System Capture", &spec, nullptr, &attr, &error);

  if (stream == nullptr) {
    // Fallback to default source (microphone) if monitor is unavailable.
    stream = pa_simple_new(nullptr, "Voxa", PA_STREAM_RECORD, nullptr,
                           "Default Capture", &spec, nullptr, &attr, &error);
  }

  if (stream == nullptr) {
    if (error_message != nullptr) {
      *error_message = pa_strerror(error);
    }
    return false;
  }

  *out_stream = stream;
  return true;
}

size_t CalculateChunkSize(int sample_rate, int channels, int bits_per_sample,
                          int chunk_duration_ms) {
  const int bytes_per_sample = std::max(bits_per_sample / 8, 1);
  const size_t bytes_per_second =
      static_cast<size_t>(sample_rate) * static_cast<size_t>(channels) *
      static_cast<size_t>(bytes_per_sample);
  size_t chunk_size =
      (bytes_per_second * static_cast<size_t>(chunk_duration_ms)) / 1000;
  if (chunk_size == 0) {
    chunk_size = bytes_per_second / 20;  // 50 ms fallback
  }
  const size_t frame_size = static_cast<size_t>(channels) * bytes_per_sample;
  chunk_size = std::max(chunk_size, frame_size);
  return chunk_size;
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
  AudioCapturePlugin* plugin = payload->plugin;

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
  AudioCapturePlugin* plugin = context->plugin;

  // Read raw audio from PulseAudio
  std::vector<uint8_t> raw_buffer(context->chunk_size);

  // Output buffer for processed audio (mono)
  const size_t output_frame_count = context->chunk_size / (sizeof(int16_t) * context->channels);
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

    // Process audio: convert to mono and apply gain boost
    const int16_t* input_samples =
        reinterpret_cast<const int16_t*>(raw_buffer.data());
    const size_t input_frame_count =
        raw_buffer.size() / (sizeof(int16_t) * context->channels);
    const size_t frames_to_process =
        std::min(input_frame_count, output_frame_count);

    // Always process to ensure mono output and gain boost application
    ApplyGainBoostAndConvertToMono(input_samples, output_buffer.data(),
                                    frames_to_process, context->channels,
                                    context->gain_boost);

    // Create output bytes (mono)
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
  AudioCapturePlugin* plugin = AUDIO_CAPTURE_PLUGIN(user_data);
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
  AudioCapturePlugin* plugin = AUDIO_CAPTURE_PLUGIN(user_data);
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
  AudioCapturePlugin* plugin = AUDIO_CAPTURE_PLUGIN(user_data);
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
  AudioCapturePlugin* plugin = AUDIO_CAPTURE_PLUGIN(user_data);
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
  AudioCapturePlugin* plugin = AUDIO_CAPTURE_PLUGIN(user_data);
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
  AudioCapturePlugin* plugin = AUDIO_CAPTURE_PLUGIN(user_data);
  (void)channel;
  (void)arguments;
  g_mutex_lock(&plugin->lock);
  plugin->has_decibel_listener = FALSE;
  g_mutex_unlock(&plugin->lock);
  return nullptr;
}

bool StartCapture(AudioCapturePlugin* plugin, FlValue* args) {
  int sample_rate = kDefaultSampleRate;
  int channels = kDefaultChannels;
  int bits_per_sample = kDefaultBitsPerSample;
  int chunk_duration_ms = kDefaultChunkDurationMs;
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

    value = fl_value_lookup_string(args, "bitsPerSample");
    if (value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_INT) {
      bits_per_sample = fl_value_get_int(value);
    }

    value = fl_value_lookup_string(args, "chunkDurationMs");
    if (value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_INT) {
      chunk_duration_ms = fl_value_get_int(value);
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

  sample_rate = std::max(sample_rate, 8000);
  channels = std::max(1, std::min(channels, 2));
  bits_per_sample = 16;
  chunk_duration_ms = std::max(chunk_duration_ms, 10);
  gain_boost = std::max(0.1f, std::min(10.0f, gain_boost));
  input_volume = std::max(0.0f, std::min(1.0f, input_volume));

  size_t chunk_size =
      CalculateChunkSize(sample_rate, channels, bits_per_sample,
                         chunk_duration_ms);

  pa_simple* stream = nullptr;
  std::string error_message;

  if (!OpenPulseStream(sample_rate, channels, bits_per_sample, chunk_size,
                       &stream, &error_message)) {
    g_warning("Failed to open PulseAudio stream: %s", error_message.c_str());
    return false;
  }

  g_mutex_lock(&plugin->lock);
  if (plugin->is_capturing) {
    g_mutex_unlock(&plugin->lock);
    pa_simple_free(stream);
    return false;
  }

  g_atomic_int_set(&plugin->should_stop, 0);
  plugin->is_capturing = TRUE;

  auto* context = new CaptureThreadContext{
      plugin,
      stream,
      chunk_size,
      sample_rate,
      channels,
      bits_per_sample,
      gain_boost,
      input_volume,
  };

  g_object_ref(plugin);
  plugin->capture_thread = g_thread_new("voxa-audio-capture", CaptureThread,
                                        context);
  g_mutex_unlock(&plugin->lock);

  if (plugin->capture_thread == nullptr) {
    g_warning("Failed to create capture thread");
    g_mutex_lock(&plugin->lock);
    plugin->is_capturing = FALSE;
    g_mutex_unlock(&plugin->lock);
    pa_simple_free(stream);
    g_object_unref(plugin);
    delete context;
    return false;
  }

  // Send status update
  g_mutex_lock(&plugin->lock);
  const gboolean has_status_listener = plugin->has_status_listener;
  g_mutex_unlock(&plugin->lock);
  
  if (has_status_listener && plugin->status_event_channel != nullptr) {
    g_autoptr(FlValue) status_map = fl_value_new_map();
    fl_value_set_string_take(status_map, "isActive", fl_value_new_bool(TRUE));
    fl_value_set_string_take(status_map, "timestamp", fl_value_new_float(g_get_real_time() / 1000000.0));
    
    g_autoptr(GError) error = nullptr;
    fl_event_channel_send(plugin->status_event_channel, status_map, nullptr, &error);
  }

  return true;
}

bool StopCapture(AudioCapturePlugin* plugin) {
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
  if (has_status_listener && plugin->status_event_channel != nullptr) {
    g_autoptr(FlValue) status_map = fl_value_new_map();
    fl_value_set_string_take(status_map, "isActive", fl_value_new_bool(FALSE));
    fl_value_set_string_take(status_map, "timestamp", fl_value_new_float(g_get_real_time() / 1000000.0));
    
    g_autoptr(GError) error = nullptr;
    fl_event_channel_send(plugin->status_event_channel, status_map, nullptr, &error);
  }

  return true;
}

void HandleMethodCall(AudioCapturePlugin* plugin, FlMethodCall* method_call) {
  const gchar* method = fl_method_call_get_name(method_call);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (strcmp(method, "requestPermissions") == 0) {
    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
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
  AudioCapturePlugin* plugin = AUDIO_CAPTURE_PLUGIN(user_data);
  HandleMethodCall(plugin, method_call);
}

}  // namespace

static void audio_capture_plugin_dispose(GObject* object) {
  AudioCapturePlugin* plugin = AUDIO_CAPTURE_PLUGIN(object);

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

  if (plugin->main_context != nullptr) {
    g_main_context_unref(plugin->main_context);
    plugin->main_context = nullptr;
  }

  g_mutex_clear(&plugin->lock);

  G_OBJECT_CLASS(audio_capture_plugin_parent_class)->dispose(object);
}

static void audio_capture_plugin_class_init(AudioCapturePluginClass* klass) {
  GObjectClass* object_class = G_OBJECT_CLASS(klass);
  object_class->dispose = audio_capture_plugin_dispose;
}

static void audio_capture_plugin_init(AudioCapturePlugin* plugin) {
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
  g_atomic_int_set(&plugin->should_stop, 0);
}

void audio_capture_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  FlBinaryMessenger* messenger = fl_plugin_registrar_get_messenger(registrar);
  audio_capture_plugin_register_with_messenger(messenger);
  // Also register the mic capture plugin
  mic_capture_plugin_register_with_messenger(messenger);
}

void audio_capture_plugin_register_with_messenger(FlBinaryMessenger* messenger) {
  AudioCapturePlugin* plugin =
      AUDIO_CAPTURE_PLUGIN(g_object_new(audio_capture_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();

  plugin->method_channel = fl_method_channel_new(
      messenger, kMethodChannelName, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      plugin->method_channel, MethodCallHandler, g_object_ref(plugin),
      g_object_unref);

  plugin->event_channel = fl_event_channel_new(
      messenger, kEventChannelName, FL_METHOD_CODEC(codec));
  
  // Use the newer API with proper function signatures
  fl_event_channel_set_stream_handlers(
      plugin->event_channel, 
      OnListenHandler, 
      OnCancelHandler,
      g_object_ref(plugin), 
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
