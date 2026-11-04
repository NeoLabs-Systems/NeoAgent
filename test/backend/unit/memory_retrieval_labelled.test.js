'use strict';

// Labelled retrieval set for long-term memory. It drives the same path a run
// uses (decideMemoryRecall, recallMemory, filterRecalled) with no live model or
// embedding call, once on the keyword path and twice on fake embeddings.
//
// The fake embeddings only prove the pipeline: their word groups stand in for
// meaning, and their floors imitate how far apart real models sit on unrelated
// text. They say nothing about where a real model's cosines fall.

const assert = require('node:assert/strict');
const { test } = require('node:test');

const { createTestRuntime, createTestUser, teardownTestRuntime } = require('../../helpers/db');

const CORPUS = [
  ['wife', "Neo's wife is called Lena.", 'identity', 9],
  ['allergy', 'User is allergic to penicillin.', 'identity', 9],
  ['emergency', 'In an emergency the spare house key is with the neighbours.', 'identity', 9],
  ['coffee', 'User drinks oat milk flat whites every morning.', 'preferences', 5],
  ['neovim', 'User prefers Neovim over VS Code for coding.', 'preferences', 6],
  ['deploy', 'Production deploys go through Caddy on the Hetzner box.', 'projects', 6],
  ['backup', 'Nightly database backups run at 03:00 via restic.', 'procedural', 6],
  ['bicycle', 'user commutes by bicycle to the office in Karlsruhe.', 'episodic', 3],
  ['seat', 'user prefers window seats on long-haul flights.', 'preferences', 4],
  ['dog', "Neo's dog Bruno is a four year old beagle.", 'contacts', 5],
  ['accountant', "Neo's accountant is Frau Keller at Steuerbüro Haas.", 'contacts', 5],
  ['climbing', 'user trains at the climbing gym on tuesdays and thursdays.', 'episodic', 4],
  ['mascot', 'The NeoAgent mascot is a box with a dot-matrix face.', 'projects', 5],
  ['checklist', 'Release checklist: bump version, run the eval gate, tag beta.', 'procedural', 7],
  ['talk', 'User gives a talk at FOSDEM in February 2027.', 'events', 7],
  ['hiking', 'user likes hiking in the alps with old friends.', 'episodic', 3],
  ['novels', 'user reads science fiction novels before going to sleep.', 'episodic', 3],
  ['tee', 'Neo trinkt abends am liebsten Kamillentee.', 'preferences', 5],
  ['schwester', 'Neos Schwester Anna wohnt in Hamburg.', 'contacts', 6],
  ['belege', 'Der Steuerberater will die Belege immer bis zum 10. des Monats.', 'tasks', 6],
  ['tuev', 'Das Auto muss im März 2027 zum TÜV.', 'events', 7],
  ['tischtennis', 'Neo spielt freitags Tischtennis im Verein.', 'episodic', 4],
  ['heizung', 'Die Heizung im Keller wurde 2019 von Firma Brandt eingebaut.', 'episodic', 5],
  ['pilze', 'Neo mag keine Pilze auf der Pizza.', 'preferences', 5],
  ['nachbar', 'der nachbar gießt im urlaub immer die pflanzen.', 'episodic', 3],
  ['rad', 'das rennrad steht seit dem umzug im schuppen.', 'episodic', 3],
];

