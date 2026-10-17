const {test}=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const planner=require('../extension/tree-plan.js');
const settings=require('../extension/provider-settings.js');
const source=fs.readFileSync(require.resolve('../extension/sorter.js'),'utf8');
const tick=()=>new Promise(resolve=>setImmediate(resolve));

async function harness(options={}){
  const ids=['status','preview','preview-title','refresh','save','read','organize','apply','undo','keep','recoveryPreview','recover','window','endpoint','model','key','depth','preserve','acceptCurrent','journalNotice','keyStatus'];
  const elements=Object.fromEntries(ids.map(id=>[id,{id,value:'',textContent:'',disabled:false,checked:true,children:[],
    addEventListener(type,fn){this[type]=fn;},replaceChildren(...children){this.children=children;this.value=children[0]?.value||'';},append(child){this.children.push(child);if(!this.value)this.value=child.value;}}]));
  Object.assign(elements.endpoint,{value:settings.defaults.endpoint});
  Object.assign(elements.model,{value:settings.defaults.model});
  elements.depth.value='3';elements.key.value=options.emptyKey?'':'secret-only-in-memory';
  const storage=options.storage||{};
  const nativeState=options.nativeState||{modified:false};
  const requests=[],sentMetadata=[];
  const tabs=[
    {id:1,windowId:7,title:'Project',url:'https://example.com/',index:1,pinned:false,active:true},
    {id:2,windowId:7,title:'Docs',url:'https://example.com/docs',index:2,pinned:false,active:false},
    {id:3,windowId:7,title:'Pinned',url:'https://example.com/pin',index:0,pinned:true,active:false}
  ];
  if(options.duplicates)tabs[1].url=tabs[0].url;
  let selectedIdentity=null;
  const restoreActive=()=>tabs.forEach(tab=>tab.active=tab.id===1);
  const snapshot={scope:{windowId:7,groupKey:'current-process'},revision:'before',tabs:tabs.map(tab=>({...tab,key:tab.pinned?'pinned-3':String(tab.id),parentKey:null,expanded:false,index:tab.pinned?0:tab.id-1}))};
  if(options.nativeScope){
    snapshot.identityMode='native-session';snapshot.selectionWrapperToken='019c7714-3b77-74d1-9866-e1f484aae2ab';snapshot.scope={windowId:777,nativeWindowNumber:777,name:'Named group',groupKey:'token1'};
    snapshot.tabs.forEach(t=>{t.id=-t.id;t.key='native-'+(-t.id);t.nativeOnly=true;t.active=false;});
  }
  if(options.nativeOnly)snapshot.tabs.push({id:-1,key:'native-1',nativeOnly:true,title:'Sleeping tab',url:'https://example.com/sleeping',active:false,pinned:false,parentKey:null,expanded:false,index:2});
  if(options.otherWindow)tabs.push({id:4,windowId:8,title:'Other window',url:'https://example.com/other',index:0,pinned:false,active:true});
  const timers=new Map();let timerID=0;
  const context=vm.createContext({window:{},document:{getElementById:id=>elements[id],createElement:()=>({value:'',textContent:''})},
    URL,setTimeout(fn,ms){if(ms===1000){setImmediate(fn);return -1;}timers.set(++timerID,fn);return timerID;},clearTimeout(id){timers.delete(id);},
    OrionTreePlan:planner,OrionRecovery:require('../extension/recovery.js'),OrionProviderSettings:settings,
    OrionAIProvider:{completionURL:require('../extension/ai-provider.js').completionURL,async proposePlan(config,before,preferences){
      sentMetadata.push(planner.metadataForAI(before));
      if(options.invalidAI)throw new Error('AI вернул недопустимый план');
      if(options.unchangedAI)return {plan:planner.fromForest(before,[1,2],preferences),noChanges:true,summary:{changedTabs:0,topicBranches:0,separateTabs:2}};
      const ordinary=before.tabs.filter(t=>!t.pinned);return {plan:planner.fromForest(before,[{parent:ordinary[0].id,children:[ordinary[1].id]},...(options.nativeOnly?[-1]:[])],preferences)};
    }},
    probeAPI:{raw:{runtime:{getURL:path=>'chrome-extension://test/'+path},permissions:{}},async call(scope,method,arg){
      if(scope==='storage.local'){
        if(method==='get')return storage;
        if(options.checkpointSetRefused&&arg.orionSortCheckpoint)throw Error('Extension storage unavailable');
        Object.assign(storage,structuredClone(arg));return;
      }
      if(scope==='permissions')return true;
      if(scope==='tabs'&&method==='update'){
        tabs.forEach(tab=>tab.active=tab.id===(options.identityMismatch?3:arg));
        return {...tabs.find(tab=>tab.id===arg)};
      }
      if(scope==='windows'&&method==='getLastFocused'){
        if(options.unsupportedWindows)throw Error('Unavailable windows API');
        return {id:options.focusedWindow||7};
      }
      if(scope==='tabs')return tabs.filter(tab=>arg?.windowId===undefined||tab.windowId===arg.windowId).map(tab=>({...tab,
        index:options.identityOrderChange&&selectedIdentity&&tab.id===2?88:tab.index,
        id:options.replaceOnApply&&nativeState.modified&&tab.id===2?999:tab.id}));
      throw Error('Unexpected API');
    }}
  });
  if(!options.disconnected)context.window.webkit={messageHandlers:{orionNativeTreeBridgeV3:{postMessage(request){
    requests.push(request);
    if(request.command==='snapshot'&&options.changedDuringAI){context.window.OrionSorter.receive({id:request.id,ok:false,error:'Selected native wrapper changed'});return;}
    if(request.command==='scopes'&&options.nativeScope&&nativeState.scopesFailure){context.window.OrionSorter.receive({id:request.id,ok:false,error:'Native scope unavailable'});return;}
    if(request.command==='scopes'&&options.nativeScope){context.window.OrionSorter.receive({id:request.id,ok:true,canUndo:nativeState.modified,result:[{id:777,name:'Named group',tabCount:2,focused:true,token:nativeState.scopeToken||'token1'}]});return;}
    if(request.command==='loadKey'&&options.keyLoadRefused){context.window.OrionSorter.receive({id:request.id,ok:false,error:'macOS Keychain locked'});return;}
    if(request.command==='saveKey'&&options.keySaveRefused){context.window.OrionSorter.receive({id:request.id,ok:false,error:'macOS Keychain error (-1)'});return;}
    if(request.command==='persistentIdentity'&&options.persistentIdentityRefused){
      context.window.OrionSorter.receive({id:request.id,ok:false,error:'Fresh UUID snapshot refused'});return;
    }
    if(request.command==='apply')nativeState.modified=true;
    if(request.command==='keep')nativeState.modified=false;
        if(request.command==='undo')nativeState.modified=false;
    if(request.command==='selectIdentity'){
      selectedIdentity=request.payload.id;
    }
    if(request.command==='cancelCapture'||request.command==='finishCapture'){
      restoreActive();selectedIdentity=null;
    }
    if(request.command==='confirmIdentity'&&(options.outlineNeverReady||(options.delayedOutline&&requests.filter(r=>r.command==='confirmIdentity').length===1))){context.window.OrionSorter.receive({id:request.id,ok:false,error:'Selected duplicate URL mismatch'});return;}
    if(request.command==='confirmIdentity'&&options.identityRefused){
      context.window.OrionSorter.receive({id:request.id,ok:false,error:'Two IDs resolved to one native object'});return;
    }
    context.window.OrionSorter.receive({id:request.id,ok:true,canUndo:nativeState.modified,
      result:request.command==='loadKey'?{found:!!options.savedKey,key:options.savedKey}:request.command==='saveKey'?{saved:true}:request.command==='recoveryJournal'?{phase:options.journalPhase||'undone'}:(request.command==='keep'||request.command==='acceptCurrent')?{accepted:true,archivePath:'/private/archive'}:request.command==='ping'?{host:'mock'}:
        request.command==='capture'&&options.duplicates?{captureToken:'identity-token',bindingIDs:options.invalidIdentityIDs?[1,1]:[1,2]}:
        structuredClone(snapshot)});
  }}}};
  vm.runInContext(source,context);await tick();
  return {elements,storage,requests,sentMetadata,nativeState,context,tabs,async click(id){await elements[id].click();await tick();},status:()=>elements.status.textContent};
}

