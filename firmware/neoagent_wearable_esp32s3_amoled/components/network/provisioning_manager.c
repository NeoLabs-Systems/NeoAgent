#include "provisioning_manager.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "esp_event.h"
#include "esp_http_server.h"
#include "esp_log.h"
#include "esp_mac.h"
#include "esp_netif.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"
#include "freertos/task.h"
#include "lwip/inet.h"

static const char *TAG = "Provisioning";

typedef struct {
    provisioning_manager_t *manager;
    session_store_t *store;
} portal_context_t;

static portal_context_t s_portal_context = {0};
static bool s_netif_initialized = false;
static bool s_event_loop_initialized = false;
static bool s_wifi_initialized = false;
static provisioning_manager_t *s_active_manager = NULL;

#define WIFI_EVENT_STA_CONNECTED_BIT BIT0
#define WIFI_EVENT_STA_FAILED_BIT BIT1

static const char *s_setup_html =
    "<!DOCTYPE html><html lang='en'><head><meta charset='utf-8'>"
    "<meta name='viewport' content='width=device-width,initial-scale=1,viewport-fit=cover'>"
    "<title>NeoAgent wearable setup</title>"
    "<style>"
    ":root{color-scheme:dark;--bg:#06111f;--bg2:#102847;--card:rgba(6,18,34,.84);--line:rgba(164,192,227,.18);"
    "--text:#f4f8ff;--muted:#a8bdd8;--accent:#74f0c4;--accent2:#6eb5ff;--danger:#ff9b8f;}"
    "*{box-sizing:border-box}body{margin:0;min-height:100vh;font:16px/1.45 ui-sans-serif,system-ui,sans-serif;"
    "color:var(--text);background:radial-gradient(circle at top,#174170 0%,var(--bg) 54%,#040912 100%);}"
    ".shell{max-width:560px;margin:0 auto;padding:24px 18px 40px}.hero{padding:20px 4px 10px}"
    ".eyebrow{display:inline-block;padding:6px 10px;border:1px solid rgba(116,240,196,.28);border-radius:999px;"
    "background:rgba(116,240,196,.1);color:var(--accent);font-size:12px;font-weight:700;letter-spacing:.08em;text-transform:uppercase}"
    "h1{margin:16px 0 10px;font-size:34px;line-height:1.04;letter-spacing:-.04em}"
    "p{margin:0;color:var(--muted)}.card{margin-top:18px;padding:18px;border-radius:24px;background:var(--card);"
    "backdrop-filter:blur(12px);border:1px solid var(--line);box-shadow:0 18px 46px rgba(0,0,0,.28)}"
    ".steps{display:grid;gap:10px;margin:0;padding:0;list-style:none}.steps li{display:grid;grid-template-columns:28px 1fr;"
    "gap:12px;align-items:start}.num{width:28px;height:28px;border-radius:50%;display:grid;place-items:center;"
    "background:linear-gradient(135deg,var(--accent2),var(--accent));color:#03111f;font-weight:800;font-size:13px}"
    ".label{font-weight:700}.hint{font-size:13px;color:var(--muted);margin-top:2px}"
    ".grid{display:grid;gap:14px}.field{display:grid;gap:7px}.field label{font-size:13px;font-weight:700;color:#dfeafe}"
    ".input,.select{width:100%;padding:15px 16px;border-radius:16px;border:1px solid rgba(177,201,232,.16);"
    "background:rgba(255,255,255,.05);color:var(--text);outline:none}.input:focus,.select:focus{border-color:rgba(116,240,196,.62);"
    "box-shadow:0 0 0 3px rgba(116,240,196,.12)}.cluster{display:grid;grid-template-columns:120px 1fr 110px;gap:10px}"
    ".button{border:0;border-radius:18px;padding:16px 18px;font-size:16px;font-weight:800;cursor:pointer;color:#02131a;"
    "background:linear-gradient(135deg,var(--accent),#9be5ff);box-shadow:0 18px 28px rgba(8,41,61,.32)}"
    ".button:disabled{opacity:.7;cursor:wait}.fine{font-size:12px;color:var(--muted)}.status{display:none;padding:14px 16px;"
    "border-radius:16px;font-size:14px}.status.ok{display:block;background:rgba(116,240,196,.12);color:#d7fff1;border:1px solid rgba(116,240,196,.25)}"
    ".status.err{display:block;background:rgba(255,155,143,.12);color:#ffe0db;border:1px solid rgba(255,155,143,.22)}"
    ".footer{margin-top:16px;color:var(--muted);font-size:12px}.mono{font-family:ui-monospace,SFMono-Regular,Menlo,monospace}"
    "@media (max-width:520px){h1{font-size:28px}.cluster{grid-template-columns:1fr}.shell{padding:18px 14px 36px}}"
    "</style></head><body><main class='shell'><section class='hero'>"
    "<div class='eyebrow'>NeoAgent wearable</div><h1>Finish setup in one short flow.</h1>"
    "<p>Stay on this screen after joining the device Wi-Fi. When you save, the wearable reboots and moves to the next step automatically.</p>"
    "</section><section class='card'><ol class='steps'>"
    "<li><div class='num'>1</div><div><div class='label'>Join the wearable Wi-Fi</div><div class='hint'>It is open for setup, so you do not need to type a password.</div></div></li>"
    "<li><div class='num'>2</div><div><div class='label'>Enter where NeoAgent is running</div><div class='hint'>Use a full URL, or choose the scheme and just enter host and port.</div></div></li>"
    "<li><div class='num'>3</div><div><div class='label'>Save once</div><div class='hint'>The device stores the config and restarts itself.</div></div></li>"
    "</ol></section><section class='card'><form id='setup-form' class='grid'>"
    "<div class='field'><label for='server_url'>NeoAgent server</label><input class='input mono' id='server_url' name='server_url' placeholder='https://app.example.com or http://192.168.1.20:3333' autocapitalize='off' spellcheck='false'></div>"
    "<div class='field'><label>Or build the URL</label><div class='cluster'>"
    "<select class='select' id='server_scheme' name='server_scheme'><option value='https'>https://</option><option value='http'>http://</option></select>"
    "<input class='input mono' id='server_host' name='server_host' placeholder='host or ip' autocapitalize='off' spellcheck='false'>"
    "<input class='input mono' id='server_port' name='server_port' placeholder='port'></div>"
    "<div class='fine'>If the full URL field is filled, it takes priority.</div></div>"
    "<div class='field'><label for='wifi_ssid'>Home or office Wi-Fi name</label><input class='input' id='wifi_ssid' name='wifi_ssid' autocomplete='wifi username' required></div>"
    "<div class='field'><label for='wifi_password'>Wi-Fi password</label><input class='input' id='wifi_password' name='wifi_password' type='password' autocomplete='current-password'></div>"
    "<div class='field'><label for='device_label'>Device name</label><input class='input' id='device_label' name='device_label' placeholder='Wrist NeoAgent'></div>"
    "<div id='status' class='status'></div><button id='submit' class='button' type='submit'>Save and restart wearable</button>"
    "<div class='footer'>This setup page lives on the wearable itself. The backend URL is stored locally on the device.</div>"
    "</form></section></main>"
    "<script>"
    "const form=document.getElementById('setup-form');const status=document.getElementById('status');const submit=document.getElementById('submit');"
    "function setStatus(kind,text){status.className='status '+kind;status.textContent=text;}"
    "function buildServerUrl(fd){const direct=(fd.get('server_url')||'').trim();if(direct)return direct;"
    "const scheme=(fd.get('server_scheme')||'https').trim();const host=(fd.get('server_host')||'').trim();const port=(fd.get('server_port')||'').trim();"
    "if(!host)return '';return scheme+'://'+host+(port?':'+port:'');}"
    "form.addEventListener('submit',async(event)=>{event.preventDefault();submit.disabled=true;setStatus('','');"
    "const fd=new FormData(form);const serverUrl=buildServerUrl(fd);if(!serverUrl){setStatus('err','Enter a NeoAgent server URL or host.');submit.disabled=false;return;}"
    "fd.set('server_url',serverUrl);try{const response=await fetch('/configure',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded;charset=UTF-8'},body:new URLSearchParams(fd)});"
    "const payload=await response.json().catch(()=>({}));if(!response.ok){throw new Error(payload.error||'Setup failed');}"
    "setStatus('ok',payload.message||'Saved. The wearable is restarting now.');form.reset();}catch(error){setStatus('err',error.message||'Setup failed');submit.disabled=false;}});"
    "</script></body></html>";

