#include "provisioning_manager.h"

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "cJSON.h"
#include "esp_crt_bundle.h"
#include "esp_event.h"
#include "esp_http_client.h"
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
#include "lwip/apps/sntp.h"

static const char *TAG = "Provisioning";

#define NEOAGENT_WIFI_SCAN_LIST_LIMIT 20

typedef struct {
    provisioning_manager_t *manager;
    session_store_t *store;
} portal_context_t;

static portal_context_t s_portal_context = {0};
static bool s_netif_initialized = false;
static bool s_event_loop_initialized = false;
static bool s_wifi_initialized = false;
static provisioning_manager_t *s_active_manager = NULL;
static wifi_ap_record_t s_scan_cache[NEOAGENT_WIFI_SCAN_LIST_LIMIT];
static size_t s_scan_cache_count = 0;
static bool s_scan_cache_valid = false;
static bool s_scan_in_progress = false;
static bool s_scan_requested = false;
static esp_err_t s_scan_last_error = ESP_OK;
static TickType_t s_scan_last_finished_ticks = 0;
static SemaphoreHandle_t s_scan_mutex = NULL;
static TaskHandle_t s_scan_task = NULL;
static bool s_sntp_initialized = false;
static char s_captive_portal_uri[48] = "http://192.168.4.1";
static int s_time_offset_seconds = 0;
static bool s_time_offset_configured = false;

#define WIFI_EVENT_STA_CONNECTED_BIT BIT0
#define WIFI_EVENT_STA_FAILED_BIT BIT1