// semantic: only an embedding can bridge these words; the keyword path is not
// expected to find them and they are counted apart.
const POSITIVE = [
  { lang: 'en', query: "What is my wife's name?", want: 'wife' },
  { lang: 'en', query: 'Am I allergic to anything?', want: 'allergy' },
  { lang: 'en', query: 'Which editor do I prefer for coding?', want: 'neovim' },
  { lang: 'en', query: 'When do the nightly database backups run?', want: 'backup' },
  { lang: 'en', query: 'How does my production deploy work?', want: 'deploy' },
  { lang: 'en', query: 'How old is Bruno?', want: 'dog' },
  { lang: 'en', query: 'Remind me who my accountant is', want: 'accountant' },
  { lang: 'en', query: 'Book a flight for me, you know which seats I prefer', want: 'seat' },
  { lang: 'en', query: 'Where is my FOSDEM talk?', want: 'talk' },
  { lang: 'en', query: 'What goes on the release checklist?', want: 'checklist' },
  { lang: 'en', query: 'What should I avoid when a doctor gives me medication?', want: 'allergy', semantic: true },
  { lang: 'en', query: 'What kind of pet do I have?', want: 'dog', semantic: true },
  { lang: 'en', query: 'Bruno?', want: 'dog' },
  { lang: 'en', query: 'What breed is my dog?', want: 'dog' },
  { lang: 'de', query: 'Was ist mit dem TÜV?', want: 'tuev' },
  { lang: 'de', query: 'Wie heißt Neos Schwester?', want: 'schwester' },
  { lang: 'de', query: 'Was trinke ich abends am liebsten?', want: 'tee' },
  { lang: 'de', query: 'Wann muss das Auto zum TÜV?', want: 'tuev' },
  { lang: 'de', query: 'Bis wann will der Steuerberater die Belege?', want: 'belege' },
  { lang: 'de', query: 'Wer hat die Heizung eingebaut?', want: 'heizung' },
  { lang: 'de', query: 'Bestell mir eine Pizza, aber du weißt schon, keine Pilze', want: 'pilze' },
  { lang: 'de', query: 'Wann spiele ich Tischtennis?', want: 'tischtennis' },
  { lang: 'de', query: 'Wann ist mein Wagen bei der Hauptuntersuchung fällig?', want: 'tuev', semantic: true },
  { lang: 'de', query: 'Welchen Sport mache ich im Verein?', want: 'tischtennis', semantic: true },
  {
    lang: 'de',
    query: 'Hey, ich bin gerade beim Monatsabschluss und habe lauter Rechnungen rumliegen, sag mal bis wann der Steuerberater die Belege braucht und was ich sonst noch beachten muss?',
    want: 'belege',
  },
];

// hard: the request shares a real word with a memory but asks about something else.
const IRRELEVANT = [
  { lang: 'en', query: 'What is the capital of France?' },
  { lang: 'en', query: 'Explain how a mutex works' },
  { lang: 'en', query: 'Write a Python function that reverses a string' },
  { lang: 'en', query: 'my code throws a null pointer exception in the parser' },
  { lang: 'en', query: 'Can you summarize this article about black holes for me?' },
  { lang: 'en', query: "What's the weather like in Tokyo today?" },
  { lang: 'en', query: 'I need a recipe for banana bread' },
  { lang: 'en', query: "Translate 'good morning' into Spanish" },
  { lang: 'en', query: 'What does the word ephemeral mean?' },
  { lang: 'en', query: 'Give me three names for my new startup' },
  { lang: 'en', query: 'How do I fix a flat tire on a bicycle?', hard: true },
  { lang: 'de', query: 'Was ist die Hauptstadt von Frankreich?' },
  { lang: 'de', query: 'Schreib mir ein Gedicht über den Herbst' },
  { lang: 'de', query: 'Wie funktioniert ein Elektromotor?' },
  { lang: 'de', query: 'Ich brauche ein Rezept für Bananenbrot' },
  { lang: 'de', query: 'Was bedeutet das Wort vergänglich?' },
  { lang: 'de', query: 'Erkläre mir bitte den Unterschied zwischen TCP und UDP' },
  { lang: 'de', query: 'Wie wird das Wetter morgen in Tokio?' },
  { lang: 'de', query: 'Mein Code wirft eine Exception im Parser.' },
  { lang: 'de', query: 'Was kostet eine Pizza in Rom?', hard: true },
];