static void url_decode_inplace(char *value) {
    char *src = value;
    char *dst = value;
    while (*src != '\0') {
        if (*src == '+') {
            *dst++ = ' ';
            src++;
            continue;
        }
        if (*src == '%' && isxdigit((unsigned char)src[1]) && isxdigit((unsigned char)src[2])) {
            char hex[3] = {src[1], src[2], '\0'};
            *dst++ = (char)strtol(hex, NULL, 16);
            src += 3;
            continue;
        }
        *dst++ = *src++;
    }
    *dst = '\0';
}

static bool is_likely_numeric_port(const char *value) {
    if (value == NULL || value[0] == '\0') {
        return false;
    }
    for (const char *cursor = value; *cursor != '\0'; ++cursor) {
        if (!isdigit((unsigned char)*cursor)) {
            return false;
        }
    }
    return true;
}

static void trim_whitespace_inplace(char *value) {
    if (value == NULL) {
        return;
    }
    char *start = value;
    while (*start != '\0' && isspace((unsigned char)*start)) {
        start++;
    }
    char *end = start + strlen(start);
    while (end > start && isspace((unsigned char)end[-1])) {
        end--;
    }
    *end = '\0';
    if (start != value) {
        memmove(value, start, (size_t)(end - start) + 1);
    }
}

