(() => {
  "use strict";

  const $ = id => document.getElementById(id);
  const status = $('status'),
    preview = $('preview');
  let pending = null,
    snapshot = null,
    proposal = null,
    baselineTabs = null,
    busy = false,
    canUndo = false,
    recoveryPlan = null;
  let journalPending = false,
    journalPhase = null,
    transactionPhase = 'idle',
    needsRecovery = false;
  let connected = false,
    supported = false,
    unknown = false,
    lateMutation = null,
    reconciling = false;
  let nativeMode = false,
    scopeToken = null,
    scopeUnavailable = false,
    mode = 'auto',
    view = 'current',
    phase = 'idle';
  let generation = null,
    operationID = 0,
    inspection = null,
    inspectionKind = null,
    layoutMode = null;
  const events = [],
    scopeTokens = new Map();
  const mutations = new Set(['apply', 'undo', 'keep', 'recover', 'recoverRetained', 'acceptCurrent', 'acknowledgeCurrent', 'abandonRetainedTransaction']);
  const controls = ['refresh', 'save', 'read', 'organize', 'apply', 'undo', 'keep', 'recoveryPreview', 'recover', 'acceptCurrent', 'inspectRetained', 'abandonRetained', 'inspectPrior', 'recoverOriginal', 'recoverApplied', 'acknowledge'];
  const editable = ['endpoint', 'model', 'key', 'depth', 'preserve', 'modeAuto', 'modeAdvanced'];
  function record(action) {
    events.push({
      action
    });
    if (events.length > 24) events.shift();
  }
  function setPhase(value, message) {
    phase = value;
    status.textContent = message;
    enableControls();
  }
  function validState(reply) {
    return typeof reply?.canUndo === 'boolean' && typeof reply.needsRecovery === 'boolean' && typeof reply.transactionPhase === 'string' && typeof reply.journalPhase === 'string';
  }
  function authoritative(reply) {
    if (!validState(reply)) {
      supported = false;
      return;
    }
    canUndo = reply.canUndo;
    needsRecovery = reply.needsRecovery;
    transactionPhase = reply.transactionPhase;
    journalPhase = reply.journalPhase;
    journalPending = needsRecovery || !canUndo && ['prepared', 'applied', 'undoing', 'rollingBack', 'recoveryRequired', 'unreadable', 'invalid'].includes(journalPhase);
    $('journalNotice').hidden = !journalPending && !unknown;
    $('journalNotice').textContent = unknown ? 'Outcome unknown. Do not repeat the operation. Reconnect the bridge and inspect recovery.' : journalPending ? 'Recovery needs attention. Inspect the retained transaction or previous journal before organizing again.' : '';
    if (journalPending) $('recoveryDetails')?.setAttribute('open', '');
  }
  function renderTree() {
    // Resolve the displayed view first, including empty and no-change states.
    const actualView = snapshot && proposal && view === 'proposed' ? 'proposed' : 'current';
    view = actualView;
    for (const name of ['Current', 'Proposed']) {
      const button = $('view' + name);
      if (button) {
        button.setAttribute('aria-pressed', String(actualView === name.toLowerCase()));
        button.disabled = !snapshot || name === 'Proposed' && !proposal;
      }
    }
    $('preview-title').textContent = actualView === 'proposed' ? 'Proposed tree' : 'Current tree';
    if (!snapshot) {
      preview.textContent = 'Read the selected group to see its tabs.';
      return;
    }
    const plan = actualView === 'proposed' ? proposal : OrionTreePlan.undoPlan(snapshot);
    if (typeof OrionTreeView !== 'undefined') OrionTreeView.render(preview, snapshot, plan, {
      query: $('search')?.value || '',
      proposed: actualView === 'proposed'
    });else preview.textContent = OrionTreePlan.describe(snapshot, plan);
  }
  function layoutSurface() {
    if (layoutMode === mode) return;
    layoutMode = mode;
    document.body?.setAttribute('data-mode', mode);
    const actionBar = $('actionBar');
    // Keep both visual and keyboard order natural: Auto actions follow status;
    // Advanced actions follow the tree and compact secondary controls.
    if (mode === 'auto') $('advanced')?.before?.(actionBar);else $('secondary')?.after?.(actionBar);
  }
  function enableControls() {
    const blocked = busy || unknown || !connected || !supported;
    controls.forEach(id => {
      if ($(id)) $(id).disabled = blocked;
    });
    editable.forEach(id => {
      if ($(id)) $(id).disabled = busy;
    });
    $('window').disabled = busy || canUndo || needsRecovery || unknown;
    $('apply').disabled = blocked || !proposal || journalPending || canUndo;
    $('undo').disabled = blocked || !canUndo;
    $('keep').disabled = blocked || !canUndo;
    $('read').disabled = blocked || canUndo || scopeUnavailable;
    $('organize').disabled = blocked || canUndo || journalPending || scopeUnavailable;
    $('refresh').disabled = busy;
    $('acceptCurrent').disabled = blocked || canUndo || transactionPhase !== 'idle' || journalPhase !== 'applied';
    $('recover').disabled = blocked || !recoveryPlan;
    if ($('cancel')) {
      $('cancel').hidden = !generation;
      $('cancel').disabled = !generation || generation.signal.aborted;
    }
    if ($('inspectRetained')) $('inspectRetained').disabled = busy || !connected || !supported || transactionPhase === 'idle';
    if ($('inspectPrior')) $('inspectPrior').disabled = busy || !connected || !supported;
    for (const id of ['recoverOriginal', 'recoverApplied']) if ($(id)) $(id).disabled = blocked || !inspection || inspectionKind !== 'retained' || !inspection.live?.available || !['recoveryRequired', 'restoredJournalPending', 'appliedJournalPending'].includes(transactionPhase) || !$('recoveryConfirmed').checked || id === 'recoverApplied' && !inspection.journal?.applied;
    if ($('abandonRetained')) $('abandonRetained').disabled = blocked || !inspection || inspectionKind !== 'retained' || !$('recoveryConfirmed').checked;
    if ($('acknowledge')) $('acknowledge').disabled = blocked || !inspection || inspectionKind !== 'prior' || !inspection.live?.available || !$('recoveryConfirmed').checked;
    layoutSurface();
    if ($('advanced')) $('advanced').hidden = mode !== 'advanced';
    const primary = canUndo ? 'undo' : generation ? 'cancel' : mode === 'auto' ? 'organize' : proposal ? 'apply' : snapshot ? 'organize' : 'read';
    for (const id of ['read', 'organize', 'apply', 'undo', 'cancel']) {
      const button = $(id);
      if (!button) continue;
      button.hidden = id !== primary;
      button.setAttribute('class', id === primary ? 'primary' : 'quiet');
    }
    // A fresh read is an optional secondary action after the initial Read step.
    if (mode === 'advanced' && snapshot && !canUndo && !generation && !busy) $('read').hidden = false;
    $('read').textContent = busy && primary === 'read' ? 'Reading…' : snapshot ? 'Read again' : 'Read tree';
    $('organize').textContent = busy && !generation ? phase === 'applying' ? 'Applying…' : 'Working…' : mode === 'auto' ? 'Organize tabs' : 'Review with AI';
    $('apply').textContent = phase === 'applying' && busy ? 'Applying…' : 'Apply changes';
    $('undo').textContent = phase === 'undoing' && busy ? 'Restoring…' : 'Undo';
    if ($('cancel')) $('cancel').textContent = generation?.signal.aborted ? 'Cancelling…' : 'Cancel generation';
    $('keep').hidden = !canUndo;
    if ($('connection')) $('connection').textContent = unknown ? 'Outcome unknown' : !connected ? 'Disconnected' : !supported ? 'Bridge update required' : needsRecovery ? 'Recovery required' : 'Orion connected';
    if ($('progress')) $('progress').hidden = !busy;
    if ($('modeAuto')) $('modeAuto').setAttribute('aria-pressed', String(mode === 'auto'));
    if ($('modeAdvanced')) $('modeAdvanced').setAttribute('aria-pressed', String(mode === 'advanced'));
    if ($('stepRead')) {
      const step = canUndo ? 'apply' : snapshot ? 'review' : 'read';
      for (const s of ['Read', 'Review', 'Apply']) $('step' + s).setAttribute('aria-current', phase === 'applying' && s === 'Apply' ? 'step' : s.toLowerCase() === step ? 'step' : 'false');
    }
  }
  function request(command, payload = {}) {
    if (pending) return Promise.reject(new Error('Wait for the current Orion response.'));
    if (mutations.has(command) && (!supported || !connected || unknown)) return Promise.reject(new Error('Mutation blocked. Reconnect an updated R49 bridge and inspect recovery.'));
    const handler = window.webkit?.messageHandlers?.orionNativeTreeBridgeV3;
    if (!handler) return Promise.reject(new Error('Open Native Tree Bridge from the Orion toolbar, then reconnect.'));
    return new Promise((resolve, reject) => {
      const id = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
      const timer = setTimeout(() => {
        pending = null;
        if (mutations.has(command)) {
          unknown = true;
          lateMutation = id;
          proposal = null;
          inspection = null;
        }
        connected = false;
        enableControls();
        reject(Object.assign(new Error(mutations.has(command) ? 'Native operation timed out. Outcome unknown; do not repeat it. Inspect recovery after reconnecting.' : 'Orion did not respond. Open Native Tree Bridge and reconnect.'), {
          unknown: mutations.has(command)
        }));
      }, mutations.has(command) ? 120000 : 30000);
      pending = {
        id,
        resolve,
        reject,
        timer
      };
      try {
        handler.postMessage({
          id,
          command,
          payload
        });
      } catch (error) {
        clearTimeout(timer);
        pending = null;
        reject(new Error('Native bridge unavailable. Reopen Native Tree Bridge.'));
      }
    });
  }
  function receive(reply) {
    if (reply?.id === lateMutation) {
      authoritative(reply);
      connected = true;
      if (validState(reply) && typeof reply.ok === 'boolean') {
        unknown = false;
        lateMutation = null;
        record('lateMutationReply');
        status.textContent = reply.ok === false ? 'Native operation failed: ' + safeError(new Error(reply.error || 'The bridge refused the operation.')) + (needsRecovery ? ' Inspect the retained transaction.' : '') : needsRecovery ? 'Operation finished with recovery required. Inspect the retained transaction.' : canUndo ? 'Operation completed. Undo or keep the order.' : 'Operation completed. Reconnect to refresh the current tree.';
      } else status.textContent = 'Late response could not be verified. Outcome remains unknown; mutations stay locked.';
      enableControls();
      return;
    }
    if (!pending || reply?.id !== pending.id) return;
    const call = pending;
    pending = null;
    clearTimeout(call.timer);
    authoritative(reply);
    connected = true;
    if (reply.ok === true) call.resolve(reply.result);else call.reject(new Error(reply.error || 'Native bridge rejected the operation.'));
    enableControls();
  }
  function credentials() {
    return Object.freeze({
      config: Object.freeze(settings()),
      apiKey: $('key').value.trim()
    });
  }
  function checkCancelled(signal) {
    if (signal?.aborted) throw Object.assign(new Error('Cancelled. Tabs were not changed.'), {
      name: 'AbortError'
    });
  }
  function clearResolved() {
    snapshot = null;
    proposal = null;
    recoveryPlan = null;
    inspection = null;
    inspectionKind = null;
    $('recoveryConfirmed') && ($('recoveryConfirmed').checked = false);
    if ($('inspectionSummary')) $('inspectionSummary').textContent = '';
    renderTree();
  }
  async function connect() {
    const ping = await request('ping');
    supported = ping?.host === 'AppleScriptObjC native tree V3R49';
    if (!supported) throw new Error('Update the Native Tree Bridge to R49, reopen it, and reconnect. Organization is disabled.');
    const state = await request('transactionStatus');
    if (!validState(state)) {
      supported = false;
      throw new Error('R49 transaction status is unavailable. Update and reopen the bridge.');
    }
    authoritative(state);
  }
  async function reconcile() {
    if (reconciling) return;
    reconciling = true;
    try {
      await connect();
      try {
        await request('inspectJournal');
      } catch {}
      try {
        const fresh = await request('snapshot');
        OrionTreePlan.indexSnapshot(fresh);
        snapshot = fresh;
        proposal = null;
        renderTree();
      } catch {}
      // R49 has no receipt linking a status/phase to a specific request. Even
      // applied/idle may predate timed-out Undo/Keep. Only its exact late ID
      // can resolve this controller's unknown outcome; never replay a mutation.
      if (unknown) status.textContent = 'Native status inspected. The timed-out request has no correlated reply; outcome remains unknown and mutations stay locked.';
    } catch {
      connected = false;
    } finally {
      reconciling = false;
      enableControls();
    }
  }
  window.OrionSorter = Object.freeze({
    receive,
    get events() {
      return events.slice();
    },
    focusCurrentWindow,
    run,
    setMode,
    getState: () => ({
      mode,
      phase,
      busy,
      canUndo,
      needsRecovery,
      unknown,
      supported,
      connected,
      transactionPhase,
      journalPhase
    })
  });
  function tabRecord({
    id,
    windowId,
    url,
    title,
    active,
    pinned,
    index
  }) {
    return {
      id,
      windowId,
      url,
      title: title || '',
      active: !!active,
      pinned: !!pinned,
      index
    };
  }
  async function saveCheckpoint(checkpoint) {
    try {
      await probeAPI.call('storage.local', 'set', {
        orionSortCheckpoint: checkpoint
      });
    } catch (error) {
      if (!nativeMode) throw error;
      record('checkpointUnavailable');
    }
  }
  async function windowTabs() {
    if (nativeMode) return [];
    const windowId = Number($('window').value);
    if (!Number.isSafeInteger(windowId)) throw new Error('Choose a window.');
    return (await probeAPI.call('tabs', 'query', {
      windowId
    })).map(tabRecord).sort((a, b) => a.id - b.id);
  }
  function sameTabs(before, after, checkOrder = false, checkActive = true) {
    if (before.length !== after.length) throw new Error('The tab set changed. Read it again.');
    before.forEach((tab, i) => {
      for (const key of ['id', 'windowId', 'url', 'pinned', ...(checkActive ? ['active'] : []), ...(checkOrder ? ['index'] : [])]) {
        if (tab[key] !== after[i][key]) throw new Error(`Tab state changed (${key}).`);
      }
    });
  }
  async function focusCurrentWindow() {
    if (busy || canUndo || needsRecovery || unknown) return;
    try {
      const focused = nativeMode ? (await request('scopes')).find(s => s.focused) : await probeAPI.call('windows', 'getLastFocused', {});
      if (busy || canUndo || needsRecovery || unknown || !focused) return;
      const option = Array.from($('window').children).find(o => Number(o.value) === focused.id);
      if (option) {
        const changed = Number($('window').value) !== focused.id || nativeMode && scopeToken !== null && focused.token && focused.token !== scopeToken;
        if (nativeMode) {
          option.textContent = focused.name + (Number.isSafeInteger(focused.tabCount) ? ` · tabs: ${focused.tabCount}` : '');
          scopeTokens.set(focused.id, focused.token);
        }
        scopeToken = focused.token ?? null;
        if (changed) {
          $('window').value = String(focused.id);
          snapshot = null;
          proposal = null;
          recoveryPlan = null;
          enableControls();
          preview.textContent = nativeMode ? 'The group changed. Read its tree again.' : 'Read the selected group to see its tabs.';
        }
      }
    } catch (error) {
      if (nativeMode) {
        scopeUnavailable = true;
        snapshot = null;
        proposal = null;
        recoveryPlan = null;
        enableControls();
        status.textContent = safeError(error);
      }
    }
  }
  async function refreshWindows() {
    try {
      const scopes = await request('scopes');
      if (Array.isArray(scopes) && scopes.length && scopes.every(s => Number.isSafeInteger(s.id) && typeof s.name === 'string')) {
        nativeMode = true;
        scopeUnavailable = false;
        scopeTokens.clear();
        scopes.forEach(s => scopeTokens.set(s.id, s.token));
        const previous = $('window').value;
        const options = scopes.map(s => {
          const o = document.createElement('option');
          o.value = String(s.id);
          o.textContent = s.name + (Number.isSafeInteger(s.tabCount) ? ` · tabs: ${s.tabCount}` : '');
          return o;
        });
        $('window').replaceChildren(...options);
        const focused = scopes.filter(s => s.focused);
        const selected = scopes.find(s => String(s.id) === previous) ?? (focused.length === 1 ? focused[0] : null);
        if (!selected) {
          const placeholder = document.createElement('option');
          placeholder.value = '';
          placeholder.textContent = 'Choose a native group';
          $('window').replaceChildren(placeholder, ...options);
          scopeUnavailable = true;
        }
        $('window').value = selected ? String(selected.id) : '';
        scopeToken = scopeTokens.get(Number($('window').value)) ?? null;
        snapshot = null;
        proposal = null;
        recoveryPlan = null;
        enableControls();
        return;
      }
      if (nativeMode) throw new Error('Native groups are unavailable. Reconnect and refresh groups.');
    } catch (error) {
      if (nativeMode || !/^Unsupported (?:native )?command$/.test(error.message)) {
        scopeUnavailable = true;
        snapshot = null;
        proposal = null;
        recoveryPlan = null;
        throw error;
      }
      // Older installed bridge uses the guarded extension scope route.
    }
    const allTabs = await probeAPI.call('tabs', 'query', {});
    const ownRoot = probeAPI.raw.runtime.getURL('');
    const groups = new Map();
    for (const tab of allTabs) {
      if (tab.url?.startsWith(ownRoot)) continue;
      groups.set(tab.windowId, (groups.get(tab.windowId) || 0) + 1);
    }
    const previous = $('window').value;
    $('window').replaceChildren();
    for (const id of groups.keys()) {
      const option = document.createElement('option');
      option.value = String(id);
      option.textContent = `Window ${id}`;
      $('window').append(option);
    }
    if (groups.has(Number(previous))) $('window').value = previous;else {
      $('window').value = '';
      scopeUnavailable = true;
      try {
        const focused = nativeMode ? {
          id: (await request('scopes')).find(s => s.focused)?.id
        } : await probeAPI.call('windows', 'getLastFocused', {});
        if (groups.has(focused.id)) {
          $('window').value = String(focused.id);
          scopeUnavailable = false;
        }
      } catch {} // No focus proof: require an explicit selection instead of guessing.
    }
    snapshot = null;
    proposal = null;
    recoveryPlan = null;
    enableControls();
  }
  function settings() {
    return OrionProviderSettings.publicSettings({
      endpoint: $('endpoint').value,
      model: $('model').value,
      maxDepth: Number($('depth').value),
      preserveExisting: $('preserve').checked
    });
  }
  function keyOrigin(endpoint) {
    return OrionAIProvider.completionURL(endpoint).origin;
  }
  async function loadSavedKey() {
    const origin = keyOrigin($('endpoint').value);
    const initialKey = $('key').value;
    const result = await request('loadKey', {
      origin
    });
    if (origin !== keyOrigin($('endpoint').value) || $('key').value !== initialKey) return;
    if (result.found && !initialKey) $('key').value = result.key;
    $('keyStatus').textContent = result.found ? 'Key saved in macOS Keychain.' : 'Enter a key and save settings to keep it in macOS Keychain.';
  }
  async function saveSettings(pair = credentials()) {
    const value = pair.config;
    const key = pair.apiKey;
    if (key) {
      const saved = await request('saveKey', {
        origin: keyOrigin(value.endpoint),
        key
      });
      if (saved.saved !== true) throw new Error('macOS Keychain did not confirm saving the key.');
      $('keyStatus').textContent = 'Key saved in macOS Keychain.';
    }
    await probeAPI.call('storage.local', 'set', {
      orionAISettings: value
    });
    return value;
  }
  async function capture(recovery = false) {
    snapshot = null;
    proposal = null;
    recoveryPlan = null;
    baselineTabs = await windowTabs();
    const initial = await request(nativeMode ? 'captureNative' : recovery ? 'captureRecovery' : 'capture', {
      windowId: Number($('window').value),
      tabs: baselineTabs
    });
    if (initial.captureToken) {
      const token = initial.captureToken;
      try {
        const ids = initial.bindingIDs;
        if (!Array.isArray(ids) || !ids.length || new Set(ids).size !== ids.length || ids.some(id => !baselineTabs.some(tab => tab.id === id && !tab.pinned))) throw new Error('Invalid duplicate-identity request.');
        for (const id of ids) {
          status.textContent = 'Checking duplicates with temporary selection; the original selection will be restored.';
          await request('selectIdentity', {
            token,
            id
          });
          await probeAPI.call('tabs', 'update', id, {
            active: true
          });
          const selected = await windowTabs();
          sameTabs(baselineTabs, selected, true, false);
          const active = selected.filter(tab => tab.active);
          if (active.length !== 1 || active[0].id !== id) throw new Error('Selected tab identity did not match the native object.');
          for (let attempt = 0; attempt < 3; attempt++) {
            try {
              await request('confirmIdentity', {
                token,
                id,
                activeId: active[0].id
              });
              break;
            } catch (error) {
              if (attempt === 2 || !['Selected duplicate URL mismatch', 'Selected duplicate has no native row'].includes(error.message)) throw error;
              await new Promise(resolve => setTimeout(resolve, 1000));
              const refreshed = await windowTabs();
              sameTabs(baselineTabs, refreshed, true, false);
              const chosen = refreshed.filter(tab => tab.active);
              if (chosen.length !== 1 || chosen[0].id !== id) throw new Error('The selected duplicate changed during confirmation.');
            }
          }
        }
        snapshot = await request('finishCapture', {
          token
        });
      } catch (error) {
        snapshot = null;
        try {
          await request('cancelCapture', {
            token
          });
          sameTabs(baselineTabs, await windowTabs(), true);
        } catch (restoreError) {
          throw new Error(`${error.message} Selection restoration was not confirmed: ${restoreError.message}`);
        }
        throw error;
      }
    } else snapshot = initial;
    scopeToken = snapshot.scope?.groupKey ?? scopeToken;
    OrionTreePlan.indexSnapshot(snapshot);
    sameTabs(baselineTabs, await windowTabs(), true);
    const scopeOption = Array.from($('window').children).find(option => Number(option.value) === Number($('window').value));
    if (scopeOption) scopeOption.textContent = (nativeMode ? snapshot.scope.name : `Window ${$('window').value}`) + ` · tabs: ${snapshot.tabs.filter(tab => !tab.pinned).length}`;
    proposal = null;
    $('preview-title').textContent = 'Current tree';
    renderTree();
    return snapshot;
  }
  async function persistentIdentity(allowRecapture = false) {
    if (snapshot?.identityMode === 'native-session') return request('nativeSessionIdentity');
    await request('refreshIdentity');
    for (let attempt = 0; attempt < 8; attempt++) {
      await new Promise(resolve => setTimeout(resolve, 1000));
      try {
        const identity = await request('persistentIdentity');
        if (identity.exposureToken) {
          status.textContent = 'Checking sleeping duplicates with temporary selection, then restoring the original selection.';
          const result = await OrionPersistentIdentity.expose({
            token: identity.exposureToken,
            ids: identity.bindingIDs,
            nativeSelections: identity.nativeSelections,
            windowId: Number($('window').value),
            beforeTabs: baselineTabs,
            request,
            call: (...args) => probeAPI.call(...args),
            sameTabs
          });
          if (result.snapshot.revision !== snapshot.revision) {
            proposal = null;
            if (!allowRecapture) throw new Error('Duplicate loading changed the tree. Generate a new proposal.');
            await capture();
          }
          baselineTabs = result.tabs.map(tabRecord);
          await request('refreshIdentity');
          continue;
        }
        return identity;
      } catch (error) {
        if (!error.message.includes('not fresh yet') || attempt === 7) throw error;
      }
    }
  }
  async function permitEndpoint(endpoint) {
    const url = OrionAIProvider.completionURL(endpoint);
    const origin = `${url.protocol}//${url.hostname}/*`;
    const permissions = probeAPI.raw.permissions;
    if (!permissions) throw new Error('Orion provider permissions are unavailable. Reopen the extension controller.');
    const allowed = await probeAPI.call('permissions', 'contains', {
      origins: [origin]
    });
    if (!allowed && !(await probeAPI.call('permissions', 'request', {
      origins: [origin]
    }))) throw new Error('Provider permission denied. Grant this endpoint access in AI settings.');
  }
  async function applyProposal() {
    if (!proposal || !snapshot || journalPending || canUndo) throw new Error('Read and review a fresh proposal first.');
    setPhase('checking', 'Checking the captured group and tab identities…');
    sameTabs(baselineTabs, await windowTabs());
    await persistentIdentity();
    const fresh = await request('snapshot');
    if (fresh.revision !== snapshot.revision) throw new Error('The group or tabs changed. Read the tree and generate a new proposal.');
    sameTabs(baselineTabs, await windowTabs());
    await saveCheckpoint({
      before: snapshot,
      tabs: baselineTabs,
      plan: proposal,
      phase: 'prepared'
    });
    setPhase('applying', 'Applying the order in Orion… This step cannot be cancelled.');
    const result = await request('apply', {
      plan: proposal
    });
    sameTabs(baselineTabs, await windowTabs());
    if (!canUndo || needsRecovery) throw new Error('Apply was not verified. Inspect recovery before continuing.');
    record('apply');
    await saveCheckpoint({
      before: snapshot,
      tabs: baselineTabs,
      after: result,
      phase: 'applied'
    });
    snapshot = result;
    proposal = null;
    view = 'current';
    renderTree();
    setPhase('applied', 'Tabs organized. Undo restores the original tree; Keep this order finishes the transaction.');
  }
  async function inspect(kind) {
    inspection = null;
    inspectionKind = null;
    $('recoveryConfirmed').checked = false;
    // A new process has no captured native context. Establish this visible
    // scope explicitly before asking for the live revision used in acknowledgment.
    if (kind === 'prior' && !unknown) {
      if (transactionPhase !== 'idle') throw new Error('Inspect the retained transaction first.');
      await capture(true);
    }
    const item = await request(kind === 'retained' ? 'inspectRetainedTransaction' : 'inspectJournal');
    if (kind === 'retained') {
      if (typeof item.inspectionToken !== 'string' || !item.transactionID || typeof item.journalRevision !== 'string' || ![1, 2].includes(item.journalVersion) || !item.journalIdentity || typeof item.live?.available !== 'boolean' || (item.live.available ? typeof item.live.revision !== 'string' : item.live.revision !== null)) throw new Error('Bridge inspection is incomplete. Update the bridge; no evidence was discarded.');
      inspection = item;
    } else {
      if (!item.journal || typeof item.journalRevision !== 'string') throw new Error('No readable journal. Keep the evidence and check the bridge installation.');
      const live = await request('snapshot');
      inspection = {
        ...item,
        journalVersion: item.journal.version,
        journalIdentity: item.journal.identity,
        live: {
          available: true,
          revision: live.revision
        }
      };
    }
    inspectionKind = kind;
    const j = inspection.journal;
    $('inspectionSummary').textContent = `${kind === 'retained' ? 'Retained transaction' : 'Previous journal'}: ${inspection.transactionPhase || j.phase}. ${inspection.live.available ? 'Current layout is readable.' : 'Current layout is unavailable; restoration is not verified.'} ${kind === 'retained' ? 'Abandoning archives the evidence, makes no tab moves and permanently ends this Undo/recovery.' : 'Acknowledging archives the old journal and keeps the current layout; it does not verify original restoration.'}`;
    setPhase(unknown ? 'unknown' : 'recovery', unknown ? 'Read-only inspection complete. The timed-out request is unresolved; mutations stay locked.' : 'Review the inspection and confirm the consequence before continuing.');
  }
  async function run(action) {
    if (busy) return;
    // Immutable endpoint/settings/credential pair before the first asynchronous step.
    let pair;
    try {
      if (action === 'organize' || action === 'save') pair = credentials();
    } catch (error) {
      status.textContent = safeError(error);
      return;
    }
    busy = true;
    const epoch = ++operationID;
    enableControls();
    try {
      if (action === 'refresh') {
        await connect();
        if (unknown) await reconcile();
        if (!canUndo && !needsRecovery && !unknown) await refreshWindows();
        status.textContent = unknown ? 'Outcome remains unknown. Keep mutations locked and reopen the bridge to inspect recovery.' : needsRecovery ? 'Recovery needs attention. Open Recovery below.' : canUndo ? 'Undo is available for the retained transaction.' : 'Connected. The selected group is the organization target.';
      } else if (action === 'loadKey') {
        await loadSavedKey();
        status.textContent = $('keyStatus').textContent;
      } else if (action === 'save') {
        await saveSettings(pair);
        status.textContent = 'Settings saved. Credentials stay in macOS Keychain.';
      } else {
        if (!supported || !connected || unknown && !['inspectRetained', 'inspectPrior'].includes(action)) throw new Error(unknown ? 'Outcome unknown. Await the exact native response; read-only inspection cannot authorize another mutation.' : 'Reconnect an updated R49 Native Tree Bridge before continuing.');
        if (['undo', 'keep'].includes(action) && !canUndo) throw new Error('No verified Undo is available. Inspect recovery.');
        if (action === 'apply' && mode !== 'advanced') throw new Error('Manual Apply is only available in Advanced mode.');
        if (action === 'read' && (canUndo || transactionPhase !== 'idle')) throw new Error('Finish Undo before reading another tree.');
        if (['organize', 'apply'].includes(action) && (canUndo || journalPending)) throw new Error('Finish Undo or resolve recovery before organizing again.');
        if (action === 'read') {
          await capture();
          view = 'current';
          renderTree();
          setPhase('read', `${snapshot.tabs.filter(t => !t.pinned).length} tabs read, including sleeping tabs. Pinned tabs stay unchanged.`);
        }
        if (action === 'organize') {
          if (scopeUnavailable) throw new Error('Refresh the native groups and choose a visible target.');
          const scope = $('window').value,
            token = scopeToken,
            auto = mode === 'auto';
          if (!scope || !token && nativeMode) throw new Error('No verified group selected. Refresh native groups.');
          generation = new AbortController();
          const signal = generation.signal;
          setPhase('checking', 'Checking AI settings and permission…');
          if (!pair.apiKey && !['localhost', '127.0.0.1'].includes(new URL(pair.config.endpoint).hostname)) throw new Error('Add an API key in AI settings before organizing.');
          await saveSettings(pair);
          checkCancelled(signal);
          await permitEndpoint(pair.config.endpoint);
          checkCancelled(signal);
          setPhase('reading', 'Reading the selected native group…');
          if (!snapshot || auto) await capture();else sameTabs(baselineTabs, await windowTabs());
          checkCancelled(signal);
          await persistentIdentity(true);
          checkCancelled(signal);
          if ($('window').value !== scope || nativeMode && snapshot.scope.groupKey !== token) throw new Error('The selected group changed. Read it again.');
          setPhase('generating', 'AI is proposing an order…');
          const result = await OrionAIProvider.proposePlan({
            ...pair.config,
            apiKey: pair.apiKey
          }, snapshot, {
            ...pair.config,
            signal,
            requireChanges: true,
            onProgress: p => {
              if (signal.aborted || epoch !== operationID) return;
              status.textContent = p.phase === 'catalogue' ? 'AI is identifying topics…' : `${p.phase === 'classify' ? 'Classifying tabs' : p.phase === 'reattach' ? 'Reviewing separate tabs' : 'Checking branches'}: batch ${p.done} of ${p.total}…`;
            }
          });
          checkCancelled(signal);
          if (epoch !== operationID) throw new Error('Stale proposal discarded.');
          const fresh = await request('snapshot');
          checkCancelled(signal);
          if (fresh.revision !== snapshot.revision || $('window').value !== scope) throw new Error('The group or tabs changed during AI generation. Read the tree again.');
          proposal = result.noChanges ? null : result.plan;
          view = 'proposed';
          renderTree();
          if (result.maxDepth > pair.config.maxDepth) $('depth').value = String(result.maxDepth);
          generation = null;
          enableControls();
          if (!proposal) setPhase('nochanges', 'No changes suggested. Nothing was applied.');else if (auto) await applyProposal();else setPhase('preview', 'Review the proposed tree. Tabs have not changed.');
        }
        if (action === 'apply') await applyProposal();
        if (action === 'keep') {
          const result = await request('keep');
          if (result.accepted !== true || needsRecovery || canUndo || transactionPhase !== 'idle') throw new Error('Keeping the order was not confirmed. Inspect recovery.');
          clearResolved();
          await saveCheckpoint({
            phase: 'accepted'
          });
          setPhase('idle', 'Order kept. Undo finished. You can organize another group.');
        }
        if (action === 'undo') {
          let checkpoint;
          try {
            checkpoint = (await probeAPI.call('storage.local', 'get', 'orionSortCheckpoint')).orionSortCheckpoint;
          } catch (error) {
            if (!nativeMode) throw error;
          }
          if (!nativeMode) {
            if (!checkpoint?.tabs) throw new Error('Original tab checkpoint is unavailable. Inspect recovery.');
            sameTabs(checkpoint.tabs, await windowTabs());
          }
          setPhase('undoing', 'Restoring the original tree… This step cannot be cancelled.');
          const result = await request('undo');
          if (!nativeMode) sameTabs(checkpoint.tabs, await windowTabs(), true);
          if (needsRecovery || canUndo) throw new Error('Undo needs recovery. Inspect the retained transaction.');
          record('undo');
          clearResolved();
          snapshot = result;
          renderTree();
          await saveCheckpoint({
            phase: 'undone'
          });
          setPhase('idle', 'Original tree, order and expansion restored. Native tab objects preserved.');
        }
        if (action === 'recoveryPreview') {
          if (transactionPhase !== 'idle') {
            await inspect('retained');
          } else {
            const journal = await request('recoveryJournal');
            await capture(true);
            const identity = await persistentIdentity();
            recoveryPlan = OrionRecovery.plan(journal, snapshot, identity);
            if (typeof OrionTreeView !== 'undefined') OrionTreeView.render(preview, snapshot, recoveryPlan, {
              proposed: true
            });else preview.textContent = OrionTreePlan.describe(snapshot, recoveryPlan);
            setPhase('recovery', 'Original tree matched by UUID. Review it before restoring.');
          }
        }
        if (action === 'recover') {
          if (!recoveryPlan) throw new Error('Inspect the recovery journal first.');
          await request('recover', {
            plan: recoveryPlan
          });
          if (needsRecovery || transactionPhase !== 'idle') throw new Error('Recovery was not resolved. Keep the evidence and inspect again.');
          clearResolved();
          record('recover');
          await saveCheckpoint({
            phase: 'recovered'
          });
          setPhase('idle', 'Original tree restored. Recovery journal archived.');
        }
        if (action === 'acceptCurrent') {
          if (transactionPhase !== 'idle' || journalPhase !== 'applied') throw new Error('Inspect unresolved recovery first.');
          await capture(true);
          await persistentIdentity(true);
          const result = await request('acceptCurrent', {
            expectedRevision: snapshot.revision
          });
          if (result.accepted !== true || needsRecovery || transactionPhase !== 'idle') throw new Error('Journal archival was not confirmed. Inspect recovery.');
          clearResolved();
          await saveCheckpoint({
            phase: 'accepted'
          });
          setPhase('idle', 'Current tree kept. Previous journal archived.');
        }
        if (action === 'inspectRetained') await inspect('retained');
        if (action === 'inspectPrior') await inspect('prior');
        if (['recoverOriginal', 'recoverApplied', 'abandonRetained', 'acknowledge'].includes(action)) {
          if (!inspection || !$('recoveryConfirmed').checked) throw new Error('Inspect the evidence and confirm the consequence first.');
          const i = inspection;
          if (action === 'abandonRetained') {
            if (inspectionKind !== 'retained') throw new Error('Inspect a retained transaction first.');
            const resolution = await request('abandonRetainedTransaction', {
              confirmed: true,
              inspectionToken: i.inspectionToken,
              expectedTransactionID: i.transactionID,
              expectedJournalRevision: i.journalRevision,
              expectedJournalVersion: i.journalVersion,
              expectedJournalIdentity: i.journalIdentity,
              expectedLiveAvailable: i.live.available,
              expectedRevision: i.live.revision
            });
            if (resolution?.abandoned !== true || resolution.acknowledged !== true || resolution.restorationVerified !== false || resolution.currentLayoutVerified !== false || needsRecovery || canUndo || transactionPhase !== 'idle' || journalPhase !== 'acknowledged') throw new Error('Evidence archival was not verified. Inspect the retained transaction again.');
            clearResolved();
            await saveCheckpoint({
              phase: 'abandoned'
            });
            setPhase('idle', 'Undo/recovery abandoned. Evidence archived; no tabs moved. Restoration was not verified.');
          } else if (action === 'acknowledge') {
            if (inspectionKind !== 'prior' || !i.live.available) throw new Error('Inspect the previous journal and current layout first.');
            await request('acknowledgeCurrent', {
              confirmed: true,
              expectedJournalRevision: i.journalRevision,
              expectedJournalVersion: i.journalVersion,
              expectedJournalIdentity: i.journalIdentity,
              expectedRevision: i.live.revision
            });
            if (needsRecovery || canUndo || transactionPhase !== 'idle' || journalPhase !== 'acknowledged') throw new Error('Acknowledgment was not verified. Inspect the journal again.');
            clearResolved();
            await saveCheckpoint({
              phase: 'acknowledged'
            });
            setPhase('idle', 'Current layout acknowledged. Evidence archived; original restoration was not verified.');
          } else {
            if (inspectionKind !== 'retained' || !i.live.available) throw new Error('A readable retained layout inspection is required.');
            const resolution = await request('recoverRetained', {
              expectedRevision: i.live.revision,
              target: action === 'recoverApplied' ? 'applied' : 'original'
            });
            if (resolution?.recovered !== true || needsRecovery || !['idle', 'applied'].includes(transactionPhase)) throw new Error('Retained recovery was not verified. Inspect the transaction again.');
            clearResolved();
            await saveCheckpoint({
              phase: 'recovered'
            });
            setPhase(canUndo ? 'applied' : 'idle', canUndo ? 'Applied order recovered. Undo or keep the order.' : 'Original layout recovered. You can organize again.');
          }
        }
      }
    } catch (error) {
      proposal = null;
      recoveryPlan = null;
      if (['abandonRetained', 'acknowledge', 'recoverOriginal', 'recoverApplied'].includes(action)) {
        inspection = null;
        inspectionKind = null;
        $('recoveryConfirmed').checked = false;
      }
      status.textContent = error.name === 'AbortError' ? 'Cancelled. Tabs were not changed.' : safeError(error, pair?.apiKey);
      phase = error.name === 'AbortError' ? 'cancelled' : unknown ? 'unknown' : 'error';
      if (error.unknown) await reconcile();
    } finally {
      generation = null;
      busy = false;
      enableControls();
    }
  }
  function safeError(error, key) {
    let message = String(error?.message || 'Operation failed. Reconnect the native bridge.');
    const currentKey = $('key')?.value.trim();
    if (currentKey) message = message.split(currentKey).join('[credential removed]');
    if (key) message = message.split(key).join('[credential removed]');
    // Never echo native JSON, request URLs or credential-bearing provider errors.
    if (/[А-Яа-я]/.test(message)) return 'Operation could not complete. Check AI settings, permissions and the selected group; tabs were not intentionally reapplied.';
    if (message.length > 320 || /Bearer |https?:\/\//i.test(message)) return 'Operation failed. Check the provider settings or inspect native recovery.';
    return message;
  }
  function setMode(next) {
    if (busy || !['auto', 'advanced'].includes(next)) return false;
    mode = next;
    enableControls();
    renderTree();
    return true;
  }
  controls.forEach(id => $(id)?.addEventListener('click', () => run(id)));
  $('recoveryConfirmed')?.addEventListener('change', enableControls);
  $('modeAuto')?.addEventListener('click', () => setMode('auto'));
  $('modeAdvanced')?.addEventListener('click', () => setMode('advanced'));
  $('cancel')?.addEventListener('click', () => {
    generation?.abort();
    enableControls();
  });
  $('search')?.addEventListener('input', renderTree);
  document.addEventListener?.('keydown', event => {
    if (mode === 'advanced' && event.key === '/' && !['INPUT', 'SELECT', 'TEXTAREA'].includes(event.target?.tagName)) {
      event.preventDefault();
      $('search').focus();
    }
  });
  for (const name of ['Current', 'Proposed']) $('view' + name)?.addEventListener('click', () => {
    view = name.toLowerCase();
    renderTree();
  });
  $('endpoint').addEventListener('change', () => {
    if (busy) return;
    $('key').value = '';
    $('keyStatus').textContent = '';
    run('loadKey');
  });
  $('window').addEventListener('change', () => {
    if (busy || canUndo || needsRecovery || unknown) return;
    scopeToken = scopeTokens.get(Number($('window').value)) ?? null;
    scopeUnavailable = !$('window').value;
    clearResolved();
    enableControls();
  });
  async function initialize() {
    busy = true;
    enableControls();
    try {
      let stored = {};
      try {
        stored = await probeAPI.call('storage.local', 'get', ['orionAISettings']);
      } catch {}
      const config = OrionProviderSettings.publicSettings(stored.orionAISettings);
      $('endpoint').value = config.endpoint;
      $('model').value = config.model;
      $('depth').value = String(config.maxDepth);
      $('preserve').checked = config.preserveExisting;
      await connect();
      await refreshWindows();
      if (canUndo && !nativeMode) {
        try {
          const checkpoint = (await probeAPI.call('storage.local', 'get', 'orionSortCheckpoint')).orionSortCheckpoint;
          const id = checkpoint?.before?.scope?.windowId;
          if (Array.from($('window').children).some(o => o.value === String(id))) $('window').value = String(id);
        } catch {}
      }
      let keyError = null;
      try {
        await loadSavedKey();
      } catch (error) {
        keyError = safeError(error);
        $('keyStatus').textContent = keyError;
      }
      status.textContent = keyError ? keyError : scopeUnavailable ? 'Choose a native group explicitly; the focused group could not be verified.' : needsRecovery ? 'Recovery needs attention. Inspect the journal below.' : canUndo ? 'Undo is available for the retained transaction.' : 'Ready. Organize tabs in the selected group.';
    } catch (error) {
      status.textContent = safeError(error);
    } finally {
      busy = false;
      enableControls();
    }
  }
  renderTree();
  initialize();
})();
