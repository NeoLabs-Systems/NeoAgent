const { v4: uuidv4 } = require('uuid');
const fs = require('fs');
const os = require('os');
const path = require('path');
const db = require('../../db/database');
const { GrokProvider } = require('./providers/grok');
const { detectPromptInjection } = require('../../utils/security');

const MODEL = 'grok-4-1-fast-reasoning';

/**
 * Turn a raw task/trigger string into a short, readable run title.
 * Strips messaging-trigger boilerplate so the history panel shows
 * the actual content instead of "You have received a message from: …"
 */
function generateTitle(task) {
  if (!task || typeof task !== 'string') return 'Untitled';
  // WhatsApp/messaging pattern: "You have received a message from <sender>: <actual text>"
  const msgMatch = task.match(/received a (?:message|media|image|video|file|audio)[^:]*:\s*(.+)/is);
  if (msgMatch) {
    const body = msgMatch[1].replace(/\n[\s\S]*/s, '').trim(); // first line only
    return body.slice(0, 90) || 'Incoming message';
  }
  // Scheduler / sub-agent trigger may start with a [tag]
  const cleaned = task.replace(/^\[.*?\]\s*/i, '').replace(/^(system|task|prompt)[:\s]+/i, '').trim();
  return cleaned.slice(0, 90);
}

/**
 * Returns a human-readable label for a millisecond gap, or null if < 5 min.
 * Injected as system messages between conversation turns so the model stays
 * aware of how much real time has elapsed.
 */
function timeDeltaLabel(ms) {
  const s = Math.round(ms / 1000);
  if (s < 300) return null; // < 5 min — not noteworthy
  if (s < 3600) return `${Math.round(s / 60)} minutes later`;
  if (s < 86400) return `${Math.round(s / 3600)} hour${Math.round(s / 3600) === 1 ? '' : 's'} later`;
  if (s < 604800) return `${Math.round(s / 86400)} day${Math.round(s / 86400) === 1 ? '' : 's'} later`;
  return `${Math.round(s / 604800)} week${Math.round(s / 604800) === 1 ? '' : 's'} later`;
}

function getProviderForUser(userId, task = '', isSubagent = false, modelOverride = null) {
  const { SUPPORTED_MODELS, createProviderInstance } = require('./models');
  const db = require('../../db/database');

  let enabledIds = [];
  let defaultChatModel = 'auto';
  let defaultSubagentModel = 'auto';

  try {
    const rows = db.prepare('SELECT key, value FROM user_settings WHERE user_id = ? AND key IN (?, ?, ?)')
      .all(userId, 'enabled_models', 'default_chat_model', 'default_subagent_model');

    for (const row of rows) {
      if (!row.value) continue;

      let parsedVal = row.value;
      try {
        parsedVal = JSON.parse(row.value);
      } catch (e) {
        // Expected for older plain-string values, keep parsedVal as the original string
      }

      if (row.key === 'enabled_models') {
        enabledIds = parsedVal;
      } else if (row.key === 'default_chat_model') {
        defaultChatModel = parsedVal;
      } else if (row.key === 'default_subagent_model') {
        defaultSubagentModel = parsedVal;
      }
    }
  } catch (e) {
    console.error("Failed to fetch settings from DB. Using default supported models. Error:", e);
  }

  // Fallback if settings empty or incorrectly parsed: Use all supported models
  if (!Array.isArray(enabledIds) || enabledIds.length === 0) {
    enabledIds = SUPPORTED_MODELS.map(m => m.id);
  }

  // Filter to secure models registry definition
  const availableModels = SUPPORTED_MODELS.filter(m => enabledIds.includes(m.id));

  // Absolute fallback in case they disabled everything/corrupted data
  const fallbackModel = availableModels.length > 0 ? availableModels[0] : SUPPORTED_MODELS[0];
  let selectedModelDef = fallbackModel;

  const userSelectedDefault = isSubagent ? defaultSubagentModel : defaultChatModel;

  if (modelOverride && typeof modelOverride === 'string') {
    const requestedModel = SUPPORTED_MODELS.find(m => m.id === modelOverride.trim());
    if (requestedModel && enabledIds.includes(requestedModel.id)) {
      selectedModelDef = requestedModel;
      return {
        provider: createProviderInstance(selectedModelDef.provider),
        model: selectedModelDef.id,
        providerName: selectedModelDef.provider
      };
    }
  }

  if (userSelectedDefault && userSelectedDefault !== 'auto') {
    selectedModelDef = SUPPORTED_MODELS.find(m => m.id === userSelectedDefault) || fallbackModel;
  } else {
    const taskStr = String(task || '').toLowerCase();
    const isPlanning = taskStr.includes('plan') || taskStr.includes('think') || taskStr.includes('analyze') || taskStr.includes('complex') || taskStr.includes('step by step');

    // Intelligent matching
    if (isPlanning) {
      selectedModelDef = availableModels.find(m => m.purpose === 'planning') || fallbackModel;
    } else if (isSubagent) {
      selectedModelDef = availableModels.find(m => m.purpose === 'fast') || fallbackModel;
    } else {
      selectedModelDef = availableModels.find(m => m.purpose === 'general') || fallbackModel;
    }
  }

  return {
    provider: createProviderInstance(selectedModelDef.provider),
    model: selectedModelDef.id,
    providerName: selectedModelDef.provider
  };
}

