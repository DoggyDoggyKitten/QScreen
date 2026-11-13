'use strict';

const DOWNLOAD = 'https://github.com/DoggyDoggyKitten/QScreen/releases/download/v1.0.0/QScreen-1.0.0-notarized.dmg';
const REPO = 'https://github.com/DoggyDoggyKitten/QScreen';
const presets = [
  { id: 'lunch', title: 'Out for lunch', short: 'Lunch', pal: 'Lunch Bear', minutes: 30, bg: '#f7f0e3', body: '#bd8865' },
  { id: 'meeting', title: 'In a meeting', short: 'Meeting', pal: 'Meeting Bunny', minutes: 60, bg: '#f0edf7', body: '#ebddc9' },
  { id: 'coffee', title: 'Coffee break', short: 'Coffee', pal: 'Coffee Cat', minutes: 10, bg: '#ecf0f3', body: '#919da9' },
  { id: 'restroom', title: 'Restroom break', short: 'Restroom', pal: 'Restroom Duck', minutes: 5, bg: '#eef3f0', body: '#f2ca67' },
  { id: 'away', title: 'Stepped away', short: 'A little break', pal: 'Away Frog', minutes: 15, bg: '#edf2e4', body: '#9ebf93' },
  { id: 'offwork', title: 'Off for the day', short: 'Home time', pal: 'Sleepy Fox', minutes: 0, bg: '#252d45', body: '#df9673' },
];
const state = { view: 0, reason: 'lunch', minutes: 30, menu: false, desktop: true };
const icon = (name, size = 20) => {
  const paths = {
    download: '<path d="M12 3v12m-4-4 4 4 4-4M5 16v4h14v-4"/>',
    arrow: '<path d="M5 12h14m-5-5 5 5-5 5"/>',
    chevron: '<path d="m8 10 4 4 4-4"/>',
    check: '<path d="m5 12 4 4L19 6"/>',
    lock: '<rect x="5" y="10" width="14" height="11" rx="3"/><path d="M8 10V7a4 4 0 0 1 8 0v3m-4 5v2"/>',
    sparkle: '<path d="m12 3 2.6 6.4L21 12l-6.4 2.6L12 21l-2.6-6.4L3 12l6.4-2.6Z"/>',
    menu: '<rect x="3" y="7" width="18" height="14" rx="3"/><path d="M6 3h12M5 5h14m-2 5v6m-3-3h6M7 13h3m-1.5-1.5v3"/>',
    expand: '<path d="M8 3H3v5m13-5h5v5M3 16v5h5m13-5v5h-5"/>',
    close: '<path d="m6 6 12 12M18 6 6 18"/>',
    github: '<path d="M9 19c-4 1-4-2-6-2m12 4v-3.4c0-1 .1-1.4-.5-2 3.4-.4 6-1.6 6-6a4.6 4.6 0 0 0-1.3-3.2A4.3 4.3 0 0 0 19 3s-1.3-.4-3.4 1.3a11.8 11.8 0 0 0-6.2 0C7.2 2.6 6 3 6 3a4.3 4.3 0 0 0-.2 3.4A4.6 4.6 0 0 0 4.5 9.6c0 4.4 2.6 5.6 6 6-.6.6-.6 1.2-.5 2V21"/>',
    apple: '<path fill="currentColor" stroke="none" d="M16.8 12.6c0-2 1.6-3 1.7-3.1-1-1.5-2.6-1.7-3.2-1.7-1.4-.2-2.7.8-3.4.8-.7 0-1.8-.8-3-.8-1.5 0-2.9.9-3.7 2.2-1.6 2.8-.4 7 1.1 9.2.8 1.1 1.6 2.2 2.8 2.1 1.1 0 1.5-.7 2.9-.7s1.8.7 3 .7c1.3 0 2-1.1 2.7-2.1.9-1.3 1.2-2.6 1.3-2.7-.1 0-2.2-.8-2.2-3.9ZM14.5 6.3c.6-.8 1.1-1.9 1-3-.9 0-2 .6-2.7 1.4-.6.7-1.2 1.8-1 2.9 1 .1 2.1-.6 2.7-1.3Z"/>',
  };
  return `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths[name] || paths.sparkle}</svg>`;
};