static const char *s_setup_html =
    "<!DOCTYPE html><html lang='en'><head><meta charset='utf-8'>"
    "<meta name='viewport' content='width=device-width,initial-scale=1,viewport-fit=cover'>"
    "<title>NeoAgent wearable setup</title>"
    "<style>"
    ":root{color-scheme:dark;--bg:#0b1017;--bg2:#131c27;--surface:#101923;--surface2:#0c141d;--line:#223243;"
    "--line2:#304356;--text:#edf2f8;--muted:#9aafc4;--accent:#d8b06b;--accent-strong:#b58b45;--danger:#ff9e92;--ok:#83d8c0;}"
    "*{box-sizing:border-box}body{margin:0;min-height:100vh;font:16px/1.45 ui-sans-serif,system-ui,sans-serif;color:var(--text);"
    "background:radial-gradient(circle at top left,rgba(216,176,107,.12),transparent 24%),linear-gradient(180deg,#0b1118 0%,#091018 100%)}"
    ".page{max-width:1120px;margin:0 auto;padding:28px 20px 42px}.frame{display:grid;grid-template-columns:280px minmax(0,1fr);gap:22px}"
    ".nav,.panel{background:rgba(20,27,30,.94);border:1px solid var(--line);border-radius:34px;box-shadow:0 18px 50px rgba(0,0,0,.22)}"
    ".nav{padding:22px 18px 18px}.brand{display:flex;align-items:center;gap:14px;padding:6px 10px 20px;border-bottom:1px solid rgba(255,255,255,.04)}"
    ".brand-mark{width:48px;height:48px;border-radius:16px;background:linear-gradient(180deg,#8fa786,#5f7f6a);display:grid;place-items:center;color:#f6f0e3;font-size:24px}"
    ".brand-name{font-size:18px;font-weight:700}.nav-label{margin:16px 12px 6px;color:#807a72;font-size:12px;font-weight:700;letter-spacing:.14em;text-transform:uppercase}"
    ".nav-item{display:flex;align-items:center;gap:12px;margin:10px 0;padding:16px 18px;border:1px solid rgba(255,255,255,.04);border-radius:22px;background:#101822;color:#d9e2eb}"
    ".nav-item.active{border-color:rgba(215,177,107,.38);box-shadow:inset 0 0 0 1px rgba(215,177,107,.12)}.nav-stick{width:7px;height:34px;border-radius:999px;background:var(--accent)}"
    ".panel{padding:28px}.toolbar{display:flex;justify-content:space-between;align-items:flex-start;gap:16px}.eyebrow{color:var(--accent);font-size:12px;font-weight:800;letter-spacing:.22em;text-transform:uppercase}"
    "h1{margin:8px 0 8px;font-size:58px;line-height:.98;letter-spacing:-.05em}.lede{max-width:760px;color:var(--muted);font-size:18px}"
    ".save-top{display:inline-flex;align-items:center;gap:10px;padding:15px 22px;border-radius:999px;border:0;background:var(--accent);color:#20160a;font-size:16px;font-weight:800;cursor:pointer}"
    ".grid{display:grid;gap:22px;margin-top:26px}.card{padding:24px 26px;border:1px solid var(--line);border-radius:32px;background:linear-gradient(180deg,var(--surface) 0%,var(--surface2) 100%)}"
    ".card-title{font-size:14px;font-weight:800;letter-spacing:.12em;text-transform:uppercase;color:#bfb7a7}.card-copy{margin:12px 0 18px;color:var(--muted);font-size:17px}"
    ".chips{display:flex;flex-wrap:wrap;gap:12px}.chip{padding:12px 16px;border-radius:999px;background:#0f1720;border:1px solid rgba(255,255,255,.04);color:#dbe4ee;font-weight:600}"
    ".chip strong{color:#8bd9d0;font-weight:700}.fields{display:grid;gap:18px}.field{display:grid;gap:9px}.field label{font-size:13px;font-weight:800;letter-spacing:.08em;text-transform:uppercase;color:#879fb5}"
    ".input,.select{width:100%;padding:18px 18px;border-radius:22px;border:1px solid var(--line2);background:#0e151d;color:var(--text);outline:none;font-size:18px}"
    ".input:focus,.select:focus{border-color:rgba(215,177,107,.48);box-shadow:0 0 0 3px rgba(215,177,107,.12)}"
    ".row{display:grid;grid-template-columns:minmax(0,1fr) 160px;gap:14px}.actions{display:flex;flex-wrap:wrap;gap:12px;align-items:center}"
    ".button{display:inline-flex;align-items:center;justify-content:center;gap:10px;border-radius:18px;padding:15px 18px;border:1px solid rgba(215,177,107,.32);background:#121b24;color:var(--text);font-size:15px;font-weight:700;cursor:pointer}"
    ".button.primary{background:var(--accent);color:#20160a;border-color:transparent}.button:disabled{opacity:.7;cursor:wait}"
    ".status{display:none;padding:14px 16px;border-radius:18px;font-size:14px;border:1px solid transparent}.status.ok{display:block;background:rgba(131,216,192,.1);border-color:rgba(131,216,192,.22);color:#d6fff2}"
    ".status.err{display:block;background:rgba(255,158,146,.1);border-color:rgba(255,158,146,.2);color:#ffd9d4}.fine{color:#827d75;font-size:13px}"
    ".footer{margin-top:12px;color:#7c776f;font-size:12px}.hidden{display:none}"
    "@media (max-width:960px){.frame{grid-template-columns:1fr}.nav{display:none}h1{font-size:42px}.row{grid-template-columns:1fr}.page{padding:18px 14px 30px}}"
    "</style></head><body><main class='page'><div class='frame'><aside class='nav'>"
    "<div class='brand'><div class='brand-mark'>◫</div><div><div class='brand-name'>NeoAgent</div><div class='fine'>Wearable setup surface</div></div></div>"
    "<div class='nav-label'>Provisioning</div><div class='nav-item active'><div class='nav-stick'></div><div><div>Wi-Fi and backend</div><div class='fine'>Prepare this device for pairing</div></div></div>"
    "<div class='nav-item'><div class='nav-stick' style='background:#2f3437'></div><div><div>Pairing</div><div class='fine'>QR approval starts after save</div></div></div>"
    "</aside><section class='panel'><div class='toolbar'><div><div class='eyebrow'>Control Surface</div><h1>Setup</h1>"
    "<div class='lede'>Choose a visible or saved Wi-Fi network, point the wearable at your NeoAgent backend, then save once. The watch restarts and moves into QR pairing automatically.</div></div>"
    "<button id='save-top' class='save-top' type='submit' form='setup-form'>▣ Save</button></div>"
    "<div class='grid'><section class='card'><div class='card-title'>Overview</div><div class='card-copy'>Use networks the device can actually see right now. The server URL and session stay stored locally on the wearable.</div>"
    "<div class='chips'><div class='chip'><strong id='chip-ap'>Setup AP</strong></div><div class='chip'><span id='chip-network-count'>Scanning networks…</span></div><div class='chip'><span id='chip-saved-count'>No saved Wi-Fi networks</span></div><div class='chip'><span id='chip-backend'>Backend URL required</span></div></div><div id='saved-networks' class='footer'>Saved Wi-Fi networks stay selectable even when they are not visible right now.</div></section>"
    "<section class='card'><form id='setup-form' class='fields'><div class='field'><label for='server_url'>NeoAgent server URL</label><input class='input' id='server_url' name='server_url' placeholder='https://agent.example.com' autocapitalize='off' spellcheck='false' required></div>"
    "<div class='field'><label for='wifi_ssid'>Visible Wi-Fi network</label><select class='select' id='wifi_ssid' name='wifi_ssid' required><option value=''>Scanning nearby networks…</option></select>"
    "<div class='actions'><button id='refresh-networks' class='button' type='button'>Refresh list</button><span class='fine'>Visible networks are discovered automatically; saved networks remain available if the scan misses them.</span></div></div>"
    "<div class='field'><label for='wifi_password'>Wi-Fi password</label><input class='input' id='wifi_password' name='wifi_password' type='password' autocomplete='current-password'></div>"
    "<div class='row'><div class='field'><label for='device_label'>Device label</label><input class='input' id='device_label' name='device_label' placeholder='NeoAgent Wrist'></div>"
    "<div class='field'><label for='wifi_channel'>Detected channel</label><input class='input' id='wifi_channel' disabled placeholder='Auto'><input type='hidden' id='wifi_channel_value' name='wifi_channel' value='0'><input type='hidden' id='wifi_bssid_value' name='wifi_bssid' value=''></div></div>"
    "<div id='status' class='status'></div><div class='actions'><button id='submit' class='button primary' type='submit'>Save and restart wearable</button></div>"
    "<div class='footer'>After save, the device reboots, joins the selected Wi-Fi, and renders the pairing QR on-watch.</div></form></section></div></section></div></main>"
    "<script>"
    "const form=document.getElementById('setup-form');const status=document.getElementById('status');const submit=document.getElementById('submit');"
    "const saveTop=document.getElementById('save-top');const wifiSelect=document.getElementById('wifi_ssid');const refreshBtn=document.getElementById('refresh-networks');"
    "const channelField=document.getElementById('wifi_channel');const channelValueField=document.getElementById('wifi_channel_value');const bssidValueField=document.getElementById('wifi_bssid_value');const chipAp=document.getElementById('chip-ap');const chipCount=document.getElementById('chip-network-count');const chipSaved=document.getElementById('chip-saved-count');const chipBackend=document.getElementById('chip-backend');const savedNetworks=document.getElementById('saved-networks');"
    "let lastNetworks=[];let lastVisibleNetworks=[];let portalRefreshTimer=null;function setStatus(kind,text){status.className='status '+kind;status.textContent=text||'';}"
    "function setBusy(busy){submit.disabled=busy;saveTop.disabled=busy;refreshBtn.disabled=busy;}"
    "function clearPortalRefresh(){if(portalRefreshTimer){clearTimeout(portalRefreshTimer);portalRefreshTimer=null;}}"
    "function schedulePortalRefresh(delayMs){clearPortalRefresh();portalRefreshTimer=setTimeout(()=>loadPortalState(false),delayMs);}"
    "function renderSavedNetworks(networks){const items=Array.isArray(networks)?networks.filter((network)=>network&&network.ssid):[];chipSaved.textContent=items.length?`${items.length} saved network${items.length===1?'':'s'}`:'No saved Wi-Fi networks';savedNetworks.textContent=items.length?`Saved: ${items.map((network)=>network.ssid).join(', ')}`:'Saved Wi-Fi networks stay selectable even if the scan misses them.';}"
    "function updateSelectedNetworkMeta(){const selected=lastNetworks.find((network)=>network.ssid===wifiSelect.value);channelField.value=selected&&selected.channel?String(selected.channel):'Auto';channelValueField.value=selected&&selected.channel?String(selected.channel):'0';bssidValueField.value=selected&&selected.bssid?selected.bssid:'';}"
    "function populateNetworks(networks,currentSsid,savedNetworks){const visible=Array.isArray(networks)?networks.filter((network)=>network&&network.ssid):[];const saved=Array.isArray(savedNetworks)?savedNetworks.filter((network)=>network&&network.ssid):[];lastVisibleNetworks=visible;const merged=[];const seen=new Set();visible.forEach((network)=>{if(seen.has(network.ssid))return;seen.add(network.ssid);merged.push({...network,source:'visible'});});saved.forEach((network)=>{if(seen.has(network.ssid))return;seen.add(network.ssid);merged.push({...network,source:'saved'});});if(currentSsid&&!seen.has(currentSsid)){merged.push({ssid:currentSsid,source:'saved'});seen.add(currentSsid);}lastNetworks=merged;wifiSelect.innerHTML='';const placeholder=document.createElement('option');placeholder.value='';placeholder.textContent=merged.length?'Select a Wi-Fi network':'No Wi-Fi networks found';wifiSelect.appendChild(placeholder);merged.forEach((network)=>{const option=document.createElement('option');option.value=network.ssid;const suffix=network.channel?` • ch ${network.channel}`:'';const tag=network.source==='saved'?' • saved':'';option.textContent=`${network.ssid}${suffix}${tag}`;wifiSelect.appendChild(option);});if(currentSsid){wifiSelect.value=currentSsid;}chipCount.textContent=visible.length?`${visible.length} visible network${visible.length===1?'':'s'}`:saved.length?`${saved.length} saved network${saved.length===1?'':'s'} available`:'No visible 2.4 GHz networks';updateSelectedNetworkMeta();}"
    "async function loadPortalState(showErrors){try{refreshBtn.disabled=true;const response=await fetch('/portal-state',{cache:'no-store'});const payload=await response.json();if(!response.ok){throw new Error(payload.error||'Failed to load setup state');}"
    "chipAp.textContent=payload.apSsid||'Setup AP';renderSavedNetworks(payload.savedNetworks);const currentSsid=payload.config&&payload.config.wifiSsid?payload.config.wifiSsid:'';const currentNetworks=Array.isArray(payload.networks)?payload.networks:[];const useLastVisible=payload.scanInProgress&&!currentNetworks.length&&lastVisibleNetworks.length>0;if(payload.config){if(payload.config.serverUrl)form.server_url.value=payload.config.serverUrl;if(payload.config.deviceLabel)form.device_label.value=payload.config.deviceLabel;if(payload.config.wifiPassword)form.wifi_password.value=payload.config.wifiPassword;chipBackend.textContent=payload.config.serverUrl||'Backend URL required';populateNetworks(useLastVisible?lastVisibleNetworks:currentNetworks,currentSsid,payload.savedNetworks||[]);}else{populateNetworks(useLastVisible?lastVisibleNetworks:currentNetworks,'',payload.savedNetworks||[]);}if(payload.scanInProgress||(!Array.isArray(payload.networks)||payload.networks.length===0)){chipCount.textContent=payload.scanInProgress?'Scanning networks…':'No visible networks yet';schedulePortalRefresh(payload.scanInProgress?1200:2500);}else{clearPortalRefresh();}}"
    "catch(error){chipCount.textContent='Retrying scan…';if(showErrors)setStatus('err',error.message||'The setup page is still loading. Retrying.');schedulePortalRefresh(3000);}"
    "finally{refreshBtn.disabled=false;}}"
    "wifiSelect.addEventListener('change',updateSelectedNetworkMeta);refreshBtn.addEventListener('click',async()=>{try{refreshBtn.disabled=true;await fetch('/portal-refresh',{method:'POST'});setStatus('','');chipCount.textContent='Scanning networks…';schedulePortalRefresh(1200);}catch(error){schedulePortalRefresh(3000);}await loadPortalState(true);});"
    "window.addEventListener('beforeunload',clearPortalRefresh);"
    "form.addEventListener('submit',async(event)=>{event.preventDefault();setBusy(true);setStatus('','');const fd=new FormData(form);const serverUrl=(fd.get('server_url')||'').trim();const wifiSsid=(fd.get('wifi_ssid')||'').trim();"
    "if(!serverUrl){setStatus('err','Enter a NeoAgent server URL.');setBusy(false);return;}if(!wifiSsid){setStatus('err','Select a Wi-Fi network.');setBusy(false);return;}"
    "try{const response=await fetch('/configure',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded;charset=UTF-8'},body:new URLSearchParams(fd)});const payload=await response.json().catch(()=>({}));if(!response.ok){throw new Error(payload.error||'Setup failed');}"
    "setStatus('ok',payload.message||'Saved. The wearable is restarting now.');}catch(error){setStatus('err',error.message||'Setup failed');setBusy(false);}});"
    "loadPortalState(false);"
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

