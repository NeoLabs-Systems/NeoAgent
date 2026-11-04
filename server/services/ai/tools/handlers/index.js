'use strict';

const handlers = {
  ...require('./shell').handlers,
  ...require('./browser').handlers,
  ...require('./desktop').handlers,
  ...require('./android').handlers,
  ...require('./web').handlers,
  ...require('./memory').handlers,
  ...require('./messaging').handlers,
  ...require('./files').handlers,
  ...require('./coding').handlers,
  ...require('./skills').handlers,
  ...require('./control').handlers,
  ...require('./agents').handlers,
  ...require('./tasks').handlers,
  ...require('./mcp').handlers,
  ...require('./media').handlers,
  ...require('./data').handlers,
};

module.exports = { handlers };