// Web vector counterparts of the app's own artwork in Shared/QSSceneView.m.
// All six characters use the same coordinates, proportions and native palette.
function animal(id, extraClass = '') {
  const p = presets.find(preset => preset.id === id) || presets[0];
  const body = p.body, ink = '#39443f', cream = '#fff6e5';
  const ellipse = (x, y, w, h, fill, more = '') => `<ellipse cx="${x + w / 2}" cy="${y + h / 2}" rx="${w / 2}" ry="${h / 2}" fill="${fill}" ${more}/>`;
  const rect = (x, y, w, h, r, fill) => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" fill="${fill}"/>`;
  const path = (d, fill, stroke = 'none', width = 0, cls = '') => `<path d="${d}" fill="${fill}" stroke="${stroke}" stroke-width="${width}" stroke-linecap="round" stroke-linejoin="round" class="${cls}"/>`;
  const triangle = (x, y, w, h, fill) => path(`M${x} ${y + h}L${x + w / 2} ${y}L${x + w} ${y + h}Z`, fill);
  const curve = (d, stroke, width, cls = '') => path(d, 'none', stroke, width, cls);
  let art = '';
  if (id === 'offwork') art += ellipse(65, 25, 105, 120, body) + ellipse(109, 34, 58, 67, cream);
  if (id === 'coffee') art += curve('M85 100C165 130 170 40 142 44', body, 24);
  art += rect(-86, -15, 172, 169, 72, body) + ellipse(-72, 125, 62, 36, body) + ellipse(10, 125, 62, 36, body);
  art += ellipse(-49, 15, 98, 115, cream, 'opacity=".48"');
  if (id === 'meeting') art += rect(-76, -203, 48, 137, 24, body) + rect(28, -212, 48, 146, 24, body) + rect(-63, -189, 22, 103, 11, '#dfb6b1') + rect(41, -198, 22, 112, 11, '#dfb6b1');
  if (id === 'coffee' || id === 'offwork') {
    art += triangle(-98, -151, 78, 95, body) + triangle(20, -151, 78, 95, body);
    art += triangle(-81, -132, 44, 61, id === 'coffee' ? '#c7b5b6' : '#f3c0a2') + triangle(37, -132, 44, 61, id === 'coffee' ? '#c7b5b6' : '#f3c0a2');
  }
  if (id === 'lunch') art += ellipse(-105, -130, 67, 67, body) + ellipse(38, -130, 67, 67, body) + ellipse(-92, -117, 41, 41, '#e5b99b') + ellipse(51, -117, 41, 41, '#e5b99b');
  if (id === 'away') art += ellipse(-96, -137, 75, 78, body) + ellipse(21, -137, 75, 78, body);
  if (id === 'restroom') art += curve('M-8-105C-5-140 23-158 13-145', body, 12);
  art += ellipse(-106, -111, 212, 180, body);
  if (id === 'offwork') art += ellipse(-84, -43, 88, 83, cream) + ellipse(-4, -43, 88, 83, cream);
  if (id === 'lunch') art += ellipse(-46, -19, 92, 68, '#eed1ae');
  if (id === 'coffee') art += curve('M-18-100l6 26M0-104v28M18-100l-6 26', '#657586', 7);
  const eyeY = id === 'away' ? -100 : -39;
  if (id === 'offwork') art += curve(`M-51 ${eyeY}C-43 ${eyeY + 8} -36 ${eyeY + 8} -28 ${eyeY}M28 ${eyeY}C36 ${eyeY + 8} 43 ${eyeY + 8} 51 ${eyeY}`, ink, 5);
  else {
    let eyes = '';
    if (id === 'away') eyes += ellipse(-80, -123, 44, 49, cream) + ellipse(36, -123, 44, 49, cream);
    eyes += ellipse(id === 'away' ? -65 : -46, eyeY, 12, 17, ink) + ellipse(id === 'away' ? 53 : 34, eyeY, 12, 17, ink);
    eyes += ellipse(id === 'away' ? -62 : -43, eyeY + 2, 4, 5, 'white') + ellipse(id === 'away' ? 56 : 37, eyeY + 2, 4, 5, 'white');
    art += `<g class="pal-eyes">${eyes}</g>`;
  }
  art += ellipse(-78, -14, 27, 16, '#e69f91', 'opacity=".75"') + ellipse(51, -14, 27, 16, '#e69f91', 'opacity=".75"');
  if (id === 'restroom') art += rect(-34, -10, 68, 29, 15, '#db9351') + curve('M-20 4h40', '#b97645', 3);
  else if (id === 'away') art += curve('M-31-10C-15 10 15 10 31-10', ink, 5);
  else art += ellipse(-8, -9, 16, 11, ink) + curve('M-17 12C-11 21-4 21 0 10C4 21 11 21 17 12', ink, 3);
  if (id === 'coffee') art += curve('M-78 8l-38-8M-77 20l-38 6M78 8l38-8M77 20l38 6', ink, 3);
  if (id === 'lunch') art += path('M-43 115C-55 112-55 100-45 88L-13 42C-7 30 7 30 13 42L45 88C55 100 55 112 43 115Z', cream) + rect(-18, 82, 36, 35, 4, '#4a6554') + ellipse(-70, 74, 43, 36, body) + ellipse(27, 74, 43, 36, body);
  if (id === 'meeting') art += rect(-116, 70, 232, 91, 13, '#a4a9c7') + ellipse(-10, 106, 20, 20, '#daddec') + rect(-130, 155, 260, 10, 5, '#838ba9') + ellipse(-94, 53, 37, 25, body) + ellipse(57, 53, 37, 25, body) + '<g fill="none" stroke="#827987" stroke-width="4"><ellipse cx="-38" cy="-33.5" rx="24" ry="21.5"/><ellipse cx="38" cy="-33.5" rx="24" ry="21.5"/><path d="M-14-36h28"/></g>';
  if (id === 'coffee') art += '<ellipse cx="47" cy="84" rx="24" ry="21" fill="none" stroke="#faf3e6" stroke-width="12"/>' + rect(-42, 54, 85, 75, 14, '#faf3e6') + ellipse(-31, 48, 63, 16, '#8a6652') + ellipse(-70, 81, 42, 32, body) + ellipse(29, 81, 35, 32, body) + curve('M-22 30C-40 16-6 7-26-10M0 30C-18 16 16 7-4-10M22 30C4 16 38 7 18-10', '#a4aaa2', 4, 'steam');
  if (id === 'restroom') art += rect(-70, 58, 140, 58, 23, '#f9faec') + curve('M-62 80H62', '#c9ded3', 3) + ellipse(-103, 41, 43, 31, body) + ellipse(60, 41, 43, 31, body) + '<g fill="none" stroke="#7dafad" stroke-width="3" opacity=".5" class="bubbles"><circle cx="-137" cy="-121" r="10"/><circle cx="125" cy="-79" r="14"/><circle cx="155" cy="-153" r="8"/></g>';
  if (id === 'away') art += rect(-93, 21, 186, 26, 12, '#dbab74') + rect(39, 28, 29, 89, 10, '#dbab74') + ellipse(-125, 70, 48, 37, body) + ellipse(77, 70, 48, 37, body) + curve('M-143-36l-19-16M143-36l19-16', '#7fa376', 5);
  if (id === 'offwork') art += rect(-101, 69, 202, 92, 40, '#b1aecf') + [-67, -22, 23, 68].map(x => ellipse(x, 112, 8, 8, '#d8d3ea')).join('') + '<g fill="#b1aecf" font-family="Nunito,sans-serif" font-weight="800" class="sleep-z"><text x="116" y="-69" font-size="29">z</text><text x="153" y="-116" font-size="38">z</text></g>';
  return `<svg class="animal ${extraClass}" viewBox="0 0 500 470" fill="none" aria-hidden="true"><ellipse cx="250" cy="411" rx="132" ry="11.5" fill="${id === 'offwork' ? '#fff' : ink}" opacity=".07"/><g class="pal-motion"><g transform="translate(250 245)">${art}</g></g></svg>`;
}