class AgentEngine {
  constructor(io, services = {}) {
    this.io = io;
    this.maxIterations = 75;
    this.activeRuns = new Map();
    this.browserController = services.browserController || null;
    this.messagingManager = services.messagingManager || null;
    this.mcpManager = services.mcpManager || services.mcpClient || null;
    this.skillRunner = services.skillRunner || null;
    this.scheduler = services.scheduler || null;
  }

  async buildSystemPrompt(userId, context = {}) {
    const { buildSystemPrompt } = require('./systemPrompt');
    const { MemoryManager } = require('../memory/manager');
    const memoryManager = new MemoryManager();
    return await buildSystemPrompt(userId, context, memoryManager);
  }

  getAvailableTools(app) {
    const { getAvailableTools } = require('./tools');
    return getAvailableTools(app);
  }

  async executeTool(toolName, args, context) {
    const { executeTool } = require('./tools');
    return await executeTool(toolName, args, context, this);
  }


  async run(userId, userMessage, options = {}) {
    return this.runWithModel(userId, userMessage, options, null);
  }

  async runWithModel(userId, userMessage, options = {}, _modelOverride = null) {
    const triggerType = options.triggerType || 'user';
    const { provider, model } = getProviderForUser(userId, userMessage, triggerType === 'subagent', _modelOverride);

    const runId = options.runId || uuidv4();
    const conversationId = options.conversationId;
    const app = options.app;
    const triggerSource = options.triggerSource || 'web';

    const runTitle = generateTitle(userMessage);
    db.prepare(`INSERT OR REPLACE INTO agent_runs(id, user_id, title, status, trigger_type, trigger_source, model)
    VALUES(?, ?, ?, 'running', ?, ?, ?)`).run(runId, userId, runTitle, triggerType, triggerSource, model);

    this.activeRuns.set(runId, { userId, status: 'running', messagingSent: false, lastToolName: null, lastToolTarget: null });
    this.emit(userId, 'run:start', { runId, title: runTitle, model, triggerType, triggerSource });

    const systemPrompt = await this.buildSystemPrompt(userId, { ...(options.context || {}), userMessage });
    const tools = this.getAvailableTools(app);

    const mcpManager = app?.locals?.mcpManager || app?.locals?.mcpClient || this.mcpManager;
    if (mcpManager) {
      const mcpTools = mcpManager.getAllTools(userId);
      tools.push(...mcpTools);
    }

    // Build recalled-memory context message to inject just before the current user turn.
    // Uses raw message content (not the full prompt wrapper) as the recall query.
    const { MemoryManager } = require('../memory/manager');
    const _mm = new MemoryManager();
    const recallQuery = options.context?.rawUserMessage || userMessage;
    const recallMsg = await _mm.buildRecallMessage(userId, recallQuery);

    let messages = [];

    if (conversationId) {
      const existingMessages = db.prepare(
        'SELECT role, content, tool_calls, tool_call_id, name, created_at FROM conversation_messages WHERE conversation_id = ? AND is_compacted = 0 ORDER BY created_at'
      ).all(conversationId);

      messages = [{ role: 'system', content: systemPrompt }];
      let lastMsgTs = null;
      for (const msg of existingMessages) {
        // Inject a time-gap marker when significant time passed before a user turn
        if (msg.created_at && msg.role === 'user') {
          const msgTs = new Date(msg.created_at).getTime();
          if (lastMsgTs !== null) {
            const label = timeDeltaLabel(msgTs - lastMsgTs);
            if (label) {
              messages.push({ role: 'system', content: `[${label} — now ${new Date(msgTs).toLocaleString('en-GB', { dateStyle: 'medium', timeStyle: 'short' })}]` });
            }
          }
        }
        const m = { role: msg.role, content: msg.content };
        if (msg.tool_calls) m.tool_calls = JSON.parse(msg.tool_calls);
        if (msg.tool_call_id) m.tool_call_id = msg.tool_call_id;
        if (msg.name) m.name = msg.name;
        messages.push(m);
        if (msg.created_at) lastMsgTs = new Date(msg.created_at).getTime();
      }

      // Annotate the incoming message if the conversation has been idle
      const nowTs = Date.now();
      if (lastMsgTs !== null) {
        const label = timeDeltaLabel(nowTs - lastMsgTs);
        if (label) {
          messages.push({ role: 'system', content: `[${label} — now ${new Date(nowTs).toLocaleString('en-GB', { dateStyle: 'medium', timeStyle: 'short' })}]` });
        }
      }
    } else {
      messages = [{ role: 'system', content: systemPrompt }];
      if (options.priorMessages && options.priorMessages.length > 0) {
        for (const pm of options.priorMessages) {
          if (pm.role && pm.content) messages.push({ role: pm.role, content: pm.content });
        }
      }
    }

    // Inject recalled memories as a system message immediately before the current user turn
    if (recallMsg) {
      messages.push({ role: 'system', content: recallMsg });
    }

    if (options.mediaAttachments && options.mediaAttachments.length > 0) {
      const contentArr = [{ type: 'text', text: userMessage }];
      for (const att of options.mediaAttachments) {
        if ((att.type === 'image' || att.type === 'video') && att.path) {
          try {
            if (fs.existsSync(att.path)) {
              const b64 = fs.readFileSync(att.path).toString('base64');
              const mime = att.path.endsWith('.png') ? 'image/png' : att.path.endsWith('.gif') ? 'image/gif' : 'image/jpeg';
              contentArr.push({ type: 'image_url', image_url: { url: `data:${mime};base64,${b64}` } });
            }
          } catch { /* skip unreadable */ }
        }
      }
      messages.push({ role: 'user', content: contentArr.length > 1 ? contentArr : userMessage });
    } else {
      messages.push({ role: 'user', content: userMessage });
    }

    if (conversationId) {
      db.prepare('INSERT INTO conversation_messages (conversation_id, role, content) VALUES (?, ?, ?)').run(conversationId, 'user', userMessage);
    }

    let iteration = 0;
    let totalTokens = 0;
    let lastContent = '';
    let stepIndex = 0;
    let forcedFinalResponse = false;

    try {
      while (iteration < this.maxIterations) {
        iteration++;

        const needsCompaction = this.estimateTokens(messages) > provider.getContextWindow(model) * 0.85;
        if (needsCompaction) {
          const { compact } = require('./compaction');
          messages = await compact(messages, provider, model);
          this.emit(userId, 'run:compaction', { runId, iteration });
        }

        this.emit(userId, 'run:thinking', { runId, iteration });

        let response;
        let streamContent = '';
        const callOptions = { model, reasoningEffort: options.reasoningEffort || process.env.REASONING_EFFORT || undefined };

        if (options.stream !== false) {
          const gen = provider.stream(messages, tools, callOptions);
          for await (const chunk of gen) {
            if (chunk.type === 'content') {
              streamContent += chunk.content;
              this.emit(userId, 'run:stream', { runId, content: streamContent, iteration });
            }
            if (chunk.type === 'done') {
              response = chunk;
            }
            if (chunk.type === 'tool_calls') {
              response = {
                content: chunk.content || streamContent,
                toolCalls: chunk.toolCalls,
                finishReason: 'tool_calls',
                usage: chunk.usage || null
              };
            }
          }
        } else {
          response = await provider.chat(messages, tools, callOptions);
        }

        if (!response) {
          response = { content: streamContent, toolCalls: [], finishReason: 'stop', usage: null };
        }

        if (response.usage) {
          totalTokens += response.usage.totalTokens || 0;
        }

        lastContent = response.content || streamContent || '';

        const assistantMessage = { role: 'assistant', content: lastContent };
        if (response.toolCalls && response.toolCalls.length > 0) {
          assistantMessage.tool_calls = response.toolCalls;
        }
        messages.push(assistantMessage);

        if (conversationId) {
          db.prepare('INSERT INTO conversation_messages (conversation_id, role, content, tool_calls, tokens) VALUES (?, ?, ?, ?, ?)')
            .run(conversationId, 'assistant', lastContent, response.toolCalls?.length > 0 ? JSON.stringify(response.toolCalls) : null, response.usage?.totalTokens || 0);
        }

        if (!response.toolCalls || response.toolCalls.length === 0) {
          break;
        }

        for (const toolCall of response.toolCalls) {
          stepIndex++;
          const stepId = uuidv4();
          const toolName = toolCall.function.name;
          let toolArgs;
          try {
            toolArgs = JSON.parse(toolCall.function.arguments || '{}');
          } catch {
            toolArgs = {};
          }

          db.prepare('INSERT INTO agent_steps (id, run_id, step_index, type, description, status, tool_name, tool_input, started_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime(\'now\'))')
            .run(stepId, runId, stepIndex, this.getStepType(toolName), `${toolName}: ${JSON.stringify(toolArgs).slice(0, 200)} `, 'running', toolName, JSON.stringify(toolArgs));

          this.emit(userId, 'run:tool_start', {
            runId, stepId, stepIndex, toolName, toolArgs: toolArgs,
            type: this.getStepType(toolName)
          });

          let toolResult;
          try {
            toolResult = await this.executeTool(toolName, toolArgs, { userId, runId, app });

            let screenshotPath = null;
            if (toolResult && toolResult.screenshotPath) {
              screenshotPath = toolResult.screenshotPath;
            }

            db.prepare('UPDATE agent_steps SET status = ?, result = ?, screenshot_path = ?, completed_at = datetime(\'now\') WHERE id = ?')
              .run('completed', JSON.stringify(toolResult).slice(0, 100000), screenshotPath, stepId);

            this.emit(userId, 'run:tool_end', {
              runId, stepId, toolName, result: toolResult, screenshotPath,
              status: 'completed'
            });
          } catch (err) {
            toolResult = { error: err.message };
            db.prepare('UPDATE agent_steps SET status = ?, error = ?, completed_at = datetime(\'now\') WHERE id = ?')
              .run('failed', err.message, stepId);

            this.emit(userId, 'run:tool_end', {
              runId, stepId, toolName, error: err.message, status: 'failed'
            });
          }

          const toolMessage = {
            role: 'tool',
            tool_call_id: toolCall.id,
            content: JSON.stringify(toolResult).slice(0, 50000)
          };
          messages.push(toolMessage);

          if (conversationId) {
            db.prepare('INSERT INTO conversation_messages (conversation_id, role, content, tool_call_id, name) VALUES (?, ?, ?, ?, ?)')
              .run(conversationId, 'tool', toolMessage.content, toolCall.id, toolName);
          }

          const runMeta = this.activeRuns.get(runId);
          if (runMeta) {
            runMeta.lastToolName = toolName;
            runMeta.lastToolTarget = (toolName === 'send_message') ? toolArgs.to : null;
          }
        }

        if (!this.activeRuns.has(runId)) break;
      }

      // ── IF we maxed out iterations and the last step was a tool block,
      // force one final generation so the AI speaks instead of ending silently.
      // Additionally, IF we organically broke out of the loop (toolCalls.length === 0)
      // BUT `lastContent` is empty and we actually ran tools (stepIndex > 0),
      // we must force a final generation so the user gets a summary.
      if ((iteration >= this.maxIterations && messages[messages.length - 1].role === 'tool') ||
        (iteration < this.maxIterations && stepIndex > 0 && !lastContent.trim() && messages[messages.length - 1].role !== 'tool')) {

        const callOptions = { model, reasoningEffort: options.reasoningEffort || process.env.REASONING_EFFORT || undefined };

        // Push an explicit instruction to force the model to summarize its tool results
        messages.push({
          role: 'system',
          content: 'You have finished executing your tools, but you did not provide a final text response. Please provide a final, natural-language summary or response to the user based on your findings.'
        });

        const finalResponse = await provider.chat(messages, [], callOptions);
        lastContent = finalResponse.content || '';
        forcedFinalResponse = true;

        messages.push({ role: 'assistant', content: lastContent });
        if (conversationId) {
          db.prepare('INSERT INTO conversation_messages (conversation_id, role, content, tokens) VALUES (?, ?, ?, ?)')
            .run(conversationId, 'assistant', lastContent, finalResponse.usage?.totalTokens || 0);
        }
        totalTokens += finalResponse.usage?.totalTokens || 0;
      }

      db.prepare('UPDATE agent_runs SET status = ?, total_tokens = ?, updated_at = datetime(\'now\'), completed_at = datetime(\'now\') WHERE id = ?')
        .run('completed', totalTokens, runId);

      if (conversationId) {
        db.prepare('UPDATE conversations SET total_tokens = total_tokens + ?, updated_at = datetime(\'now\') WHERE id = ?')
          .run(totalTokens, conversationId);
      }

      const runMeta = this.activeRuns.get(runId);
      const messagingSent = runMeta?.messagingSent || false;
      const lastToolName = runMeta?.lastToolName;
      const lastToolTarget = runMeta?.lastToolTarget;
      this.activeRuns.delete(runId);
      this.emit(userId, 'run:complete', { runId, content: lastContent, totalTokens, iterations: iteration, triggerSource });

      const lastActionWasSendToChat = lastToolName === 'send_message' && lastToolTarget === options.chatId;
      if (triggerSource === 'messaging' && options.source && options.chatId && (!lastActionWasSendToChat || forcedFinalResponse)) {
        if (lastContent && lastContent.trim() && lastContent.trim() !== '[NO RESPONSE]') {
          const manager = this.messagingManager;
          if (manager) {
            const chunks = lastContent.split(/\n\s*\n/).filter(c => c.trim().length > 0);
            (async () => {
              for (let i = 0; i < chunks.length; i++) {
                if (i > 0) {
                  const delay = Math.max(1000, Math.min(chunks[i].length * 30, 4000));
                  await manager.sendTyping(userId, options.source, options.chatId, true).catch(() => { });
                  await new Promise(r => setTimeout(r, delay));
                }
                await manager.sendMessage(userId, options.source, options.chatId, chunks[i]).catch(err =>
                  console.error('[Engine] Auto-reply fallback failed:', err.message)
                );
              }
            })();
          }
        }
      }

      return { runId, content: lastContent, totalTokens, iterations: iteration, status: 'completed' };
    } catch (err) {
      db.prepare('UPDATE agent_runs SET status = ?, error = ?, updated_at = datetime(\'now\') WHERE id = ?')
        .run('failed', err.message, runId);

      this.activeRuns.delete(runId);
      this.emit(userId, 'run:error', { runId, error: err.message });
      throw err;
    }
  }

