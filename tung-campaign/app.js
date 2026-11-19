(() => {
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const store = {
    get(k, d) { try { const v = localStorage.getItem(k); return v === null ? d : JSON.parse(v); } catch { return d; } },
    set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch {} }
  };

  /* ---------- Intro curtain ---------- */
  window.addEventListener('load', () => {
    setTimeout(() => $('#curtain').classList.add('done'), 1700);
    document.body.classList.add('loaded');
  });

  /* ---------- Wood-drum sound (Web Audio, no files) ---------- */
  let ctx;
  function tung(pitch = 1) {
    try {
      ctx = ctx || new (window.AudioContext || window.webkitAudioContext)();
      const t = ctx.currentTime;
      const o = ctx.createOscillator(), g = ctx.createGain();
      o.type = 'sine';
      o.frequency.setValueAtTime(260 * pitch, t);
      o.frequency.exponentialRampToValueAtTime(110 * pitch, t + 0.18);
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(0.9, t + 0.005);
      g.gain.exponentialRampToValueAtTime(0.0001, t + 0.35);
      o.connect(g).connect(ctx.destination);
      o.start(t); o.stop(t + 0.4);
      // woody click
      const len = ctx.sampleRate * 0.03, buf = ctx.createBuffer(1, len, ctx.sampleRate), d = buf.getChannelData(0);
      for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / len);
      const n = ctx.createBufferSource(), f = ctx.createBiquadFilter(), ng = ctx.createGain();
      n.buffer = buf; f.type = 'bandpass'; f.frequency.value = 1800 * pitch; ng.gain.value = 0.5;
      n.connect(f).connect(ng).connect(ctx.destination); n.start(t);
    } catch {}
  }

  /* ---------- Floating background words ---------- */
  const fw = $('#floatWords');
  const words = ['TUNG', 'TUNG', 'TUNG', 'SAHUR', 'VOTE', 'TUNG', '🥁', 'LOG'];
  for (let i = 0; i < 22; i++) {
    const s = document.createElement('span');
    s.textContent = words[i % words.length];
    s.style.left = Math.random() * 100 + '%';
    s.style.fontSize = (1.5 + Math.random() * 5) + 'rem';
    s.style.animationDuration = (14 + Math.random() * 20) + 's';
    s.style.animationDelay = (-Math.random() * 30) + 's';
    s.style.setProperty('--r', (Math.random() * 60 - 30) + 'deg');
    fw.appendChild(s);
  }

  /* ---------- Confetti ---------- */
  const cv = $('#confetti'), cx = cv.getContext('2d');
  let parts = [], raf = null;
  function resize() { cv.width = innerWidth * devicePixelRatio; cv.height = innerHeight * devicePixelRatio; }
  resize(); addEventListener('resize', resize);
  const colors = ['#d62839', '#ffc93c', '#0d1b3e', '#fcf1d8', '#7096a0', '#a8652f'];
  function confetti(n = 120, x = innerWidth / 2, y = innerHeight / 3, emoji = false) {
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2, v = 4 + Math.random() * 10;
      parts.push({ x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v - 6, r: Math.random() * 6.28, vr: Math.random() * .3 - .15,
        s: 6 + Math.random() * 8, c: colors[i % colors.length], life: 160, e: emoji && Math.random() < .25 ? (Math.random() < .5 ? '🥁' : '⚾') : null });
    }
    if (!raf) loop();
  }
  function loop() {
    cx.setTransform(devicePixelRatio, 0, 0, devicePixelRatio, 0, 0);
    cx.clearRect(0, 0, innerWidth, innerHeight);
    parts = parts.filter(p => p.life-- > 0 && p.y < innerHeight + 40);
    for (const p of parts) {
      p.vy += .25; p.vx *= .99; p.x += p.vx; p.y += p.vy; p.r += p.vr;
      cx.save(); cx.translate(p.x, p.y); cx.rotate(p.r);
      if (p.e) { cx.font = '22px serif'; cx.fillText(p.e, -11, 8); }
      else { cx.fillStyle = p.c; cx.fillRect(-p.s / 2, -p.s / 4, p.s, p.s / 2); }
      cx.restore();
    }
    raf = parts.length ? requestAnimationFrame(loop) : (cx.clearRect(0, 0, innerWidth, innerHeight), null);
  }

  /* ---------- Big drum button ---------- */
  let total = store.get('ttts-tungs', 0) + 1000000 + Math.floor(Math.random() * 999);
  const tc = $('#tungCount');
  const fmt = n => n.toLocaleString('en-US');
  tc.textContent = fmt(total);
  const title = $('.hero-title');
  let seq = 0;
  $('#bigDrum').addEventListener('click', e => {
    seq++;
    const isSahur = seq % 4 === 0;
    tung(isSahur ? .7 : 1 + (seq % 4) * .08);
    total++; tc.textContent = fmt(total);
    store.set('ttts-tungs', store.get('ttts-tungs', 0) + 1);
    document.body.classList.remove('shake'); void document.body.offsetWidth; document.body.classList.add('shake');
    title.classList.remove('thump'); void title.offsetWidth; title.classList.add('thump');
    const r = e.currentTarget.getBoundingClientRect();
    confetti(isSahur ? 160 : 30, r.left + r.width / 2, r.top, isSahur);
  });

  /* ---------- Scroll: progress, nav ---------- */
  const bar = $('#progress-bar'), plog = $('#progress-log'), nav = $('#nav');
  function onScroll() {
    const h = document.documentElement.scrollHeight - innerHeight;
    const p = h > 0 ? scrollY / h : 0;
    bar.style.width = (p * 100) + '%';
    plog.style.left = (p * 100) + '%';
    plog.style.transform = `translateX(-50%) rotate(${scrollY / 3}deg)`;
    nav.classList.toggle('scrolled', scrollY > 40);
  }
  addEventListener('scroll', onScroll, { passive: true }); onScroll();

  /* ---------- Reveal on scroll ---------- */
  const io = new IntersectionObserver(es => es.forEach(en => {
    if (!en.isIntersecting) return;
    en.target.classList.add('in');
    io.unobserve(en.target);
  }), { threshold: .15 });
  $$('.reveal,.reveal-left,.reveal-right,.final,.tcard,.contrast').forEach(el => io.observe(el));
  // stagger
  $$('.cards .flip, .tgrid .tcard').forEach((el, i) => el.style.transitionDelay = (i % 3) * 0.12 + 's');

  /* ---------- Counters ---------- */
  const cio = new IntersectionObserver(es => es.forEach(en => {
    if (!en.isIntersecting) return;
    const el = en.target, to = +el.dataset.to, suf = el.dataset.suffix || '';
    const start = performance.now(), dur = 1400;
    (function step(now) {
      const k = Math.min(1, (now - start) / dur), e = 1 - Math.pow(1 - k, 3);
      el.textContent = Math.round(to * e) + suf;
      if (k < 1) requestAnimationFrame(step);
    })(start);
    cio.unobserve(el);
  }), { threshold: .6 });
  $$('.count').forEach(el => cio.observe(el));

  /* ---------- Legend typewriter ---------- */
  const lt = $('#legendText');
  const lio = new IntersectionObserver(es => {
    if (!es[0].isIntersecting) return;
    lio.disconnect();
    const txt = lt.dataset.text; let i = 0;
    (function type() {
      lt.textContent = txt.slice(0, ++i);
      const ch = txt[i - 1];
      if (txt.slice(i - 4, i).toLowerCase() === 'tung') tung(1 + Math.random() * .1);
      if (i < txt.length) setTimeout(type, ch === ',' || ch === '.' ? 180 : 28);
    })();
  }, { threshold: .5 });
  lio.observe(lt);

  /* ---------- Scary section ---------- */
  const scary = $('#attack');
  $$('.scary-line').forEach(l => l.style.transitionDelay = (l.dataset.delay * 1.1) + 's');
  const sio = new IntersectionObserver(es => {
    if (!es[0].isIntersecting) return;
    scary.classList.add('on'); sio.disconnect();
    [8.0, 8.6, 9.2].forEach(d => setTimeout(() => tung(.6), d * 1000));
  }, { threshold: .35 });
  sio.observe(scary);

  /* ---------- Flip cards ---------- */
  $$('.flip').forEach(f => f.addEventListener('click', () => { f.classList.toggle('flipped'); tung(1.3); }));

  /* ---------- Endorsement rotator ---------- */
  const qs = $$('#quotes blockquote'); let qi = 0;
  setInterval(() => { qs[qi].classList.remove('active'); qi = (qi + 1) % qs.length; qs[qi].classList.add('active'); }, 3200);

  /* ---------- Happy campaign music (Transfer) ---------- */
  $('#anthem').addEventListener('click', e => {
    try {
      ctx = ctx || new (window.AudioContext || window.webkitAudioContext)();
      const notes = [523, 659, 784, 1047, 0, 784, 1047, 0, 880, 784, 659, 784, 1047];
      const durs  = [.18, .18, .18, .45, .05, .18, .5, .1, .2, .2, .2, .2, .7];
      let t = ctx.currentTime + .05;
      notes.forEach((f, i) => {
        if (f) {
          const o = ctx.createOscillator(), g = ctx.createGain();
          o.type = 'triangle'; o.frequency.value = f;
          g.gain.setValueAtTime(.0001, t); g.gain.exponentialRampToValueAtTime(.35, t + .02);
          g.gain.exponentialRampToValueAtTime(.0001, t + durs[i] * .95);
          o.connect(g).connect(ctx.destination); o.start(t); o.stop(t + durs[i]);
        }
        t += durs[i];
      });
    } catch {}
    const r = e.currentTarget.getBoundingClientRect();
    confetti(120, r.left + r.width / 2, r.top, true);
  });

  /* ---------- Debate ---------- */
  const script = [
    ['m', 'MODERATOR', 'Welcome to the first presidential debate. Candidates, your opening statements.'],
    ['t', 'TUNG', 'Tung tung tung tung tung tung tung tung tung. Sahur.'],
    ['s', 'SNOOZE', 'Ugh… just… five more minutes…'],
    ['m', 'MODERATOR', 'Mr. Sahur, what is your plan for the economy?'],
    ['t', 'TUNG', 'Breakfast. Earlier. For everyone. Breakfast is the economy.'],
    ['m', 'MODERATOR', 'Mr. Button, your response?'],
    ['s', 'SNOOZE', 'zzzzz…'],
    ['m', 'MODERATOR', 'Mr. Button, you have used your snooze 9 times. Your time is up.'],
    ['t', 'TUNG', 'My opponent has been asleep for this entire debate. I have been awake since 3 AM. Like YOU, the working family.'],
    ['s', 'SNOOZE', 'That\'s a log with a bat. He keeps showing up at people\'s houses!'],
    ['t', 'TUNG', 'That\'s called DOOR-TO-DOOR CAMPAIGNING. 🥁'],
    ['m', 'MODERATOR', '[Audience erupts. Chants of “TUNG TUNG SUPPORT US!”]'],
    ['m', 'MODERATOR', 'Post-debate poll: TUNG WINS 94% – 5%. (1% was a cowbell.)']
  ];
  const tr = $('#transcript'), pl = $('.podium.left'), pr = $('.podium.right');
  let dTimer = null;
  function playDebate() {
    clearTimeout(dTimer); tr.innerHTML = ''; let i = 0;
    (function next() {
      pl.classList.remove('talking'); pr.classList.remove('talking');
      if (i >= script.length) { confetti(140, innerWidth / 2, innerHeight / 2, true); return; }
      const [k, who, text] = script[i++];
      const m = document.createElement('div'); m.className = 'msg ' + k;
      m.innerHTML = `<b>${who}</b>`; m.appendChild(document.createTextNode(text));
      tr.appendChild(m); tr.scrollTop = tr.scrollHeight;
      if (k === 't') { pl.classList.add('talking'); tung(); }
      if (k === 's') pr.classList.add('talking');
      dTimer = setTimeout(next, 900 + text.length * 28);
    })();
  }
  $('#replayDebate').addEventListener('click', playDebate);
  const dio = new IntersectionObserver(es => { if (es[0].isIntersecting) { dio.disconnect(); playDebate(); } }, { threshold: .4 });
  dio.observe(tr);

  /* ---------- Wake-up game ---------- */
  const logBtn = $('#logBtn'), fill = $('#meterFill'), mt = $('#meterText'), houses = $$('#houses span'), pops = $('#pops');
  let hits = 0;
  logBtn.addEventListener('click', e => {
    if (hits >= 9) { hits = 0; houses.forEach(h => h.classList.remove('lit')); }
    hits++;
    tung(hits === 9 ? .65 : 1 + hits * .03);
    logBtn.classList.remove('hit'); void logBtn.offsetWidth; logBtn.classList.add('hit');
    setTimeout(() => logBtn.classList.remove('hit'), 90);
    fill.style.width = (hits / 9 * 100) + '%';
    houses[hits - 1].classList.add('lit');
    const p = document.createElement('div'); p.className = 'pop';
    p.textContent = hits === 9 ? 'SAHUR!!' : 'TUNG';
    p.style.setProperty('--dx', (Math.random() * 240 - 120) + 'px');
    p.style.setProperty('--dr', (Math.random() * 60 - 30) + 'deg');
    if (hits === 9) { p.style.fontSize = '3rem'; p.style.color = '#0d1b3e'; }
    pops.appendChild(p); setTimeout(() => p.remove(), 1000);
    mt.textContent = hits === 9 ? '🎉 9 / 9 — EVERYONE IS AWAKE AND VOTING TUNG! (tap to go again)' : `${hits} / 9 tungs`;
    if (hits === 9) confetti(200, e.clientX || innerWidth / 2, e.clientY || innerHeight / 2, true);
  });

  /* ---------- Pledge ---------- */
  const pc = $('#pledgeCount');
  let pledges = 48213 + store.get('ttts-pledges', 0);
  pc.textContent = fmt(pledges);
  setInterval(() => { if (Math.random() < .5) { pledges++; pc.textContent = fmt(pledges); } }, 2500);
  $('#pledgeForm').addEventListener('submit', e => {
    e.preventDefault();
    const name = $('#pledgeName').value.trim() || 'A Plain Folk';
    $('#certName').textContent = name;
    const c = $('#certificate'); c.hidden = false;
    const ci = $('.cert-in'); ci.style.animation = 'none'; void ci.offsetWidth; ci.style.animation = '';
    pledges++; pc.textContent = fmt(pledges);
    store.set('ttts-pledges', store.get('ttts-pledges', 0) + 1);
    [0, 150, 300].forEach((d, i) => setTimeout(() => tung(1 - i * .15), d));
    confetti(220, innerWidth / 2, innerHeight / 2, true);
    c.scrollIntoView({ behavior: 'smooth', block: 'center' });
  });
})();
