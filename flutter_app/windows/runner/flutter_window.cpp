#include "flutter_window.h"

#include <flutter/encodable_value.h>

#include <gdiplus.h>
#include <shellapi.h>
#include <windows.h>

#include <cctype>
#include <cstring>
#include <cwchar>
#include <cmath>
#include <memory>
#include <optional>
#include <sstream>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return std::wstring();
  }
  const int length =
      MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, nullptr, 0);
  if (length <= 0) {
    return std::wstring();
  }
  std::wstring wide(static_cast<size_t>(length), L'\0');
  MultiByteToWideChar(
      CP_UTF8, 0, value.c_str(), -1, wide.data(), length);
  wide.resize(wcslen(wide.c_str()));
  return wide;
}

std::string WideToUtf8(const std::wstring& value) {
  if (value.empty()) {
    return std::string();
  }
  const int length =
      WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, nullptr, 0, nullptr, nullptr);
  if (length <= 0) {
    return std::string();
  }
  std::string utf8(static_cast<size_t>(length), '\0');
  WideCharToMultiByte(
      CP_UTF8, 0, value.c_str(), -1, utf8.data(), length, nullptr, nullptr);
  utf8.resize(strlen(utf8.c_str()));
  return utf8;
}

const EncodableValue* MapValue(const EncodableMap& map, const char* key) {
  auto it = map.find(EncodableValue(key));
  if (it == map.end()) {
    return nullptr;
  }
  return &it->second;
}

bool GetInt(const EncodableMap& map, const char* key, int* out) {
  const EncodableValue* value = MapValue(map, key);
  if (value == nullptr) {
    return false;
  }
  if (std::holds_alternative<int>(*value)) {
    *out = std::get<int>(*value);
    return true;
  }
  if (std::holds_alternative<int64_t>(*value)) {
    *out = static_cast<int>(std::get<int64_t>(*value));
    return true;
  }
  if (std::holds_alternative<double>(*value)) {
    *out = static_cast<int>(std::lround(std::get<double>(*value)));
    return true;
  }
  return false;
}

std::string GetString(const EncodableMap& map, const char* key,
                      const std::string& fallback = std::string()) {
  const EncodableValue* value = MapValue(map, key);
  if (value == nullptr) {
    return fallback;
  }
  if (std::holds_alternative<std::string>(*value)) {
    return std::get<std::string>(*value);
  }
  return fallback;
}

bool GetBool(const EncodableMap& map, const char* key, bool fallback = false) {
  const EncodableValue* value = MapValue(map, key);
  if (value == nullptr) {
    return fallback;
  }
  if (std::holds_alternative<bool>(*value)) {
    return std::get<bool>(*value);
  }
  return fallback;
}

struct DisplayInfo {
  std::wstring id;
  RECT rect;
  bool primary;
  std::wstring label;
};

BOOL CALLBACK CollectDisplays(HMONITOR monitor, HDC, LPRECT, LPARAM data) {
  auto* displays = reinterpret_cast<std::vector<DisplayInfo>*>(data);
  MONITORINFOEXW info;
  info.cbSize = sizeof(MONITORINFOEXW);
  if (!GetMonitorInfoW(monitor, &info)) {
    return TRUE;
  }

  std::wstringstream id;
  id << info.szDevice;
  displays->push_back(DisplayInfo{
      id.str(),
      info.rcMonitor,
      (info.dwFlags & MONITORINFOF_PRIMARY) != 0,
      info.szDevice,
  });
  return TRUE;
}

std::vector<DisplayInfo> EnumerateDisplays() {
  std::vector<DisplayInfo> displays;
  EnumDisplayMonitors(nullptr, nullptr, CollectDisplays,
                      reinterpret_cast<LPARAM>(&displays));
  return displays;
}

DisplayInfo ResolveDisplay(const std::string& requested_id) {
  const auto displays = EnumerateDisplays();
  if (!requested_id.empty()) {
    const std::wstring requested_wide = Utf8ToWide(requested_id);
    for (const auto& display : displays) {
      if (display.id == requested_wide) {
        return display;
      }
    }
  }
  for (const auto& display : displays) {
    if (display.primary) {
      return display;
    }
  }
  return displays.empty()
             ? DisplayInfo{L"primary", RECT{0, 0, GetSystemMetrics(SM_CXSCREEN),
                                            GetSystemMetrics(SM_CYSCREEN)},
                           true, L"Primary Display"}
             : displays.front();
}

