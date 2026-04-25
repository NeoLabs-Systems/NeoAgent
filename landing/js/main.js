document.addEventListener('DOMContentLoaded', () => {
  initScrollReveal();
  initNavScroll();
  initMobileNav();
  initTypingEffect();
  initParticles();
  initCountUp();
});

// ── Scroll Reveal ──
function initScrollReveal() {
  const els = document.querySelectorAll('.reveal, .reveal-left, .reveal-right, .reveal-scale');
  if (!els.length) return;

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });

  els.forEach(el => observer.observe(el));
}

// ── Nav: frosted glass on scroll ──
function initNavScroll() {
  const nav = document.querySelector('.nav');
  if (!nav) return;

  const toggle = () => {
    nav.classList.toggle('scrolled', window.scrollY > 40);
  };

  window.addEventListener('scroll', toggle, { passive: true });
  toggle();
}

// ── Mobile hamburger ──
function initMobileNav() {
  const toggle = document.querySelector('.nav__mobile-toggle');
  const links = document.querySelector('.nav__links');
  if (!toggle || !links) return;

  toggle.addEventListener('click', () => {
    links.classList.toggle('open');
    const open = links.classList.contains('open');
    toggle.setAttribute('aria-expanded', String(open));
  });

  links.querySelectorAll('a').forEach(a => {
    a.addEventListener('click', () => links.classList.remove('open'));
  });
}

// ── Terminal typing effect ──
function initTypingEffect() {
  const el = document.getElementById('typed-command');
  if (!el) return;

  const commands = [
    { prompt: '~$', text: 'npm install -g neoagent', delay: 800 },
    { prompt: '~$', text: 'neoagent install', delay: 600 },
  ];

  const outputLines = [
    '✓ Dependencies installed',
    '✓ Web client built',
    '✓ Service started on :3456',
    '✓ NeoAgent is running',
  ];

  let commandIdx = 0;
  let charIdx = 0;
  const container = el;

  async function sleep(ms) {
    return new Promise(r => setTimeout(r, ms));
  }

  async function typeCommand(cmd) {
    const lineEl = document.createElement('div');
    lineEl.className = 'terminal__line';

    const promptEl = document.createElement('span');
    promptEl.className = 'terminal__prompt';
    promptEl.textContent = cmd.prompt + ' ';
    lineEl.appendChild(promptEl);

    const textEl = document.createElement('span');
    textEl.className = 'terminal__command';
    lineEl.appendChild(textEl);

    const cursor = document.createElement('span');
    cursor.className = 'terminal__cursor';
    lineEl.appendChild(cursor);

    container.appendChild(lineEl);

    for (let i = 0; i < cmd.text.length; i++) {
      textEl.textContent += cmd.text[i];
      await sleep(35 + Math.random() * 30);
    }

    cursor.remove();
    await sleep(cmd.delay);
  }

  async function typeOutput(lines) {
    for (const line of lines) {
      const lineEl = document.createElement('div');
      lineEl.className = 'terminal__output';
      lineEl.textContent = line;
      lineEl.style.opacity = '0';
      lineEl.style.transform = 'translateY(4px)';
      container.appendChild(lineEl);
      await sleep(60);
      lineEl.style.transition = 'all 0.3s ease';
      lineEl.style.opacity = '1';
      lineEl.style.transform = 'translateY(0)';
      await sleep(280);
    }
  }

  async function run() {
    for (const cmd of commands) {
      await typeCommand(cmd);
    }
    await typeOutput(outputLines);

    // Add final cursor
    await sleep(300);
    const finalLine = document.createElement('div');
    finalLine.className = 'terminal__line';
    const finalPrompt = document.createElement('span');
    finalPrompt.className = 'terminal__prompt';
    finalPrompt.textContent = '~$ ';
    finalLine.appendChild(finalPrompt);
    const finalCursor = document.createElement('span');
    finalCursor.className = 'terminal__cursor';
    finalLine.appendChild(finalCursor);
    container.appendChild(finalLine);
  }

  const observer = new IntersectionObserver((entries) => {
    if (entries[0].isIntersecting) {
      observer.disconnect();
      setTimeout(run, 400);
    }
  }, { threshold: 0.3 });

  observer.observe(container);
}

