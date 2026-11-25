function selectOption(selector, optionIndex) {
  const el = document.querySelector(selector);
  const option = el?.tagName === 'SELECT' ? el.options[optionIndex] : null;
  if (!option) return { error: 'Element not found' };
  Object.getOwnPropertyDescriptor(window.HTMLSelectElement.prototype, 'value').set.call(el, option.value);
  el.dispatchEvent(new Event('input', { bubbles: true }));
  el.dispatchEvent(new Event('change', { bubbles: true }));
  return { success: true, selected: option.text };
}