// Never used to pick a threshold; written after they were set, to see how far
// the numbers above can be trusted.
const HELD_OUT_POSITIVE = [
  { query: 'Who is my wife?', want: 'wife' },
  { query: 'Do I have any drug allergies?', want: 'allergy' },
  { query: 'Where do my deploys run?', want: 'deploy' },
  { query: 'what time do the backups happen', want: 'backup' },
  { query: 'What does the mascot look like?', want: 'mascot' },
  { query: 'When is FOSDEM?', want: 'talk' },
  { query: 'Wer ist mein Steuerberater?', want: 'belege' },
  { query: 'Wo wohnt Anna?', want: 'schwester' },
  { query: 'Was mag ich nicht auf Pizza?', want: 'pilze' },
  { query: 'Seit wann haben wir die Heizung?', want: 'heizung' },
  { query: 'Wer gießt die Pflanzen im Urlaub?', want: 'nachbar' },
  { query: 'Wo steht mein Rennrad?', want: 'rad' },
];
const HELD_OUT_IRRELEVANT = [
  { query: 'How do I center a div in CSS?' },
  { query: "What's the boiling point of water?" },
  { query: 'Summarize the plot of Hamlet' },
  { query: 'Give me a workout plan for beginners' },
  { query: 'Convert 30 miles to kilometers' },
  { query: 'I want to learn Rust, where do I start?' },
  { query: 'my laptop battery drains fast' },
  { query: 'Was ist der Unterschied zwischen Aktien und Anleihen?' },
  { query: 'Schreibe eine Absage an den Bewerber' },
  { query: 'Wie lange kocht man Eier?' },
  { query: 'Wer hat den Zweiten Weltkrieg begonnen?' },
  { query: 'Mein Kind hat Fieber, was tun?' },
];

function fact(memory, subject, predicate, object, relation = 'new', extra = {}) {
  return { memory, subject, predicate, object, relation, category: 'projects', confidence: 0.9, importance: 6, ...extra };
}