// ── Canvas particle field ──
function initParticles() {
  const canvas = document.getElementById('particle-canvas');
  if (!canvas) return;

  const ctx = canvas.getContext('2d');
  let particles = [];
  const PARTICLE_COUNT = 60;
  let w, h;
  let animId;

  function resize() {
    const dpr = window.devicePixelRatio || 1;
    const rect = canvas.parentElement.getBoundingClientRect();
    w = rect.width;
    h = rect.height;
    canvas.width = w * dpr;
    canvas.height = h * dpr;
    canvas.style.width = w + 'px';
    canvas.style.height = h + 'px';
    ctx.scale(dpr, dpr);
  }

  function createParticle() {
    return {
      x: Math.random() * w,
      y: Math.random() * h,
      size: Math.random() * 1.5 + 0.5,
      speedX: (Math.random() - 0.5) * 0.3,
      speedY: (Math.random() - 0.5) * 0.3,
      opacity: Math.random() * 0.4 + 0.1,
      pulseSpeed: Math.random() * 0.01 + 0.005,
      pulseOffset: Math.random() * Math.PI * 2,
    };
  }

  function init() {
    resize();
    particles = Array.from({ length: PARTICLE_COUNT }, createParticle);
  }

  let frame = 0;
  function draw() {
    ctx.clearRect(0, 0, w, h);
    frame++;

    particles.forEach(p => {
      p.x += p.speedX;
      p.y += p.speedY;

      if (p.x < 0) p.x = w;
      if (p.x > w) p.x = 0;
      if (p.y < 0) p.y = h;
      if (p.y > h) p.y = 0;

      const pulse = Math.sin(frame * p.pulseSpeed + p.pulseOffset) * 0.3 + 0.7;
      const alpha = p.opacity * pulse;

      ctx.beginPath();
      ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(199, 163, 106, ${alpha})`;
      ctx.fill();
    });

    // Draw connections between close particles
    for (let i = 0; i < particles.length; i++) {
      for (let j = i + 1; j < particles.length; j++) {
        const dx = particles[i].x - particles[j].x;
        const dy = particles[i].y - particles[j].y;
        const dist = Math.sqrt(dx * dx + dy * dy);

        if (dist < 120) {
          const alpha = (1 - dist / 120) * 0.08;
          ctx.beginPath();
          ctx.moveTo(particles[i].x, particles[i].y);
          ctx.lineTo(particles[j].x, particles[j].y);
          ctx.strokeStyle = `rgba(199, 163, 106, ${alpha})`;
          ctx.lineWidth = 0.5;
          ctx.stroke();
        }
      }
    }

    animId = requestAnimationFrame(draw);
  }

  init();
  draw();

  let resizeTimer;
  window.addEventListener('resize', () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => {
      resize();
      particles.forEach(p => { p.x = Math.min(p.x, w); p.y = Math.min(p.y, h); });
    }, 200);
  });
}

// ── Count-up animation for stats ──
function initCountUp() {
  const els = document.querySelectorAll('[data-count]');
  if (!els.length) return;

  const observer = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        const el = entry.target;
        const target = parseInt(el.dataset.count, 10);
        const suffix = el.dataset.suffix || '';
        const duration = 2000;
        const startTime = performance.now();

        function update(now) {
          const elapsed = now - startTime;
          const progress = Math.min(elapsed / duration, 1);
          const eased = 1 - Math.pow(1 - progress, 4);
          el.textContent = Math.floor(target * eased) + suffix;

          if (progress < 1) requestAnimationFrame(update);
        }

        requestAnimationFrame(update);
        observer.unobserve(el);
      }
    });
  }, { threshold: 0.5 });

  els.forEach(el => observer.observe(el));
}