test('native scope failure never falls back to incomplete extension tab IDs',async()=>{
  const h=await harness({nativeScope:true});
  assert.equal(h.elements.window.value,'777');
  h.nativeState.scopesFailure=true;
  await h.click('refresh');
  assert.match(h.status(),/Native scope unavailable/);
  assert.equal(h.elements.window.value,'777');
  assert.equal(h.elements.read.disabled,true);
  h.nativeState.scopesFailure=false;
  await h.click('refresh');
  assert.equal(h.elements.read.disabled,false);
  assert.equal(h.elements.window.value,'777');
});

test('initial native scopes error blocks incomplete extension fallback',async()=>{
  const h=await harness({nativeScope:true,nativeState:{modified:false,scopesFailure:true}});
  assert.match(h.status(),/Native scope unavailable/);
  assert.equal(h.elements.read.disabled,true);
  assert.equal(h.elements.window.children.length,0);
});

test('native group changes during AI cannot enable a stale preview or Apply',async()=>{
 const h=await harness({nativeScope:true,changedDuringAI:true});await h.click('organize');
 assert.equal(h.elements.apply.disabled,true);
 assert.match(h.status(),/изменились во время ответа AI/);
 assert.equal(h.requests.some(r=>r.command==='apply'),false);
});

test('duplicate URLs require confirmed native selection for each ID before preview and Apply',async()=>{
  const h=await harness({duplicates:true});await h.click('organize');
  assert.equal(h.elements.apply.disabled,false);
  assert.deepEqual(h.requests.filter(r=>r.command==='selectIdentity').map(r=>r.payload.id),[1,2]);
  assert.deepEqual(h.requests.filter(r=>r.command==='confirmIdentity').map(r=>r.payload.activeId),[1,2]);
  assert.equal(h.requests.filter(r=>r.command==='finishCapture').length,1);
  assert.equal(h.tabs.find(t=>t.active).id,1);
  await h.click('apply');await h.click('undo');
  assert.equal(h.storage.orionSortCheckpoint.phase,'undone');
});

