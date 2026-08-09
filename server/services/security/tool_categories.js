'use strict';

const TOOL_CATEGORIES = {
  shell: ['execute_command'],
  file_write: ['write_file', 'edit_file'],
  android_privileged: [
    'android_shell',
    'android_install_apk',
    'android_open_intent',
    'android_open_app',
  ],
  desktop_control: [
    'desktop_click',
    'desktop_type',
    'desktop_press_key',
    'desktop_drag',
    'desktop_launch_app',
    'desktop_observe',
  ],
  browser_privileged: ['browser_evaluate'],
  credential_use: ['credential_fill_browser', 'credential_http_request'],
  network_write: ['http_request'],
  skill_mutation: [
    'create_skill',
    'update_skill',
    'delete_skill',
  ],
  external: [],
};

// Tools that bypass all policy checks — read-only or always safe
const SAFE_TOOLS = new Set([
  'think',
  'task_complete',
  'send_interim_update',
  'activate_tools',
  'notify_user',
  'memory_recall',
  'memory_read',
  'memory_save',
  'memory_update_core',
  'session_search',
  'search_memory',
  'read_core_memory',
  'write_core_memory',
  'memory_create',
  'browser_navigate',
  'browser_screenshot',
  'browser_get_text',
  'browser_get_html',
  'browser_find_element',
  'browser_scroll',
  'browser_wait',
  'read_file',
  'list_directory',
  'web_search',
  'web_fetch',
  'search_web',
  'get_weather',
  'get_date_time',
  'send_message',
  'create_task',
  'update_task',
  'get_task',
  'list_tasks',
  'spawn_subagent',
  'delegate_to_agent',
]);

const BUILT_IN_TOOLS = new Set([
  'execute_command',
  'browser_navigate',
  'browser_click',
  'browser_type',
  'browser_extract',
  'browser_screenshot',
  'browser_evaluate',
  'credential_fill_browser',
  'credential_submit_browser',
  'credential_cancel_browser',
  'credential_http_request',
  'desktop_list_devices',
  'desktop_select_device',
  'desktop_observe',
  'desktop_click',
  'desktop_drag',
  'desktop_scroll',
  'desktop_type',
  'desktop_press_key',
  'desktop_launch_app',
  'desktop_get_tree',
  'android_start_emulator',
  'android_stop_emulator',
  'android_list_devices',
  'android_open_app',
  'android_open_intent',
  'android_tap',
  'android_long_press',
  'android_type',
  'android_swipe',
  'android_press_key',
  'android_wait_for',
  'android_observe',
  'android_dump_ui',
  'android_screenshot',
  'android_list_apps',
  'android_install_apk',
  'android_shell',
  'web_search',
  'memory_save',
  'memory_recall',
  'session_search',
  'memory_update_core',
  'memory_write',
  'memory_read',
  'send_message',
  'read_file',
  'read_files',
  'write_file',
  'edit_file',
  'replace_file_range',
  'list_directory',
  'search_files',
  'code_navigate',
  'query_structured_data',
  'http_request',
  'create_skill',
  'list_skills',
  'update_skill',
  'delete_skill',
  'think',
  'activate_tools',
  'spawn_subagent',
  'delegate_to_agent',
  'list_subagents',
  'wait_subagent',
  'cancel_subagent',
  'notify_user',
  'create_task',
  'list_tasks',
  'delete_task',
  'update_task',
  'mcp_add_server',
  'mcp_list_servers',
  'mcp_remove_server',
  'generate_image',
  'generate_table',
  'generate_graph',
  'analyze_image',
  'ocr_extract',
  'read_health_data',
  'social_video_extract',
  'task_complete',
  'send_interim_update',
]);

// category → policy for users with no DB row yet
const DEFAULT_POLICY = {
  shell: 'require_approval',
  file_write: 'require_approval',
  android_privileged: 'require_approval',
  desktop_control: 'require_approval',
  browser_privileged: 'require_approval',
  credential_use: 'require_approval',
  network_write: 'require_approval',
  skill_mutation: 'deny',
  external: 'require_approval',
};

// Reverse map: tool → category, built once
const _toolToCategory = {};
for (const [category, tools] of Object.entries(TOOL_CATEGORIES)) {
  for (const tool of tools) {
    _toolToCategory[tool] = category;
  }
}

/**
 * Returns the category for a tool.
 * - Known built-in tools may return null when they are read-only or otherwise
 *   intentionally left uncategorized.
 * - Unknown tool names are treated as external capabilities and must never
 *   silently bypass policy checks.
 */
function getCategoryForTool(toolName, toolArgs = {}) {
  if (toolName === 'http_request') {
    const method = (toolArgs.method || 'GET').toUpperCase();
    return ['GET', 'HEAD', 'OPTIONS'].includes(method) ? null : 'network_write';
  }
  if (_toolToCategory[toolName]) {
    return _toolToCategory[toolName];
  }
  if (BUILT_IN_TOOLS.has(toolName) || SAFE_TOOLS.has(toolName)) {
    return null;
  }
  return 'external';
}

module.exports = {
  TOOL_CATEGORIES,
  SAFE_TOOLS,
  DEFAULT_POLICY,
  BUILT_IN_TOOLS,
  getCategoryForTool,
};