CLSID PngEncoderClsid() {
  UINT count = 0;
  UINT size = 0;
  Gdiplus::GetImageEncodersSize(&count, &size);
  std::vector<BYTE> buffer(size);
  auto* codecs = reinterpret_cast<Gdiplus::ImageCodecInfo*>(buffer.data());
  Gdiplus::GetImageEncoders(count, size, codecs);
  for (UINT index = 0; index < count; ++index) {
    if (wcscmp(codecs[index].MimeType, L"image/png") == 0) {
      return codecs[index].Clsid;
    }
  }
  return CLSID{};
}

std::vector<uint8_t> CaptureDisplayPng(const DisplayInfo& display) {
  const int width = display.rect.right - display.rect.left;
  const int height = display.rect.bottom - display.rect.top;
  HDC screen_dc = GetDC(nullptr);
  HDC memory_dc = CreateCompatibleDC(screen_dc);
  HBITMAP bitmap = CreateCompatibleBitmap(screen_dc, width, height);
  HGDIOBJ old_object = SelectObject(memory_dc, bitmap);

  BitBlt(memory_dc, 0, 0, width, height, screen_dc, display.rect.left,
         display.rect.top, SRCCOPY | CAPTUREBLT);

  Gdiplus::Bitmap image(bitmap, nullptr);
  IStream* stream = nullptr;
  CreateStreamOnHGlobal(nullptr, TRUE, &stream);
  const CLSID encoder = PngEncoderClsid();
  image.Save(stream, &encoder, nullptr);

  STATSTG stats;
  stream->Stat(&stats, STATFLAG_NONAME);
  std::vector<uint8_t> bytes(static_cast<size_t>(stats.cbSize.QuadPart));
  LARGE_INTEGER seek_start{};
  ULARGE_INTEGER new_position{};
  stream->Seek(seek_start, STREAM_SEEK_SET, &new_position);
  ULONG read = 0;
  stream->Read(bytes.data(), static_cast<ULONG>(bytes.size()), &read);

  stream->Release();
  SelectObject(memory_dc, old_object);
  DeleteObject(bitmap);
  DeleteDC(memory_dc);
  ReleaseDC(nullptr, screen_dc);
  return bytes;
}

EncodableList DisplaysToEncodable() {
  EncodableList list;
  for (const auto& display : EnumerateDisplays()) {
    const int width = display.rect.right - display.rect.left;
    const int height = display.rect.bottom - display.rect.top;
    EncodableMap item;
    item[EncodableValue("id")] = EncodableValue(WideToUtf8(display.id));
    item[EncodableValue("label")] = EncodableValue(WideToUtf8(display.label));
    item[EncodableValue("width")] = EncodableValue(width);
    item[EncodableValue("height")] = EncodableValue(height);
    item[EncodableValue("scaleFactor")] = EncodableValue(1.0);
    item[EncodableValue("primary")] = EncodableValue(display.primary);
    list.emplace_back(item);
  }
  return list;
}

std::string ForegroundWindowTitle() {
  HWND window = GetForegroundWindow();
  if (window == nullptr) {
    return std::string();
  }
  wchar_t buffer[512];
  const int length = GetWindowTextW(window, buffer, 512);
  if (length <= 0) {
    return std::string();
  }
  return WideToUtf8(std::wstring(buffer, buffer + length));
}

void SendMouseButton(DWORD flag) {
  INPUT input{};
  input.type = INPUT_MOUSE;
  input.mi.dwFlags = flag;
  SendInput(1, &input, sizeof(INPUT));
}