test('native-only suspended objects remain in the plan while extension identity guards cover the exposed tabs',async()=>{
  const h=await harness({nativeOnly:true});await h.click('organize');
  assert.equal(h.elements.apply.disabled,false);
  assert.deepEqual(h.sentMetadata[0].map(t=>t.id),[1,2,-1]);
  assert.equal(Object.hasOwn(h.sentMetadata[0][2],'nativeOnly'),false);
  await h.click('apply');
  assert.equal(h.storage.orionSortCheckpoint.before.tabs.find(t=>t.id===-1).key,'native-1');
  assert.deepEqual(h.storage.orionSortCheckpoint.tabs.map(t=>t.id),[1,2,3]);
  await h.click('undo');assert.equal(h.storage.orionSortCheckpoint.phase,'undone');
});

test('wrong active ID, changed indexes, native refusal and malformed duplicate requests cancel capture before AI or Apply',async()=>{
  for(const failure of [{identityMismatch:true},{identityOrderChange:true},{identityRefused:true},{invalidIdentityIDs:true}]){
    const h=await harness({duplicates:true,...failure});await h.click('organize');
    assert.equal(h.elements.apply.disabled,true);
    assert.equal(h.requests.some(r=>r.command==='apply'||r.command==='finishCapture'),false);
    assert.equal(h.requests.filter(r=>r.command==='cancelCapture').length,1);
    assert.equal(h.sentMetadata.length,0);
    assert.equal(h.tabs.find(t=>t.active).id,1);
  }
});

