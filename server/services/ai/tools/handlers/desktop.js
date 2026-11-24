'use strict';

const { executeDesktopTool } = require('../../integrated_tools/device_tools');

async function handleDesktopTool(args, ctx) {
  const { dc, signal, toolName } = ctx;
  return await executeDesktopTool(toolName, args, { getController: dc, signal });
}

const handlers = {
  desktop_observe: handleDesktopTool,

  desktop_click: handleDesktopTool,

  desktop_drag: handleDesktopTool,

  desktop_scroll: handleDesktopTool,

  desktop_type: handleDesktopTool,

  desktop_press_key: handleDesktopTool,

  desktop_launch_app: handleDesktopTool,

  desktop_get_tree: handleDesktopTool,
};

module.exports = { handlers };
