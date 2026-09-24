// The NeoAgent mascot: a dark tile with a 9×9 dot-matrix face. Same faces and
// timing as the app (flutter_app/lib/src/mascot/mascot_frames.dart), drawn in
// SVG. Frames step on timers and CSS transitions fade each dot, so nothing
// runs per animation frame; timers stop while a mascot is off screen.
//
//   data-mascot="look"   idle, eyes follow the pointer
//   data-mascot="story"  acts out the hero run log it sits in
//   data-mascot="still"  one idle face, no motion
(() => {
  'use strict';

  const hosts = document.querySelectorAll('[data-mascot]');
  if (!hosts.length) return;

  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const N = 9;
  const NS = 'http://www.w3.org/2000/svg';
  const LEVEL = { '#': 1, '-': 0.5, '+': 0.25 };

  const frame = (rows, o = {}) => ({
    dots: Array.from(rows.join(''), (c) => LEVEL[c] || 0),
    hold: o.hold || 400,
    alert: Boolean(o.alert),
    shift: o.shift || 0,
    scale: o.scale || 1,
    rim: o.rim || 0,
  });

  const BLANK = '.........';
  const DONE = [BLANK, BLANK, '..#...#..', '.#.#.#.#.', BLANK, BLANK, '..#...#..', '...###...', BLANK];

  // Underscore eyes with a comet running round the edge of the screen.
  const comet = () => {
    const ring = [];
    for (let x = 0; x < N; x++) ring.push(x);
    for (let y = 1; y < N; y++) ring.push(y * N + N - 1);
    for (let x = N - 2; x >= 0; x--) ring.push((N - 1) * N + x);
    for (let y = N - 2; y >= 1; y--) ring.push(y * N);
    const eyes = frame([BLANK, BLANK, BLANK, BLANK, '.###.###.', BLANK, BLANK, BLANK, BLANK]).dots;
    return ring.map((_, head) => {
      const dots = eyes.slice();
      dots[ring[head]] = 1;
      dots[ring[(head - 1 + ring.length) % ring.length]] = 0.5;
      dots[ring[(head - 2 + ring.length) % ring.length]] = 0.2;
      return { dots, hold: 45, alert: false, shift: 0, scale: 1, rim: 0 };
    });
  };

  const CLIPS = {
    idle: { fade: 120, loop: true, frames: [
      frame([BLANK, BLANK, '..##.##..', '..##.##..', '..##.##..', BLANK, BLANK, BLANK, BLANK]),
    ] },
    blink: { fade: 50, loop: false, frames: [
      frame([BLANK, BLANK, BLANK, '..##.##..', '..##.##..', BLANK, BLANK, BLANK, BLANK], { hold: 50 }),
      frame([BLANK, BLANK, BLANK, BLANK, '..##.##..', BLANK, BLANK, BLANK, BLANK], { hold: 80 }),
      frame([BLANK, BLANK, BLANK, '..##.##..', '..##.##..', BLANK, BLANK, BLANK, BLANK], { hold: 50 }),
    ] },
    thinking: { fade: 120, loop: true, frames: ['...#++...', '...+#+...', '...++#...', '...+++...'].map((d) =>
      frame([BLANK, '...##.##.', '...##.##.', '...##.##.', BLANK, BLANK, d, BLANK, BLANK], { hold: 280 })) },
    working: { fade: 60, loop: true, frames: comet() },
    waiting: { fade: 160, loop: true, frames: [
      frame([BLANK, '..##.##..', '..##.##..', '..##.##..', '..##.##..', BLANK, BLANK, '...###...', BLANK], { hold: 530, rim: 1 }),
      frame([BLANK, '..##.##..', '..##.##..', '..##.##..', '..##.##..', BLANK, BLANK, BLANK, BLANK], { hold: 530, rim: 0.35 }),
    ] },
    done: { fade: 110, loop: false, frames: [
      frame(DONE, { hold: 110, scale: 1.12 }),
      frame(DONE, { hold: 110, scale: 0.96 }),
      frame(DONE),
    ] },
  };

  const keyFrame = (mood) => {
    const frames = CLIPS[mood].frames;
    if (mood === 'working') return frames[4];
    if (mood === 'done') return frames[frames.length - 1];
    return frames[0];
  };

  const svg = (name, attrs = {}) => {
    const node = document.createElementNS(NS, name);
    for (const [key, value] of Object.entries(attrs)) node.setAttribute(key, value);
    return node;
  };

  // Shared gradient and glow, referenced by every mascot on the page.
  const defs = svg('svg', { width: 0, height: 0, 'aria-hidden': 'true', focusable: 'false' });
  defs.style.position = 'absolute';
  defs.innerHTML =
    '<defs>' +
    '<linearGradient id="mascot-tile" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#243029"/><stop offset="1" stop-color="#0c120e"/></linearGradient>' +
    '<filter id="mascot-glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="1.1" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>' +
    '</defs>';
  document.body.prepend(defs);

  // Geometry on a 100-unit box: a 95-unit tile standing on a 5-unit lip.
  const TILE = 95;
  const RADIUS = TILE * 0.33;
  const INSET = TILE * 0.06;
  const SCREEN = TILE - INSET * 2;
  const PITCH = (SCREEN * 10) / 102;
  const FIRST = INSET + (SCREEN * 11) / 102;

  class Mascot {
    constructor(host, mode) {
      this.host = host;
      this.mode = mode;
      this.still = reduced || mode === 'still';
      this.mood = null;
      this.clip = null;
      this.index = 0;
      this.then = null;
      this.stepTimer = 0;
      this.idleTimer = 0;
      this.look = [0, 0];
      this.shown = null;
      this.onScreen = true;
      this.running = true;

      const root = svg('svg', { viewBox: '0 0 100 100', class: 'mascot-svg', focusable: 'false' });
      root.append(svg('rect', { class: 'm-lip', x: 0, y: 5, width: TILE, height: TILE, rx: RADIUS }));
      this.body = svg('g', { class: 'm-body' });
      this.rim = svg('rect', { class: 'm-rim', x: 1, y: 1, width: TILE - 2, height: TILE - 2, rx: RADIUS - 1 });
      const off = svg('g', { class: 'm-off' });
      const lit = svg('g', { class: 'm-lit', filter: 'url(#mascot-glow)' });
      this.dots = [];
      for (let y = 0; y < N; y++) {
        for (let x = 0; x < N; x++) {
          const cx = FIRST + x * PITCH;
          const cy = FIRST + y * PITCH;
          off.append(svg('circle', { cx, cy, r: PITCH * 0.21 }));
          const dot = svg('circle', { cx, cy, r: PITCH * 0.36 });
          dot.style.fillOpacity = 0;
          lit.append(dot);
          this.dots.push(dot);
        }
      }
      this.body.append(
        svg('rect', { x: 0, y: 0, width: TILE, height: TILE, rx: RADIUS, fill: 'url(#mascot-tile)' }),
        svg('rect', { class: 'm-edge', x: 0.6, y: 0.6, width: TILE - 1.2, height: TILE - 1.2, rx: RADIUS - 0.6 }),
        this.rim,
        svg('rect', { class: 'm-screen', x: INSET, y: INSET, width: SCREEN, height: SCREEN, rx: TILE * 0.267 }),
        off,
        lit,
      );
      root.append(this.body);
      host.append(root);
    }

    setMood(mood) {
      if (mood === this.mood) return;
      this.mood = mood;
      this.enter(this.shown ? 180 : 0);
    }

    setLook(x, y) {
      if (x === this.look[0] && y === this.look[1]) return;
      this.look = [x, y];
      if (this.mood === 'idle' && this.shown) this.show(this.shown, 140);
    }

    refreshRunning() {
      const running = this.onScreen && !document.hidden;
      if (running === this.running) return;
      this.running = running;
      if (running) this.enter(0);
      else this.stop();
    }

    stop() {
      clearTimeout(this.stepTimer);
      clearTimeout(this.idleTimer);
    }

    enter(fade) {
      this.stop();
      if (this.still || !this.running) {
        this.show(keyFrame(this.mood), 0);
        return;
      }
      this.play(CLIPS[this.mood], fade);
      if (this.mood === 'idle') this.scheduleIdleMove();
    }

    play(clip, fade, then = null) {
      clearTimeout(this.stepTimer);
      this.clip = clip;
      this.index = 0;
      this.then = then;
      this.show(clip.frames[0], fade);
      this.scheduleStep();
    }

    scheduleStep() {
      const frames = this.clip.frames;
      const hold = frames[this.index].hold;
      if (this.index === frames.length - 1 && !this.clip.loop) {
        if (this.then) this.stepTimer = setTimeout(this.then, hold);
        return;
      }
      if (frames.length === 1) return;
      this.stepTimer = setTimeout(() => {
        this.index = (this.index + 1) % frames.length;
        this.show(frames[this.index], this.clip.fade);
        this.scheduleStep();
      }, hold);
    }

    // Every few seconds at rest, a blink.
    scheduleIdleMove() {
      this.idleTimer = setTimeout(() => {
        this.play(CLIPS.blink, CLIPS.blink.fade, () => {
          this.play(CLIPS.idle, 90);
          this.scheduleIdleMove();
        });
      }, 2600 + Math.random() * 3800);
    }

    show(f, fade) {
      this.shown = f;
      this.host.style.setProperty('--m-fade', `${fade}ms`);
      const [lx, ly] = this.mood === 'idle' ? this.look : [0, 0];
      for (let y = 0; y < N; y++) {
        for (let x = 0; x < N; x++) {
          const sx = x - lx;
          const sy = y - ly;
          const level = sx >= 0 && sx < N && sy >= 0 && sy < N ? f.dots[sy * N + sx] : 0;
          const dot = this.dots[y * N + x];
          if (dot.style.fillOpacity !== String(level)) dot.style.fillOpacity = level;
        }
      }
      this.host.classList.toggle('is-alert', f.alert);
      this.rim.style.opacity = f.rim * 0.75;
      this.body.style.transform = `translateX(${f.shift * PITCH}px) scale(${f.scale})`;
    }
  }

  // The hero's run log cycles its stories with CSS animations. Reading their
  // clock keeps the mascot in step, including while hovering pauses them.
  const storyMood = (host) => {
    const rails = [...(host.closest('.hrun') || document).querySelectorAll('.hrun-rail[data-mascot-end]')];
    const clock = rails.length && rails[0].getAnimations ? rails[0].getAnimations()[0] : null;
    return () => {
      if (!rails.length) return 'idle';
      if (!clock || clock.currentTime === null) return rails[0].dataset.mascotEnd;
      const duration = clock.effect.getComputedTiming().duration;
      const per = duration / rails.length;
      const t = clock.currentTime % duration;
      const local = t % per;
      if (local < per * 0.16) return 'thinking';
      if (local < per * 0.6) return 'working';
      return rails[Math.floor(t / per)].dataset.mascotEnd;
    };
  };

  const mascots = [...hosts].map((host) => {
    const mascot = new Mascot(host, host.dataset.mascot);
    if (mascot.mode === 'story') {
      const read = storyMood(host);
      mascot.setMood(read());
      if (!mascot.still) setInterval(() => mascot.running && mascot.setMood(read()), 200);
    } else {
      mascot.setMood('idle');
    }
    return mascot;
  });

  if ('IntersectionObserver' in window) {
    const byHost = new Map(mascots.map((m) => [m.host, m]));
    const observer = new IntersectionObserver((entries) => {
      for (const entry of entries) {
        const mascot = byHost.get(entry.target);
        mascot.onScreen = entry.isIntersecting;
        mascot.refreshRunning();
      }
    });
    mascots.forEach((m) => observer.observe(m.host));
  }
  document.addEventListener('visibilitychange', () => {
    mascots.forEach((m) => m.refreshRunning());
  });

  const lookers = mascots.filter((m) => m.mode === 'look' && !m.still);
  if (lookers.length) {
    let pointer = [0, 0];
    let queued = false;
    window.addEventListener('pointermove', (event) => {
      pointer = [event.clientX, event.clientY];
      if (queued) return;
      queued = true;
      requestAnimationFrame(() => {
        queued = false;
        for (const m of lookers) {
          const box = m.host.getBoundingClientRect();
          const dx = pointer[0] - (box.left + box.width / 2);
          const dy = pointer[1] - (box.top + box.height / 2);
          m.setLook(
            Math.abs(dx) > box.width ? Math.sign(dx) : 0,
            Math.abs(dy) > box.height * 1.5 ? Math.sign(dy) : 0,
          );
        }
      });
    }, { passive: true });
  }
})();