test('preview sends no pinned tabs and Apply/Undo preserve verified extension identities',async()=>{
  const h=await harness();
  await h.click('organize');
  assert.equal(h.elements.apply.disabled,false);
  assert.deepEqual(h.sentMetadata[0].map(tab=>tab.id),[1,2]);
  assert.match(h.elements.preview.textContent,/Project\n  Docs/);
  await h.click('apply');
  assert.equal(h.elements.undo.disabled,false);
  assert.equal(h.storage.orionSortCheckpoint.phase,'applied');
  await h.click('undo');
  assert.equal(h.storage.orionSortCheckpoint.phase,'undone');
  assert.match(h.status(),/ID вкладок сохранены/);
  assert.equal(JSON.stringify(h.storage).includes('secret-only-in-memory'),false);
});

test('controller reload discovers the retained native Undo and stored checkpoint',async()=>{
  const h=await harness();await h.click('organize');await h.click('apply');
  const reloaded=await harness({storage:h.storage,nativeState:h.nativeState});
  assert.equal(reloaded.elements.undo.disabled,false);
  await reloaded.click('undo');
  assert.equal(reloaded.storage.orionSortCheckpoint.phase,'undone');
});

test('an invalid AI plan cannot enable Apply or issue a native mutation',async()=>{
  const h=await harness({invalidAI:true});await h.click('organize');
  assert.equal(h.elements.apply.disabled,true);
  assert.equal(h.requests.some(request=>request.command==='apply'),false);
  assert.match(h.status(),/недопустимый план/);
});

test('a replaced extension tab after Apply is reported as an error with Undo retained',async()=>{
  const h=await harness({replaceOnApply:true});await h.click('organize');await h.click('apply');
  assert.match(h.status(),/Состояние вкладок изменилось/);
  assert.equal(h.context.window.OrionSorter.events.length,0);
  assert.equal(h.elements.undo.disabled,false);
  assert.equal(h.storage.orionSortCheckpoint.phase,'prepared');
});

test('a disconnected bridge prevents AI transmission',async()=>{
  const h=await harness({disconnected:true});await h.click('organize');
  assert.equal(h.sentMetadata.length,0);
  assert.equal(h.elements.apply.disabled,true);
  assert.match(h.status(),/Native Tree Bridge/);
});

 test('an unverified persistent identity snapshot prevents Apply and requires a new preview',async()=>{
  const options={};const h=await harness(options);await h.click('organize');options.persistentIdentityRefused=true;await h.click('apply');
  assert.match(h.status(),/UUID snapshot refused/);
  assert.equal(h.requests.some(r=>r.command==='apply'),false);
  assert.equal(h.elements.apply.disabled,true);
});
 test('an old journal without verified UUIDs cannot enable recovery or mutate tabs',async()=>{
  const h=await harness();await h.click('recoveryPreview');
  assert.equal(h.elements.recover.disabled,true);
  assert.equal(h.requests.some(r=>r.command==='recover'||r.command==='apply'),false);
});

