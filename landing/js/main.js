/* NeoAgent landing — Control Surface interactions */
(function () {
  'use strict';

  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const nav = document.querySelector('[data-nav]');
  const toggle = document.querySelector('[data-nav-toggle]');
  const mobileMenu = document.querySelector('[data-mobile-menu]');

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

  // Duplicate marquee content for seamless loop
  document.querySelectorAll('[data-marquee]').forEach((row) => {
    row.innerHTML = row.innerHTML + row.innerHTML;
  });

  // Scroll reveals
  const reveals = Array.from(document.querySelectorAll('.reveal'));
  let pending = reveals.slice();
  const checkReveals = () => {
    const vh = window.innerHeight;
    pending = pending.filter((el) => {
      const rect = el.getBoundingClientRect();
      if (rect.top < vh * 0.9 && rect.bottom > 0) {
        el.classList.add('in');
        return false;
      }
      return true;
    });
    if (!pending.length) {
      window.removeEventListener('scroll', onReveal);
      window.removeEventListener('resize', onReveal);
    }
  };

  let revealTick = false;
  const onReveal = () => {
    if (revealTick) return;
    revealTick = true;
    requestAnimationFrame(() => {
      checkReveals();
      revealTick = false;
    });
  };

  window.addEventListener('scroll', onReveal, { passive: true });
  window.addEventListener('resize', onReveal, { passive: true });
  requestAnimationFrame(checkReveals);
  setTimeout(() => reveals.forEach((el) => el.classList.add('in')), 1400);

  // Scroll progress
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

  // Hide sign-in on static GitHub Pages hosts
  if (location.hostname.includes('github.io')) {
    document.querySelectorAll('a.signin').forEach((a) => {
      a.style.display = 'none';
    });
  }

  if (reduced) return;

  // Subtle hero parallax
  const stage = document.querySelector('.product-stage');
  let raf = null;
  const onParallax = () => {
    if (raf) return;
    raf = requestAnimationFrame(() => {
      if (stage) {
        const y = Math.min(window.scrollY, 480);
        stage.style.transform = `translateY(${y * -0.03}px)`;
      }
      raf = null;
    });
  };
  window.addEventListener('scroll', onParallax, { passive: true });
})();
