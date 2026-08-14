/* NeoAgent landing — Control Surface interactions */
(function () {
  'use strict';

  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const nav = document.querySelector('[data-nav]');
  const toggle = document.querySelector('[data-nav-toggle]');
  const mobileMenu = document.querySelector('[data-mobile-menu]');

  /* ---------- nav ---------- */
  const onScrollNav = () => {
    if (!nav) return;
    nav.classList.toggle('scrolled', window.scrollY > 10);
  };
  window.addEventListener('scroll', onScrollNav, { passive: true });
  onScrollNav();

  if (toggle && nav) {
    toggle.addEventListener('click', () => {
      const open = nav.classList.toggle('open');
      toggle.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    mobileMenu?.querySelectorAll('a').forEach((link) => {
      link.addEventListener('click', () => {
        nav.classList.remove('open');
        toggle.setAttribute('aria-expanded', 'false');
        toggle.setAttribute('aria-label', 'Open menu');
      });
    });
  }

  /* ---------- scroll reveals ---------- */
  const io = new IntersectionObserver((entries) => {
    entries.forEach((e) => {
      if (e.isIntersecting) {
        e.target.classList.add('in');
        io.unobserve(e.target);
      }
    });
  }, { threshold: 0.15, rootMargin: '0px 0px -5% 0px' });

  document.querySelectorAll('.reveal, [data-stagger]').forEach((el) => io.observe(el));

  // stagger indices + a tiny random tilt per channel chip (human touch)
  document.querySelectorAll('[data-stagger]').forEach((grid) => {
    grid.querySelectorAll('.channel-chip').forEach((chip, i) => {
      chip.style.setProperty('--i', i);
      chip.style.setProperty('--r', ((i % 5) - 2) * 0.8);
    });
  });

  /* ---------- scroll progress ---------- */
  const bar = document.createElement('div');
  bar.className = 'scroll-progress';
  bar.setAttribute('aria-hidden', 'true');
  document.body.appendChild(bar);
  const onProgress = () => {
    const max = document.documentElement.scrollHeight - window.innerHeight;
    bar.style.width = (max > 0 ? (window.scrollY / max) * 100 : 0) + '%';
  };
  window.addEventListener('scroll', onProgress, { passive: true });
  onProgress();

  /* ---------- hide sign-in on static GitHub Pages hosts ---------- */
  if (location.hostname.includes('github.io')) {
    document.querySelectorAll('a.signin').forEach((a) => { a.style.display = 'none'; });
  }

  /* ---------- pointer tilt on framed surfaces ---------- */
  if (!reduced && matchMedia('(hover: hover) and (pointer: fine)').matches) {
    document.querySelectorAll('[data-tilt]').forEach((el) => {
      const base = {
        ty: parseFloat(getComputedStyle(el).getPropertyValue('--ty')) || 0,
        tx: parseFloat(getComputedStyle(el).getPropertyValue('--tx')) || 0,
      };
      el.addEventListener('pointermove', (ev) => {
        const r = el.getBoundingClientRect();
        const px = (ev.clientX - r.left) / r.width - 0.5;
        const py = (ev.clientY - r.top) / r.height - 0.5;
        el.style.setProperty('--ty', (base.ty + px * 5).toFixed(2));
        el.style.setProperty('--tx', (base.tx - py * 4).toFixed(2));
      });
      el.addEventListener('pointerleave', () => {
        el.style.setProperty('--ty', base.ty);
        el.style.setProperty('--tx', base.tx);
      });
    });
  }

  /* ============================================================
     Hero chat demo — a small replay engine over the UI replica
     ============================================================ */
  const demo = document.querySelector('[data-chat-demo]');
  if (demo) {
    const thread = demo.querySelector('[data-demo-thread]');
    const input = demo.querySelector('[data-demo-input]');
    const status = demo.querySelector('[data-demo-status]');
    const sendBtn = demo.querySelector('.sa-btn.send');
    const chips = document.querySelectorAll('.demo-chip');

    const scenarios = [
      {
        user: 'Morning. What’s waiting for me?',
        tools: ['Calendar', 'Mail', 'Memory'],
        reply: '<strong>Calendar</strong> — design review at 09:30 collides with your focus block. ' +
          '<strong>Mail</strong> — 3 need answers, 11 archived as noise. ' +
          '<strong>Standup draft</strong> is ready in your notes. Want me to move the focus block?',
        stamp: '08:04',
      },
      {
        user: 'Renew the car insurance before Friday. Same coverage.',
        tools: ['Browser', 'Vault', 'Memory'],
        reply: 'Done — renewed on the insurer’s portal with the saved policy details, same coverage, ' +
          '€12 cheaper than last year. Confirmation PDF is in your mail. <strong>Full session recording in the log.</strong>',
        stamp: '14:31',
      },
      {
        user: 'When the build goes green, tell Maya it’s safe to merge.',
        tools: ['Watch: CI', 'Telegram'],
        reply: 'Watching the pipeline. The moment it passes, Maya gets a message on Telegram — ' +
          'and you get a one-line note in tomorrow’s brief. <strong>Trigger armed.</strong> You can close this tab.',
        stamp: '17:52',
      },
    ];

    // A dimmed earlier exchange so the canvas never reads as empty.
    const threadPrefix =
      '<div class="sa-earlier">earlier today</div>' +
      '<div class="sa-msg user faded">Move the 14:00 partner sync, Maya can’t make it.</div>' +
      '<div class="sa-msg agent faded">Moved to Thursday 10:00 — both calendars had the slot. Maya got a heads-up on Telegram.</div>';

    let timers = [];
    let running = 0;

    const later = (fn, ms) => { timers.push(setTimeout(fn, reduced ? 0 : ms)); };
    const clearTimers = () => { timers.forEach(clearTimeout); timers = []; };

    const el = (cls, html) => {
      const node = document.createElement('div');
      node.className = cls;
      if (html !== undefined) node.innerHTML = html;
      return node;
    };

    const setStatus = (busy) => {
      status.classList.toggle('busy', busy);
      status.innerHTML = '<i></i>' + (busy ? 'working' : 'idle');
    };

    const play = (idx) => {
      clearTimers();
      const s = scenarios[idx];
      const run = ++running;
      const alive = () => run === running;
      thread.innerHTML = threadPrefix;
      input.innerHTML = '<span class="sa-placeholder">Ask a question or start a task…</span><span class="caret" aria-hidden="true"></span>';
      setStatus(false);
      sendBtn.classList.remove('armed');

      // 1. type the request into the composer
      later(() => {
        if (!alive()) return;
        const caret = '<span class="caret" aria-hidden="true"></span>';
        if (reduced) {
          input.innerHTML = s.user + caret;
          send();
          return;
        }
        let i = 0;
        const tick = () => {
          if (!alive()) return;
          i++;
          input.innerHTML = s.user.slice(0, i) + caret;
          if (i < s.user.length) {
            timers.push(setTimeout(tick, 26 + Math.random() * 42));
          } else {
            sendBtn.classList.add('armed');
            later(send, 420);
          }
        };
        tick();
      }, 700);

      // 2. send: user bubble appears, composer clears
      const send = () => {
        if (!alive()) return;
        sendBtn.classList.remove('armed');
        input.innerHTML = '<span class="sa-placeholder">Ask a question or start a task…</span><span class="caret" aria-hidden="true"></span>';
        thread.appendChild(el('sa-msg user', s.user + '<span class="stamp">' + s.stamp + '</span>'));
        setStatus(true);

        // 3. tool chips appear and resolve one by one
        const row = el('sa-toolrow');
        thread.appendChild(row);
        s.tools.forEach((name, i) => {
          later(() => {
            if (!alive()) return;
            const chip = el('sa-tool', '<i></i>' + name);
            row.appendChild(chip);
            later(() => { if (alive()) chip.classList.add('done'); }, 900 + Math.random() * 500);
          }, 500 + i * 650);
        });

        // 4. typing indicator, then the reply
        const afterTools = 500 + s.tools.length * 650 + 1100;
        later(() => {
          if (!alive()) return;
          const typing = el('sa-typing', '<i></i><i></i><i></i>');
          thread.appendChild(typing);
          later(() => {
            if (!alive()) return;
            typing.remove();
            thread.appendChild(el('sa-msg agent', s.reply + '<span class="stamp">' + s.stamp + '</span>'));
            setStatus(false);
            // idle a while, then move on to the next scenario
            later(() => { if (alive()) select((idx + 1) % scenarios.length); }, 7000);
          }, 1300);
        }, afterTools);
      };
    };

    const select = (idx) => {
      chips.forEach((c) => c.classList.toggle('is-active', Number(c.dataset.scenario) === idx));
      play(idx);
    };

    chips.forEach((chip) => {
      chip.addEventListener('click', () => select(Number(chip.dataset.scenario)));
    });

    // start once the demo scrolls into view
    const demoIo = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) {
        demoIo.disconnect();
        select(0);
      }
    }, { threshold: 0.4 });
    demoIo.observe(demo);
  }

  /* ============================================================
     Scrollytelling — steps drive the sticky stage
     ============================================================ */
  const story = document.querySelector('[data-story]');
  if (story) {
    const steps = story.querySelectorAll('[data-step]');
    const panels = story.querySelectorAll('[data-panel]');

    const activate = (idx) => {
      steps.forEach((s) => s.classList.toggle('is-active', Number(s.dataset.step) === idx));
      panels.forEach((p) => p.classList.toggle('is-active', Number(p.dataset.panel) === idx));
    };

    const stepIo = new IntersectionObserver((entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting) activate(Number(e.target.dataset.step));
      });
    }, { threshold: 0.55 });
    steps.forEach((s) => stepIo.observe(s));
    activate(0);

    /* ---- run-panel loop: steps complete one after another ---- */
    const runSteps = story.querySelectorAll('[data-run-steps] .run-step');
    if (runSteps.length && !reduced) {
      let cursor = 0;
      const advance = () => {
        runSteps.forEach((s, i) => {
          s.classList.toggle('done', i < cursor);
          s.classList.toggle('doing', i === cursor);
        });
        cursor++;
        if (cursor > runSteps.length) cursor = 0;
      };
      advance();
      setInterval(advance, 1900);
    } else {
      runSteps.forEach((s) => s.classList.add('done'));
    }

    /* ---- memory graph: build, drift, hover-highlight, cycle facts ---- */
    const graph = story.querySelector('[data-mem-graph]');
    if (graph) {
      const nodes = [
        { id: 'neoagent', label: 'NeoAgent', x: 230, y: 128, r: 20 },
        { id: 'maya', label: 'Maya', x: 118, y: 60, r: 15 },
        { id: 'flutter', label: 'Flutter', x: 66, y: 168, r: 14 },
        { id: 'mac', label: 'Mac mini', x: 190, y: 205, r: 15 },
        { id: 'prefers', label: 'Prefers', x: 330, y: 52, r: 13 },
        { id: 'primary', label: 'Primary', x: 392, y: 150, r: 16 },
        { id: 'when', label: 'Evenings', x: 320, y: 210, r: 12 },
      ];
      const links = [
        ['neoagent', 'maya'], ['neoagent', 'flutter'], ['neoagent', 'mac'],
        ['neoagent', 'primary'], ['maya', 'prefers'], ['primary', 'when'],
        ['mac', 'flutter'], ['prefers', 'primary'],
      ];
      const facts = {
        neoagent: 'Primary workspace is NeoAgent self-hosted on a local Mac mini with Flutter web as the control surface.',
        maya: 'Maya reviews design PRs — prefers a Telegram ping over email, and never before 09:00.',
        flutter: 'The control surface is Flutter web; Neo builds it himself — the agent never runs the build.',
        mac: 'The Mac mini in the closet runs the backend — restarts are fine on Sundays before 07:00.',
        prefers: 'Prefers quiet terrace tables, window seats on trains, and briefs under five lines.',
        primary: 'The "Main" agent is the default — other agents are scoped per project.',
        when: 'Evening wind-down runs at 22:00; nothing non-urgent gets through after that.',
      };

      const ns = 'http://www.w3.org/2000/svg';
      const linkGroup = graph.querySelector('.mem-links');
      const nodeGroup = graph.querySelector('.mem-nodes');
      const factText = story.querySelector('[data-mem-fact-text]');
      const byId = {};
      nodes.forEach((n) => { byId[n.id] = n; });

      const lineEls = links.map(([a, b]) => {
        const l = document.createElementNS(ns, 'line');
        l.dataset.a = a;
        l.dataset.b = b;
        linkGroup.appendChild(l);
        return l;
      });

      const nodeEls = nodes.map((n) => {
        const g = document.createElementNS(ns, 'g');
        g.setAttribute('class', 'mem-node');
        g.dataset.id = n.id;
        const halo = document.createElementNS(ns, 'circle');
        halo.setAttribute('class', 'halo');
        halo.setAttribute('r', n.r);
        const core = document.createElementNS(ns, 'circle');
        core.setAttribute('class', 'core');
        core.setAttribute('r', Math.max(3, n.r * 0.28));
        const label = document.createElementNS(ns, 'text');
        label.setAttribute('dy', n.r + 13);
        label.textContent = n.label;
        g.append(halo, core, label);
        nodeGroup.appendChild(g);
        return g;
      });

      const highlight = (id) => {
        nodeEls.forEach((g) => {
          const active = !id || g.dataset.id === id ||
            links.some(([a, b]) => (a === id && b === g.dataset.id) || (b === id && a === g.dataset.id));
          g.classList.toggle('lit', Boolean(id) && active);
        });
        lineEls.forEach((l) => {
          l.classList.toggle('lit', Boolean(id) && (l.dataset.a === id || l.dataset.b === id));
        });
        if (id && facts[id] && factText) factText.textContent = facts[id];
      };

      nodeEls.forEach((g) => {
        g.addEventListener('pointerenter', () => highlight(g.dataset.id));
        g.addEventListener('click', () => highlight(g.dataset.id));
      });
      graph.addEventListener('pointerleave', () => highlight(null));

      // gentle autonomous drift + a slow tour through the facts
      let t = 0;
      let tourIdx = 0;
      const drift = () => {
        t += 0.008;
        nodes.forEach((n, i) => {
          n.dx = Math.sin(t * (0.7 + i * 0.13) + i * 2.1) * 6;
          n.dy = Math.cos(t * (0.6 + i * 0.11) + i * 1.3) * 5;
        });
        nodeEls.forEach((g, i) => {
          const n = nodes[i];
          g.setAttribute('transform', 'translate(' + (n.x + n.dx) + ',' + (n.y + n.dy) + ')');
        });
        lineEls.forEach((l) => {
          const a = byId[l.dataset.a];
          const b = byId[l.dataset.b];
          l.setAttribute('x1', a.x + a.dx); l.setAttribute('y1', a.y + a.dy);
          l.setAttribute('x2', b.x + b.dx); l.setAttribute('y2', b.y + b.dy);
        });
        requestAnimationFrame(drift);
      };

      if (reduced) {
        nodes.forEach((n) => { n.dx = 0; n.dy = 0; });
        nodeEls.forEach((g, i) => {
          g.setAttribute('transform', 'translate(' + nodes[i].x + ',' + nodes[i].y + ')');
        });
        lineEls.forEach((l) => {
          const a = byId[l.dataset.a];
          const b = byId[l.dataset.b];
          l.setAttribute('x1', a.x); l.setAttribute('y1', a.y);
          l.setAttribute('x2', b.x); l.setAttribute('y2', b.y);
        });
      } else {
        nodes.forEach((n) => { n.dx = 0; n.dy = 0; });
        requestAnimationFrame(drift);
        setInterval(() => {
          if (!graph.matches(':hover')) {
            highlight(nodes[tourIdx % nodes.length].id);
            tourIdx++;
          }
        }, 3400);
      }
    }
  }

  /* ============================================================
     Terminal — type the install command when it scrolls into view
     ============================================================ */
  const term = document.querySelector('[data-term]');
  if (term) {
    const cmdEl = term.querySelector('[data-term-cmd]');
    const outLines = term.querySelectorAll('[data-term-out] > div');
    const cmd = cmdEl.getAttribute('data-term-cmd');

    const runTerm = () => {
      if (reduced) {
        cmdEl.textContent = cmd;
        outLines.forEach((l) => l.classList.add('show'));
        return;
      }
      let i = 0;
      const type = () => {
        i++;
        cmdEl.textContent = cmd.slice(0, i);
        if (i < cmd.length) {
          setTimeout(type, 34 + Math.random() * 40);
        } else {
          outLines.forEach((l, j) => {
            setTimeout(() => l.classList.add('show'), 500 + j * 380);
          });
        }
      };
      setTimeout(type, 400);
    };

    const termIo = new IntersectionObserver((entries) => {
      if (entries.some((e) => e.isIntersecting)) {
        termIo.disconnect();
        runTerm();
      }
    }, { threshold: 0.5 });
    termIo.observe(term);
  }
})();