static void copy_string_bounded(char *destination, size_t destination_size, const char *source) {
    if (destination == NULL || destination_size == 0) {
        return;
    }
    destination[0] = '\0';
    if (source == NULL) {
        return;
    }
    strncpy(destination, source, destination_size - 1);
    destination[destination_size - 1] = '\0';
}

static void append_string_bounded(char *destination, size_t destination_size, const char *suffix) {
    if (destination == NULL || destination_size == 0 || suffix == NULL) {
        return;
    }
    size_t used = strlen(destination);
    if (used >= destination_size - 1) {
        return;
    }
    strncpy(destination + used, suffix, destination_size - used - 1);
    destination[destination_size - 1] = '\0';
}

static void normalize_server_url(neoagent_device_config_t *config, const char *scheme, const char *host, const char *port) {
    if (config == NULL) {
        return;
    }
    trim_whitespace_inplace(config->server_url);
    if (config->server_url[0] != '\0') {
        if (strncmp(config->server_url, "http://", 7) != 0 && strncmp(config->server_url, "https://", 8) != 0) {
            char normalized[NEOAGENT_SERVER_URL_MAX] = {0};
            copy_string_bounded(normalized, sizeof(normalized), "https://");
            append_string_bounded(normalized, sizeof(normalized), config->server_url);
            copy_string_bounded(config->server_url, sizeof(config->server_url), normalized);
        }
        return;
    }

    char host_copy[NEOAGENT_SERVER_URL_MAX];
    char port_copy[16];
    strncpy(host_copy, host != NULL ? host : "", sizeof(host_copy) - 1);
    host_copy[sizeof(host_copy) - 1] = '\0';
    strncpy(port_copy, port != NULL ? port : "", sizeof(port_copy) - 1);
    port_copy[sizeof(port_copy) - 1] = '\0';
    trim_whitespace_inplace(host_copy);
    trim_whitespace_inplace(port_copy);
    if (host_copy[0] == '\0') {
        return;
    }

    const char *safe_scheme = (scheme != NULL && strcmp(scheme, "http") == 0) ? "http" : "https";
    config->server_url[0] = '\0';
    append_string_bounded(config->server_url, sizeof(config->server_url), safe_scheme);
    append_string_bounded(config->server_url, sizeof(config->server_url), "://");
    append_string_bounded(config->server_url, sizeof(config->server_url), host_copy);
    if (port_copy[0] != '\0' && is_likely_numeric_port(port_copy)) {
        append_string_bounded(config->server_url, sizeof(config->server_url), ":");
        append_string_bounded(config->server_url, sizeof(config->server_url), port_copy);
    }
}