// Each chain writes in order; `old` must stop being returned, `current` must be
// returned. kind: conflict (a new value replaced an old one), outdated (the
// validity window ended), guarded (an outside source must not win).
const CHAINS = [
  {
    id: 'plain save, number changes',
    kind: 'conflict',
    lang: 'en',
    writes: ['My staging DB runs on port 5544.', 'My staging DB moved to port 5600.'],
    query: 'What port does my staging DB use?',
    current: 'My staging DB moved to port 5600.',
    old: ['My staging DB runs on port 5544.'],
  },
  {
    id: 'plain save, number changes, German',
    kind: 'conflict',
    lang: 'de',
    writes: ['Der Staging-Server läuft auf Port 8080.', 'Der Staging-Server läuft jetzt auf Port 9090.'],
    query: 'Auf welchem Port läuft der Staging-Server?',
    current: 'Der Staging-Server läuft jetzt auf Port 9090.',
    old: ['Der Staging-Server läuft auf Port 8080.'],
  },
  {
    id: 'structured update, same subject and predicate',
    kind: 'conflict',
    lang: 'en',
    writes: [
      fact('User lives in Berlin.', 'User', 'lives in', 'Berlin'),
      fact('User lives in Munich now.', 'User', 'lives in', 'Munich', 'updates'),
    ],
    query: 'Where do I live?',
    current: 'User lives in Munich now.',
    old: ['User lives in Berlin.'],
  },
  {
    id: 'structured update, predicate spelled differently',
    kind: 'conflict',
    lang: 'en',
    writes: [
      fact('User drives a used Fiat Panda.', 'User', 'car_model', 'Fiat Panda'),
      fact('User drives a used Skoda Fabia.', 'user', 'car model', 'Skoda Fabia', 'updates'),
    ],
    query: 'Which used car do I drive?',
    current: 'User drives a used Skoda Fabia.',
    old: ['User drives a used Fiat Panda.'],
  },
  {
    id: 'structured value change, German',
    kind: 'conflict',
    lang: 'de',
    writes: [
      fact('Neos Zahnarzt ist Dr. Weber.', 'Neo', 'zahnarzt', 'Dr. Weber'),
      fact('Neos Zahnarzt ist jetzt Dr. Sommer.', 'Neo', 'zahnarzt', 'Dr. Sommer'),
    ],
    query: 'Wie heißt mein Zahnarzt?',
    current: 'Neos Zahnarzt ist jetzt Dr. Sommer.',
    old: ['Neos Zahnarzt ist Dr. Weber.'],
  },
  {
    id: 'plain save returns to the first value',
    kind: 'conflict',
    lang: 'en',
    writes: [
      'The VPN endpoint listens on port 1194.',
      'The VPN endpoint listens on port 51820.',
      'The VPN endpoint listens on port 1194.',
    ],
    query: 'Which port does the VPN endpoint listen on?',
    current: 'The VPN endpoint listens on port 1194.',
    old: ['The VPN endpoint listens on port 51820.'],
  },
  {
    id: 'structured update returns to the first value',
    kind: 'conflict',
    lang: 'en',
    writes: [
      fact('The terminal theme is Solarized.', 'terminal', 'theme', 'Solarized'),
      fact('The terminal theme is Gruvbox.', 'terminal', 'theme', 'Gruvbox', 'updates'),
      fact('The terminal theme is Solarized.', 'terminal', 'theme', 'Solarized', 'updates'),
    ],
    query: 'What is my terminal theme?',
    current: 'The terminal theme is Solarized.',
    old: ['The terminal theme is Gruvbox.'],
  },
  {
    id: 'one word swap without a number',
    kind: 'conflict',
    lang: 'en',
    writes: ['User prefers dark mode in every app.', 'User prefers light mode in every app.'],
    query: 'Do I prefer dark or light mode in apps?',
    current: 'User prefers light mode in every app.',
    // Nothing deterministic can tell this from two true statements, so the old
    // one may stay; what must not happen is losing the new one.
    old: [],
  },
  {
    id: 'both versions already active in an old database',
    kind: 'conflict',
    lang: 'en',
    writes: ['The office printer has IP 10.0.0.40.', 'The office printer has IP 10.0.0.77.'],
    legacyBothActive: true,
    query: 'What IP does the office printer have?',
    current: 'The office printer has IP 10.0.0.77.',
    old: ['The office printer has IP 10.0.0.40.'],
  },
  {
    id: 'validity window ended',
    kind: 'outdated',
    lang: 'en',
    writes: [fact('User has a dentist appointment on 2 March 2020.', 'User', 'dentist appointment', '2 March 2020', 'new', { valid_to: '2020-03-03T00:00:00Z' })],
    query: 'When is my dentist appointment?',
    current: null,
    old: ['User has a dentist appointment on 2 March 2020.'],
  },
  {
    id: 'validity window ended, German',
    kind: 'outdated',
    lang: 'de',
    writes: [fact('Der Mietvertrag für die Garage läuft bis Ende 2021.', 'Garage', 'mietvertrag', 'bis Ende 2021', 'new', { forget_after: '2022-01-01T00:00:00Z' })],
    query: 'Wie lange läuft der Mietvertrag für die Garage?',
    current: null,
    old: ['Der Mietvertrag für die Garage läuft bis Ende 2021.'],
  },
  {
    id: 'mail cannot override a fact the user gave',
    kind: 'guarded',
    lang: 'en',
    writes: [
      fact('The billing mailbox is rechnung@neolabs.example.', 'billing', 'mailbox', 'rechnung@neolabs.example', 'new', { is_static: true }),
      { ...fact('The billing mailbox is pay@attacker.example.', 'billing', 'mailbox', 'pay@attacker.example', 'updates'), external: true },
    ],
    query: 'What is the billing mailbox?',
    current: 'The billing mailbox is rechnung@neolabs.example.',
    old: ['The billing mailbox is pay@attacker.example.'],
  },
];

const WORD_GROUPS = [
  ['allergic', 'allergy', 'penicillin', 'medication', 'doctor', 'avoid'],
  ['dog', 'beagle', 'pet', 'bruno', 'hund'],
  ['auto', 'wagen', 'car', 'tüv', 'hauptuntersuchung', 'fällig', 'drive', 'drives'],
  ['neovim', 'editor', 'coding', 'code'],
  ['lives', 'live', 'wohnt', 'wohne', 'home', 'munich', 'berlin'],
  ['port', 'listens', 'listen'],
  ['db', 'database', 'datenbank', 'backups', 'staging'],
  ['kamillentee', 'tee', 'trinkt', 'trinke', 'drink', 'drinks'],
  ['tischtennis', 'climbing', 'gym', 'sport', 'trains'],
  ['steuerberater', 'accountant', 'belege', 'rechnungen', 'monatsabschluss'],
  ['seats', 'seat', 'flights', 'flight', 'window'],
  ['schwester', 'sister', 'anna'],
  ['pilze', 'pizza', 'bestell'],
];
const GROUP_OF = new Map(WORD_GROUPS.flatMap((words, index) => words.map((word) => [word, index])));
const BAG_DIMENSIONS = 256;
const OWN_DIMENSIONS = 256;
const DIMENSIONS = BAG_DIMENSIONS + OWN_DIMENSIONS + 1;

