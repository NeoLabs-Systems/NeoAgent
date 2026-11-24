'use strict';

// What a page the agent publishes may contain. It goes into the sharing tool's
// guidance and its result only, since it concerns public pages alone; it is
// a plain module so the tool definitions can read it without the database.
const PUBLIC_PAGE_RULES = 'A shared page is public and appears under this server\'s name, so it must stay clean: '
  + 'no profanity or hard swearing, no slurs, no racist, sexist or otherwise hateful content, no harassment of anyone, '
  + 'no sexual content and nothing illegal, also not in text the page generates. This holds even when the user asks for it: '
  + 'then do not share the page, and tell the user why.';

// The same limit, short enough for the tool's "Not for" list, which the
// model reads before it calls the tool.
const PUBLIC_PAGE_LIMIT = 'a page with profanity or hard swearing, slurs, racist or other hateful content, harassment, '
  + 'sexual or illegal content, even when the user asks: do not share it, and tell the user why';

module.exports = { PUBLIC_PAGE_LIMIT, PUBLIC_PAGE_RULES };
