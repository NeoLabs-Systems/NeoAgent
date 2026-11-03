(function () {
  'use strict';
  const labels = { operational: 'Operational', degraded: 'Degraded', unavailable: 'Unavailable', unknown: 'Unknown' };
  const titles = { operational: 'All monitored systems operational', degraded: 'Some systems need attention', unavailable: 'Service disruption', unknown: 'Status unavailable' };
  let timer;
  function node(tag, className, text) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (text) element.textContent = text;
    return element;
  }
  function safeStatus(value) { return Object.hasOwn(labels, value) ? value : 'unknown'; }
  function render(data) {
    const status = safeStatus(data.status);
    document.getElementById('status-icon').className = 'status-icon ' + status;
    document.getElementById('overall').textContent = titles[status];
    document.getElementById('note').textContent = data.note || '';
    document.getElementById('updated').textContent = data.updatedAt ? new Date(data.updatedAt).toLocaleString() : 'Unavailable';
    const items = Array.isArray(data.components) ? data.components : [];
    document.getElementById('component-count').textContent = items.length ? items.length + ' COMPONENTS' : '';
    const list = document.getElementById('components');
    list.replaceChildren();
    items.forEach(function (item) {
      const state = safeStatus(item.status);
      const row = node('article', 'component');
      const main = node('div', 'component-main');
      const details = node('div');
      details.append(node('h3', '', item.name), node('p', '', item.description));
      main.append(node('span', 'component-dot ' + state), details);
      row.append(main, node('span', 'badge ' + state, labels[state]));
      list.append(row);
    });
    const chart = document.getElementById('history');
    chart.replaceChildren();
    const hours = Array.isArray(data.history) ? data.history : [];
    hours.forEach(function (hour) {
      const state = safeStatus(hour.status);
      const bar = node('span', 'bar ' + state);
      bar.title = new Date(hour.time).toLocaleString() + ': ' + (state === 'unknown' ? 'No data' : labels[state]);
      chart.append(bar);
    });
    chart.setAttribute('aria-label', hours.length ? '48 hours of hourly status samples. Grey bars indicate no data.' : 'No status history available.');
  }
  function refresh() {
    fetch('/api/public/status', { headers: { accept: 'application/json' }, cache: 'no-store' })
      .then(function (response) { if (!response.ok) throw new Error('Status unavailable'); return response.json(); })
      .then(render)
      .catch(function () { render({ status: 'unknown', note: 'Could not reach the status endpoint. Please try again.' }); })
      .finally(function () { clearTimeout(timer); timer = setTimeout(refresh, 60000); });
  }
  refresh();
}());