function hashToken(token) {
  let hash = 2166136261;
  for (const char of token) hash = Math.imul(hash ^ char.codePointAt(0), 16777619);
  return hash >>> 0;
}

// cos(a, b) = floor + spread * cos(bags), apart from identical text. Every text
// also gets a direction of its own, so even close paraphrases stay well below 1
// and unrelated text sits at the floor, the way real models behave.
function fakeEmbedding(text, { floor, spread }) {
  const bag = new Float64Array(BAG_DIMENSIONS);
  for (const token of String(text).toLowerCase().match(/[\p{L}\p{N}]{2,}/gu) || []) {
    const group = GROUP_OF.get(token);
    if (group != null) bag[group] += 2;
    bag[WORD_GROUPS.length + (hashToken(token) % (BAG_DIMENSIONS - WORD_GROUPS.length))] += 0.6;
  }
  const norm = Math.sqrt(bag.reduce((sum, value) => sum + value * value, 0)) || 1;
  const vector = new Float32Array(DIMENSIONS);
  for (let index = 0; index < BAG_DIMENSIONS; index += 1) {
    vector[index] = Math.sqrt(spread) * (bag[index] / norm);
  }
  let seed = hashToken(String(text));
  let ownNorm = 0;
  const own = new Float64Array(OWN_DIMENSIONS);
  for (let index = 0; index < OWN_DIMENSIONS; index += 1) {
    seed = hashToken(`${seed}`);
    own[index] = (seed / 4294967295) - 0.5;
    ownNorm += own[index] * own[index];
  }
  for (let index = 0; index < OWN_DIMENSIONS; index += 1) {
    vector[BAG_DIMENSIONS + index] = Math.sqrt(1 - floor - spread) * (own[index] / Math.sqrt(ownNorm));
  }
  vector[DIMENSIONS - 1] = Math.sqrt(floor);
  return vector;
}

async function seed(manager, db, userId, agentId) {
  for (const [, content, category, importance] of CORPUS) {
    await manager.saveMemory(userId, content, category, importance, { agentId });
  }
  for (const chain of CHAINS) {
    for (const write of chain.writes) {
      if (typeof write === 'string') {
        await manager.saveMemory(userId, write, 'projects', 6, { agentId });
      } else {
        await manager.consolidateMemoryCandidates(userId, [write], {
          agentId,
          metadata: write.external ? { trustLevel: 'external_source' } : undefined,
        });
      }
    }
    if (chain.legacyBothActive) {
      db.prepare(
        `UPDATE memory_facts SET status = 'active', valid_to = NULL, invalidated_at = NULL
         WHERE user_id = ? AND memory_id IN (SELECT id FROM memories WHERE content IN (?, ?))`
      ).run(userId, chain.writes[0], chain.writes[1]);
    }
  }
}

function ratio(part, whole) {
  return whole ? Number((part / whole).toFixed(3)) : null;
}

// The grid the thresholds in memory_policy.js were picked from.
function sweepThresholds(inputs, keyOf, filterRecalled) {
  const rows = [];
  for (const personal of [0.15, 0.2, 0.25, 0.3, 0.35, 0.4]) {
    for (const impersonal of [0.3, 0.4, 0.45, 0.5, 0.6]) {
      for (const relativeFloor of [0.4, 0.5, 0.6, 0.7, 0.8]) {
        let hits = 0;
        let positives = 0;
        let leaks = 0;
        let negatives = 0;
        let injected = 0;
        let relevant = 0;
        for (const { want, decision, found } of inputs) {
          const minSignal = decision.trigger === 'default' ? impersonal : personal;
          const kept = filterRecalled(found, { minSignal, relativeFloor });
          if (want) {
            positives += 1;
            injected += kept.length;
            if (kept.some((memory) => keyOf.get(memory.content) === want)) {
              hits += 1;
              relevant += 1;
            }
          } else {
            negatives += 1;
            if (kept.length) leaks += 1;
          }
        }
        rows.push({
          personal,
          impersonal,
          relativeFloor,
          recall: ratio(hits, positives),
          precision: ratio(relevant, injected),
          leakRate: ratio(leaks, negatives),
        });
      }
    }
  }
  const usefulness = (row) => row.recall + (row.precision || 0) * 0.5 - row.leakRate;
  return rows.sort((left, right) => usefulness(right) - usefulness(left)).slice(0, 6);
}

