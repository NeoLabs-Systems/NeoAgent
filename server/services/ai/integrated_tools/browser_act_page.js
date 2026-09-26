'use strict';

// These functions run inside the browser page through the controller's
// evaluate route, so they may only use DOM APIs. Their source is sent as a
// script string, which the controller caps at 10,000 characters.

const STAMP_ATTRIBUTE = 'data-neo-act';
const PAGE_LIMITS = Object.freeze({
  maxElements: 150,
  maxOptions: 25,
  maxNameChars: 90,
  maxValueChars: 120,
  maxTextChars: 2500,
  belowFold: 2,
});

/* global document, window, getComputedStyle, NodeFilter, location, scrollY */
function snapshotPage(snapshotId, limits, stampAttribute) {
  for (const node of document.querySelectorAll(`[${stampAttribute}]`)) node.removeAttribute(stampAttribute);
  const vw = window.innerWidth;
  const vh = window.innerHeight;
  const clip = (value, max) => {
    const text = String(value == null ? '' : value).replace(/\s+/g, ' ').trim();
    return text.length > max ? `${text.slice(0, max - 1)}…` : text;
  };
  // Controls just below the fold are listed too (marked below): consent
  // buttons and submit buttons often sit there, and a click scrolls to them.
  const boxOf = (el) => {
    const style = getComputedStyle(el);
    if (style.visibility === 'hidden' || style.display === 'none' || Number(style.opacity) === 0) return null;
    const rect = el.getBoundingClientRect();
    if (rect.width < 2 || rect.height < 2) return null;
    if (rect.bottom < 0 || rect.top > vh * limits.belowFold || rect.right < 0 || rect.left > vw) return null;
    return rect;
  };
  const uncovered = (el, rect) => {
    const x = Math.min(vw - 1, Math.max(0, rect.left + rect.width / 2));
    const y = Math.min(vh - 1, Math.max(0, rect.top + rect.height / 2));
    const hit = document.elementFromPoint(x, y);
    return !hit || hit === el || el.contains(hit) || hit.contains(el) || Boolean(hit.closest?.('label')?.contains(el));
  };
  const nameOf = (el) => {
    const aria = el.getAttribute('aria-label');
    if (aria && aria.trim()) return aria;
    const labelledBy = el.getAttribute('aria-labelledby');
    if (labelledBy) {
      const text = labelledBy.split(/\s+/).map((id) => document.getElementById(id)?.innerText || '').join(' ');
      if (text.trim()) return text;
    }
    if (el.labels && el.labels.length) {
      const text = Array.from(el.labels).map((label) => label.innerText).join(' ');
      if (text.trim()) return text;
    }
    if (el.tagName !== 'INPUT' && el.tagName !== 'SELECT' && el.tagName !== 'TEXTAREA') {
      const text = el.innerText || el.textContent;
      if (text && text.trim()) return text;
    }
    return el.getAttribute('placeholder') || el.getAttribute('title') || el.getAttribute('alt')
      || el.querySelector?.('img[alt]')?.getAttribute('alt')
      || (el.type === 'submit' || el.type === 'button' ? el.value : '')
      || el.getAttribute('name') || '';
  };
  const roleOf = (el) => {
    const explicit = el.getAttribute('role');
    if (explicit) return explicit.split(/\s+/)[0];
    const tag = el.tagName.toLowerCase();
    if (tag === 'a') return 'link';
    if (tag === 'select') return 'select';
    if (tag === 'textarea') return 'textbox';
    if (tag === 'input') {
      const type = (el.getAttribute('type') || 'text').toLowerCase();
      if (type === 'checkbox' || type === 'radio') return type;
      if (['button', 'submit', 'reset', 'image'].includes(type)) return 'button';
      if (type === 'range') return 'slider';
      return type === 'search' ? 'searchbox' : 'textbox';
    }
    if (el.isContentEditable) return 'textbox';
    return 'button';
  };
  const sensitive = (el) => el.tagName === 'INPUT'
    && ((el.getAttribute('type') || '').toLowerCase() === 'password'
      || String(el.getAttribute('autocomplete') || '').toLowerCase().startsWith('cc-'));
  const typeable = (el, role) => {
    if (el.disabled || el.readOnly || sensitive(el)) return false;
    if (el.isContentEditable || el.tagName === 'TEXTAREA') return true;
    if (el.tagName === 'INPUT') return role === 'textbox' || role === 'searchbox' || role === 'combobox';
    return false;
  };
  const selector = 'a[href],button,input:not([type=hidden]),select,textarea,summary,[contenteditable="true"],[onclick],'
    + '[role=button],[role=link],[role=checkbox],[role=radio],[role=switch],[role=tab],[role=menuitem],[role=menuitemcheckbox],'
    + '[role=menuitemradio],[role=option],[role=combobox],[role=textbox],[role=searchbox],[role=treeitem],[role=gridcell]';
  const onScreen = [];
  const belowFold = [];
  for (const el of document.querySelectorAll(selector)) {
    if (el.disabled || el.getAttribute('aria-disabled') === 'true') continue;
    const rect = boxOf(el);
    if (!rect) continue;
    if (rect.top < vh) {
      if (uncovered(el, rect)) onScreen.push(el);
    } else {
      belowFold.push(el);
    }
  }
  const visibleNow = new Set(onScreen);
  const elements = [];
  for (const el of [...onScreen, ...belowFold].slice(0, limits.maxElements)) {
    const role = roleOf(el);
    const entry = { i: elements.length + 1, role, name: clip(nameOf(el), limits.maxNameChars) };
    if (!visibleNow.has(el)) entry.below = true;
    if (el === document.activeElement) entry.focused = true;
    if (el.tagName === 'SELECT') {
      entry.ops = ['SELECT'];
      entry.value = clip(el.selectedOptions?.[0]?.text, limits.maxValueChars);
      entry.options = Array.from(el.options).slice(0, limits.maxOptions).map((option) => clip(option.text, 60));
    } else if (typeable(el, role)) {
      entry.ops = role === 'combobox' ? ['TYPE_TEXT', 'CLICK'] : ['TYPE_TEXT'];
      entry.value = clip(el.isContentEditable ? el.innerText : el.value, limits.maxValueChars);
    } else if (sensitive(el)) {
      entry.ops = [];
      entry.sensitive = true;
    } else {
      entry.ops = ['CLICK'];
    }
    const checked = el.checked === true || el.getAttribute('aria-checked') === 'true';
    if (role === 'checkbox' || role === 'radio' || role === 'switch') entry.checked = checked;
    if (el.getAttribute('aria-selected') === 'true') entry.selected = true;
    if (el.hasAttribute('aria-expanded')) entry.expanded = el.getAttribute('aria-expanded') === 'true';
    el.setAttribute(stampAttribute, `${snapshotId}-${entry.i}`);
    elements.push(entry);
  }
  const texts = [];
  let total = 0;
  const walker = document.createTreeWalker(document.body || document.documentElement, NodeFilter.SHOW_TEXT, {
    acceptNode(node) {
      const parent = node.parentElement;
      if (!parent || !node.textContent.trim() || ['SCRIPT', 'STYLE', 'NOSCRIPT', 'TEMPLATE'].includes(parent.tagName)) {
        return NodeFilter.FILTER_REJECT;
      }
      return NodeFilter.FILTER_ACCEPT;
    },
  });
  const range = document.createRange();
  while (total < limits.maxTextChars && walker.nextNode()) {
    const node = walker.currentNode;
    range.selectNodeContents(node);
    const rect = range.getBoundingClientRect();
    if (!rect.width || rect.bottom < 0 || rect.top > vh || rect.right < 0 || rect.left > vw) continue;
    const text = clip(node.textContent, 300);
    texts.push(text);
    total += text.length + 1;
  }
  const scrollHeight = document.documentElement.scrollHeight;
  return {
    url: location.href,
    title: document.title,
    text: texts.join(' ').slice(0, limits.maxTextChars),
    canScrollUp: scrollY > 8,
    canScrollDown: scrollY + vh < scrollHeight - 8,
    viewportHeight: vh,
    elements,
  };
}

