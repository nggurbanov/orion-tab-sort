(function (root) {
  'use strict';

  // Pure rows are also used by tests. Search keeps the complete ancestor path.
  function rows(snapshot, plan, query = '') {
    const {
        byKey
      } = root.OrionTreePlan.indexSnapshot(snapshot),
      nodes = new Map(plan.nodes.map(n => [n.key, n]));
    const titleCounts = new Map(),
      counts = new Map(),
      occurrences = new Map();
    for (const tab of snapshot.tabs) {
      titleCounts.set(tab.title, (titleCounts.get(tab.title) || 0) + 1);
      const identity = JSON.stringify([tab.title || '', tab.url || '']);
      const ordinal = (counts.get(identity) || 0) + 1;
      counts.set(identity, ordinal);
      occurrences.set(tab.key, ordinal);
    }
    const matching = new Set(),
      needle = query.trim().toLowerCase();
    for (const n of nodes.values()) {
      const t = byKey.get(n.key);
      if (!needle || (t.title + ' ' + t.url).toLowerCase().includes(needle)) {
        let k = n.key;
        while (k !== null && !matching.has(k)) {
          matching.add(k);
          k = nodes.get(k)?.parentKey ?? null;
        }
      }
    }
    const children = new Map();
    for (const n of nodes.values()) {
      if (!children.has(n.parentKey)) children.set(n.parentKey, []);
      children.get(n.parentKey).push(n);
    }
    const walk = (parent, depth) => (children.get(parent) || []).sort((a, b) => a.index - b.index).filter(n => matching.has(n.key)).map(n => {
      const t = byKey.get(n.key);
      let domain = 'Local page';
      try {
        const u = new URL(t.url);
        domain = u.hostname || 'Local page';
        if (titleCounts.get(t.title) > 1) domain += u.pathname + u.search;
      } catch {}
      const duplicate = counts.get(JSON.stringify([t.title || '', t.url || ''])) > 1;
      return {
        key: n.key,
        title: t.title || t.url || 'Untitled tab',
        url: String(t.url || ''),
        domain,
        changed: t.parentKey !== n.parentKey || t.index !== n.index,
        duplicate,
        position: occurrences.get(t.key),
        depth,
        children: walk(n.key, depth + 1)
      };
    });
    return walk(null, 1);
  }
  function render(container, snapshot, plan, options = {}) {
    const doc = container.ownerDocument || document;
    const svg = (path, cls) => {
      const el = doc.createElementNS('http://www.w3.org/2000/svg', 'svg');
      el.setAttribute('viewBox', '0 0 20 20');
      el.setAttribute('aria-hidden', 'true');
      if (cls) el.setAttribute('class', cls);
      const p = doc.createElementNS('http://www.w3.org/2000/svg', 'path');
      p.setAttribute('d', path);
      el.append(p);
      return el;
    };
    const list = entries => {
      const ul = doc.createElement('ul');
      for (const item of entries) {
        const li = doc.createElement('li'),
          row = doc.createElement('div');
        row.className = 'tree-row';
        let nested;
        if (item.children.length) {
          const toggle = doc.createElement('button');
          toggle.className = 'tree-toggle';
          toggle.setAttribute('aria-label', 'Collapse ' + item.title);
          toggle.setAttribute('aria-expanded', 'true');
          toggle.append(svg('m6 8 4 4 4-4'));
          toggle.addEventListener('click', () => {
            nested.hidden = !nested.hidden;
            toggle.setAttribute('aria-expanded', String(!nested.hidden));
            toggle.setAttribute('aria-label', (nested.hidden ? 'Expand ' : 'Collapse ') + item.title);
          });
          row.append(toggle);
          nested = list(item.children);
        } else {
          const spacer = doc.createElement('span');
          spacer.className = 'tree-spacer';
          row.append(spacer);
        }
        row.append(svg('M5 2h7l4 4v12H5z M12 2v5h4 M8 10h5 M8 13h5', 'document-icon'));
        const copy = doc.createElement('span');
        copy.className = 'tab-copy';
        const title = doc.createElement('span');
        title.className = 'tab-title';
        title.textContent = item.title;
        title.setAttribute('title', item.title + '\n' + item.url);
        title.setAttribute('aria-label', item.title + ' — ' + item.url);
        const domain = doc.createElement('span');
        domain.className = 'tab-domain';
        domain.textContent = item.domain;
        domain.setAttribute('title', item.url);
        copy.append(title, domain);
        if (item.duplicate) {
          const duplicate = doc.createElement('span');
          duplicate.className = 'duplicate';
          duplicate.textContent = `Duplicate · copy ${item.position}`;
          copy.append(duplicate);
        }
        row.append(copy);
        if (options.proposed && item.changed) {
          const mark = doc.createElement('span');
          mark.className = 'changed';
          mark.textContent = 'Moved';
          row.append(mark);
        }
        li.append(row);
        if (nested) li.append(nested);
        ul.append(li);
      }
      return ul;
    };
    const data = rows(snapshot, plan, options.query);
    container.replaceChildren(list(data));
    if (!data.length) container.textContent = 'No matching tabs. Try another title or domain.';
  }
  const api = Object.freeze({
    rows,
    render
  });
  if (typeof module === 'object' && module.exports) module.exports = api;else root.OrionTreeView = api;
})(typeof module === 'object' && module.exports ? {
  OrionTreePlan: require('./tree-plan.js')
} : globalThis);
