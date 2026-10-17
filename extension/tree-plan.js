(function (root) {
  "use strict";

  function indexSnapshot(snapshot) {
    if (!snapshot || !Array.isArray(snapshot.tabs) || !snapshot.scope || typeof snapshot.revision !== "string") {
      throw new Error("Invalid native snapshot");
    }
    if (snapshot.tabs.length === 0 || snapshot.tabs.length > 2000) throw new Error("Unsupported tab count");
    const byId = new Map();
    const byKey = new Map();
    for (const tab of snapshot.tabs) {
      if (!Number.isSafeInteger(tab.id) ||
          (tab.id < 0 && !(tab.nativeOnly === true && tab.key === `native-${-tab.id}`)) ||
          typeof tab.key !== "string" || !tab.key ||
          typeof tab.pinned !== "boolean" || typeof tab.expanded !== "boolean" ||
          !Number.isInteger(tab.index) || tab.index < 0 ||
          !(tab.parentKey === null || typeof tab.parentKey === "string") ||
          byId.has(tab.id) || byKey.has(tab.key)) throw new Error("Invalid or duplicate native tab identity");
      byId.set(tab.id, tab);
      byKey.set(tab.key, tab);
    }
    for (const tab of snapshot.tabs) {
      const visited = new Set([tab.key]);
      let parent = tab.parentKey;
      while (parent !== null) {
        if (!byKey.has(parent)) throw new Error("Parent is outside the current group");
        if (visited.has(parent)) throw new Error("Native snapshot contains a cycle");
        visited.add(parent);
        parent = byKey.get(parent).parentKey;
      }
    }
    const activeCount=snapshot.tabs.filter(tab=>tab.active).length;
    const nativeSelection=snapshot.identityMode==='native-session'&&Number.isSafeInteger(snapshot.scope.nativeWindowNumber)&&snapshot.scope.nativeWindowNumber>0&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(snapshot.selectionWrapperToken);
    if(activeCount!==1&&!(nativeSelection&&activeCount===0))throw new Error("Expected one active tab");
    return { byId, byKey };
  }

  function fromForest(snapshot, forest, options = {}) {
    const { byId, byKey } = indexSnapshot(snapshot);
    const maxDepth = options.maxDepth ?? 3;
    if (!Number.isInteger(maxDepth) || maxDepth < 1 || maxDepth > 8) throw new Error("Invalid maximum depth");
    if (!Array.isArray(forest)) throw new Error("AI result must contain a trees array");
    const nodes = [];
    const seen = new Set();
    const walk = (entries, parentKey, depth) => {
      if (depth > maxDepth && entries.length) throw new Error("Proposed tree exceeds the maximum depth");
      entries.forEach((entry, index) => {
        const branch = typeof entry === "object" && entry !== null && !Array.isArray(entry);
        const id = branch ? entry.parent : entry;
        if (!Number.isSafeInteger(id) || !byId.has(id)) throw new Error("AI selected an unknown tab ID");
        const tab = byId.get(id);
        if (tab.pinned) throw new Error("AI selected a pinned tab");
        if (seen.has(id)) throw new Error(`AI used the same tab more than once: ${id}. Remove repeated occurrences; a branch parent already counts as one use`);
        if (branch && (!Array.isArray(entry.children) || Object.keys(entry).some(key => !["parent", "children"].includes(key)))) {
          throw new Error("Invalid tree branch");
        }
        seen.add(id);
        const children = branch ? entry.children : [];
        nodes.push({ id, key: tab.key, parentKey, index,
          expanded: children.length > 0 });
        walk(children, tab.key, depth + 1);
      });
    };
    walk(forest, null, 1);
    const movable = snapshot.tabs.filter(tab => !tab.pinned);
    if (seen.size !== movable.length) throw new Error("AI omitted an existing tab");
    const proposed = new Map(nodes.map(node => [node.key, node]));
    if (options.preserveExisting !== false) {
      for (const tab of movable) {
        if (tab.parentKey !== null && proposed.get(tab.key).parentKey !== tab.parentKey) {
          throw new Error("Proposed tree breaks an existing parent-child relationship");
        }
      }
    }
    for (const node of nodes) {
      if (node.parentKey !== null && byKey.get(node.parentKey).pinned) throw new Error("Pinned parents are locked");
    }
    return { version: 1, scope: { ...snapshot.scope }, expectedRevision: snapshot.revision,
      nodes, pinnedKeys: snapshot.tabs.filter(tab => tab.pinned).map(tab => tab.key) };
  }

  function metadataForAI(snapshot) {
    indexSnapshot(snapshot);
    return snapshot.tabs.filter(tab => !tab.pinned).map(tab => ({
      id: tab.id, title: String(tab.title || ""), url: String(tab.url || ""),
      parentId: tab.parentKey === null ? null : snapshot.tabs.find(parent => parent.key === tab.parentKey).id
    }));
  }

  function undoPlan(snapshot) {
    indexSnapshot(snapshot);
    return { version: 1, scope: { ...snapshot.scope },
      nodes: snapshot.tabs.filter(tab => !tab.pinned).map(({ id, key, parentKey, index, expanded }) =>
        ({ id, key, parentKey, index, expanded })),
      pinnedKeys: snapshot.tabs.filter(tab => tab.pinned).map(tab => tab.key) };
  }

  function describe(snapshot, plan) {
    const { byKey } = indexSnapshot(snapshot);
    const children = new Map();
    for (const node of plan.nodes) {
      if (!children.has(node.parentKey)) children.set(node.parentKey, []);
      children.get(node.parentKey).push(node);
    }
    const lines = [];
    const walk = (parentKey, depth) => {
      const siblings = (children.get(parentKey) || []).sort((a, b) => a.index - b.index);
      for (const node of siblings) {
        const tab = byKey.get(node.key);
        if (!tab) throw new Error("Preview references a missing tab");
        lines.push(`${"  ".repeat(depth)}${tab.title || tab.url || `Tab ${tab.id}`}`);
        walk(node.key, depth + 1);
      }
    };
    walk(null, 0);
    return lines.join("\n");
  }

  const api = Object.freeze({ indexSnapshot, fromForest, metadataForAI, undoPlan, describe });
  if (typeof module === "object" && module.exports) module.exports = api;
  else root.OrionTreePlan = api;
})(globalThis);