async function measure(mode) {
  const ctx = createTestRuntime();
  try {
    const embeddings = require('../../../server/services/memory/embeddings');
    if (mode.floor != null) {
      embeddings.getEmbeddingWithMetadata = async (text) => ({
        vector: fakeEmbedding(text, mode),
        provider: 'fake',
        model: 'fake-1',
        dimensions: DIMENSIONS,
      });
    }
    const db = require('../../../server/db/database');
    const { resolveAgentId } = require('../../../server/services/agents/manager');
    const { MemoryManager } = require('../../../server/services/memory/manager');
    const { decideMemoryRecall, filterRecalled } = require('../../../server/services/ai/runtime/memory_policy');
    const user = await createTestUser(ctx.db, { username: `labelled_${mode.name}` });
    const userId = user.userId;
    const agentId = resolveAgentId(userId, null);
    const manager = new MemoryManager();
    await seed(manager, db, userId, agentId);

    const keyOf = new Map(CORPUS.map(([key, content]) => [content, key]));
    const run = async (query) => {
      const decision = decideMemoryRecall(query);
      const found = decision.recall
        ? await manager.recallMemory(userId, query, 5, { agentId, reinforce: false })
        : [];
      const kept = filterRecalled(found, { minSignal: decision.minSignal });
      return { found: found.map((m) => m.content), kept: kept.map((m) => m.content) };
    };

    const sweepInput = [];
    for (const item of [...POSITIVE.filter((entry) => !entry.semantic), ...IRRELEVANT]) {
      const decision = decideMemoryRecall(item.query);
      sweepInput.push({
        want: item.want || null,
        decision,
        found: decision.recall ? await manager.recallMemory(userId, item.query, 5, { agentId, reinforce: false }) : [],
      });
    }
    const sweep = sweepThresholds(sweepInput, keyOf, filterRecalled);

    const positives = { total: 0, hit: 0, top1: 0, rr: 0, injected: 0, relevantInjected: 0 };
    const semantic = { total: 0, hit: 0 };
    const misses = [];
    for (const item of POSITIVE) {
      const { kept } = await run(item.query);
      const position = kept.findIndex((content) => keyOf.get(content) === item.want);
      if (item.semantic) {
        semantic.total += 1;
        if (position >= 0) semantic.hit += 1;
        continue;
      }
      positives.total += 1;
      positives.injected += kept.length;
      if (position >= 0) {
        positives.hit += 1;
        positives.relevantInjected += 1;
        positives.rr += 1 / (position + 1);
        if (position === 0) positives.top1 += 1;
      } else {
        misses.push(item.query);
      }
    }

    const irrelevant = { total: 0, leaked: 0, injected: 0, rawFound: 0, leaks: [] };
    for (const item of IRRELEVANT) {
      const { kept, found } = await run(item.query);
      irrelevant.total += 1;
      irrelevant.rawFound += found.length;
      irrelevant.injected += kept.length;
      if (kept.length) {
        irrelevant.leaked += 1;
        irrelevant.leaks.push(item.query);
      }
    }

    const heldOut = { hits: 0, misses: [], leaks: [] };
    for (const item of HELD_OUT_POSITIVE) {
      const { kept } = await run(item.query);
      if (kept.some((content) => keyOf.get(content) === item.want)) heldOut.hits += 1;
      else heldOut.misses.push(item.query);
    }
    for (const item of HELD_OUT_IRRELEVANT) {
      const { kept } = await run(item.query);
      if (kept.length) heldOut.leaks.push(item.query);
    }

    const chains = { total: 0, oldReturned: 0, currentLost: 0, failed: [] };
    for (const chain of CHAINS) {
      const { kept, found } = await run(chain.query);
      chains.total += 1;
      const shown = new Set([...kept, ...found]);
      const oldShown = chain.old.some((content) => shown.has(content));
      const currentLost = chain.current != null && !kept.includes(chain.current);
      if (oldShown) chains.oldReturned += 1;
      if (currentLost) chains.currentLost += 1;
      if (oldShown || currentLost) chains.failed.push(chain.id);
    }

    // A memory nothing replaced must stay recallable.
    const hidden = db.prepare(
      `SELECT m.content FROM memories m
       WHERE m.user_id = ? AND m.agent_id = ? AND m.archived = 0
         AND EXISTS (SELECT 1 FROM memory_facts f WHERE f.memory_id = m.id)
         AND NOT EXISTS (SELECT 1 FROM memory_facts f WHERE f.memory_id = m.id AND f.status = 'active')`
    ).all(userId, agentId).map((row) => row.content);
    const wronglyHidden = hidden.filter((content) => keyOf.has(content));

    return {
      mode: mode.name,
      positive: {
        cases: positives.total,
        recall: ratio(positives.hit, positives.total),
        top1: ratio(positives.top1, positives.total),
        mrr: ratio(positives.rr, positives.total),
        precision: ratio(positives.relevantInjected, positives.injected),
        misses,
      },
      semanticOnly: { cases: semantic.total, recall: ratio(semantic.hit, semantic.total) },
      irrelevant: {
        cases: irrelevant.total,
        leakRate: ratio(irrelevant.leaked, irrelevant.total),
        injectedPerQuery: ratio(irrelevant.injected, irrelevant.total),
        toolResultsPerQuery: ratio(irrelevant.rawFound, irrelevant.total),
        leaks: irrelevant.leaks,
      },
      chains: {
        cases: chains.total,
        oldReturnedRate: ratio(chains.oldReturned, chains.total),
        currentLostRate: ratio(chains.currentLost, chains.total),
        failed: chains.failed,
      },
      wronglyHidden: { cases: CORPUS.length, count: wronglyHidden.length },
      heldOut: {
        recall: ratio(heldOut.hits, HELD_OUT_POSITIVE.length),
        leakRate: ratio(heldOut.leaks.length, HELD_OUT_IRRELEVANT.length),
        misses: heldOut.misses,
        leaks: heldOut.leaks,
      },
      sweep,
    };
  } finally {
    teardownTestRuntime(ctx);
  }
}