const selected = () => presets.find(p => p.id === state.reason);
const returnText = () => state.reason === 'offwork' ? 'See you tomorrow' : `Back in about ${state.minutes} ${state.minutes === 1 ? 'minute' : 'minutes'}`;
const download = (label = 'Download for Mac', small = false) => `<a class="button primary ${small ? 'small' : ''}" href="${DOWNLOAD}">${icon('apple', 21)}${label}${icon('arrow', 18)}</a>`;
const header = () => `<header class="site-header"><a class="brand" href="./" aria-label="QScreen home"><img src="assets/wordmark.png" width="160" height="54" alt="QScreen"></a><div class="header-actions">${state.view === 0 ? '<a class="text-link how-link" href="#how-it-works">How it works</a>' : ''}<a class="text-link github-link" href="${REPO}" target="_blank" rel="noopener noreferrer">${icon('github', 18)}<span>GitHub</span></a>${download('Get QScreen', true)}</div></header>`;
const footer = () => `<footer class="site-footer"><span>QScreen 1.0.0</span><span>macOS 13+ <i>·</i> Apple Silicon & Intel <i>·</i> <a href="${REPO}" target="_blank" rel="noopener noreferrer">GitHub ${icon('arrow', 13)}</a></span></footer>`;
const stamp = () => `<span class="trust-note">${icon('check', 14)} Apple notarized · Free & open source</span>`;
const dots = '<span class="window-dots" aria-hidden="true"><i></i><i></i><i></i></span>';