static void normalize_server_url(neoagent_device_config_t *config) {
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
    }
}

static bool wifi_bssid_is_set(const uint8_t bssid[6]) {
    if (bssid == NULL) {
        return false;
    }
    for (size_t index = 0; index < 6; ++index) {
        if (bssid[index] != 0) {
            return true;
        }
    }
    return false;
}

static void clear_wifi_network(neoagent_wifi_network_t *network) {
    if (network == NULL) {
        return;
    }
    memset(network, 0, sizeof(*network));
}

static void copy_primary_network_to_slot(const neoagent_device_config_t *config, neoagent_wifi_network_t *network) {
    if (config == NULL || network == NULL) {
        return;
    }
    memset(network, 0, sizeof(*network));
    copy_string_bounded(network->ssid, sizeof(network->ssid), config->wifi_ssid);
    copy_string_bounded(network->password, sizeof(network->password), config->wifi_password);
    network->channel = config->wifi_channel;
    memcpy(network->bssid, config->wifi_bssid, sizeof(network->bssid));
}

static void copy_slot_to_primary_network(neoagent_device_config_t *config, const neoagent_wifi_network_t *network) {
    if (config == NULL || network == NULL) {
        return;
    }
    copy_string_bounded(config->wifi_ssid, sizeof(config->wifi_ssid), network->ssid);
    copy_string_bounded(config->wifi_password, sizeof(config->wifi_password), network->password);
    config->wifi_channel = network->channel;
    memcpy(config->wifi_bssid, network->bssid, sizeof(config->wifi_bssid));
}

static void compact_wifi_networks(neoagent_device_config_t *config) {
    if (config == NULL) {
        return;
    }
    size_t write_index = 0;
    for (size_t read_index = 0; read_index < NEOAGENT_WIFI_NETWORK_MAX; ++read_index) {
        if (config->wifi_networks[read_index].ssid[0] == '\0') {
            continue;
        }
        if (write_index != read_index) {
            config->wifi_networks[write_index] = config->wifi_networks[read_index];
            clear_wifi_network(&config->wifi_networks[read_index]);
        }
        write_index += 1;
    }
    for (size_t index = write_index; index < NEOAGENT_WIFI_NETWORK_MAX; ++index) {
        clear_wifi_network(&config->wifi_networks[index]);
    }
    config->wifi_network_count = (uint8_t)write_index;
}

static void ensure_primary_network_present(neoagent_device_config_t *config) {
    if (config == NULL || config->wifi_ssid[0] == '\0') {
        return;
    }
    for (size_t index = 0; index < config->wifi_network_count && index < NEOAGENT_WIFI_NETWORK_MAX; ++index) {
        if (strcmp(config->wifi_networks[index].ssid, config->wifi_ssid) == 0) {
            copy_string_bounded(config->wifi_networks[index].password, sizeof(config->wifi_networks[index].password), config->wifi_password);
            config->wifi_networks[index].channel = config->wifi_channel;
            memcpy(config->wifi_networks[index].bssid, config->wifi_bssid, sizeof(config->wifi_bssid));
            return;
        }
    }

    if (config->wifi_network_count < NEOAGENT_WIFI_NETWORK_MAX) {
        copy_primary_network_to_slot(config, &config->wifi_networks[config->wifi_network_count]);
        config->wifi_network_count += 1;
        return;
    }

    for (size_t index = NEOAGENT_WIFI_NETWORK_MAX - 1; index > 0; --index) {
        config->wifi_networks[index] = config->wifi_networks[index - 1];
    }
    copy_primary_network_to_slot(config, &config->wifi_networks[0]);
    config->wifi_network_count = NEOAGENT_WIFI_NETWORK_MAX;
}

static void sync_primary_network_from_saved(neoagent_device_config_t *config) {
    if (config == NULL) {
        return;
    }
    compact_wifi_networks(config);
    if (config->wifi_ssid[0] != '\0') {
        ensure_primary_network_present(config);
        compact_wifi_networks(config);
        return;
    }
    if (config->wifi_network_count > 0) {
        copy_slot_to_primary_network(config, &config->wifi_networks[0]);
    }
}

static void upsert_saved_wifi_network(neoagent_device_config_t *config) {
    if (config == NULL || config->wifi_ssid[0] == '\0') {
        return;
    }

    size_t match_index = NEOAGENT_WIFI_NETWORK_MAX;
    for (size_t index = 0; index < config->wifi_network_count && index < NEOAGENT_WIFI_NETWORK_MAX; ++index) {
        if (strcmp(config->wifi_networks[index].ssid, config->wifi_ssid) == 0) {
            match_index = index;
            break;
        }
    }

    neoagent_wifi_network_t selected = {0};
    copy_primary_network_to_slot(config, &selected);

    if (match_index == NEOAGENT_WIFI_NETWORK_MAX) {
        if (config->wifi_network_count < NEOAGENT_WIFI_NETWORK_MAX) {
            match_index = config->wifi_network_count;
            config->wifi_network_count += 1;
        } else {
            match_index = NEOAGENT_WIFI_NETWORK_MAX - 1;
        }
    }

    for (size_t index = match_index; index > 0; --index) {
        config->wifi_networks[index] = config->wifi_networks[index - 1];
    }
    config->wifi_networks[0] = selected;
    compact_wifi_networks(config);
    copy_slot_to_primary_network(config, &config->wifi_networks[0]);
}