static esp_err_t apply_form_field(neoagent_device_config_t *config, const char *key, char *value, char *scheme, size_t scheme_size, char *host, size_t host_size, char *port, size_t port_size) {
    url_decode_inplace(value);
    trim_whitespace_inplace(value);
    if (strcmp(key, "server_url") == 0) {
        strncpy(config->server_url, value, sizeof(config->server_url) - 1);
        config->server_url[sizeof(config->server_url) - 1] = '\0';
    } else if (strcmp(key, "wifi_ssid") == 0) {
        strncpy(config->wifi_ssid, value, sizeof(config->wifi_ssid) - 1);
        config->wifi_ssid[sizeof(config->wifi_ssid) - 1] = '\0';
    } else if (strcmp(key, "wifi_password") == 0) {
        strncpy(config->wifi_password, value, sizeof(config->wifi_password) - 1);
        config->wifi_password[sizeof(config->wifi_password) - 1] = '\0';
    } else if (strcmp(key, "device_label") == 0) {
        strncpy(config->device_label, value, sizeof(config->device_label) - 1);
        config->device_label[sizeof(config->device_label) - 1] = '\0';
    } else if (strcmp(key, "server_scheme") == 0) {
        strncpy(scheme, value, scheme_size - 1);
        scheme[scheme_size - 1] = '\0';
    } else if (strcmp(key, "server_host") == 0) {
        strncpy(host, value, host_size - 1);
        host[host_size - 1] = '\0';
    } else if (strcmp(key, "server_port") == 0) {
        strncpy(port, value, port_size - 1);
        port[port_size - 1] = '\0';
    }
    return ESP_OK;
}

static esp_err_t parse_form_body(char *body, neoagent_device_config_t *config) {
    char scheme[8] = {0};
    char host[NEOAGENT_SERVER_URL_MAX] = {0};
    char port[16] = {0};

    char *pair = strtok(body, "&");
    while (pair != NULL) {
        char *equals = strchr(pair, '=');
        if (equals != NULL) {
            *equals = '\0';
            char *key = pair;
            char *value = equals + 1;
            apply_form_field(config, key, value, scheme, sizeof(scheme), host, sizeof(host), port, sizeof(port));
        }
        pair = strtok(NULL, "&");
    }

    normalize_server_url(config, scheme, host, port);
    return ESP_OK;
}

static void reboot_after_save_task(void *arg) {
    provisioning_manager_t *manager = (provisioning_manager_t *)arg;
    vTaskDelay(pdMS_TO_TICKS(1800));
    if (manager != NULL && manager->http_server != NULL) {
        httpd_stop(manager->http_server);
        manager->http_server = NULL;
    }
    esp_restart();
}

static void send_json_response(httpd_req_t *request, const char *status, const char *body) {
    httpd_resp_set_status(request, status);
    httpd_resp_set_type(request, "application/json");
    httpd_resp_set_hdr(request, "Cache-Control", "no-store");
    httpd_resp_send(request, body, HTTPD_RESP_USE_STRLEN);
}

static esp_err_t redirect_to_root_handler(httpd_req_t *request) {
    httpd_resp_set_status(request, "303 See Other");
    httpd_resp_set_hdr(request, "Location", "http://192.168.4.1/");
    httpd_resp_set_type(request, "text/plain");
    return httpd_resp_send(request, "Open NeoAgent setup", HTTPD_RESP_USE_STRLEN);
}

static esp_err_t root_get_handler(httpd_req_t *request) {
    httpd_resp_set_type(request, "text/html");
    httpd_resp_set_hdr(request, "Cache-Control", "no-store");
    return httpd_resp_send(request, s_setup_html, HTTPD_RESP_USE_STRLEN);
}

static esp_err_t health_get_handler(httpd_req_t *request) {
    send_json_response(request, "200 OK", "{\"ok\":true,\"service\":\"neoagent-wearable-setup\"}");
    return ESP_OK;
}

