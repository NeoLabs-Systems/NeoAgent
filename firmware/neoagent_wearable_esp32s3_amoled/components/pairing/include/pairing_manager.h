#pragma once

#include "esp_err.h"
#include "session_store.h"
#include "neoagent_wearable_types.h"

typedef enum {
    PAIRING_STATE_IDLE = 0,
    PAIRING_STATE_QR_READY = 1,
    PAIRING_STATE_APPROVED = 2,
    PAIRING_STATE_CLAIMED = 3,
    PAIRING_STATE_EXPIRED = 4,
} pairing_flow_state_t;

typedef struct {
    neoagent_pairing_state_t qr_state;
    pairing_flow_state_t state;
} pairing_manager_t;

esp_err_t pairing_manager_init(pairing_manager_t *manager);
esp_err_t pairing_manager_set_challenge(pairing_manager_t *manager, const neoagent_pairing_state_t *challenge);
esp_err_t pairing_manager_create_challenge(pairing_manager_t *manager, const char *server_url, const char *device_label);
esp_err_t pairing_manager_poll_status(pairing_manager_t *manager, const char *server_url);
esp_err_t pairing_manager_claim_session(pairing_manager_t *manager, const char *server_url, neoagent_session_state_t *session, session_store_t *store);
void pairing_manager_mark_approved(pairing_manager_t *manager);
void pairing_manager_mark_claimed(pairing_manager_t *manager);
void pairing_manager_mark_expired(pairing_manager_t *manager);
