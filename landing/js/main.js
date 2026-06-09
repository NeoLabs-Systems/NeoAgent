/* NeoAgent landing v3 — interactions */
(function () {
  'use strict';
  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ---- nav scrolled ---- */
  const nav = document.querySelector('.nav');
  const onScroll = () => nav.classList.toggle('scrolled', window.scrollY > 12);
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  /* ---- mobile menu ---- */
  const toggle = document.querySelector('.nav-toggle');
  if (toggle) {
    toggle.addEventListener('click', () => nav.classList.toggle('open'));
    nav.querySelectorAll('.mobile-menu a').forEach((a) =>
      a.addEventListener('click', () => nav.classList.remove('open'))
    );
  }

  /* ---- scroll reveals (rect-based) ---- */
  const reveals = Array.from(document.querySelectorAll('.reveal'));
  let pending = reveals.slice();
  const check = () => {
    const vh = window.innerHeight;
    pending = pending.filter((el) => {
      const r = el.getBoundingClientRect();
      if (r.top < vh * 0.9 && r.bottom > 0) { el.classList.add('in'); return false; }
      return true;
    });
    if (!pending.length) window.removeEventListener('scroll', onRev);
  };
  let tick = false;
  const onRev = () => { if (tick) return; tick = true; requestAnimationFrame(() => { check(); tick = false; }); };
  window.addEventListener('scroll', onRev, { passive: true });
  window.addEventListener('resize', onRev, { passive: true });
  requestAnimationFrame(check);
  // safety nets: all reveals + hero animated elements
  setTimeout(() => {
    reveals.forEach((el) => el.classList.add('in'));
    const heroEls = document.querySelectorAll('.hero h1 .w, .hero .pill, .hero .lede, .hero-actions, .hero-note');
    heroEls.forEach((el) => { el.style.animation = 'none'; el.style.opacity = '1'; el.style.transform = 'none'; el.style.filter = 'none'; });
  }, 1200);

  /* ---- scroll progress ---- */
  const bar = document.createElement('div');
  bar.className = 'scroll-progress';
  document.body.appendChild(bar);
  const onProg = () => {
    const h = document.documentElement.scrollHeight - window.innerHeight;
    bar.style.width = (h > 0 ? (window.scrollY / h) * 100 : 0) + '%';
  };
  window.addEventListener('scroll', onProg, { passive: true });
  onProg();

  if (reduced) return;

  /* ---- github pages: hide sign-in (no app at /app on static host) ---- */
  if (location.hostname.includes('github.io')) {
    document.querySelectorAll('a.signin').forEach((a) => (a.style.display = 'none'));
  }

  /* ---- hero parallax ---- */
  const stage = document.querySelector('.hero-stage');
  const orbitStage = document.querySelector('.orbit-stage');
  let raf = null;
  const onPar = () => {
    if (raf) return;
    raf = requestAnimationFrame(() => {
      const y = window.scrollY;
      if (stage) stage.style.transform = `translateY(${Math.min(y, 500) * -0.028}px)`;
      if (orbitStage) orbitStage.style.transform = `translateY(${Math.min(y, 400) * -0.015}px)`;
      raf = null;
    });
  };
  window.addEventListener('scroll', onPar, { passive: true });
})();