test('sidebar opening chooses the focused real window and clears an obsolete preview',async()=>{
  const h=await harness({otherWindow:true,focusedWindow:8});
  h.elements.window.value='7';h.elements.preview.textContent='Old preview';
  await h.context.window.OrionSorter.focusCurrentWindow();
  assert.equal(h.elements.window.value,'8');
  assert.equal(h.elements.preview.textContent,'Прочитай дерево выбранного окна.');
  assert.equal(h.elements.apply.disabled,true);
});
test('sidebar opening cannot switch the Undo scope',async()=>{
  const h=await harness({otherWindow:true,focusedWindow:8,nativeState:{modified:true},storage:{orionSortCheckpoint:{phase:'applied',before:{scope:{windowId:7}}}}});
  assert.equal(h.elements.window.value,'7');
  await h.context.window.OrionSorter.focusCurrentWindow();
  assert.equal(h.elements.window.value,'7');
  assert.equal(h.elements.window.disabled,true);
});
test('unsupported focused-window API preserves explicit sidebar scope',async()=>{
  const h=await harness({unsupportedWindows:true});
  await h.context.window.OrionSorter.focusCurrentWindow();
  assert.equal(h.elements.window.value,'7');
});

test('window labels never present partial extension counts as totals; capture includes sleeping tabs and excludes pins',async()=>{
  const h=await harness({nativeOnly:true});
  assert.equal(h.elements.window.children[0].textContent,'Окно 7');
  await h.click('read');
  assert.equal(h.elements.window.children[0].textContent,'Окно 7 · вкладок: 3');
  await h.click('refresh');
  assert.equal(h.elements.window.children[0].textContent,'Окно 7');
});

test('persistent identity refusal prevents the AI request before showing a preview',async()=>{
 const h=await harness({persistentIdentityRefused:true});await h.click('organize');assert.equal(h.sentMetadata.length,0);assert.equal(h.elements.apply.disabled,true);assert.match(h.status(),/UUID snapshot refused/);
});

test('applied journal after restart permits reading, blocks AI and offers explicit current-tree acceptance',async()=>{
 const h=await harness({journalPhase:'applied'});assert.equal(h.elements.acceptCurrent.disabled,false);await h.click('read');assert.equal(h.requests.some(r=>r.command==='capture'),true);await h.click('organize');assert.equal(h.sentMetadata.length,0);await h.click('acceptCurrent');assert.equal(h.storage.orionSortCheckpoint.phase,'accepted');assert.equal(h.requests.filter(r=>r.command==='acceptCurrent').length,1);assert.equal(h.requests.some(r=>r.command==='apply'||r.command==='recover'),false);await h.click('organize');assert.equal(h.sentMetadata.length,1);
});
test('partially applied journals cannot enable current-tree acceptance',async()=>{
 for(const journalPhase of ['prepared','undoing','rollingBack']){const h=await harness({journalPhase});assert.equal(h.elements.acceptCurrent.disabled,true);}
});

test('Save settings persists the API key only through the native Keychain bridge',async()=>{
 const h=await harness();await h.click('save');const r=h.requests.find(r=>r.command==='saveKey');assert.equal(r.payload.origin,'https://openrouter.ai');assert.equal(r.payload.key,'secret-only-in-memory');assert.equal(JSON.stringify(h.storage).includes('secret-only-in-memory'),false);assert.match(h.status(),/Keychain/);
});
test('startup reloads a saved Keychain value into an empty field without saving it in extension storage',async()=>{
 const h=await harness({savedKey:'restored-secret',emptyKey:true});assert.equal(h.elements.key.value,'restored-secret');assert.equal(JSON.stringify(h.storage).includes('restored-secret'),false);
});
test('Keychain write failure is visible and never falls back to plain extension storage',async()=>{
 const h=await harness({keySaveRefused:true});await h.click('save');assert.match(h.status(),/Keychain error/);assert.equal(JSON.stringify(h.storage).includes('secret-only-in-memory'),false);
});
test('an empty key does not overwrite the saved Keychain entry',async()=>{
 const h=await harness({emptyKey:true});await h.click('save');assert.equal(h.requests.some(r=>r.command==='saveKey'),false);
});

test('Keychain read errors remain visible without repeated credential requests or losing the bridge',async()=>{
 const h=await harness({keyLoadRefused:true,emptyKey:true});assert.match(h.status(),/Keychain locked/);assert.equal(h.requests.filter(r=>r.command==='loadKey').length,1);assert.equal(h.elements.key.value,'');await h.click('read');assert.equal(h.requests.some(r=>r.command==='capture'),true);
});

