const { test } = require('node:test');
const assert = require('node:assert/strict');
const plan = require('../extension/tree-plan.js');

function snapshot() {
  return { scope: { windowId: 7, groupKey: 'group-one' }, revision: 'baseline', tabs: [
    { id: 1, key: 'a', title: 'Project', url: 'https://example.com/same', parentKey: null, index: 0, pinned: false, active: false, expanded: true },
    { id: 2, key: 'b', title: 'Reference', url: 'https://example.com/same', parentKey: 'a', index: 0, pinned: false, active: false, expanded: false },
    { id: 3, key: 'c', title: 'Article', url: 'https://example.com/article', parentKey: null, index: 1, pinned: false, active: true, expanded: false },
    { id: 4, key: 'p', title: 'Pinned', url: 'https://example.com/pinned', parentKey: null, index: 0, pinned: true, active: false, expanded: false }
  ] };
}

test('negative IDs are accepted only in the explicit native-only namespace', () => {
  const before = snapshot();
  Object.assign(before.tabs[2], { id: -1, key: 'native-1', nativeOnly: true });
  assert.equal(plan.fromForest(before, [{parent:1,children:[2]},-1]).nodes.at(-1).id,-1);
  delete before.tabs[2].nativeOnly;
  assert.throws(()=>plan.indexSnapshot(before),/native tab identity/);
  before.tabs[2].nativeOnly=true;before.tabs[2].key='native-2';
  assert.throws(()=>plan.indexSnapshot(before),/native tab identity/);
});

test('maps duplicate URLs by native identity and preserves an existing subtree', () => {
  const before = snapshot();
  const after = plan.fromForest(before, [{ parent: 1, children: [{ parent: 2, children: [3] }] }]);
  assert.deepEqual(after.nodes.map(node => [node.key, node.parentKey, node.index]), [['a', null, 0], ['b', 'a', 0], ['c', 'b', 0]]);
  assert.deepEqual(after.pinnedKeys, ['p']);
  assert.equal(after.expectedRevision, 'baseline');
  assert.equal(plan.describe(before, after), 'Project\n  Reference\n    Article');
  assert.equal(before.tabs[2].parentKey, null);
});

test('rejects fake IDs, omissions, duplicates and pinned tabs from the model', () => {
  for (const forest of [[1, 2, 999], [1, 2], [1, 2, 2, 3], [1, 2, 3, 4], [{ parent: 1, children: [1, 2, 3] }]]) {
    assert.throws(() => plan.fromForest(snapshot(), forest, { preserveExisting: false }));
  }
});

test('preserve-existing can be explicitly disabled but depth remains enforced', () => {
  assert.throws(() => plan.fromForest(snapshot(), [1, 2, 3]), /existing parent-child/);
  assert.equal(plan.fromForest(snapshot(), [1, 2, 3], { preserveExisting: false }).nodes.length, 3);
  assert.throws(() => plan.fromForest(snapshot(), [{ parent: 1, children: [{ parent: 2, children: [3] }] }], { maxDepth: 2 }), /maximum depth/);
});

test('rejects native cycles and parents outside the captured group', () => {
  const cyclic = snapshot();
  cyclic.tabs[0].parentKey = 'b';
  assert.throws(() => plan.indexSnapshot(cyclic), /cycle/);
  cyclic.tabs[0].parentKey = 'other-group-tab';
  assert.throws(() => plan.indexSnapshot(cyclic), /outside the current group/);
});

test('AI metadata excludes pinned tabs, native identifiers, history and other page data', () => {
  const before = snapshot();
  before.tabs[0].history = { back: ['https://private.example/'] };
  const metadata = plan.metadataForAI(before);
  assert.equal(metadata.length, 3);
  assert.deepEqual(Object.keys(metadata[0]), ['id', 'title', 'url', 'parentId']);
  assert.equal(metadata[1].parentId, 1);
  assert.equal(JSON.stringify(metadata).includes('private.example'), false);
});

test('Undo retains the captured sibling order and collapsed state', () => {
  const before = snapshot();
  const undo = plan.undoPlan(before);
  assert.deepEqual(undo.nodes[1], { id: 2, key: 'b', parentKey: 'a', index: 0, expanded: false });
  assert.deepEqual(undo.nodes[2], { id: 3, key: 'c', parentKey: null, index: 1, expanded: false });
});

test('retained native wrapper selects the page independently of indistinguishable duplicate metadata',()=>{
 const s={scope:{windowId:123,nativeWindowNumber:123},revision:'native',identityMode:'native-session',selectionWrapperToken:'019c7714-3b77-74d1-9866-e1f484aae2ab',tabs:[
 {id:-1,key:'native-1',nativeOnly:true,title:'Duplicate',url:'https://example.com',parentKey:null,index:0,active:false,pinned:false,expanded:false},
 {id:-2,key:'native-2',nativeOnly:true,title:'Duplicate',url:'https://example.com',parentKey:null,index:1,active:false,pinned:false,expanded:false}
 ]};
 assert.equal(plan.fromForest(s,[{parent:-1,children:[-2]}],{preserveExisting:false}).nodes.length,2);
 delete s.selectionWrapperToken;assert.throws(()=>plan.indexSnapshot(s),/active tab/);
});

test('regrouping a former branch into a leaf clears its expansion flag', () => {
  const s={scope:{windowId:1},revision:'r',tabs:[
    {id:1,key:'1',parentKey:null,index:0,pinned:false,active:true,expanded:true},
    {id:2,key:'2',parentKey:'1',index:0,pinned:false,active:false,expanded:false}
  ]};
  const proposal=plan.fromForest(s,[2,1],{preserveExisting:false});
  assert.equal(proposal.nodes.find(n=>n.id===1).expanded,false);
});