function scene(className = '') {
  const p = selected();
  return `<div class="screen-scene ${className} ${p.id === 'offwork' ? 'night' : ''}" data-scene style="--scene-bg:${p.bg}"><span class="scene-spark s1">+</span><span class="scene-spark s2">+</span><span class="scene-spark s3">·</span><span class="scene-spark s4">·</span><span class="scene-moon" aria-hidden="true"></span><div class="scene-character" data-character>${animal(p.id)}</div><div class="scene-copy"><span class="scene-title" data-status>${p.title}</span><span class="scene-return" data-return>${returnText()}</span></div><span class="scene-lock" title="Preview of the native screen saver">${icon('lock', 12)} QScreen</span></div>`;
}

function monitor(className = '', top = false) {
  return `<div class="monitor ${className}"><div class="monitor-bezel">${top ? `<div class="preview-top">${dots}<span>QScreen · Interactive preview</span><button class="icon-button" data-expand aria-label="Expand screen saver preview">${icon('expand', 14)}</button></div>` : '<span class="monitor-camera" aria-hidden="true"></span>'}${scene()}<span class="monitor-bottom" aria-hidden="true"></span></div><div class="monitor-neck" aria-hidden="true"></div><div class="monitor-foot" aria-hidden="true"></div></div>`;
}

function reasonButtons(kind = 'pills') {
  return `<div class="reason-picker ${kind}" aria-label="Choose a screen saver">${presets.map(p => `<button class="reason-button ${state.reason === p.id ? 'selected' : ''}" data-reason="${p.id}" aria-pressed="${state.reason === p.id}" style="--tile-bg:${p.bg}"><span class="reason-art">${animal(p.id)}</span><span class="reason-label">${kind === 'crew-grid' ? p.title : p.short}</span><span class="choice-check">${icon('check', 12)}</span></button>`).join('')}</div>`;
}

