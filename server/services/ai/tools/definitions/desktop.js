'use strict';

// Desktop control tools: schemas plus the metadata the harness reads.

module.exports = [
  {
    name: 'desktop_observe',
    group: 'desktop', access: 'read', stateScope: 'desktop', latencyClass: 'local', repeatable: true,
    capabilities: ['desktop', 'screen'],
    prerequisites: ['desktop'],
    policy: { category: 'desktop_control' },
    description: 'Capture the current cloud computer screen plus its accessibility tree.',
    parameters: {
      type: 'object',
      properties: {
        includeTree: { type: 'boolean', description: 'Include accessibility tree or semantic nodes when available.' }
      }
    }
  },
  {
    name: 'desktop_click',
    group: 'desktop', access: 'write', sideEffect: 'device', stateScope: 'desktop', latencyClass: 'local', repeatable: true,
    capabilities: ['desktop', 'click'],
    prerequisites: ['desktop'],
    policy: { category: 'desktop_control' },
    description: 'Click at an absolute coordinate in the cloud computer desktop.',
    parameters: {
      type: 'object',
      properties: {
        x: { type: 'number', description: 'Absolute X coordinate in desktop pixels.' },
        y: { type: 'number', description: 'Absolute Y coordinate in desktop pixels.' },
        button: { type: 'string', description: 'Optional mouse button name, default left.' }
      },
      required: ['x', 'y']
    }
  },
  {
    name: 'desktop_drag',
    group: 'desktop', access: 'write', sideEffect: 'device', stateScope: 'desktop', latencyClass: 'local', repeatable: true,
    capabilities: ['desktop', 'drag'],
    prerequisites: ['desktop'],
    policy: { category: 'desktop_control' },
    description: 'Drag the mouse from one point to another in the cloud computer desktop.',
    parameters: {
      type: 'object',
      properties: {
        x1: { type: 'number', description: 'Start X coordinate.' },
        y1: { type: 'number', description: 'Start Y coordinate.' },
        x2: { type: 'number', description: 'End X coordinate.' },
        y2: { type: 'number', description: 'End Y coordinate.' },
        durationMs: { type: 'number', description: 'Optional drag duration in milliseconds.' }
      },
      required: ['x1', 'y1', 'x2', 'y2']
    }
  },
  {
    name: 'desktop_scroll',
    group: 'desktop', access: 'write', sideEffect: 'device', stateScope: 'desktop', latencyClass: 'local', repeatable: true,
    capabilities: ['desktop', 'scroll'],
    prerequisites: ['desktop'],
    description: 'Scroll in the cloud computer desktop.',
    parameters: {
      type: 'object',
      properties: {
        deltaX: { type: 'number', description: 'Horizontal scroll delta.' },
        deltaY: { type: 'number', description: 'Vertical scroll delta.' }
      }
    }
  },
  {
    name: 'desktop_type',
    group: 'desktop', access: 'write', sideEffect: 'device', stateScope: 'desktop', latencyClass: 'local', repeatable: true,
    capabilities: ['desktop', 'keyboard', 'input'],
    prerequisites: ['desktop'],
    policy: { category: 'desktop_control' },
    description: 'Type text into the focused element in the cloud computer desktop.',
    parameters: {
      type: 'object',
      properties: {
        text: { type: 'string', description: 'Text to type.' },
        pressEnter: { type: 'boolean', description: 'Press Enter after typing.' }
      },
      required: ['text']
    }
  },
  {
    name: 'desktop_press_key',
    group: 'desktop', access: 'write', sideEffect: 'device', stateScope: 'desktop', latencyClass: 'local', repeatable: true,
    capabilities: ['desktop', 'keyboard'],
    prerequisites: ['desktop'],
    policy: { category: 'desktop_control' },
    description: 'Press a named key in the cloud computer desktop.',
    parameters: {
      type: 'object',
      properties: {
        key: { type: 'string', description: 'Key to press, for example Enter, Escape, Meta, or Tab.' }
      },
      required: ['key']
    }
  },
  {
    name: 'desktop_launch_app',
    group: 'desktop', access: 'write', sideEffect: 'device', stateScope: 'desktop', latencyClass: 'local', repeatable: true,
    capabilities: ['desktop', 'apps'],
    prerequisites: ['desktop'],
    policy: { category: 'desktop_control' },
    description: 'Launch an allowed application in the cloud computer desktop.',
    parameters: {
      type: 'object',
      properties: {
        app: { type: 'string', description: 'Application identifier, executable, or app name.' }
      },
      required: ['app']
    }
  },
  {
    name: 'desktop_get_tree',
    group: 'desktop', access: 'read', stateScope: 'desktop', latencyClass: 'local', repeatable: true,
    capabilities: ['desktop', 'accessibility'],
    prerequisites: ['desktop'],
    description: 'Return the cloud computer accessibility tree or semantic node snapshot.',
    parameters: {
      type: 'object',
      properties: {
      }
    }
  },
];