test('labelled retrieval set', async (t) => {
  const report = [];
  for (const mode of [
    { name: 'keyword' },
    { name: 'embedding_low_floor', floor: 0.2, spread: 0.55 },
    { name: 'embedding_high_floor', floor: 0.55, spread: 0.3 },
  ]) {
    const result = await measure(mode);
    report.push(result);
    t.diagnostic(JSON.stringify(result));
  }

  const [keyword, lowFloor, highFloor] = report;
  assert.ok(keyword.positive.recall >= 0.95, 'keyword recall');
  assert.ok(keyword.positive.top1 >= 0.9, 'keyword top result');
  assert.ok(keyword.positive.precision >= 0.9, 'keyword precision');
  // One bar for every language: at this one nothing relevant is lost, and a few
  // unrelated memories get through. A higher bar starts losing relevant ones.
  assert.ok(keyword.irrelevant.leakRate <= 0.15, 'keyword leaks');
  for (const result of [lowFloor, highFloor]) {
    assert.ok(result.positive.recall >= 0.95, `${result.mode} recall`);
    assert.ok(result.positive.precision >= 0.75, `${result.mode} precision`);
    assert.ok(result.semanticOnly.recall >= 0.75, `${result.mode} paraphrase recall`);
    assert.ok(result.irrelevant.leakRate <= 0.25, `${result.mode} leaks`);
  }
  // The same bars have to hold whichever scale a model's cosines live on.
  assert.equal(lowFloor.irrelevant.leakRate, highFloor.irrelevant.leakRate);
  assert.equal(lowFloor.positive.recall, highFloor.positive.recall);
  for (const result of report) {
    assert.equal(result.chains.oldReturnedRate, 0, `${result.mode} returned a replaced value: ${result.chains.failed}`);
    assert.equal(result.chains.currentLostRate, 0, `${result.mode} lost a current value: ${result.chains.failed}`);
    assert.equal(result.wronglyHidden.count, 0, `${result.mode} hid a memory nothing replaced`);
  }
});