function timer(className = '') {
  return `<div class="time-control ${className} ${state.reason === 'offwork' ? 'is-offwork' : ''}"><span class="time-label">Back in</span><div class="time-options" aria-label="Return time">${[5, 15, 30, 60].map(n => `<button data-minutes="${n}" class="${state.minutes === n ? 'selected' : ''}" aria-pressed="${state.minutes === n}">${n}<span> min</span></button>`).join('')}</div><span class="no-timer">No timer. You’re off the clock.</span></div>`;
}

function selectionLabel() {
  return `<span class="selection-label"><span class="live-dot"></span> LIVE PREVIEW</span>`;
}

function menuRows() {
  return presets.map(p => `<button class="menu-row ${state.reason === p.id ? 'selected' : ''}" data-reason="${p.id}" data-menu-choice aria-pressed="${state.reason === p.id}"><span class="menu-avatar" style="background:${p.bg}">${animal(p.id)}</span><span>${p.title}</span><span class="menu-time">${p.minutes ? `${p.minutes} min` : 'No timer'} ${p.minutes ? icon('chevron', 11) : ''}</span></button>`).join('');
}

function desktop() {
  return `<div class="desktop-demo ${state.desktop ? '' : 'showing-saver'}"><div class="desktop-bar"><div class="desktop-mac">${icon('apple', 13)} <strong>Finder</strong><span>File</span><span>Edit</span><span>View</span></div><button class="menubar-trigger ${state.menu ? 'open' : ''}" data-toggle-menu aria-label="Open QScreen quick menu" aria-expanded="${state.menu}" aria-controls="quick-menu">${icon('menu', 23)}<span class="click-halo"></span><span class="menu-step" aria-hidden="true">1</span></button><span class="desktop-clock">9:41</span></div><div class="desktop-wallpaper"><div class="wallpaper-blob blob-one"></div><div class="wallpaper-blob blob-two"></div><span class="desktop-hello">a little room<br>for a little break.</span><div class="desktop-dock" aria-hidden="true"><i>☺</i><i>✉</i><i>✎</i><i>☀</i><i>♫</i></div></div><div class="desktop-saver" inert aria-hidden="true">${scene()}<button class="return-demo" data-return-desktop>${icon('arrow', 14)} Back to demo desktop</button></div><div class="quick-menu ${state.menu ? 'is-open' : ''}" id="quick-menu" ${state.menu ? '' : 'hidden'}>${menuRows()}<div class="menu-footer">${icon('menu', 13)} QScreen <span>English</span></div></div><button class="desktop-prompt ${state.menu || !state.desktop ? 'is-hidden' : ''}" data-demo-start><span>Click here to try it</span><svg class="prompt-arrow" viewBox="0 0 80 70" aria-hidden="true"><path d="M8 60C48 60 62 38 62 8M49 20 62 7 74 20"/></svg></button></div>`;
}

function plant() {
  return '<svg class="desk-plant" viewBox="0 0 140 235" aria-hidden="true"><path d="M70 171V59" stroke="#7b9974" stroke-width="6" stroke-linecap="round"/><path d="M70 131C9 143 1 81 35 88c22 5 26 24 35 43M72 102c59 12 68-50 34-43-22 5-26 24-34 43M70 74C21 64 25 20 49 30c16 8 17 29 21 44M73 58c32-22 19-57 1-44-13 10-9 30-1 44" fill="#9fba94"/><path d="M29 163h86l-13 61H41Z" fill="#d9c0a0"/><rect x="24" y="158" width="96" height="15" rx="5" fill="#cbb18f"/></svg>';
}

