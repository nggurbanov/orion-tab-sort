const {test}=require('node:test'),assert=require('node:assert/strict');
global.OrionTreePlan=require('../extension/tree-plan.js');
const Recovery=require('../extension/recovery.js');
const uuids=['11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222'];
function fixture(){
 const before={scope:{windowId:3,groupKey:'old'},revision:'old',tabs:[{id:1,key:'1',title:'A',url:'https://same.test/',parentKey:null,index:0,pinned:false,active:true,expanded:false},{id:2,key:'2',title:'B',url:'https://same.test/',parentKey:'1',index:0,pinned:false,active:false,expanded:true}]};
 const current={scope:{windowId:9,groupKey:'new'},revision:'new',tabs:before.tabs.map((t,i)=>({...t,id:41+i,key:String(41+i),parentKey:null,index:i}))};
 const identity=(s)=>({windowUUID:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',revision:s.revision,tabs:s.tabs.map((t,i)=>({key:t.key,uuid:uuids[i]}))});
 return {journal:{phase:'applied',before,identity:identity(before)},current,identity:identity(current)};
}
test('recovers duplicate URLs by UUID despite changed IDs, window IDs and parent layout',()=>{
 const f=fixture(),plan=Recovery.plan(f.journal,f.current,f.identity);
 assert.deepEqual(plan.nodes.map(t=>[t.id,t.parentKey,t.expanded]),[[41,null,false],[42,'41',true]]);
 assert.equal(plan.expectedRevision,'new');
});
test('refuses missing, duplicate, invalid, stale and foreign persistent identities',()=>{
 for(const alter of [f=>f.identity.tabs.pop(),f=>f.identity.tabs[1].uuid=uuids[0],f=>f.identity.tabs[0].uuid='bad',f=>f.identity.revision='stale',f=>f.identity.windowUUID='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',f=>f.identity.tabs[1].uuid='33333333-3333-4333-8333-333333333333']){
  const f=fixture();alter(f);assert.throws(()=>Recovery.plan(f.journal,f.current,f.identity));
 }
});
test('refuses changed URLs, active tabs, pinned state and resolved journals',()=>{
 for(const alter of [f=>f.current.tabs[0].url='https://changed.test/',f=>{f.current.tabs[0].active=false;f.current.tabs[1].active=true;},f=>f.journal.phase='undone',f=>f.current.tabs[1].pinned=true]){
  const f=fixture();alter(f);assert.throws(()=>Recovery.plan(f.journal,f.current,f.identity));
 }
});
