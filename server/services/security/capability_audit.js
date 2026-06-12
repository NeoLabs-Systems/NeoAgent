'use strict';

const path = require('path');
const db = require('../../db/database');
const { AGENT_DATA_DIR } = require('../../../runtime/paths');

const SKILLS_ROOT = path.resolve(AGENT_DATA_DIR, 'skills');
const SECRET_KEY = /(^|_)(secret|token|password|api_key|private_key)($|_)/i;
const SHELL_METACHAR_RE = /[;&|`$\n\r(){}\\<>]/;

function walkObject(value, visitor, currentPath = '') {
  if (!value || typeof value !== 'object') return;
  for (const [key, child] of Object.entries(value)) {
    const nextPath = currentPath ? `${currentPath}.${key}` : key;
    visitor(key, child, nextPath);
    walkObject(child, visitor, nextPath);
  }
}

class CapabilityAuditService {
  constructor(options = {}) {
    this.mcpClient = options.mcpClient;
    this.skillRunner = options.skillRunner;
  }

  auditMcp(userId, options = {}) {
    const rows = db.prepare(
      'SELECT id, name, command, config, enabled FROM mcp_servers WHERE user_id = ?'
    ).all(userId);
    return rows.map((row) => {
      const findings = [];
      let config = {};
      try { config = JSON.parse(row.config || '{}'); } catch {
        findings.push({ severity: 'high', code: 'invalid_config_json', message: 'Configuration is not valid JSON.' });
      }
      walkObject(config, (key, value, fieldPath) => {
        if (SECRET_KEY.test(key) && typeof value === 'string' && value && !value.startsWith('enc:v1:')) {
          findings.push({
            severity: 'high',
            code: 'plaintext_secret',
            message: `Sensitive field ${fieldPath} is stored without application encryption.`,
          });
        }
      });
      try {
        const endpoint = new URL(row.command);
        if (!['https:', 'http:'].includes(endpoint.protocol)) {
          findings.push({ severity: 'high', code: 'unsupported_transport', message: 'MCP endpoint uses an unsupported protocol.' });
        }
      } catch {
        findings.push({ severity: 'high', code: 'invalid_endpoint', message: 'MCP endpoint is not a valid URL.' });
      }
      const tools = this.mcpClient?.getAllTools?.(userId, options) || [];
      for (const tool of tools.filter((item) => Number(item.serverId) === Number(row.id))) {
        if (!tool.name || !tool.inputSchema || tool.inputSchema.type !== 'object') {
          findings.push({
            severity: 'medium',
            code: 'invalid_tool_schema',
            message: `Tool ${tool.name || 'unknown'} does not expose a valid object input schema.`,
          });
        }
      }
      return {
        id: row.id,
        name: row.name,
        enabled: Boolean(row.enabled),
        findingCount: findings.length,
        findings,
      };
    });
  }

  auditSkills() {
    return Array.from(this.skillRunner?.skills?.values?.() || []).map((skill) => {
      const findings = [];
      const resolvedPath = path.resolve(skill.filePath);
      const relative = path.relative(SKILLS_ROOT, resolvedPath);
      if (relative.startsWith('..') || path.isAbsolute(relative)) {
        findings.push({ severity: 'high', code: 'path_escape', message: 'Skill file is outside the managed skills directory.' });
      }
      const command = String(skill.metadata?.command || '');
      if (command) {
        const bare = command.replace(/\{[^{}]*\}/g, '');
        if (SHELL_METACHAR_RE.test(bare)) {
          findings.push({ severity: 'high', code: 'unsafe_command_template', message: 'Command template contains unsafe shell metacharacters.' });
        }
      }
      const dependencies = Array.isArray(skill.metadata?.dependencies) ? skill.metadata.dependencies : [];
      for (const dependency of dependencies) {
        if (typeof dependency !== 'string' || !/^(?:@[\w.-]+\/)?[\w.-]+(?:@[\w.*^~<>=|-]+)?$/.test(dependency)) {
          findings.push({ severity: 'medium', code: 'untrusted_dependency', message: 'Dependency metadata contains an unsupported package reference.' });
        }
      }
      return {
        name: skill.name,
        enabled: skill.metadata?.enabled !== false,
        autoCreated: skill.metadata?.auto_created === true,
        findingCount: findings.length,
        findings,
      };
    });
  }
}

module.exports = {
  CapabilityAuditService,
};
