const {test}=require('node:test');const assert=require('node:assert/strict');const {expose}=require('../extension/persistent-identity.js');
function harness(failure){
  const beforeTabs=[{id:1,windowId:7,url:'https://example.com/a',active:true,index:0,pinned:false}];
  let tabs=structuredClone(beforeTabs);const commands=[];
  const sameTabs=(before,after,order,active=true)=>{
    assert.equal(before.length,after.length);
    for(let i=0;i<before.length;i++)for(const key of ['id','url','windowId','pinned',...(order?['index']:[]),...(active?['active']:[])])assert.equal(before[i][key],after[i][key]);
  };
  return {beforeTabs,commands,tabs:()=>tabs,args:{token:'token',ids:[2,3],windowId:7,beforeTabs,sameTabs,
    request:async(command,payload)=>{commands.push(command);if(command==='confirmExposure'&&failure==='native')throw Error('Two IDs selected one object');if(command==='finishExposure')return {revision:'before'};},
    call:async(scope,method,id)=>{if(method==='query')return structuredClone(tabs);if(!tabs.some(t=>t.id===id))tabs.push({id,windowId:7,url:'https://example.com/duplicate',active:false,index:id-1,pinned:false});tabs.forEach(t=>t.active=t.id===id);if(failure==='order'&&id!==1)tabs[0].index=99;}
  }};
}
test('exposes only requested sleeping duplicates and restores original selection before expanding API baseline',async()=>{
  const h=harness();const result=await expose(h.args);
  assert.deepEqual(result.tabs.map(t=>t.id),[1,2,3]);assert.equal(result.tabs.find(t=>t.active).id,1);
  assert.equal(result.snapshot.revision,'before');assert.equal(h.commands.filter(x=>x==='confirmExposure').length,2);
});
test('native refusal restores the active tab and cancels before allowing a new identity',async()=>{
  const h=harness('native');await assert.rejects(expose(h.args),/Two IDs/);assert.equal(h.tabs().find(t=>t.active).id,1);assert.ok(h.commands.includes('cancelCapture'));assert.ok(!h.commands.includes('finishExposure'));
});
test('unexpected original order changes abort exposure and report unconfirmed restoration',async()=>{
  const h=harness('order');await assert.rejects(expose(h.args),/Восстановление выбора/);assert.ok(!h.commands.includes('confirmExposure'));assert.ok(h.commands.includes('cancelCapture'));
});
test('native activation uses retained wrapper indexes and confirms the actual exposed IDs without tabs.update',async()=>{
 const h=harness();h.args.nativeSelections=[9,10];const originalRequest=h.args.request,originalCall=h.args.call;
 h.args.request=async(command,p)=>{
  if(command==='selectExposure')await originalCall('tabs','update',p.id===9?2:3);
  if(command==='finishExposure'||command==='cancelCapture')await originalCall('tabs','update',1);
  if(command==='confirmExposure')assert.equal(p.activeId,p.id===9?2:3);
  return originalRequest(command,p);
 };
 h.args.call=async(s,m,...a)=>{assert.equal(m,'query');return originalCall(s,m,...a);};
 const result=await expose(h.args);assert.equal(result.tabs.find(t=>t.active).id,1);assert.equal(h.commands.filter(c=>c==='selectExposure').length,2);
});
test('native activation refusal restores through cancellation without calling a missing sleeping tab API',async()=>{
 const h=harness('native');h.args.nativeSelections=[9,10];const r=h.args.request,c=h.args.call;
 h.args.request=async(command,p)=>{if(command==='selectExposure')await c('tabs','update',2);if(command==='cancelCapture')await c('tabs','update',1);return r(command,p);};
 h.args.call=async(s,m,...a)=>{assert.equal(m,'query');return c(s,m,...a);};
 await assert.rejects(expose(h.args),/Two IDs/);assert.equal(h.tabs().find(t=>t.active).id,1);
});