static esp_err_t configure_post_handler(httpd_req_t *request) {
    if (s_portal_context.manager == NULL || s_portal_context.store == NULL) {
        send_json_response(request, "500 Internal Server Error", "{\"error\":\"portal unavailable\"}");
        return ESP_OK;
    }

    const int content_length = request->content_len;
    if (content_length <= 0 || content_length > 1535) {
        send_json_response(request, "400 Bad Request", "{\"error\":\"invalid form body\"}");
        return ESP_OK;
    }

    char body[1536];
    int offset = 0;
    while (offset < content_length) {
        int received = httpd_req_recv(request, body + offset, content_length - offset);
        if (received <= 0) {
            send_json_response(request, "400 Bad Request", "{\"error\":\"failed to read request\"}");
            return ESP_OK;
        }
        offset += received;
    }
    body[offset] = '\0';

    neoagent_device_config_t config = {0};
    parse_form_body(body, &config);
    if (provisioning_manager_validate_server_url(config.server_url) != ESP_OK || config.wifi_ssid[0] == '\0') {
        send_json_response(request, "400 Bad Request", "{\"error\":\"enter a valid server URL and Wi-Fi name\"}");
        return ESP_OK;
    }

    s_portal_context.manager->pending_config = config;
    s_portal_context.manager->has_pending_config = true;
    s_portal_context.manager->portal_saved_config = true;
    ESP_ERROR_CHECK(session_store_save_device_config(s_portal_context.store, &config));
    ESP_LOGI(TAG, "saved config for ssid=%s server=%s label=%s", config.wifi_ssid, config.server_url, config.device_label);

    if (xTaskCreate(reboot_after_save_task, "neo_reboot", 3072, s_portal_context.manager, 4, NULL) != pdPASS) {
        send_json_response(request, "500 Internal Server Error", "{\"error\":\"saved config but failed to schedule reboot\"}");
        return ESP_OK;
    }

    send_json_response(request, "200 OK", "{\"ok\":true,\"message\":\"Configuration saved. The wearable is restarting now.\"}");
    return ESP_OK;
}

static void wifi_event_handler(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data) {
    (void)arg;
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_AP_STACONNECTED) {
        wifi_event_ap_staconnected_t *event = (wifi_event_ap_staconnected_t *)event_data;
        ESP_LOGI(TAG, "station " MACSTR " join, AID=%d", MAC2STR(event->mac), event->aid);
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_AP_STADISCONNECTED) {
        wifi_event_ap_stadisconnected_t *event = (wifi_event_ap_stadisconnected_t *)event_data;
        ESP_LOGI(TAG, "station " MACSTR " leave, AID=%d, reason=%d", MAC2STR(event->mac), event->aid, event->reason);
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        ESP_LOGI(TAG, "station start");
        esp_wifi_connect();
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        wifi_event_sta_disconnected_t *event = (wifi_event_sta_disconnected_t *)event_data;
        if (s_active_manager != NULL && s_active_manager->wifi_events != NULL) {
            xEventGroupSetBits(s_active_manager->wifi_events, WIFI_EVENT_STA_FAILED_BIT);
        }
        ESP_LOGW(TAG, "station disconnected reason=%d", event->reason);
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t *event = (ip_event_got_ip_t *)event_data;
        if (s_active_manager != NULL) {
            s_active_manager->wifi_connected = true;
            if (s_active_manager->wifi_events != NULL) {
                xEventGroupSetBits(s_active_manager->wifi_events, WIFI_EVENT_STA_CONNECTED_BIT);
            }
        }
        ESP_LOGI(TAG, "station got ip " IPSTR, IP2STR(&event->ip_info.ip));
    }
}

static esp_err_t ensure_network_stack(void) {
    if (!s_netif_initialized) {
        ESP_ERROR_CHECK(esp_netif_init());
        s_netif_initialized = true;
    }
    if (!s_event_loop_initialized) {
        const esp_err_t err = esp_event_loop_create_default();
        if (err != ESP_OK && err != ESP_ERR_INVALID_STATE) {
            return err;
        }
        s_event_loop_initialized = true;
    }
    if (!s_wifi_initialized) {
        wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
        ESP_ERROR_CHECK(esp_wifi_init(&cfg));
        ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler, NULL));
        ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &wifi_event_handler, NULL));
        s_wifi_initialized = true;
    }
    return ESP_OK;
}