function deskSection(home = false) {
  return `<section class="desk-hero" aria-labelledby="desk-title"><div class="desk-heading"><h1 id="desk-title">Away from your desk.<br><span class="sage-text">Still making someone smile.</span></h1></div><div class="desk-composition"><div class="desk-note"><div class="note-binding" aria-hidden="true"><i></i><i></i><i></i></div><span class="note-date">TODAY’S LITTLE BREAK</span><div class="note-current" data-status>${selected().title}</div><div class="note-hint"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m5 3 14 9-7 1-3 7Z"/></svg><span>Click to switch the screen</span><svg class="note-hint-arrow" viewBox="0 0 30 24" aria-hidden="true"><path d="M2 4c13-2 20 4 20 16m-5-5 5 5 5-5"/></svg></div>${reasonButtons('note-picks')}${timer('note-timer')}</div><div class="desk-monitor-area">${monitor('desk-monitor')}${plant()}<div class="desk-keyboard" aria-hidden="true"><div>${Array.from({ length: 36 }, () => '<i></i>').join('')}</div></div><div class="desk-mouse" aria-hidden="true"></div><div class="desk-cup" aria-hidden="true"><span></span></div><span class="desk-line" aria-hidden="true"></span></div></div><div class="desk-bottom">${download()}${home ? `<a class="scroll-to-demo" href="#how-it-works">Try it in the menu bar ${icon('arrow', 18)}</a>` : ''}</div></section>`;
}

function howSection(home = false) {
  return `<section class="click-hero" id="how-it-works" aria-labelledby="how-title"><div class="click-heading"><${home ? 'h2' : 'h1'} id="how-title">One little click.<br><span class="sage-text">And you’re off.</span></${home ? 'h2' : 'h1'}></div><div class="click-layout"><div class="click-instructions"><div class="step-item"><span class="step-number">1</span><div><h3>Click QScreen.</h3><p>Up in your Mac’s menu bar.</p></div></div><div class="step-item"><span class="step-number">2</span><div><h3>Pick your break.</h3></div></div><div class="keyboard-hint"><kbd>⌃</kbd><kbd>⌥</kbd><kbd>Q</kbd><span>works, too</span></div>${home ? '' : `<div class="click-cta">${download()}${stamp()}</div>`}</div><div class="click-demo-wrap">${desktop()}</div></div></section>`;
}

const views = {
  0: () => `${header()}${deskSection(true)}${howSection(true)}${footer()}`,
  1: () => `${header()}<section class="hero hello-hero"><div class="hero-copy"><h1>A little<br> out of <span class="hand-underline">office.</span><span class="title-spark" aria-hidden="true">✳</span></h1><p class="hero-description">Let a little friend tell your coworkers<br>what you’re up to, and when you’ll be back.</p><div class="hero-cta">${download()}${stamp()}</div></div><div class="hello-preview"><span class="preview-sticker">Gone for a bite.<svg viewBox="0 0 100 60" aria-hidden="true"><path d="M3 8Q28 61 88 26m-12-3 15 2-6 13"/></svg></span>${monitor('hello-monitor')}<div class="floating-tag">${icon('lock', 13)} A real screen saver. A properly locked Mac.</div></div></section><section class="hello-controls"><div class="picker-caption">Every break has a little character.<span>Pick yours ${icon('arrow', 17)}</span></div>${reasonButtons('pills')}${timer()}</section>${footer()}`,
  2: () => `${header()}<section class="cinema-hero"><div class="cinema-heading"><h1>Taking a break?<br><span class="sage-text">Leave a little personality.</span></h1></div><div class="cinema-stage"><div class="cinema-preview">${scene()}<button class="cinema-expand icon-button" data-expand aria-label="Expand screen saver preview">${icon('expand', 19)}</button><span class="preview-corner">INTERACTIVE PREVIEW</span></div><div class="cinema-switcher"><span>Choose your company</span>${reasonButtons('rounds')}</div></div><div class="cinema-bottom">${timer()}${download()}</div></section>${footer()}`,
  3: () => `${header()}<section class="crew-hero"><div class="crew-heading"><div><h1>Meet your<br> <span class="hand-underline">away team.</span></h1></div><p class="hero-description">A friend for every kind of break.<br>Who’s covering your desk today?</p></div><div class="crew-layout"><div class="crew-picking">${reasonButtons('crew-grid')}</div><div class="crew-live"><div class="crew-live-top">${selectionLabel()}<button class="icon-button" data-expand aria-label="Expand screen saver preview">${icon('expand', 17)}</button></div>${scene()}${timer()}</div></div><div class="crew-bottom">${stamp()}${download('Take the crew with you')}</div></section>${footer()}`,
  4: () => `${header()}${howSection()}${footer()}`,
  5: () => `${header()}${deskSection()}${footer()}`,
};

