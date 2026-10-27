'use strict';

const { readSettingValue } = require('../settings/store');

// Sent when a chat message arrives after the usage limit is used up. No model
// call is possible at that point, so the text is fixed per UI language.
const NOTICES = {
  en: ['I have reached my usage limit and can’t reply right now.', 'Try again {when}.'],
  de: ['Ich habe mein Nutzungslimit erreicht und kann gerade nicht antworten.', 'Versuch es {when} noch einmal.'],
  bg: ['Достигнах лимита си за използване и не мога да отговоря в момента.', 'Опитайте отново {when}.'],
  hr: ['Dosegnuo sam ograničenje korištenja i trenutno ne mogu odgovoriti.', 'Pokušaj ponovno {when}.'],
  cs: ['Dosáhl jsem limitu využití a teď nemohu odpovědět.', 'Zkus to znovu {when}.'],
  da: ['Jeg har nået min forbrugsgrænse og kan ikke svare lige nu.', 'Prøv igen {when}.'],
  nl: ['Ik heb mijn gebruikslimiet bereikt en kan nu niet antwoorden.', 'Probeer het {when} opnieuw.'],
  et: ['Olen jõudnud oma kasutuspiiranguni ega saa praegu vastata.', 'Proovi uuesti {when}.'],
  fi: ['Käyttörajani on täynnä, enkä voi vastata juuri nyt.', 'Yritä uudelleen {when}.'],
  fr: ['J’ai atteint ma limite d’utilisation et je ne peux pas répondre pour le moment.', 'Réessaie {when}.'],
  el: ['Έφτασα το όριο χρήσης μου και δεν μπορώ να απαντήσω αυτή τη στιγμή.', 'Δοκίμασε ξανά {when}.'],
  hu: ['Elértem a használati korlátomat, ezért most nem tudok válaszolni.', 'Próbáld újra {when}.'],
  ga: ['Tá mo theorainn úsáide bainte amach agam agus ní féidir liom freagra a thabhairt anois.', 'Bain triail eile as {when}.'],
  it: ['Ho raggiunto il mio limite di utilizzo e non posso rispondere ora.', 'Riprova {when}.'],
  lv: ['Esmu sasniedzis lietošanas limitu un šobrīd nevaru atbildēt.', 'Mēģini vēlreiz {when}.'],
  lt: ['Pasiekiau naudojimo limitą ir šiuo metu negaliu atsakyti.', 'Bandyk dar kartą {when}.'],
  mt: ['Wasalt il-limitu tal-użu tiegħi u ma nistax nwieġeb bħalissa.', 'Erġa’ pprova {when}.'],
  pl: ['Osiągnąłem limit użycia i nie mogę teraz odpowiedzieć.', 'Spróbuj ponownie {when}.'],
  pt: ['Atingi o meu limite de utilização e não posso responder agora.', 'Tenta novamente {when}.'],
  ro: ['Am atins limita de utilizare și nu pot răspunde acum.', 'Încearcă din nou {when}.'],
  sk: ['Dosiahol som limit využitia a teraz nemôžem odpovedať.', 'Skús to znova {when}.'],
  sl: ['Dosegel sem omejitev uporabe in trenutno ne morem odgovoriti.', 'Poskusi znova {when}.'],
  es: ['He alcanzado mi límite de uso y no puedo responder ahora.', 'Vuelve a intentarlo {when}.'],
  sv: ['Jag har nått min användningsgräns och kan inte svara just nu.', 'Försök igen {when}.'],
};

function relativeRetryTime(language, recoversAt, now) {
  const ms = Date.parse(recoversAt || '') - now;
  if (!Number.isFinite(ms) || ms <= 0) return null;
  const minutes = Math.ceil(ms / 60_000);
  const [value, unit] = minutes < 60
    ? [minutes, 'minute']
    : minutes < 48 * 60 ? [Math.ceil(minutes / 60), 'hour'] : [Math.ceil(minutes / 1440), 'day'];
  try {
    return new Intl.RelativeTimeFormat(language, { numeric: 'auto' }).format(value, unit);
  } catch {
    return null;
  }
}

function buildUsageLimitNotice(language, rateLimit, now = Date.now()) {
  const code = NOTICES[language] ? language : 'en';
  const [notice, retry] = NOTICES[code];
  const when = relativeRetryTime(code, rateLimit?.recoversAt?.[rateLimit?.window], now);
  return when ? `${notice} ${retry.replace('{when}', when)}` : notice;
}

async function sendUsageLimitNotice({ messagingManager, userId, msg, error }) {
  const agentId = msg.agentId || null;
  let language = null;
  try {
    language = readSettingValue(userId, agentId, 'ui_language');
  } catch {
    language = null;
  }
  await messagingManager.sendMessage(
    userId,
    msg.platform,
    msg.chatId,
    buildUsageLimitNotice(language, error.rateLimit),
    { runId: null, agentId },
  );
}

function isUsageLimitError(error) {
  return error?.code === 'RATE_LIMIT_EXCEEDED';
}

module.exports = { buildUsageLimitNotice, isUsageLimitError, sendUsageLimitNotice };
