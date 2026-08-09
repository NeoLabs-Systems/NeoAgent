'use strict';

function buildVoiceRunContext({ promptHint = '' } = {}) {
  const sections = [
    'This canonical chat run originated from a live voice transcript.',
    'Perform the task with the normal NeoAgent tools, memory, approvals, verification, and delivery flow.',
    'Keep the final answer clear and natural when spoken aloud, without sacrificing required evidence or precision.',
    'Progress and final presentation are handled by the shared outbox; do not create a separate delivery or follow-up task.',
  ];
  const hint = String(promptHint || '').trim();
  if (hint) sections.push(`Additional caller instruction: ${hint}`);
  return sections.join('\n');
}

module.exports = {
  buildVoiceRunContext,
};