// Sets a native <select> the way a user would. The prototype setter bypasses
// framework value trackers so React-style listeners see the change.
function selectOption(selector, optionIndex) {
  const el = document.querySelector(selector);
  const option = el?.tagName === 'SELECT' ? el.options[optionIndex] : null;
  if (!option) return { error: 'Element not found' };
  Object.getOwnPropertyDescriptor(window.HTMLSelectElement.prototype, 'value').set.call(el, option.value);
  el.dispatchEvent(new Event('input', { bubbles: true }));
  el.dispatchEvent(new Event('change', { bubbles: true }));
  return { success: true, selected: option.text };
}

function stampSelector(stamp) {
  return `[${STAMP_ATTRIBUTE}="${stamp}"]`;
}

function buildSnapshotScript(snapshotId) {
  return `(${snapshotPage.toString()})(${JSON.stringify(snapshotId)}, ${JSON.stringify(PAGE_LIMITS)}, ${JSON.stringify(STAMP_ATTRIBUTE)})`;
}

function buildSelectScript(stamp, optionIndex) {
  return `(${selectOption.toString()})(${JSON.stringify(stampSelector(stamp))}, ${Number(optionIndex)})`;
}

module.exports = {
  buildSelectScript,
  buildSnapshotScript,
  stampSelector,
};