static esp_err_t apply_form_field(neoagent_device_config_t *config, const char *key, char *value) {
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
    } else if (strcmp(key, "wifi_channel") == 0) {
        long channel = strtol(value, NULL, 10);
        if (channel >= 0 && channel <= 255) {
            config->wifi_channel = (uint8_t)channel;
        }
    } else if (strcmp(key, "wifi_bssid") == 0) {
        unsigned int bssid[6] = {0};
        if (sscanf(value, "%02x:%02x:%02x:%02x:%02x:%02x", &bssid[0], &bssid[1], &bssid[2], &bssid[3], &bssid[4], &bssid[5]) == 6) {
            for (size_t index = 0; index < 6; ++index) {
                config->wifi_bssid[index] = (uint8_t)bssid[index];
            }
        }
    }
    return ESP_OK;
}

static esp_err_t parse_form_body(char *body, neoagent_device_config_t *config) {
    char *pair = strtok(body, "&");
    while (pair != NULL) {
        char *equals = strchr(pair, '=');
        if (equals != NULL) {
            *equals = '\0';
            char *key = pair;
            char *value = equals + 1;
            apply_form_field(config, key, value);
        }
        pair = strtok(NULL, "&");
    }

    normalize_server_url(config);
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

static void append_json_escaped(char *destination, size_t destination_size, const char *value) {
    if (destination == NULL || destination_size == 0 || value == NULL) {
        return;
    }
    for (const char *cursor = value; *cursor != '\0'; ++cursor) {
        const unsigned char byte = (unsigned char)*cursor;
        switch (byte) {
            case '\\':
                append_string_bounded(destination, destination_size, "\\\\");
                break;
            case '"':
                append_string_bounded(destination, destination_size, "\\\"");
                break;
            case '\n':
                append_string_bounded(destination, destination_size, "\\n");
                break;
            case '\r':
                append_string_bounded(destination, destination_size, "\\r");
                break;
            case '\t':
                append_string_bounded(destination, destination_size, "\\t");
                break;
            default: {
                if (byte < 0x20 || byte >= 0x7f) {
                    char escaped[7];
                    snprintf(escaped, sizeof(escaped), "\\u%04x", (unsigned)byte);
                    append_string_bounded(destination, destination_size, escaped);
                } else {
                    char chunk[2] = {(char)byte, '\0'};
                    append_string_bounded(destination, destination_size, chunk);
                }
                break;
            }
        }
    }
}

static void sanitize_json_text(char *destination, size_t destination_size, const char *source) {
    if (destination == NULL || destination_size == 0) {
        return;
    }
    destination[0] = '\0';
    if (source == NULL) {
        return;
    }

    size_t write_index = 0;
    for (size_t read_index = 0; source[read_index] != '\0' && write_index + 1 < destination_size; ++read_index) {
        const unsigned char byte = (unsigned char)source[read_index];
        if (byte >= 0x20 && byte < 0x7f) {
            destination[write_index++] = (char)byte;
        } else {
            destination[write_index++] = '?';
        }
    }
    destination[write_index] = '\0';
}

typedef struct {
    char body[256];
    size_t body_length;
} timezone_http_capture_t;

static void build_http_url(const char *base_url, const char *path, char *output, size_t output_size) {
    if (output == NULL || output_size == 0) {
        return;
    }
    output[0] = '\0';
    if (base_url == NULL || base_url[0] == '\0' || path == NULL) {
        return;
    }
    size_t base_length = strlen(base_url);
    while (base_length > 0 && base_url[base_length - 1] == '/') {
        base_length--;
    }
    if (base_length + strlen(path) + 1 > output_size) {
        return;
    }
    memcpy(output, base_url, base_length);
    output[base_length] = '\0';
    strncat(output, path, output_size - strlen(output) - 1);
}

static esp_err_t timezone_http_event_handler(esp_http_client_event_t *event) {
    timezone_http_capture_t *capture = (timezone_http_capture_t *)event->user_data;
    if (capture == NULL) {
        return ESP_OK;
    }
    if (event->event_id == HTTP_EVENT_ON_DATA && event->data != NULL && event->data_len > 0) {
        size_t writable = sizeof(capture->body) - capture->body_length - 1;
        size_t to_copy = (size_t)event->data_len < writable ? (size_t)event->data_len : writable;
        if (to_copy > 0) {
            memcpy(capture->body + capture->body_length, event->data, to_copy);
            capture->body_length += to_copy;
            capture->body[capture->body_length] = '\0';
        }
    }
    return ESP_OK;
}

static esp_err_t fetch_server_time_offset_seconds(const char *server_url, int *offset_seconds_out) {
    if (server_url == NULL || server_url[0] == '\0' || offset_seconds_out == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    char url[NEOAGENT_SERVER_URL_MAX + 48];
    build_http_url(server_url, "/api/wearable/timezone", url, sizeof(url));
    if (url[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }

    timezone_http_capture_t capture = {0};
    esp_http_client_config_t config = {
        .url = url,
        .method = HTTP_METHOD_GET,
        .timeout_ms = 8000,
        .event_handler = timezone_http_event_handler,
        .user_data = &capture,
        .crt_bundle_attach = esp_crt_bundle_attach,
    };
    esp_http_client_handle_t client = esp_http_client_init(&config);
    if (client == NULL) {
        return ESP_ERR_NO_MEM;
    }

    esp_err_t err = esp_http_client_perform(client);
    if (err != ESP_OK) {
        esp_http_client_cleanup(client);
        return err;
    }

    int status_code = esp_http_client_get_status_code(client);
    esp_http_client_cleanup(client);
    if (status_code < 200 || status_code >= 300) {
        return ESP_FAIL;
    }

    cJSON *root = cJSON_Parse(capture.body);
    if (!cJSON_IsObject(root)) {
        cJSON_Delete(root);
        return ESP_ERR_INVALID_RESPONSE;
    }
    cJSON *offset_item = cJSON_GetObjectItemCaseSensitive(root, "utcOffsetSeconds");
    if (!cJSON_IsNumber(offset_item)) {
        cJSON_Delete(root);
        return ESP_ERR_INVALID_RESPONSE;
    }
    *offset_seconds_out = offset_item->valueint;
    cJSON_Delete(root);
    return ESP_OK;
}

int provisioning_manager_time_offset_seconds(void) {
    return s_time_offset_configured ? s_time_offset_seconds : 0;
}

static esp_err_t fetch_visible_wifi_networks(wifi_ap_record_t *records, size_t max_records, size_t *record_count) {
    if (records == NULL || record_count == NULL || max_records == 0) {
        return ESP_ERR_INVALID_ARG;
    }

    wifi_scan_config_t scan_config = {
        .ssid = NULL,
        .bssid = NULL,
        .channel = 0,
        .show_hidden = false,
        .scan_type = WIFI_SCAN_TYPE_ACTIVE,
    };

    esp_err_t err = esp_wifi_scan_start(&scan_config, true);
    if (err != ESP_OK) {
        return err;
    }

    uint16_t ap_count = 0;
    err = esp_wifi_scan_get_ap_num(&ap_count);
    if (err != ESP_OK) {
        return err;
    }

    uint16_t count = ap_count < max_records ? ap_count : max_records;
    err = esp_wifi_scan_get_ap_records(&count, records);
    if (err != ESP_OK) {
        return err;
    }

    *record_count = count;
    return ESP_OK;
}

static void provisioning_scan_task(void *arg) {
    (void)arg;
    while (true) {
        if (!s_scan_requested || s_portal_context.manager == NULL || !s_portal_context.manager->portal_running) {
            vTaskDelay(pdMS_TO_TICKS(250));
            continue;
        }
        s_scan_requested = false;
        s_scan_in_progress = true;

        wifi_ap_record_t local_records[NEOAGENT_WIFI_SCAN_LIST_LIMIT] = {0};
        size_t local_count = 0;
        esp_err_t err = fetch_visible_wifi_networks(local_records, NEOAGENT_WIFI_SCAN_LIST_LIMIT, &local_count);

        if (s_scan_mutex != NULL && xSemaphoreTake(s_scan_mutex, pdMS_TO_TICKS(1000)) == pdTRUE) {
            s_scan_last_error = err;
            if (err == ESP_OK) {
                memset(s_scan_cache, 0, sizeof(s_scan_cache));
                memcpy(s_scan_cache, local_records, sizeof(wifi_ap_record_t) * local_count);
                s_scan_cache_count = local_count;
                s_scan_cache_valid = true;
                s_scan_last_finished_ticks = xTaskGetTickCount();
                ESP_LOGI(TAG, "portal scan updated count=%u", (unsigned)local_count);
            } else {
                if (!s_scan_cache_valid) {
                    s_scan_cache_count = 0;
                }
                s_scan_last_finished_ticks = xTaskGetTickCount();
                ESP_LOGW(TAG, "portal scan failed: %s", esp_err_to_name(err));
            }
            xSemaphoreGive(s_scan_mutex);
        }

        s_scan_in_progress = false;
    }
}

static void ensure_scan_task_started(void) {
    if (s_scan_mutex == NULL) {
        s_scan_mutex = xSemaphoreCreateMutex();
    }
    if (s_scan_task == NULL) {
        xTaskCreate(provisioning_scan_task, "prov_scan", 6144, NULL, 4, &s_scan_task);
    }
}

static esp_err_t portal_state_get_handler(httpd_req_t *request) {
    if (s_portal_context.manager == NULL || s_portal_context.store == NULL) {
        send_json_response(request, "500 Internal Server Error", "{\"error\":\"portal unavailable\"}");
        return ESP_OK;
    }

    neoagent_device_config_t config = {0};
    session_store_load_device_config(s_portal_context.store, &config);
    sync_primary_network_from_saved(&config);

    wifi_ap_record_t local_records[NEOAGENT_WIFI_SCAN_LIST_LIMIT] = {0};
    size_t local_count = 0;
    bool local_valid = false;
    esp_err_t local_scan_err = s_scan_last_error;
    bool local_scan_in_progress = s_scan_in_progress;
    if (s_scan_mutex != NULL && xSemaphoreTake(s_scan_mutex, pdMS_TO_TICKS(250)) == pdTRUE) {
        local_count = s_scan_cache_count;
        local_valid = s_scan_cache_valid;
        local_scan_err = s_scan_last_error;
        memcpy(local_records, s_scan_cache, sizeof(local_records));
        xSemaphoreGive(s_scan_mutex);
    }

    const TickType_t now_ticks = xTaskGetTickCount();
    const bool scan_stale =
        s_scan_last_finished_ticks == 0 ||
        (now_ticks - s_scan_last_finished_ticks) > pdMS_TO_TICKS(8000);
    if (!local_scan_in_progress && (!local_valid || scan_stale)) {
        s_scan_requested = true;
    }

    cJSON *root = cJSON_CreateObject();
    cJSON *config_json = cJSON_CreateObject();
    cJSON *saved_networks_json = cJSON_CreateArray();
    cJSON *networks_json = cJSON_CreateArray();
    if (root == NULL || config_json == NULL || saved_networks_json == NULL || networks_json == NULL) {
        cJSON_Delete(root);
        cJSON_Delete(config_json);
        cJSON_Delete(saved_networks_json);
        cJSON_Delete(networks_json);
        send_json_response(request, "500 Internal Server Error", "{\"error\":\"out of memory\"}");
        return ESP_OK;
    }

    char safe_text[128];
    sanitize_json_text(safe_text, sizeof(safe_text), s_portal_context.manager->ap_ssid);
    cJSON_AddBoolToObject(root, "ok", true);
    cJSON_AddStringToObject(root, "apSsid", safe_text);

    sanitize_json_text(safe_text, sizeof(safe_text), config.server_url);
    cJSON_AddStringToObject(config_json, "serverUrl", safe_text);
    sanitize_json_text(safe_text, sizeof(safe_text), config.wifi_ssid);
    cJSON_AddStringToObject(config_json, "wifiSsid", safe_text);
    cJSON_AddBoolToObject(config_json, "wifiPasswordSet", config.wifi_password[0] != '\0');
    sanitize_json_text(safe_text, sizeof(safe_text), config.device_label);
    cJSON_AddStringToObject(config_json, "deviceLabel", safe_text);
    cJSON_AddNumberToObject(config_json, "wifiChannel", (double)config.wifi_channel);

    char config_bssid[18];
    snprintf(
        config_bssid,
        sizeof(config_bssid),
        "%02x:%02x:%02x:%02x:%02x:%02x",
        config.wifi_bssid[0],
        config.wifi_bssid[1],
        config.wifi_bssid[2],
        config.wifi_bssid[3],
        config.wifi_bssid[4],
        config.wifi_bssid[5]
    );
    cJSON_AddStringToObject(config_json, "wifiBssid", config_bssid);
    cJSON_AddItemToObject(root, "config", config_json);

    for (size_t index = 0; index < config.wifi_network_count && index < NEOAGENT_WIFI_NETWORK_MAX; ++index) {
        if (config.wifi_networks[index].ssid[0] == '\0') {
            continue;
        }
        cJSON *network_json = cJSON_CreateObject();
        if (network_json == NULL) {
            cJSON_Delete(root);
            send_json_response(request, "500 Internal Server Error", "{\"error\":\"out of memory\"}");
            return ESP_OK;
        }
        sanitize_json_text(safe_text, sizeof(safe_text), config.wifi_networks[index].ssid);
        cJSON_AddStringToObject(network_json, "ssid", safe_text);
        cJSON_AddItemToArray(saved_networks_json, network_json);
    }
    cJSON_AddItemToObject(root, "savedNetworks", saved_networks_json);
    cJSON_AddBoolToObject(root, "scanInProgress", local_scan_in_progress);

    if (local_valid) {
        for (size_t index = 0; index < local_count; ++index) {
            const char *ssid = (const char *)local_records[index].ssid;
            if (ssid == NULL || ssid[0] == '\0') {
                continue;
            }
            cJSON *network_json = cJSON_CreateObject();
            if (network_json == NULL) {
                cJSON_Delete(root);
                send_json_response(request, "500 Internal Server Error", "{\"error\":\"out of memory\"}");
                return ESP_OK;
            }
            sanitize_json_text(safe_text, sizeof(safe_text), ssid);
            cJSON_AddStringToObject(network_json, "ssid", safe_text);
            cJSON_AddNumberToObject(network_json, "channel", (double)local_records[index].primary);
            cJSON_AddNumberToObject(network_json, "rssi", (double)local_records[index].rssi);
            char bssid[18];
            snprintf(
                bssid,
                sizeof(bssid),
                "%02x:%02x:%02x:%02x:%02x:%02x",
                local_records[index].bssid[0],
                local_records[index].bssid[1],
                local_records[index].bssid[2],
                local_records[index].bssid[3],
                local_records[index].bssid[4],
                local_records[index].bssid[5]
            );
            cJSON_AddStringToObject(network_json, "bssid", bssid);
            cJSON_AddItemToArray(networks_json, network_json);
        }
    }
    cJSON_AddItemToObject(root, "networks", networks_json);
    if (!local_valid && local_scan_err != ESP_OK) {
        cJSON_AddStringToObject(root, "scanError", esp_err_to_name(local_scan_err));
    }

    char *json = cJSON_PrintUnformatted(root);
    cJSON_Delete(root);
    if (json == NULL) {
        send_json_response(request, "500 Internal Server Error", "{\"error\":\"out of memory\"}");
        return ESP_OK;
    }
    send_json_response(request, "200 OK", json);
    free(json);
    return ESP_OK;
}

static esp_err_t portal_refresh_post_handler(httpd_req_t *request) {
    (void)request;
    s_scan_requested = true;
    send_json_response(request, "202 Accepted", "{\"ok\":true,\"refreshing\":true}");
    return ESP_OK;
}

static esp_err_t redirect_to_root_handler(httpd_req_t *request) {
    httpd_resp_set_status(request, "303 See Other");
    httpd_resp_set_hdr(request, "Location", s_captive_portal_uri);
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
    session_store_load_device_config(s_portal_context.store, &config);
    sync_primary_network_from_saved(&config);
    parse_form_body(body, &config);
    if (provisioning_manager_validate_server_url(config.server_url) != ESP_OK || config.wifi_ssid[0] == '\0') {
        send_json_response(request, "400 Bad Request", "{\"error\":\"enter a valid server URL and Wi-Fi name\"}");
        return ESP_OK;
    }
    upsert_saved_wifi_network(&config);

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
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        wifi_event_sta_disconnected_t *event = (wifi_event_sta_disconnected_t *)event_data;
        if (s_active_manager != NULL) {
            s_active_manager->wifi_connected = false;
            s_active_manager->last_disconnect_reason = event->reason;
            if (
                s_active_manager->station_connecting &&
                s_active_manager->max_retries > 0 &&
                s_active_manager->retry_count < s_active_manager->max_retries
            ) {
                s_active_manager->retry_count += 1;
                ESP_LOGW(
                    TAG,
                    "station disconnected reason=%d retry=%d/%d",
                    event->reason,
                    s_active_manager->retry_count,
                    s_active_manager->max_retries
                );
                ESP_ERROR_CHECK_WITHOUT_ABORT(esp_wifi_connect());
                return;
            }
            if (s_active_manager->wifi_events != NULL) {
                xEventGroupSetBits(s_active_manager->wifi_events, WIFI_EVENT_STA_FAILED_BIT);
            }
        }
        ESP_LOGW(TAG, "station disconnected reason=%d", event->reason);
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t *event = (ip_event_got_ip_t *)event_data;
        if (s_active_manager != NULL) {
            s_active_manager->wifi_connected = true;
            s_active_manager->station_connecting = false;
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
        ESP_ERROR_CHECK(esp_wifi_set_storage(WIFI_STORAGE_RAM));
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
    esp_netif_ip_info_t ap_ip_info = {0};
    const bool have_ap_ip = esp_netif_get_ip_info(netif, &ap_ip_info) == ESP_OK && ap_ip_info.ip.addr != 0;
    if (have_ap_ip) {
        snprintf(
            s_captive_portal_uri,
            sizeof(s_captive_portal_uri),
            "http://" IPSTR,
            IP2STR(&ap_ip_info.ip)
        );
    } else {
        strncpy(s_captive_portal_uri, "http://192.168.4.1", sizeof(s_captive_portal_uri) - 1);
        s_captive_portal_uri[sizeof(s_captive_portal_uri) - 1] = '\0';
    }
    ESP_ERROR_CHECK_WITHOUT_ABORT(esp_netif_dhcps_stop(netif));
    if (have_ap_ip) {
        esp_netif_dns_info_t ap_dns = {0};
        ap_dns.ip.type = ESP_IPADDR_TYPE_V4;
        ap_dns.ip.u_addr.ip4 = ap_ip_info.ip;
        ESP_ERROR_CHECK_WITHOUT_ABORT(esp_netif_set_dns_info(netif, ESP_NETIF_DNS_MAIN, &ap_dns));
    }
    ESP_ERROR_CHECK_WITHOUT_ABORT(esp_netif_dhcps_option(
        netif,
        ESP_NETIF_OP_SET,
        ESP_NETIF_CAPTIVEPORTAL_URI,
        s_captive_portal_uri,
        strlen(s_captive_portal_uri)
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

static const char *wifi_authmode_name(wifi_auth_mode_t authmode) {
    switch (authmode) {
        case WIFI_AUTH_OPEN:
            return "open";
        case WIFI_AUTH_WEP:
            return "wep";
        case WIFI_AUTH_WPA_PSK:
            return "wpa";
        case WIFI_AUTH_WPA2_PSK:
            return "wpa2";
        case WIFI_AUTH_WPA_WPA2_PSK:
            return "wpa/wpa2";
        case WIFI_AUTH_WPA3_PSK:
            return "wpa3";
        case WIFI_AUTH_WPA2_WPA3_PSK:
            return "wpa2/wpa3";
        case WIFI_AUTH_OWE:
            return "owe";
        default:
            return "other";
    }
}

static bool scan_for_target_ssid(const char *target_ssid, bool directed_scan) {
    wifi_scan_config_t scan_config = {
        .ssid = directed_scan && target_ssid != NULL ? (uint8_t *)target_ssid : NULL,
        .bssid = NULL,
        .channel = 0,
        .show_hidden = true,
        .scan_type = WIFI_SCAN_TYPE_ACTIVE,
    };

    esp_err_t scan_err = esp_wifi_scan_start(&scan_config, true);
    if (scan_err != ESP_OK) {
        ESP_LOGW(TAG, "wifi scan failed before connect: %s", esp_err_to_name(scan_err));
        return false;
    }

    uint16_t ap_count = 0;
    scan_err = esp_wifi_scan_get_ap_num(&ap_count);
    if (scan_err != ESP_OK) {
        ESP_LOGW(TAG, "wifi scan count failed: %s", esp_err_to_name(scan_err));
        return false;
    }

    wifi_ap_record_t records[NEOAGENT_WIFI_SCAN_LIST_LIMIT] = {0};
    uint16_t record_count = ap_count < NEOAGENT_WIFI_SCAN_LIST_LIMIT ? ap_count : NEOAGENT_WIFI_SCAN_LIST_LIMIT;
    scan_err = esp_wifi_scan_get_ap_records(&record_count, records);
    if (scan_err != ESP_OK) {
        ESP_LOGW(TAG, "wifi scan record fetch failed: %s", esp_err_to_name(scan_err));
        return false;
    }

    bool found_target = false;
    ESP_LOGI(TAG, "wifi scan found %u APs mode=%s", (unsigned)ap_count, directed_scan ? "directed" : "broadcast");
    for (uint16_t index = 0; index < record_count; ++index) {
        const wifi_ap_record_t *record = &records[index];
        const char *ssid = (const char *)record->ssid;
        bool target_match = target_ssid != NULL && target_ssid[0] != '\0' && strcmp(ssid, target_ssid) == 0;
        if (target_match) {
            found_target = true;
        }
        ESP_LOGI(
            TAG,
            "wifi scan ap[%u] ssid=%s channel=%u rssi=%d auth=%s%s",
            (unsigned)index,
            ssid[0] != '\0' ? ssid : "<hidden>",
            (unsigned)record->primary,
            record->rssi,
            wifi_authmode_name(record->authmode),
            target_match ? " target" : ""
        );
    }

    if (!found_target && target_ssid != NULL && target_ssid[0] != '\0') {
        ESP_LOGW(TAG, "target ssid %s not visible in %s scan", target_ssid, directed_scan ? "directed" : "broadcast");
    }
    return found_target;
}

static void enable_extended_2g_channels(void) {
    wifi_country_t current = {0};
    esp_err_t get_err = esp_wifi_get_country(&current);
    if (get_err != ESP_OK) {
        ESP_LOGW(TAG, "could not read Wi-Fi country settings, leaving policy unchanged: %s", esp_err_to_name(get_err));
        return;
    }
    if (current.schan <= 1 && current.nchan >= 13) {
        ESP_LOGI(
            TAG,
            "Wi-Fi country already supports channels 1-13 cc=%c%c policy=%d",
            current.cc[0],
            current.cc[1],
            (int)current.policy
        );
        return;
    }
    ESP_LOGI(
        TAG,
        "Wi-Fi country limits provisioning scan to schan=%u nchan=%u cc=%c%c policy=%d; keeping regional defaults",
        (unsigned)current.schan,
        (unsigned)current.nchan,
        current.cc[0],
        current.cc[1],
        (int)current.policy
    );
    if (current.policy != WIFI_COUNTRY_POLICY_AUTO) {
        current.policy = WIFI_COUNTRY_POLICY_AUTO;
        esp_err_t set_err = esp_wifi_set_country(&current);
        if (set_err != ESP_OK) {
            ESP_LOGW(TAG, "failed to switch Wi-Fi country policy to AUTO: %s", esp_err_to_name(set_err));
        } else {
            ESP_LOGI(TAG, "using Wi-Fi country policy AUTO for provisioning scans");
        }
    }
}

static EventBits_t wait_for_station_result(provisioning_manager_t *manager, int timeout_ms) {
    return xEventGroupWaitBits(
        manager->wifi_events,
        WIFI_EVENT_STA_CONNECTED_BIT | WIFI_EVENT_STA_FAILED_BIT,
        pdTRUE,
        pdFALSE,
        pdMS_TO_TICKS(timeout_ms > 0 ? timeout_ms : 15000)
    );
}

static esp_err_t attempt_channel_connect(
    provisioning_manager_t *manager,
    const neoagent_device_config_t *config,
    wifi_config_t *wifi_config,
    uint8_t channel,
    int timeout_ms
) {
    manager->wifi_connected = false;
    manager->station_connecting = true;
    manager->retry_count = 0;
    manager->max_retries = 0;
    manager->last_disconnect_reason = 0;
    xEventGroupClearBits(manager->wifi_events, WIFI_EVENT_STA_CONNECTED_BIT | WIFI_EVENT_STA_FAILED_BIT);

    wifi_config->sta.channel = channel;
    ESP_ERROR_CHECK_WITHOUT_ABORT(esp_wifi_disconnect());
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, wifi_config));
    ESP_LOGI(TAG, "attempting station connect ssid=%s channel_hint=%u", config->wifi_ssid, (unsigned)channel);
    ESP_ERROR_CHECK_WITHOUT_ABORT(esp_wifi_connect());

    EventBits_t bits = wait_for_station_result(manager, timeout_ms);
    if (bits & WIFI_EVENT_STA_CONNECTED_BIT) {
        ESP_LOGI(TAG, "connected to wifi ssid=%s channel_hint=%u", config->wifi_ssid, (unsigned)channel);
        return ESP_OK;
    }

    manager->station_connecting = false;
    ESP_LOGW(
        TAG,
        "channel connect failed ssid=%s channel_hint=%u last_reason=%d",
        config->wifi_ssid,
        (unsigned)channel,
        manager->last_disconnect_reason
    );
    return ESP_ERR_TIMEOUT;
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
    sync_primary_network_from_saved(&manager->pending_config);
    manager->has_pending_config = true;
    return ESP_OK;
}

bool provisioning_manager_has_complete_config(const provisioning_manager_t *manager) {
    if (manager == NULL || !manager->has_pending_config) {
        return false;
    }
    return manager->pending_config.wifi_ssid[0] != '\0' &&
           manager->pending_config.server_url[0] != '\0';
}

static void fill_wifi_config_for_network(
    wifi_config_t *wifi_config,
    const char *ssid,
    const char *password,
    uint8_t channel,
    const uint8_t bssid[6]
) {
    if (wifi_config == NULL) {
        return;
    }
    memset(wifi_config, 0, sizeof(*wifi_config));
    if (ssid != NULL) {
        strncpy((char *)wifi_config->sta.ssid, ssid, sizeof(wifi_config->sta.ssid) - 1);
    }
    if (password != NULL) {
        strncpy((char *)wifi_config->sta.password, password, sizeof(wifi_config->sta.password) - 1);
    }
    wifi_config->sta.channel = channel;
    wifi_config->sta.bssid_set = wifi_bssid_is_set(bssid);
    if (wifi_config->sta.bssid_set) {
        memcpy(wifi_config->sta.bssid, bssid, 6);
    }
    wifi_config->sta.scan_method = WIFI_ALL_CHANNEL_SCAN;
    wifi_config->sta.sort_method = WIFI_CONNECT_AP_BY_SIGNAL;
    wifi_config->sta.failure_retry_cnt = 1;
    wifi_config->sta.threshold.authmode = (password != NULL && password[0] != '\0') ? WIFI_AUTH_WPA2_PSK : WIFI_AUTH_OPEN;
    wifi_config->sta.pmf_cfg.capable = true;
    wifi_config->sta.pmf_cfg.required = false;
    wifi_config->sta.sae_pwe_h2e = WPA3_SAE_PWE_BOTH;
}

static esp_err_t connect_with_network_candidate(
    provisioning_manager_t *manager,
    const char *ssid,
    const char *password,
    uint8_t saved_channel,
    const uint8_t bssid[6],
    int timeout_ms
) {
    if (manager == NULL || ssid == NULL || ssid[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }

    wifi_config_t wifi_config = {0};
    fill_wifi_config_for_network(&wifi_config, ssid, password, saved_channel, bssid);
    ESP_LOGI(
        TAG,
        "connecting to ssid=%s password_len=%u auth_threshold=%s saved_channel=%u bssid_set=%d",
        ssid,
        (unsigned)(password != NULL ? strlen(password) : 0),
        wifi_authmode_name(wifi_config.sta.threshold.authmode),
        (unsigned)saved_channel,
        wifi_config.sta.bssid_set
    );

    bool found_target = scan_for_target_ssid(ssid, false);
    if (!found_target) {
        found_target = scan_for_target_ssid(ssid, true);
    }
    if (!found_target) {
        enable_extended_2g_channels();
        found_target = scan_for_target_ssid(ssid, false);
    }
    if (saved_channel > 0) {
        neoagent_device_config_t temp = {0};
        copy_string_bounded(temp.wifi_ssid, sizeof(temp.wifi_ssid), ssid);
        temp.wifi_channel = saved_channel;
        if (bssid != NULL) {
            memcpy(temp.wifi_bssid, bssid, sizeof(temp.wifi_bssid));
        }
        if (attempt_channel_connect(manager, &temp, &wifi_config, saved_channel, timeout_ms) == ESP_OK) {
            return ESP_OK;
        }
    }
    if (found_target) {
        neoagent_device_config_t temp = {0};
        copy_string_bounded(temp.wifi_ssid, sizeof(temp.wifi_ssid), ssid);
        if (bssid != NULL) {
            memcpy(temp.wifi_bssid, bssid, sizeof(temp.wifi_bssid));
        }
        if (attempt_channel_connect(manager, &temp, &wifi_config, 0, timeout_ms) == ESP_OK) {
            return ESP_OK;
        }
    }

    return ESP_ERR_TIMEOUT;
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
    manager->station_connecting = false;
    manager->wifi_connected = false;
    manager->retry_count = 0;
    manager->max_retries = 0;
    manager->last_disconnect_reason = 0;
    if (manager->ap_netif == NULL) {
        manager->ap_netif = esp_netif_create_default_wifi_ap();
    }
    if (manager->sta_netif == NULL) {
        manager->sta_netif = esp_netif_create_default_wifi_sta();
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

    ESP_ERROR_CHECK_WITHOUT_ABORT(esp_wifi_disconnect());
    ESP_ERROR_CHECK_WITHOUT_ABORT(esp_wifi_stop());
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_APSTA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_AP, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());
    ESP_ERROR_CHECK(esp_wifi_set_ps(WIFI_PS_NONE));
    enable_extended_2g_channels();
    maybe_set_captive_portal_uri(manager->ap_netif);

    httpd_config_t server_config = HTTPD_DEFAULT_CONFIG();
    server_config.stack_size = 8192;
    server_config.max_open_sockets = 7;
    server_config.max_uri_handlers = 16;
    server_config.lru_purge_enable = true;
    ESP_ERROR_CHECK(httpd_start(&manager->http_server, &server_config));

    s_portal_context.manager = manager;
    s_portal_context.store = store;

    ESP_ERROR_CHECK(register_static_handler(manager->http_server, "/", HTTP_GET, root_get_handler));
    ESP_ERROR_CHECK(register_static_handler(manager->http_server, "/health", HTTP_GET, health_get_handler));
    ESP_ERROR_CHECK(register_static_handler(manager->http_server, "/portal-state", HTTP_GET, portal_state_get_handler));
    ESP_ERROR_CHECK(register_static_handler(manager->http_server, "/portal-refresh", HTTP_POST, portal_refresh_post_handler));
    ESP_ERROR_CHECK(register_static_handler(manager->http_server, "/configure", HTTP_POST, configure_post_handler));
    ESP_ERROR_CHECK(register_static_handler(manager->http_server, "/generate_204", HTTP_GET, redirect_to_root_handler));
    ESP_ERROR_CHECK(register_static_handler(manager->http_server, "/hotspot-detect.html", HTTP_GET, redirect_to_root_handler));
    ESP_ERROR_CHECK(register_static_handler(manager->http_server, "/library/test/success.html", HTTP_GET, redirect_to_root_handler));
    ESP_ERROR_CHECK(register_static_handler(manager->http_server, "/success.txt", HTTP_GET, redirect_to_root_handler));
    ESP_ERROR_CHECK(register_static_handler(manager->http_server, "/fwlink", HTTP_GET, redirect_to_root_handler));
    ESP_ERROR_CHECK(register_static_handler(manager->http_server, "/redirect", HTTP_GET, redirect_to_root_handler));
    ESP_ERROR_CHECK(register_static_handler(manager->http_server, "/connecttest.txt", HTTP_GET, redirect_to_root_handler));
    ESP_ERROR_CHECK(register_static_handler(manager->http_server, "/ncsi.txt", HTTP_GET, redirect_to_root_handler));
    ESP_ERROR_CHECK(httpd_register_err_handler(manager->http_server, HTTPD_404_NOT_FOUND, not_found_redirect_handler));

    manager->portal_running = true;
    ensure_scan_task_started();
    s_scan_requested = true;
    ESP_LOGI(TAG, "provisioning portal ready ssid=%s password=<open> url=http://192.168.4.1", manager->ap_ssid);
    return ESP_OK;
}

esp_err_t provisioning_manager_connect_station(provisioning_manager_t *manager, const neoagent_device_config_t *config, int timeout_ms) {
    if (manager == NULL || config == NULL || config->wifi_ssid[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }
    neoagent_device_config_t resolved_config = *config;
    sync_primary_network_from_saved(&resolved_config);

    ESP_ERROR_CHECK(ensure_network_stack());
    s_active_manager = manager;
    manager->wifi_connected = false;
    manager->station_connecting = true;
    manager->retry_count = 0;
    manager->max_retries = 4;
    manager->last_disconnect_reason = 0;
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

    ESP_ERROR_CHECK_WITHOUT_ABORT(esp_wifi_disconnect());
    ESP_ERROR_CHECK_WITHOUT_ABORT(esp_wifi_stop());
    ESP_ERROR_CHECK(esp_wifi_restore());
    ESP_ERROR_CHECK(esp_wifi_set_storage(WIFI_STORAGE_RAM));
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_start());
    ESP_ERROR_CHECK(esp_wifi_set_ps(WIFI_PS_NONE));

    if (connect_with_network_candidate(
            manager,
            resolved_config.wifi_ssid,
            resolved_config.wifi_password,
            resolved_config.wifi_channel,
            resolved_config.wifi_bssid,
            timeout_ms
        ) == ESP_OK) {
        return ESP_OK;
    }

    for (size_t index = 0; index < resolved_config.wifi_network_count && index < NEOAGENT_WIFI_NETWORK_MAX; ++index) {
        const neoagent_wifi_network_t *network = &resolved_config.wifi_networks[index];
        if (network->ssid[0] == '\0' || strcmp(network->ssid, resolved_config.wifi_ssid) == 0) {
            continue;
        }
        if (connect_with_network_candidate(
                manager,
                network->ssid,
                network->password,
                network->channel,
                network->bssid,
                timeout_ms
            ) == ESP_OK) {
            return ESP_OK;
        }
    }

    manager->station_connecting = false;
    ESP_LOGW(TAG, "station connect timed out last_reason=%d", manager->last_disconnect_reason);
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

esp_err_t provisioning_manager_sync_time(provisioning_manager_t *manager, const char *server_url, int timeout_ms) {
    if (manager == NULL || !manager->wifi_connected) {
        return ESP_ERR_INVALID_STATE;
    }

    if (!s_sntp_initialized) {
        sntp_setoperatingmode(SNTP_OPMODE_POLL);
        sntp_setservername(0, "pool.ntp.org");
        sntp_setservername(1, "time.google.com");
        sntp_init();
        s_sntp_initialized = true;
    }

    const int attempts = timeout_ms > 0 ? (timeout_ms / 250) : 0;
    for (int index = 0; index < attempts; ++index) {
        time_t now = time(NULL);
        if (now > 1700000000) {
            int offset_seconds = 0;
            if (server_url != NULL && server_url[0] != '\0' && fetch_server_time_offset_seconds(server_url, &offset_seconds) == ESP_OK) {
                s_time_offset_seconds = offset_seconds;
                s_time_offset_configured = true;
                ESP_LOGI(TAG, "time offset configured seconds=%d", offset_seconds);
            } else {
                s_time_offset_seconds = 0;
                s_time_offset_configured = false;
            }
            return ESP_OK;
        }
        vTaskDelay(pdMS_TO_TICKS(250));
    }
    return ESP_ERR_TIMEOUT;
}
