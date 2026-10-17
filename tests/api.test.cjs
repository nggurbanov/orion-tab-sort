const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const source = fs.readFileSync(require.resolve('../extension/api.js'), 'utf8');

test('routes nested storage object through promise browser API', async () => {
  const context = vm.createContext({ browser: {
    storage: { local: { async get(key) { return { [key]: 'value' }; } } }
  }});
  vm.runInContext(source, context);
  assert.equal((await context.probeAPI.call('storage.local', 'get', 'fixture')).fixture, 'value');
  await assert.rejects(context.probeAPI.call('tabs', 'missing'), /Unavailable API/);
});

test('callback API surfaces runtime.lastError instead of silent success', async () => {
  const chrome = { runtime: {}, tabs: { update(id, properties, callback) {
    chrome.runtime.lastError = { message: 'Unsupported openerTabId' };
    callback(undefined);
    delete chrome.runtime.lastError;
  } } };
  const context = vm.createContext({ chrome });
  vm.runInContext(source, context);
  await assert.rejects(context.probeAPI.call('tabs', 'update', 1, { openerTabId: 2 }), /Unsupported openerTabId/);
});
