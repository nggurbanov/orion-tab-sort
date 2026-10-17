const {
  test
} = require('node:test');
const assert = require('node:assert/strict');
const provider = require('../extension/ai-provider.js');
const config = {
  endpoint: 'https://ai.example/v1',
  model: 'test-model'
};
const snapshot = {
  scope: {
    windowId: 1
  },
  revision: 'before',
  tabs: [{
    id: 1,
    key: 'a',
    title: 'Project',
    url: 'https://example.com/',
    parentKey: null,
    index: 0,
    pinned: false,
    expanded: false,
    active: true
  }, {
    id: 2,
    key: 'b',
    title: 'Docs',
    url: 'https://example.com/docs',
    parentKey: null,
    index: 1,
    pinned: false,
    expanded: false,
    active: false
  }]
};
function response(forest) {
  return {
    ok: true,
    status: 200,
    json: async () => ({
      choices: [{
        message: {
          content: JSON.stringify({
            trees: forest
          })
        }
      }]
    })
  };
}
test('repairs duplicate IDs once and returns only a locally validated plan', async () => {
  const bodies = [];
  const result = await provider.proposePlan(config, snapshot, {
    fetch: async (url, request) => {
      bodies.push(JSON.parse(request.body));
      return response(bodies.length === 1 ? [1, 1, 2] : [{
        parent: 1,
        children: [2]
      }]);
    }
  });
  assert.equal(result.attempts, 2);
  assert.equal(result.plan.nodes[1].parentKey, 'a');
  assert.match(bodies[1].messages.at(-1).content, /same tab more than once/);
  assert.equal(snapshot.tabs[1].parentKey, null);
});
test('refuses repeated invalid proposals without an unbounded retry loop', async () => {
  let calls = 0;
  await assert.rejects(provider.proposePlan(config, snapshot, {
    fetch: async () => {
      calls++;
      return response([1, 999]);
    }
  }), /twice/);
  assert.equal(calls, 2);
});
test('does not retry authentication or other API failures', async () => {
  let calls = 0;
  await assert.rejects(provider.proposePlan(config, snapshot, {
    fetch: async () => {
      calls++;
      return {
        ok: false,
        status: 401,
        json: async () => ({
          error: {}
        })
      };
    }
  }), /HTTP 401/);
  assert.equal(calls, 1);
});
test('real provider accepts guarded native-only sleeping IDs and preserves negative parent references', async () => {
  const sleeping = {
    ...structuredClone(snapshot),
    tabs: [...structuredClone(snapshot.tabs), {
      id: -1,
      key: 'native-1',
      nativeOnly: true,
      title: 'Sleeping parent',
      url: 'https://example.com/sleep',
      parentKey: null,
      index: 2,
      pinned: false,
      expanded: true,
      active: false
    }, {
      id: -2,
      key: 'native-2',
      nativeOnly: true,
      title: 'Sleeping child',
      url: 'https://example.com/child',
      parentKey: 'native-1',
      index: 0,
      pinned: false,
      expanded: false,
      active: false
    }]
  };
  let metadata;
  const result = await provider.proposePlan(config, sleeping, {
    fetch: async (url, request) => {
      metadata = JSON.parse(JSON.parse(request.body).messages[1].content).tabs;
      return response([1, 2, {
        parent: -1,
        children: [-2]
      }]);
    }
  });
  assert.deepEqual(metadata.map(t => t.id), [1, 2, -1, -2]);
  assert.equal(metadata.at(-1).parentId, -1);
  assert.equal(result.plan.nodes.at(-1).parentKey, 'native-1');
  let calls = 0;
  sleeping.tabs.at(-1).nativeOnly = false;
  await assert.rejects(provider.proposePlan(config, sleeping, {
    fetch: async () => {
      calls++;
      return response([]);
    }
  }), /identity/);
  assert.equal(calls, 0);
});
test('repairs malformed or empty output once through the real provider, never loops', async () => {
  for (const content of ['Not JSON', null]) {
    let calls = 0;
    const result = await provider.proposePlan(config, snapshot, {
      fetch: async () => {
        calls++;
        return calls === 1 ? {
          ok: true,
          status: 200,
          json: async () => ({
            choices: [{
              message: {
                content
              }
            }]
          })
        } : response([1, 2]);
      }
    });
    assert.equal(calls, 2);
    assert.equal(result.attempts, 2);
    assert.equal(result.plan.nodes.length, 2);
  }
  let calls = 0;
  await assert.rejects(provider.proposePlan(config, snapshot, {
    fetch: async () => {
      calls++;
      return {
        ok: true,
        status: 200,
        json: async () => ({
          choices: [{
            message: {
              content: 'not JSON'
            }
          }]
        })
      };
    }
  }), /twice/);
  assert.equal(calls, 2);
});
test('flat placements compile to a native tree with each ID represented once', async () => {
  const result = await provider.proposePlan(config, snapshot, {
    fetch: async () => ({
      ok: true,
      status: 200,
      json: async () => ({
        choices: [{
          message: {
            content: JSON.stringify({
              placements: [{
                id: 1,
                parentId: null
              }, {
                id: 2,
                parentId: 1
              }]
            })
          }
        }]
      })
    })
  });
  assert.deepEqual(result.forest, [{
    parent: 1,
    children: [2]
  }]);
  assert.equal(result.plan.nodes[1].parentKey, 'a');
});
test('duplicate and missing flat placement records never produce a valid plan', async () => {
  for (const placements of [[{
    id: 1,
    parentId: null
  }, {
    id: 1,
    parentId: null
  }], [{
    id: 1,
    parentId: null
  }]]) {
    let calls = 0;
    await assert.rejects(provider.proposePlan(config, snapshot, {
      fetch: async () => {
        calls++;
        return {
          ok: true,
          status: 200,
          json: async () => ({
            choices: [{
              message: {
                content: JSON.stringify({
                  placements
                })
              }
            }]
          })
        };
      }
    }));
    assert.equal(calls, 2);
  }
});
test('preserved links are locked in the placement compiler instead of delegated to the model', async () => {
  const existing = structuredClone(snapshot);
  existing.tabs[1].parentKey = 'a';
  const fetch = async () => ({
    ok: true,
    status: 200,
    json: async () => ({
      choices: [{
        message: {
          content: '{"placements":[{"id":1,"parentId":null},{"id":2,"parentId":null}]}'
        }
      }]
    })
  });
  const preserved = await provider.proposePlan(config, existing, {
    fetch
  });
  assert.equal(preserved.plan.nodes[1].parentKey, 'a');
  const unlocked = await provider.proposePlan(config, existing, {
    fetch,
    preserveExisting: false
  });
  assert.equal(unlocked.plan.nodes[1].parentKey, null);
});
test('optional cyclic or overdeep AI links are dropped while every tab and locked branch remains', async () => {
  const existing = structuredClone(snapshot);
  existing.tabs[1].parentKey = 'a';
  const fetch = async () => ({
    ok: true,
    status: 200,
    json: async () => ({
      choices: [{
        message: {
          content: '{"placements":[{"id":1,"parentId":2},{"id":2,"parentId":1}]}'
        }
      }]
    })
  });
  const repaired = await provider.proposePlan(config, existing, {
    fetch,
    maxDepth: 2
  });
  assert.equal(repaired.plan.nodes.length, 2);
  assert.equal(repaired.plan.nodes[0].parentKey, null);
  assert.equal(repaired.plan.nodes[1].parentKey, 'a');
  const flat = await provider.proposePlan(config, snapshot, {
    fetch,
    maxDepth: 1
  });
  assert.ok(flat.plan.nodes.every(node => node.parentKey === null));
});
test('preserving an existing branch raises a too-small default depth before requesting a plan', async () => {
  const existing = structuredClone(snapshot);
  existing.tabs[1].parentKey = 'a';
  const result = await provider.proposePlan(config, existing, {
    maxDepth: 1,
    fetch: async (url, request) => {
      assert.match(JSON.parse(request.body).messages[0].content, /including roots: 2/);
      return {
        ok: true,
        status: 200,
        json: async () => ({
          choices: [{
            message: {
              content: '{"placements":[{"id":1,"parentId":null},{"id":2,"parentId":null}]}'
            }
          }]
        })
      };
    }
  });
  assert.equal(result.maxDepth, 2);
  assert.equal(result.plan.nodes[1].parentKey, 'a');
});
test('requested regrouping repairs an unchanged plan once and reports genuine structure changes', async () => {
  const bodies = [];
  const r = await provider.proposePlan(config, snapshot, {
    preserveExisting: false,
    requireChanges: true,
    fetch: async (u, q) => {
      bodies.push(JSON.parse(q.body));
      return response(bodies.length === 1 ? [1, 2] : [{
        parent: 1,
        children: [2]
      }]);
    }
  });
  assert.equal(r.attempts, 2);
  assert.equal(r.noChanges, false);
  assert.equal(r.summary.parentChanges, 1);
  assert.match(bodies[1].messages.at(-1).content, /unchanged/);
  assert.match(bodies[0].messages[0].content, /topics and tasks/);
});
test('repeated unchanged plans are explicitly marked rather than counted as sorting', async () => {
  let calls = 0;
  const r = await provider.proposePlan(config, snapshot, {
    requireChanges: true,
    fetch: async () => {
      calls++;
      return response([1, 2]);
    }
  });
  assert.equal(calls, 2);
  assert.equal(r.noChanges, true);
  assert.equal(r.summary.changedTabs, 0);
});
test('full topic regrouping compiles complete flat groups into shallow trees across old branches', async () => {
  const old = structuredClone(snapshot);
  old.tabs[1].parentKey = 'a';
  old.tabs[1].index = 0;
  const r = await provider.proposePlan(config, old, {
    preserveExisting: false,
    fetch: async () => ({
      ok: true,
      status: 200,
      json: async () => ({
        choices: [{
          message: {
            content: JSON.stringify({
              groups: [{
                topic: 'Project',
                parent: 2,
                tabs: [1, 2]
              }],
              ungrouped: []
            })
          }
        }]
      })
    })
  });
  assert.equal(r.plan.nodes.find(n => n.id === 1).parentKey, 'b');
  assert.equal(r.plan.nodes.find(n => n.id === 2).parentKey, null);
});
test('topic grouping rejects overlap, repeated parents and missing IDs rather than dropping tabs', async () => {
  for (const result of [{
    groups: [{
      topic: 'Project',
      parent: 1,
      tabs: [1, 2]
    }],
    ungrouped: [2]
  }, {
    groups: [{
      topic: 'Project',
      parent: 1,
      tabs: [1, 1, 2]
    }],
    ungrouped: []
  }, {
    groups: [],
    ungrouped: [1]
  }]) {
    let calls = 0;
    await assert.rejects(provider.proposePlan(config, snapshot, {
      preserveExisting: false,
      fetch: async () => {
        calls++;
        return {
          ok: true,
          status: 200,
          json: async () => ({
            choices: [{
              message: {
                content: JSON.stringify(result)
              }
            }]
          })
        };
      }
    }));
    assert.equal(calls, 2);
  }
});
test('one topic assignment per ID compiles to a shallow topic tree and rejects repeated assignment IDs', async () => {
  const result = {
    topics: [{
      id: 'p',
      name: 'Project',
      parent: 2
    }],
    assignments: [{
      id: 2,
      topic: 'p'
    }, {
      id: 1,
      topic: 'p'
    }]
  };
  const fetch = async () => ({
    ok: true,
    status: 200,
    json: async () => ({
      choices: [{
        message: {
          content: JSON.stringify(result)
        }
      }]
    })
  });
  const r = await provider.proposePlan(config, snapshot, {
    preserveExisting: false,
    fetch
  });
  assert.equal(r.plan.nodes.find(n => n.id === 1).parentKey, 'b');
  result.assignments.push({
    id: 1,
    topic: 'p'
  });
  await assert.rejects(provider.proposePlan(config, snapshot, {
    preserveExisting: false,
    fetch
  }), /ID: 1/);
});
test('topic representative hints cannot create cross-topic links or reject singleton assignments', async () => {
  const result = {
    topics: [{
      id: 'p',
      name: 'Project',
      parent: 2
    }, {
      id: 'unused',
      name: 'Unused',
      parent: 999
    }],
    assignments: [{
      id: 1,
      topic: 'p'
    }, {
      id: 2,
      topic: null
    }]
  };
  const fetch = async () => ({
    ok: true,
    status: 200,
    json: async () => ({
      choices: [{
        message: {
          content: JSON.stringify(result)
        }
      }]
    })
  });
  const r = await provider.proposePlan(config, snapshot, {
    preserveExisting: false,
    fetch
  });
  assert.equal(r.plan.nodes.length, 2);
  assert.ok(r.plan.nodes.every(n => n.parentKey === null));
});
test('ordered labels bind only to captured IDs and reject wrong-length responses', async () => {
  const result = {
    topics: [{
      id: 'p',
      name: 'Project',
      parent: 2
    }],
    assignmentTopics: ['p', 'p']
  };
  const fetch = async () => ({
    ok: true,
    status: 200,
    json: async () => ({
      choices: [{
        message: {
          content: JSON.stringify(result)
        }
      }]
    })
  });
  const r = await provider.proposePlan(config, snapshot, {
    preserveExisting: false,
    fetch
  });
  assert.equal(r.plan.nodes.find(n => n.id === 1).parentKey, 'b');
  result.assignmentTopics.pop();
  await assert.rejects(provider.proposePlan(config, snapshot, {
    preserveExisting: false,
    fetch
  }), /exactly 2/);
});
test('indexed topic map requires every captured index and refuses foreign or missing keys', async () => {
  const result = {
    topics: [{
      id: 'p',
      name: 'Project',
      parent: 2
    }],
    topicByIndex: {
      '0': 'p',
      '1': 'p'
    }
  };
  const fetch = async () => ({
    ok: true,
    status: 200,
    json: async () => ({
      choices: [{
        message: {
          content: JSON.stringify(result)
        }
      }]
    })
  });
  const r = await provider.proposePlan(config, snapshot, {
    preserveExisting: false,
    fetch
  });
  assert.equal(r.plan.nodes.find(n => n.id === 1).parentKey, 'b');
  result.topicByIndex = {
    '0': 'p',
    '2': 'p'
  };
  await assert.rejects(provider.proposePlan(config, snapshot, {
    preserveExisting: false,
    fetch
  }), /keys 0 through 1/);
});
test('large regrouping shares a catalogue across bounded classification batches and retains every ID', async () => {
  const many = {
    ...snapshot,
    tabs: Array.from({
      length: 33
    }, (_, i) => ({
      ...snapshot.tabs[0],
      id: 100 + i,
      key: 't' + i,
      index: i,
      active: i === 0
    }))
  };
  const counts = [];
  const fetch = async (url, request) => {
    const body = JSON.parse(request.body),
      input = JSON.parse(body.messages[1].content);
    counts.push(input.tabs.length);
    const value = body.messages[0].content.includes('CATALOGUE STEP') ? {
      topics: [{
        id: 'p',
        name: 'Project',
        parent: 100
      }]
    } : {
      topicByIndex: Object.fromEntries(input.tabs.map((t, i) => [i, 'p']))
    };
    return {
      ok: true,
      status: 200,
      json: async () => ({
        choices: [{
          message: {
            content: JSON.stringify(value)
          }
        }]
      })
    };
  };
  const r = await provider.proposePlan(config, many, {
    preserveExisting: false,
    fetch
  });
  assert.deepEqual(counts, [33, 16, 16, 1, 33, 16, 16, 1]);
  assert.equal(r.plan.nodes.length, 33);
  assert.equal(r.plan.nodes.filter(n => n.parentKey === 't0').length, 32);
  assert.deepEqual(new Set(r.plan.nodes.map(n => n.id)), new Set(many.tabs.map(n => n.id)));
});
test('coherence review splits a broad branch without losing singleton or duplicate-ID coverage', async () => {
  const many = {
    ...snapshot,
    tabs: Array.from({
      length: 25
    }, (_, i) => ({
      ...snapshot.tabs[0],
      id: 200 + i,
      key: 'q' + i,
      index: i,
      active: i === 0,
      url: 'https://different.example/' + i
    }))
  };
  let audits = 0;
  const fetch = async (url, request) => {
    const body = JSON.parse(request.body),
      input = JSON.parse(body.messages[1].content);
    let value;
    if (body.messages[0].content.includes('CATALOGUE STEP')) value = {
      topics: [{
        id: 'broad',
        name: 'Broad',
        parent: 200
      }]
    };else if (body.messages[0].content.includes('COHERENCE REVIEW')) {
      audits++;
      value = {
        topics: [{
          id: 'games',
          name: 'Games',
          parent: 200
        }, {
          id: 'hardware',
          name: 'Hardware',
          parent: 202
        }],
        topicByIndex: {
          0: 'games',
          1: 'games',
          2: 'hardware',
          3: 'hardware',
          4: null,
          5: null
        }
      };
    } else value = {
      topicByIndex: Object.fromEntries(input.tabs.map((t, i) => [i, body.messages[0].content.includes('DETACHED ROOT REVIEW') ? null : t.id < 206 ? 'broad' : null]))
    };
    return {
      ok: true,
      status: 200,
      json: async () => ({
        choices: [{
          message: {
            content: JSON.stringify(value)
          }
        }]
      })
    };
  };
  const r = await provider.proposePlan(config, many, {
    preserveExisting: false,
    fetch
  });
  assert.equal(audits, 1);
  assert.equal(r.plan.nodes.length, 25);
  assert.equal(r.plan.nodes.find(n => n.id === 201).parentKey, 'q0');
  assert.equal(r.plan.nodes.find(n => n.id === 203).parentKey, 'q2');
  assert.equal(r.plan.nodes.find(n => n.id === 204).parentKey, null);
  assert.equal(new Set(r.plan.nodes.map(n => n.id)).size, 25);
});
test('coherence review also rejects unrelated two-tab branches', async () => {
  const many = {
    ...snapshot,
    tabs: Array.from({
      length: 25
    }, (_, i) => ({
      ...snapshot.tabs[0],
      id: 500 + i,
      key: 'pair' + i,
      index: i,
      active: i === 0,
      url: 'https://different.example/' + i
    }))
  };
  let audits = 0;
  const fetch = async (url, request) => {
    const body = JSON.parse(request.body),
      input = JSON.parse(body.messages[1].content);
    const value = body.messages[0].content.includes('CATALOGUE STEP') ? {
      topics: [{
        id: 'pair',
        name: 'Profile pair',
        parent: 500
      }]
    } : body.messages[0].content.includes('COHERENCE REVIEW') ? (audits++, {
      topics: [],
      topicByIndex: {
        0: null,
        1: null
      }
    }) : {
      topicByIndex: Object.fromEntries(input.tabs.map((t, i) => [i, body.messages[0].content.includes('DETACHED ROOT REVIEW') ? null : t.id < 502 ? 'pair' : null]))
    };
    return {
      ok: true,
      status: 200,
      json: async () => ({
        choices: [{
          message: {
            content: JSON.stringify(value)
          }
        }]
      })
    };
  };
  const r = await provider.proposePlan(config, many, {
    preserveExisting: false,
    fetch
  });
  assert.equal(audits, 1);
  assert.equal(r.plan.nodes.length, 25);
  assert.equal(r.plan.nodes.find(n => n.id === 501).parentKey, null);
});
test('coherence cannot split repeated named product pages and its visible localhost route', async () => {
  const many = {
    ...snapshot,
    tabs: Array.from({
      length: 25
    }, (_, i) => ({
      ...snapshot.tabs[0],
      id: 700 + i,
      key: 'product' + i,
      index: i,
      active: i === 0,
      title: i < 2 ? 'Acme' : i === 2 ? 'Failed to open page' : 'Unrelated ' + i,
      url: i < 2 ? 'https://acme.lol/' + i : i === 2 ? 'http://127.0.0.1:8766/acme/' : 'https://unrelated.example/' + i
    }))
  };
  const fetch = async (url, request) => {
    const body = JSON.parse(request.body),
      input = JSON.parse(body.messages[1].content);
    let value;
    if (body.messages[0].content.includes('CATALOGUE STEP')) value = {
      topics: [{
        id: 'product',
        name: 'Acme',
        parent: 700
      }]
    };else if (body.messages[0].content.includes('COHERENCE REVIEW')) value = {
      topics: [],
      topicByIndex: Object.fromEntries(input.tabs.map((t, i) => [i, null]))
    };else value = {
      topicByIndex: Object.fromEntries(input.tabs.map((t, i) => [i, body.messages[0].content.includes('DETACHED ROOT REVIEW') ? null : t.id < 703 ? 'product' : null]))
    };
    return {
      ok: true,
      status: 200,
      json: async () => ({
        choices: [{
          message: {
            content: JSON.stringify(value)
          }
        }]
      })
    };
  };
  const r = await provider.proposePlan(config, many, {
    preserveExisting: false,
    fetch
  });
  assert.equal(r.plan.nodes.find(n => n.id === 701).parentKey, 'product0');
  assert.equal(r.plan.nodes.find(n => n.id === 702).parentKey, 'product0');
  assert.equal(r.plan.nodes.find(n => n.id === 703).parentKey, null);
  assert.equal(r.plan.nodes.length, 25);
});
test('final root review reunites an overlooked product page without changing existing branch membership', async () => {
  const many = {
    ...snapshot,
    tabs: Array.from({
      length: 25
    }, (_, i) => ({
      ...snapshot.tabs[0],
      id: 600 + i,
      key: 'root' + i,
      index: i,
      active: i === 0,
      title: i < 3 ? 'Acme Product' : 'Unrelated ' + i,
      url: i < 3 ? 'https://acme.example/' + i : 'https://elsewhere.example/' + i
    }))
  };
  let rootReviews = 0;
  const fetch = async (url, request) => {
    const body = JSON.parse(request.body),
      input = JSON.parse(body.messages[1].content);
    let value;
    if (body.messages[0].content.includes('CATALOGUE STEP')) value = {
      topics: [{
        id: 'product',
        name: 'Product',
        parent: 600
      }]
    };else if (body.messages[0].content.includes('DETACHED ROOT REVIEW')) {
      rootReviews++;
      const topic = input.topics.find(t => t.representative.id === 600).id;
      value = {
        topicByIndex: Object.fromEntries(input.tabs.map((t, i) => [i, [602, 603].includes(t.id) ? topic : null]))
      };
    } else if (body.messages[0].content.includes('COHERENCE REVIEW')) value = {
      topics: [{
        id: 'product',
        name: 'Product',
        parent: 600
      }],
      topicByIndex: {
        0: 'product',
        1: 'product'
      }
    };else value = {
      topicByIndex: Object.fromEntries(input.tabs.map((t, i) => [i, t.id < 602 ? 'product' : null]))
    };
    return {
      ok: true,
      status: 200,
      json: async () => ({
        choices: [{
          message: {
            content: JSON.stringify(value)
          }
        }]
      })
    };
  };
  const r = await provider.proposePlan(config, many, {
    preserveExisting: false,
    fetch
  });
  assert.equal(rootReviews, 2);
  assert.equal(r.plan.nodes.length, 25);
  assert.equal(r.plan.nodes.find(n => n.id === 601).parentKey, 'root0');
  assert.equal(r.plan.nodes.find(n => n.id === 602).parentKey, 'root0');
  assert.equal(r.plan.nodes.find(n => n.id === 603).parentKey, null);
});
test('reasoning truncation gets one larger completion budget before accepting a full plan', async () => {
  const budgets = [];
  const fetch = async (url, request) => {
    budgets.push(JSON.parse(request.body).max_tokens);
    return {
      ok: true,
      status: 200,
      json: async () => ({
        choices: [budgets.length === 1 ? {
          finish_reason: 'length',
          message: {
            content: null,
            reasoning: 'not logged'
          }
        } : {
          finish_reason: 'stop',
          message: {
            content: JSON.stringify({
              trees: [{
                parent: 1,
                children: [2]
              }]
            })
          }
        }]
      })
    };
  };
  const r = await provider.proposePlan(config, snapshot, {
    fetch
  });
  assert.equal(r.plan.nodes.length, 2);
  assert.equal(budgets.length, 2);
  assert.equal(budgets[1], budgets[0] * 4);
});
test('an exhausted catalogue repair does not restart and repay the entire large pipeline', async () => {
  const many = {
    ...snapshot,
    tabs: Array.from({
      length: 25
    }, (_, i) => ({
      ...snapshot.tabs[0],
      id: 300 + i,
      key: 'e' + i,
      index: i,
      active: i === 0
    }))
  };
  let calls = 0;
  await assert.rejects(provider.proposePlan(config, many, {
    preserveExisting: false,
    fetch: async () => {
      calls++;
      return {
        ok: true,
        status: 200,
        json: async () => ({
          choices: [{
            finish_reason: 'length',
            message: {
              content: null
            }
          }]
        })
      };
    }
  }), /twice/);
  assert.equal(calls, 2);
});
test('aborting after an invalid plan prevents the repair request', async () => {
  const controller = new AbortController();
  let calls = 0;
  await assert.rejects(provider.proposePlan(config, snapshot, {
    signal: controller.signal,
    onInvalidProposal: () => controller.abort(),
    fetch: async () => {
      calls++;
      return response([1, 999]);
    }
  }), e => e.name === 'AbortError');
  assert.equal(calls, 1);
});