  stopRun(runId) {
    this.activeRuns.delete(runId);
    db.prepare("UPDATE agent_runs SET status = 'stopped', updated_at = datetime('now') WHERE id = ?").run(runId);
  }

  abort(runId) {
    if (runId) this.stopRun(runId);
  }

  abortAll(userId) {
    for (const [runId, run] of this.activeRuns) {
      if (run.userId === userId) this.stopRun(runId);
    }
  }

  getStepType(toolName) {
    if (toolName.startsWith('browser_')) return 'browser';
    if (toolName === 'execute_command') return 'cli';
    if (toolName.startsWith('memory_')) return 'memory';
    if (toolName === 'send_message') return 'messaging';
    if (toolName === 'make_call') return 'messaging';
    if (toolName === 'http_request') return 'http';
    if (toolName === 'think') return 'thinking';
    if (toolName.includes('scheduled_task')) return 'scheduler';
    return 'tool';
  }

  estimateTokens(messages) {
    let total = 0;
    for (const msg of messages) {
      if (msg.content) total += Math.ceil(msg.content.length / 4);
      if (msg.tool_calls) total += Math.ceil(JSON.stringify(msg.tool_calls).length / 4);
    }
    return total;
  }

  emit(userId, event, data) {
    if (this.io) {
      this.io.to(`user:${userId} `).emit(event, data);
    }
  }
}

module.exports = { AgentEngine };
