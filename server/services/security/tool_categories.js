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
  network_write: ['http_request'],
  skill_mutation: [
    'create_skill',
    'update_skill',
    'delete_skill',
    'create_ai_widget',
    'update_ai_widget',
    'delete_ai_widget',
  ],
};

// Tools that bypass all policy checks — read-only or always safe
const SAFE_TOOLS = new Set([
  'think',
  'task_complete',
  'send_interim_update',
  'activate_tools',
  'notify_user',
  'save_widget_snapshot',
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
  'recordings_list',
  'recordings_get',
]);

// category → policy for users with no DB row yet
const DEFAULT_POLICY = {
  shell: 'require_approval',
  file_write: 'require_approval',
  android_privileged: 'require_approval',
  desktop_control: 'require_approval',
  browser_privileged: 'require_approval',
  network_write: 'require_approval',
  skill_mutation: 'deny',
};

// Reverse map: tool → category, built once
const _toolToCategory = {};
for (const [category, tools] of Object.entries(TOOL_CATEGORIES)) {
  for (const tool of tools) {
    _toolToCategory[tool] = category;
  }
}

/**
 * Returns the category for a tool, or null if the tool is uncategorised (safe).
 * For http_request, write methods map to network_write; read methods return null.
 */
function getCategoryForTool(toolName, toolArgs = {}) {
  if (toolName === 'http_request') {
    const method = (toolArgs.method || 'GET').toUpperCase();
    return ['GET', 'HEAD', 'OPTIONS'].includes(method) ? null : 'network_write';
  }
  return _toolToCategory[toolName] ?? null;
}

module.exports = { TOOL_CATEGORIES, SAFE_TOOLS, DEFAULT_POLICY, getCategoryForTool };