test('an unchanged AI proposal displays no changes and cannot enable or issue Apply',async()=>{
 const h=await harness({unchangedAI:true});await h.click('organize');assert.equal(h.elements.apply.disabled,true);assert.match(h.status(),/не предложил изменений/);await h.click('apply');assert.equal(h.requests.some(r=>r.command==='apply'),false);assert.equal(h.storage.orionSortCheckpoint,undefined);
});

test('duplicate confirmation waits for delayed outline selection while rechecking the exact active ID',async()=>{
 const h=await harness({duplicates:true,delayedOutline:true});
 await h.click('read');
 assert.equal(h.requests.filter(r=>r.command==='confirmIdentity').length,3);
 assert.ok(h.requests.some(r=>r.command==='finishCapture'));
 assert.ok(!h.requests.some(r=>r.command==='apply'));
});

test('persistent duplicate URL disagreement remains blocked and restores selection after bounded retries',async()=>{
 const h=await harness({duplicates:true,outlineNeverReady:true});await h.click('read');
 assert.equal(h.requests.filter(r=>r.command==='confirmIdentity').length,3);
 assert.ok(h.requests.some(r=>r.command==='cancelCapture'));
 assert.ok(!h.requests.some(r=>['finishCapture','apply'].includes(r.command)));
 assert.match(h.elements.status.textContent,/Selected duplicate URL mismatch/);
});

test('native scope sorts sleeping duplicate objects without extension activation or saved-state identity',async()=>{
 const h=await harness({nativeScope:true,duplicates:true});await h.click('organize');await h.click('apply');await h.click('undo');
 assert.ok(h.requests.some(r=>r.command==='captureNative'));
 assert.ok(h.requests.some(r=>r.command==='nativeSessionIdentity'));
 assert.ok(h.requests.some(r=>r.command==='apply'));assert.ok(h.requests.some(r=>r.command==='undo'));
 assert.ok(!h.requests.some(r=>['capture','selectIdentity','refreshIdentity','persistentIdentity'].includes(r.command)));
 assert.equal(h.nativeState.modified,false);
});

test('keeping a verified sort ends Undo and permits a new native capture',async()=>{
 const h=await harness({nativeScope:true});await h.click('organize');await h.click('apply');
 assert.equal(h.elements.read.disabled,true);assert.equal(h.elements.keep.disabled,false);
 await h.click('keep');assert.equal(h.elements.read.disabled,false);assert.equal(h.elements.keep.disabled,true);
 assert.equal(h.storage.orionSortCheckpoint.phase,'accepted');
 await h.click('organize');assert.equal(h.elements.apply.disabled,false);
});

test('switching in-place groups in the same native window invalidates the old preview',async()=>{
 const h=await harness({nativeScope:true});await h.click('organize');assert.equal(h.elements.apply.disabled,false);
 h.nativeState.scopeToken='token2';await h.context.window.OrionSorter.focusCurrentWindow();await tick();
 assert.equal(h.elements.apply.disabled,true);assert.match(h.elements.preview.textContent,/Группа изменилась/);
});

test('native Undo remains available when the optional controller checkpoint is absent',async()=>{
 const h=await harness({nativeScope:true,nativeState:{modified:true}});
 await h.click('undo');assert.equal(h.nativeState.modified,false);
 assert.match(h.status(),/восстановлены/);
});

test('optional extension checkpoint write failure cannot hide a verified native Apply or Undo',async()=>{
 const h=await harness({nativeScope:true,checkpointSetRefused:true});
 await h.click('organize');await h.click('apply');assert.equal(h.nativeState.modified,true);assert.match(h.status(),/Дерево применено/);
 await h.click('undo');assert.equal(h.nativeState.modified,false);assert.match(h.status(),/восстановлены/);
});