function sync() {
  const p = selected();
  document.querySelectorAll('[data-scene]').forEach(el => { el.style.setProperty('--scene-bg', p.bg); el.classList.toggle('night', p.id === 'offwork'); });
  document.querySelectorAll('[data-character]').forEach(el => { el.innerHTML = animal(p.id); });
  document.querySelectorAll('[data-status]').forEach(el => { el.textContent = p.title; });
  document.querySelectorAll('[data-return]').forEach(el => { el.textContent = returnText(); });
  document.querySelectorAll('[data-reason]').forEach(el => { const on = el.dataset.reason === p.id; el.classList.toggle('selected', on); el.setAttribute('aria-pressed', String(on)); });
  document.querySelectorAll('[data-minutes]').forEach(el => { const on = Number(el.dataset.minutes) === state.minutes; el.classList.toggle('selected', on); el.setAttribute('aria-pressed', String(on)); el.disabled = p.id === 'offwork'; });
  document.querySelectorAll('.time-control').forEach(el => el.classList.toggle('is-offwork', p.id === 'offwork'));
  document.querySelectorAll('.preview-sticker').forEach(el => { el.firstChild.textContent = ({ lunch: 'Gone for a bite.', meeting: 'A meeting of minds.', coffee: 'Just one more sip.', restroom: 'Nature is calling.', away: 'Back in a little bit.', offwork: 'A well-earned rest.' })[p.id]; });
  const expanded = document.querySelector('.expanded-preview');
  if (expanded) expanded.querySelector('.expanded-title').textContent = `${p.pal} · Interactive preview`;
  document.getElementById('announcement').textContent = `${p.title}. ${returnText()}.`;
}

function syncMenu() {
  const demo = document.querySelector('.desktop-demo');
  if (!demo) return;
  demo.classList.toggle('showing-saver', !state.desktop);
  const saver = demo.querySelector('.desktop-saver');
  saver.inert = state.desktop;
  saver.setAttribute('aria-hidden', String(state.desktop));
  const menu = document.getElementById('quick-menu');
  menu.hidden = !state.menu;
  menu.classList.toggle('is-open', state.menu);
  const trigger = document.querySelector('[data-toggle-menu]');
  trigger.classList.toggle('open', state.menu);
  trigger.setAttribute('aria-expanded', String(state.menu));
  const prompt = document.querySelector('.desktop-prompt');
  prompt.classList.toggle('is-hidden', state.menu || !state.desktop);
  prompt.inert = state.menu || !state.desktop;
}

function render(view, push = true) {
  state.view = views[view] ? view : 0;
  state.menu = false;
  state.desktop = true;
  document.body.dataset.design = String(state.view);
  document.querySelector('.design-bar').hidden = state.view === 0;
  document.querySelector('meta[name="robots"]').content = state.view === 0 ? 'index, follow' : 'noindex, nofollow';
  document.querySelectorAll('.design-options [data-view]').forEach(el => { const active = Number(el.dataset.view) === state.view; el.classList.toggle('active', active); if (active) el.setAttribute('aria-current', 'page'); else el.removeAttribute('aria-current'); });
  document.getElementById('main').innerHTML = views[state.view]();
  const name = document.querySelector(`.design-options [data-view="${state.view}"]`)?.textContent.trim();
  document.title = state.view === 0 ? 'QScreen — A little out of office' : `QScreen — ${name}`;
  if (push) history.pushState({ view: state.view }, '', `?view=${state.view}`);
  sync();
}

