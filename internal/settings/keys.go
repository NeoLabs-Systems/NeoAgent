package settings

import (
	"regexp"
	"strings"
)

// Settings stored per agent rather than per account.
var agentSettingKeys = setOf(
	"cost_mode", "chat_history_window", "tool_replay_budget_chars", "tool_replay_budget_file_chars",
	"tool_replay_budget_browser_chars", "tool_replay_budget_command_chars",
	"max_consecutive_read_only_iterations", "max_consecutive_tool_failures", "subagent_max_children_per_run",
	"assistant_behavior_notes", "auto_skill_learning", "system_one_model", "neorouter_roles",
	"ai_provider_configs", "default_chat_model", "default_subagent_model", "default_speech_model",
	"task_models", "enabled_models", "voice_stt_provider", "voice_stt_model", "voice_live_provider",
	"voice_live_model", "voice_live_voice", "voice_input_mode", "last_platform", "last_chat_id",
)

// Data-sharing consent is only changed through /api/account/data-sharing.
var serverManagedKeys = setOf("ai_provider_configs", "ai_provider_api_keys", "usage_data_sharing")

var hiddenKeys = setOf("ai_provider_api_keys", "usage_data_sharing")

var retiredKeys = setOf(
	"voice_tts_provider", "voice_tts_model", "voice_tts_voice", "voice_media_mode", "browser_backend",
	"browser_extension_token_id", "selected_browser_extension_token_id", "cli_backend",
	"cli_desktop_device_id", "desktop_backend", "desktop_device_id", "max_iterations",
	"max_model_failure_recoveries", "compaction_threshold", "subagent_max_iterations",
)

var runtimeKeys = []string{"runtime_profile", "runtime_backend", "computer_backend", "android_backend", "mcp_backend"}

var socialReachKey = regexp.MustCompile(`(?i)^social_reach_cookies_`)

func setOf(keys ...string) map[string]bool {
	set := make(map[string]bool, len(keys))
	for _, k := range keys {
		set[k] = true
	}
	return set
}

func isAgentScoped(key string) bool {
	return agentSettingKeys[key] || strings.HasPrefix(key, "platform_whitelist_") || strings.HasPrefix(key, "platform_access_policy_")
}

func isProtectedSecret(key string) bool { return socialReachKey.MatchString(key) }