WORD VirtualKeyForString(const std::string& key) {
  const std::string lowered = [&]() {
    std::string value = key;
    for (auto& ch : value) {
      ch = static_cast<char>(tolower(ch));
    }
    return value;
  }();
  if (lowered == "enter" || lowered == "return") return VK_RETURN;
  if (lowered == "tab") return VK_TAB;
  if (lowered == "space") return VK_SPACE;
  if (lowered == "escape" || lowered == "esc") return VK_ESCAPE;
  if (lowered == "backspace" || lowered == "delete") return VK_BACK;
  if (lowered == "left") return VK_LEFT;
  if (lowered == "right") return VK_RIGHT;
  if (lowered == "up") return VK_UP;
  if (lowered == "down") return VK_DOWN;
  return 0;
}

void SendVirtualKey(WORD key_code) {
  INPUT inputs[2]{};
  inputs[0].type = INPUT_KEYBOARD;
  inputs[0].ki.wVk = key_code;
  inputs[1].type = INPUT_KEYBOARD;
  inputs[1].ki.wVk = key_code;
  inputs[1].ki.dwFlags = KEYEVENTF_KEYUP;
  SendInput(2, inputs, sizeof(INPUT));
}

void SendUnicodeText(const std::wstring& text) {
  for (const wchar_t ch : text) {
    INPUT inputs[2]{};
    inputs[0].type = INPUT_KEYBOARD;
    inputs[0].ki.dwFlags = KEYEVENTF_UNICODE;
    inputs[0].ki.wScan = ch;
    inputs[1].type = INPUT_KEYBOARD;
    inputs[1].ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
    inputs[1].ki.wScan = ch;
    SendInput(2, inputs, sizeof(INPUT));
  }
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  Gdiplus::GdiplusStartupInput gdiplus_startup_input;
  ULONG_PTR gdiplus_token = 0;
  Gdiplus::GdiplusStartup(&gdiplus_token, &gdiplus_startup_input, nullptr);

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  desktop_channel_ =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "neoagent/desktop_companion_native",
          &flutter::StandardMethodCodec::GetInstance());

  desktop_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        const auto* arguments = std::get_if<EncodableMap>(call.arguments());

        if (call.method_name() == "getStatus") {
          EncodableMap permissions;
          permissions[EncodableValue("screenCapture")] = EncodableValue("available");
          permissions[EncodableValue("inputControl")] = EncodableValue("available");
          permissions[EncodableValue("accessibility")] = EncodableValue("available");

          EncodableMap status;
          status[EncodableValue("permissions")] = EncodableValue(permissions);
          status[EncodableValue("displays")] = EncodableValue(DisplaysToEncodable());
          status[EncodableValue("activeDisplayId")] =
              EncodableValue(WideToUtf8(ResolveDisplay("").id));
          const std::string window_title = ForegroundWindowTitle();
          if (!window_title.empty()) {
            status[EncodableValue("frontmostWindowTitle")] =
                EncodableValue(window_title);
          }
          result->Success(EncodableValue(status));
          return;
        }

        if (call.method_name() == "listDisplays") {
          result->Success(EncodableValue(DisplaysToEncodable()));
          return;
        }

        if (call.method_name() == "captureFrame") {
          const std::string display_id =
              arguments == nullptr ? std::string() : GetString(*arguments, "displayId");
          const DisplayInfo display = ResolveDisplay(display_id);
          const auto bytes = CaptureDisplayPng(display);

          EncodableMap payload;
          payload[EncodableValue("bytes")] =
              EncodableValue(std::vector<uint8_t>(bytes.begin(), bytes.end()));
          payload[EncodableValue("mimeType")] = EncodableValue("image/png");
          payload[EncodableValue("width")] =
              EncodableValue(display.rect.right - display.rect.left);
          payload[EncodableValue("height")] =
              EncodableValue(display.rect.bottom - display.rect.top);
          payload[EncodableValue("displayId")] =
              EncodableValue(WideToUtf8(display.id));
          payload[EncodableValue("displays")] =
              EncodableValue(DisplaysToEncodable());
          const std::string window_title = ForegroundWindowTitle();
          if (!window_title.empty()) {
            payload[EncodableValue("frontmostWindowTitle")] =
                EncodableValue(window_title);
          }
          result->Success(EncodableValue(payload));
          return;
        }

        if (call.method_name() == "click") {
          if (arguments == nullptr) {
            result->Error("invalid_arguments", "Missing click payload.");
            return;
          }
          int x = 0;
          int y = 0;
          GetInt(*arguments, "x", &x);
          GetInt(*arguments, "y", &y);
          const std::string button = GetString(*arguments, "button", "left");
          SetCursorPos(x, y);
          if (button == "right") {
            SendMouseButton(MOUSEEVENTF_RIGHTDOWN);
            SendMouseButton(MOUSEEVENTF_RIGHTUP);
          } else if (button == "middle") {
            SendMouseButton(MOUSEEVENTF_MIDDLEDOWN);
            SendMouseButton(MOUSEEVENTF_MIDDLEUP);
          } else {
            SendMouseButton(MOUSEEVENTF_LEFTDOWN);
            SendMouseButton(MOUSEEVENTF_LEFTUP);
          }
          result->Success(EncodableValue());
          return;
        }

        if (call.method_name() == "drag") {
          if (arguments == nullptr) {
            result->Error("invalid_arguments", "Missing drag payload.");
            return;
          }
          int x1 = 0, y1 = 0, x2 = 0, y2 = 0, duration_ms = 280;
          GetInt(*arguments, "x1", &x1);
          GetInt(*arguments, "y1", &y1);
          GetInt(*arguments, "x2", &x2);
          GetInt(*arguments, "y2", &y2);
          GetInt(*arguments, "durationMs", &duration_ms);
          const int steps = std::max(4, std::min(90, duration_ms / 16));
          SetCursorPos(x1, y1);
          SendMouseButton(MOUSEEVENTF_LEFTDOWN);
          for (int step = 1; step <= steps; ++step) {
            const double t = static_cast<double>(step) / steps;
            const int nx = static_cast<int>(std::lround(x1 + ((x2 - x1) * t)));
            const int ny = static_cast<int>(std::lround(y1 + ((y2 - y1) * t)));
            SetCursorPos(nx, ny);
            Sleep(std::max(1, duration_ms / std::max(1, steps)));
          }
          SendMouseButton(MOUSEEVENTF_LEFTUP);
          result->Success(EncodableValue());
          return;
        }

        if (call.method_name() == "scroll") {
          if (arguments == nullptr) {
            result->Error("invalid_arguments", "Missing scroll payload.");
            return;
          }
          int delta_x = 0;
          int delta_y = 0;
          GetInt(*arguments, "deltaX", &delta_x);
          GetInt(*arguments, "deltaY", &delta_y);
          if (delta_y != 0) {
            INPUT input{};
            input.type = INPUT_MOUSE;
            input.mi.dwFlags = MOUSEEVENTF_WHEEL;
            input.mi.mouseData = static_cast<DWORD>(delta_y);
            SendInput(1, &input, sizeof(INPUT));
          }
          if (delta_x != 0) {
            INPUT input{};
            input.type = INPUT_MOUSE;
            input.mi.dwFlags = MOUSEEVENTF_HWHEEL;
            input.mi.mouseData = static_cast<DWORD>(delta_x);
            SendInput(1, &input, sizeof(INPUT));
          }
          result->Success(EncodableValue());
          return;
        }

        if (call.method_name() == "typeText") {
          if (arguments == nullptr) {
            result->Error("invalid_arguments", "Missing text payload.");
            return;
          }
          const std::wstring text = Utf8ToWide(GetString(*arguments, "text", ""));
          const bool press_enter = GetBool(*arguments, "pressEnter", false);
          if (!text.empty()) {
            SendUnicodeText(text);
          }
          if (press_enter) {
            SendVirtualKey(VK_RETURN);
          }
          result->Success(EncodableValue());
          return;
        }

        if (call.method_name() == "pressKey") {
          if (arguments == nullptr) {
            result->Error("invalid_arguments", "Missing key payload.");
            return;
          }
          const std::string key = GetString(*arguments, "key", "");
          const WORD virtual_key = VirtualKeyForString(key);
          if (virtual_key == 0) {
            result->Error("unsupported_key", "Key is not supported.");
            return;
          }
          SendVirtualKey(virtual_key);
          result->Success(EncodableValue());
          return;
        }

        result->NotImplemented();
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() { this->Show(); });
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }
  desktop_channel_.reset();
  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      if (flutter_controller_ != nullptr &&
          flutter_controller_->engine() != nullptr) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