static void maybe_set_captive_portal_uri(esp_netif_t *netif) {
#ifdef CONFIG_ESP_ENABLE_DHCP_CAPTIVEPORTAL
    if (netif == NULL) {
        return;
    }
    char captive_portal_uri[] = "http://192.168.4.1";
    ESP_ERROR_CHECK_WITHOUT_ABORT(esp_netif_dhcps_stop(netif));
    ESP_ERROR_CHECK_WITHOUT_ABORT(esp_netif_dhcps_option(
        netif,
        ESP_NETIF_OP_SET,
        ESP_NETIF_CAPTIVEPORTAL_URI,
        captive_portal_uri,
        strlen(captive_portal_uri)
    ));
    ESP_ERROR_CHECK_WITHOUT_ABORT(esp_netif_dhcps_start(netif));
#else
    (void)netif;
#endif
}

static esp_err_t register_static_handler(httpd_handle_t server, const char *uri, httpd_method_t method, esp_err_t (*handler)(httpd_req_t *)) {
    const httpd_uri_t descriptor = {
        .uri = uri,
        .method = method,
        .handler = handler,
        .user_ctx = NULL,
    };
    return httpd_register_uri_handler(server, &descriptor);
}

static esp_err_t not_found_redirect_handler(httpd_req_t *request, httpd_err_code_t error) {
    (void)error;
    return redirect_to_root_handler(request);
}