let expandTrigger = null;
function closeExpanded() {
  const dialog = document.querySelector('.expanded-preview');
  if (!dialog) return;
  dialog.close();
  dialog.remove();
  document.body.classList.remove('dialog-open');
  expandTrigger?.focus();
}

document.addEventListener('click', event => {
  const view = event.target.closest('.design-options [data-view]');
  if (view && !event.metaKey && !event.ctrlKey && !event.shiftKey) { event.preventDefault(); render(Number(view.dataset.view)); window.scrollTo({ top: 0, behavior: 'instant' }); return; }
  const reason = event.target.closest('[data-reason]');
  if (reason) {
    state.reason = reason.dataset.reason;
    state.minutes = selected().minutes;
    if (reason.hasAttribute('data-menu-choice')) { state.menu = false; state.desktop = false; syncMenu(); document.querySelector('[data-return-desktop]')?.focus(); }
    sync();
    return;
  }
  const minutes = event.target.closest('[data-minutes]');
  if (minutes) { state.minutes = Number(minutes.dataset.minutes); sync(); return; }
  if (event.target.closest('[data-toggle-menu], [data-demo-start]')) { state.menu = !state.menu; state.desktop = true; syncMenu(); if (state.menu) document.querySelector('.menu-row')?.focus(); return; }
  if (event.target.closest('[data-return-desktop]')) { state.desktop = true; state.menu = false; syncMenu(); document.querySelector('[data-toggle-menu]')?.focus(); return; }
  const expand = event.target.closest('[data-expand]');
  if (expand) {
    expandTrigger = expand;
    const dialog = document.createElement('dialog');
    dialog.className = 'expanded-preview';
    dialog.setAttribute('aria-label', 'Interactive screen saver preview');
    dialog.innerHTML = `<div class="expanded-header"><span class="expanded-title">${selected().pal} · Interactive preview</span><button class="icon-button" data-close-expand aria-label="Close preview">${icon('close', 22)}</button></div>${scene()}<div class="expanded-controls">${reasonButtons('pills')}${timer()}</div>`;
    document.body.append(dialog);
    document.body.classList.add('dialog-open');
    dialog.addEventListener('cancel', e => { e.preventDefault(); closeExpanded(); });
    dialog.addEventListener('click', e => { if (e.target === dialog) closeExpanded(); });
    dialog.showModal();
    return;
  }
  if (event.target.closest('[data-close-expand]')) { closeExpanded(); return; }
  if (state.menu && !event.target.closest('.quick-menu')) { state.menu = false; syncMenu(); }
});

document.addEventListener('keydown', event => {
  if ((state.view === 4 || state.view === 0) && event.ctrlKey && event.altKey && event.code === 'KeyQ') { event.preventDefault(); state.menu = !state.menu; state.desktop = true; syncMenu(); return; }
  if (event.key === 'Escape' && state.menu) { state.menu = false; syncMenu(); document.querySelector('[data-toggle-menu]')?.focus(); }
  const row = event.target.closest('.menu-row');
  if (row && ['ArrowDown', 'ArrowUp'].includes(event.key)) {
    event.preventDefault();
    const rows = [...document.querySelectorAll('.menu-row')];
    const next = (rows.indexOf(row) + (event.key === 'ArrowDown' ? 1 : -1) + rows.length) % rows.length;
    rows[next].focus();
  }
});
const currentView = () => Number(new URLSearchParams(location.search).get('view')) || 0;
window.addEventListener('popstate', () => render(currentView(), false));
render(currentView(), false);
