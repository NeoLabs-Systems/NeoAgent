'use strict';

function normalizeReply(content) {
  return String(content || '')
    .replace(/[\u2018\u2019]/g, "'")
    .replace(/^[\s>*_`#-]+/, '')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
}

function hasExternalBlocker(text) {
  return /\b(?:blocked|cannot|can't|could not|couldn't|unable to|do not have access|don't have access|missing (?:access|credentials|permission|information)|need you to|requires? your|waiting for your|please (?:provide|send|choose|confirm|authorize|approve)|blockiert|kann nicht|konnte nicht|mir fehlt|ich brauche von dir|warte auf dein(?:e|en)?|bitte (?:gib|schick|sende|nenn|bestätige|waehle|wähle|genehmige))\b/.test(text);
}

function isTerminalQuestionOrBlockerReply(content) {
  const text = normalizeReply(content);
  if (!text) return false;
  return /[?？]/.test(text) || hasExternalBlocker(text);
}

/**
 * Detect replies that only announce or promise work which has not happened yet.
 * This is intentionally conservative and supplements the model completion judge;
 * it is a deterministic last line of defence against terminating after a status
 * phrase such as "I'm working on it" or "let me check".
 */
function isDeferredWorkReply(content) {
  const text = normalizeReply(content);
  if (!text || hasExternalBlocker(text)) return false;

  const acknowledgement = '(?:(?:sure|okay|ok|alright|absolutely|of course|got it|understood)[,.!]?\\s+)?';
  const taskTarget = '(?:it|this|that|your\\s+(?:request|task|issue)|the\\s+(?:request|task|issue|problem|code|logs?|repository|repo|build|tests?))';
  const activeWork = `(?:working\\s+(?:on|through)\\s+${taskTarget}|checking(?:\\s+${taskTarget})?|looking\\s+(?:into|at)\\s+${taskTarget}|investigating\\s+${taskTarget}|reviewing\\s+${taskTarget}|researching\\s+${taskTarget}|testing\\s+${taskTarget}|debugging\\s+${taskTarget}|running\\s+${taskTarget}|processing\\s+${taskTarget}|handling\\s+${taskTarget}|starting\\s+${taskTarget}|continuing\\s+${taskTarget})`;
  const promisedWork = '(?:check|look\\s+into|investigate|review|research|test|debug|run|work\\s+on|handle|start|continue|fix|send|create|update|delete|install|restart|deploy|publish|do\\s+that|take\\s+care\\s+of)';
  const patterns = [
    new RegExp(`^${acknowledgement}i(?:'m| am)\\s+(?:(?:still|currently|now|already)\\s+)?${activeWork}\\b`),
    new RegExp(`^${acknowledgement}i(?:'ll| will)\\s+(?:now\\s+)?${promisedWork}\\b`),
    new RegExp(`^${acknowledgement}(?:let me|allow me to)\\s+${promisedWork}\\b`),
    new RegExp(`^${acknowledgement}(?:i(?:'m| am)\\s+going to)\\s+${promisedWork}\\b`),
    /^(?:(?:please )?give me\s+(?:(?:a|one|another)\s+)?(?:moment|minute|bit)|hang tight|please wait|one moment|bear with me)\b/,
    /^(?:working on it|checking now|on it)[.!…]*$/,
    /\bi(?:'ll| will)\s+(?:get back to you|update you|report back|let you know|keep you posted)\b/,
    /\b(?:i(?:'ll| will)\s+follow up|stay tuned)\b/,
    /^(?:(?:klar|okay|ok|alles klar)[,.!]?\s+)?ich\s+(?:(?:arbeite|pruefe|prüfe|schaue|untersuche|teste|debugge|starte)\s+(?:(?:gerade|aktuell|jetzt|noch)\b|(?:das|dies|die logs?|den code|deine anfrage|deinen auftrag)\b)|(?:kuemmere|kümmere)\s+mich\s+(?:gerade|aktuell|jetzt|noch)\b)/,
    /^(?:(?:klar|okay|ok|alles klar)[,.!]?\s+)?ich\s+(?:werde|wuerde|würde)\s+(?:jetzt\s+)?(?:pruefen|prüfen|nachsehen|untersuchen|testen|debuggen|starten|fixen|erledigen)\b/,
    /^(?:(?:klar|okay|ok|alles klar)[,.!]?\s+)?(?:lass|lasst)\s+mich\s+(?:(?:das|dies|die logs?|den code)\s+)?(?:pruefen|prüfen|nachsehen|untersuchen|testen|debuggen)\b/,
    /^(?:gib mir|gebt mir)\s+(?:einen\s+)?(?:moment|augenblick)|^(?:bin dran|mache ich)[.!…]*$/,
    /\bich\s+(?:melde mich|gebe dir bescheid|halte dich auf dem laufenden)\b/,
  ];
  return patterns.some((pattern) => pattern.test(text));
}

module.exports = {
  isDeferredWorkReply,
  isTerminalQuestionOrBlockerReply,
};