esp_err_t provisioning_manager_init(provisioning_manager_t *manager) {
    if (manager == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    memset(manager, 0, sizeof(*manager));
    return ESP_OK;
}

esp_err_t provisioning_manager_validate_server_url(const char *server_url) {
    if (server_url == NULL || server_url[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }
    const bool has_http = strncmp(server_url, "http://", 7) == 0;
    const bool has_https = strncmp(server_url, "https://", 8) == 0;
    return (has_http || has_https) ? ESP_OK : ESP_ERR_INVALID_ARG;
}

esp_err_t provisioning_manager_set_pending_config(provisioning_manager_t *manager, const neoagent_device_config_t *config) {
    if (manager == NULL || config == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    if (provisioning_manager_validate_server_url(config->server_url) != ESP_OK) {
        return ESP_ERR_INVALID_ARG;
    }
    manager->pending_config = *config;
    manager->has_pending_config = true;
    return ESP_OK;
}

bool provisioning_manager_has_complete_config(const provisioning_manager_t *manager) {
    if (manager == NULL || !manager->has_pending_config) {
        return false;
    }
    return manager->pending_config.wifi_ssid[0] != '\0' && manager->pending_config.server_url[0] != '\0';
}

esp_err_t provisioning_manager_start_portal(provisioning_manager_t *manager, session_store_t *store) {
    if (manager == NULL || store == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    if (manager->portal_running) {
        return ESP_OK;
    }

    ESP_ERROR_CHECK(ensure_network_stack());
    s_active_manager = manager;
    if (manager->ap_netif == NULL) {
        manager->ap_netif = esp_netif_create_default_wifi_ap();
    }

    uint8_t mac[6] = {0};
    ESP_ERROR_CHECK(esp_read_mac(mac, ESP_MAC_WIFI_SOFTAP));
    snprintf(manager->ap_ssid, sizeof(manager->ap_ssid), "NeoAgent Setup %02X%02X", mac[4], mac[5]);
    manager->ap_password[0] = '\0';

    wifi_config_t wifi_config = {0};
    strncpy((char *)wifi_config.ap.ssid, manager->ap_ssid, sizeof(wifi_config.ap.ssid) - 1);
    wifi_config.ap.ssid_len = strlen(manager->ap_ssid);
    wifi_config.ap.channel = 1;
    wifi_config.ap.max_connection = 4;
    wifi_config.ap.authmode = WIFI_AUTH_OPEN;
    wifi_config.ap.pmf_cfg.required = false;

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_AP));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_AP, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());
    maybe_set_captive_portal_uri(manager->ap_netif);

    httpd_config_t server_config = HTTPD_DEFAULT_CONFIG();
    server_config.stack_size = 8192;
    server_config.max_open_sockets = 7;
    server_config.max_uri_handlers = 12;
    server_config.lru_purge_enable = true;
    ESP_ERROR_CHECK(httpd_start(&manager->http_server, &server_config));

    s_portal_context.manager = manager;
    s_portal_context.store = store;

    ESP_ERROR_CHECK(register_static_handler(manager->http_server, "/", HTTP_GET, root_get_handler));
    ESP_ERROR_CHECK(register_static_handler(manager->http_server, "/health", HTTP_GET, health_get_handler));
    ESP_ERROR_CHECK(register_static_handler(manager->http_server, "/configure", HTTP_POST, configure_post_handler));
    ESP_ERROR_CHECK(register_static_handler(manager->http_server, "/generate_204", HTTP_GET, redirect_to_root_handler));
    ESP_ERROR_CHECK(register_static_handler(manager->http_server, "/hotspot-detect.html", HTTP_GET, redirect_to_root_handler));
    ESP_ERROR_CHECK(register_static_handler(manager->http_server, "/library/test/success.html", HTTP_GET, redirect_to_root_handler));
    ESP_ERROR_CHECK(register_static_handler(manager->http_server, "/connecttest.txt", HTTP_GET, redirect_to_root_handler));
    ESP_ERROR_CHECK(register_static_handler(manager->http_server, "/ncsi.txt", HTTP_GET, redirect_to_root_handler));
    ESP_ERROR_CHECK(httpd_register_err_handler(manager->http_server, HTTPD_404_NOT_FOUND, not_found_redirect_handler));

    manager->portal_running = true;
    ESP_LOGI(TAG, "provisioning portal ready ssid=%s password=<open> url=http://192.168.4.1", manager->ap_ssid);
    return ESP_OK;
}

esp_err_t provisioning_manager_connect_station(provisioning_manager_t *manager, const neoagent_device_config_t *config, int timeout_ms) {
    if (manager == NULL || config == NULL || config->wifi_ssid[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }

    ESP_ERROR_CHECK(ensure_network_stack());
    s_active_manager = manager;
    manager->wifi_connected = false;
    if (manager->wifi_events == NULL) {
        manager->wifi_events = xEventGroupCreate();
        if (manager->wifi_events == NULL) {
            return ESP_ERR_NO_MEM;
        }
    }
    xEventGroupClearBits(manager->wifi_events, WIFI_EVENT_STA_CONNECTED_BIT | WIFI_EVENT_STA_FAILED_BIT);

    if (manager->sta_netif == NULL) {
        manager->sta_netif = esp_netif_create_default_wifi_sta();
    }

    wifi_config_t wifi_config = {0};
    strncpy((char *)wifi_config.sta.ssid, config->wifi_ssid, sizeof(wifi_config.sta.ssid) - 1);
    strncpy((char *)wifi_config.sta.password, config->wifi_password, sizeof(wifi_config.sta.password) - 1);
    wifi_config.sta.threshold.authmode = WIFI_AUTH_OPEN;
    wifi_config.sta.pmf_cfg.capable = true;
    wifi_config.sta.pmf_cfg.required = false;

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());
    ESP_ERROR_CHECK(esp_wifi_connect());

    EventBits_t bits = xEventGroupWaitBits(
        manager->wifi_events,
        WIFI_EVENT_STA_CONNECTED_BIT | WIFI_EVENT_STA_FAILED_BIT,
        pdTRUE,
        pdFALSE,
        pdMS_TO_TICKS(timeout_ms > 0 ? timeout_ms : 15000)
    );
    if (bits & WIFI_EVENT_STA_CONNECTED_BIT) {
        ESP_LOGI(TAG, "connected to wifi ssid=%s", config->wifi_ssid);
        return ESP_OK;
    }
    return ESP_ERR_TIMEOUT;
}

const char *provisioning_manager_ap_ssid(const provisioning_manager_t *manager) {
    return manager != NULL ? manager->ap_ssid : NULL;
}

const char *provisioning_manager_ap_password(const provisioning_manager_t *manager) {
    return manager != NULL ? manager->ap_password : NULL;
}

bool provisioning_manager_portal_saved_config(const provisioning_manager_t *manager) {
    return manager != NULL && manager->portal_saved_config;
}
