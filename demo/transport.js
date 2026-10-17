/* Synthetic boundaries only. The actual sorter, planner, settings and tree view run unchanged. */
(() => {
  'use strict';
  const params=new URLSearchParams(location.search),scenario=params.get('scenario')||'idle',fixture=params.get('fixture')||'outline';
  if(['light','dark'].includes(params.get('theme')))document.documentElement.dataset.theme=params.get('theme');
  const names=['Interface research','macOS outline views','Accessible tree patterns','Sidebar interaction notes','Weekend reading','Long-form reading list','A field guide to typography','Design notes','Design systems overview','Component references','Design notes','Project planning'];
  const domains=['example.org','developer.apple.com','w3.org','example.net','example.com','example.net','example.org','example.org','example.com','example.net','example.net','example.com'];
  const count=fixture==='deep'?8:fixture==='long'?40:12;
  const before={scope:{windowId:777,nativeWindowNumber:777,name:'Research tabs',groupKey:'synthetic-group'},identityMode:'native-session',selectionWrapperToken:'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',revision:'synthetic-before',tabs:Array.from({length:count},(_,i)=>({id:-(i+1),key:'native-'+(i+1),nativeOnly:true,title:fixture==='long'?(i<3?'Duplicate research note':'A long research title about native outline interaction, keyboard navigation and preserving the original order — reference '+(i+1)):fixture==='deep'?'Nested reference level '+(i+1):names[i],url:'https://'+(domains[i%12])+'/'+(fixture==='long'&&i<3?'duplicate':'reference-'+i),pinned:false,expanded:fixture==='deep',active:false,parentKey:fixture==='deep'&&i?'native-'+i:null,index:fixture==='deep'?0:i}))};
  // Exact duplicates exercise occurrence labels without introducing network resources.
  if(fixture==='long')before.tabs.slice(0,3).forEach(t=>t.url='https://example.org/duplicate');
  let current=structuredClone(before),canUndo=false,needsRecovery=scenario==='recovery',transactionPhase=needsRecovery?'recoveryRequired':'idle',journalPhase=needsRecovery?'recoveryRequired':'undone';
  const requests=[];const state=()=>({canUndo,needsRecovery,transactionPhase,journalPhase});
  const journal=()=>({version:2,phase:journalPhase,identity:{mode:'native-session',sessionKey:'synthetic-session'},before,applied:canUndo?current:undefined});
  const respond=(request,result,ok=true,error)=>window.OrionSorter.receive({id:request.id,ok,result,error,...state()});
  const transport={postMessage(request){
    requests.push({command:request.command});if(requests.length>40)requests.shift();
    setTimeout(()=>{
      const {command,payload}=request;
      if(command==='ping')return respond(request,{host:'AppleScriptObjC native tree V3R49'});
      if(command==='transactionStatus')return respond(request,state());
      if(command==='scopes')return respond(request,[{id:777,name:fixture==='long'?'Research tabs · a long group title that still fits the selected scope':'Research tabs',tabCount:current.tabs.length,token:'synthetic-group',focused:true}]);
      if(command==='loadKey')return respond(request,{found:true,key:'synthetic-demo-key'});
      if(command==='saveKey')return respond(request,{saved:true});
      if(['captureNative','snapshot'].includes(command))return respond(request,structuredClone(current));
      if(command==='nativeSessionIdentity')return respond(request,{synthetic:true});
      if(command==='apply'){
        current={...structuredClone(current),revision:'synthetic-applied',tabs:current.tabs.map(t=>({...t,...payload.plan.nodes.find(n=>n.key===t.key)}))};
        canUndo=true;needsRecovery=false;transactionPhase='applied';journalPhase='applied';return respond(request,structuredClone(current));
      }
      if(command==='undo'){current=structuredClone(before);canUndo=false;needsRecovery=false;transactionPhase='idle';journalPhase='undone';return respond(request,structuredClone(current));}
      if(command==='keep'){canUndo=false;transactionPhase='idle';journalPhase='accepted';return respond(request,{accepted:true});}
      if(command==='inspectJournal')return respond(request,{journal:journal(),journalRevision:'c3ludGhldGljLWpvdXJuYWw='});
      if(command==='recoveryJournal')return respond(request,journal());
      if(command==='inspectRetainedTransaction')return respond(request,{inspectionToken:'synthetic-inspection',transactionID:'synthetic-transaction',transactionPhase,journal:journal(),journalRevision:'c3ludGhldGljLWpvdXJuYWw=',journalVersion:2,journalIdentity:journal().identity,live:{available:true,revision:current.revision,snapshot:structuredClone(current)}});
      if(command==='recoverRetained'){current=structuredClone(before);canUndo=false;needsRecovery=false;transactionPhase='idle';journalPhase='recovered';return respond(request,{recovered:true});}
      if(command==='abandonRetainedTransaction'){canUndo=false;needsRecovery=false;transactionPhase='idle';journalPhase='acknowledged';return respond(request,{acknowledged:true,abandoned:true,restorationVerified:false,currentLayoutVerified:false});}
      respond(request,null,false,'Unsupported synthetic command');
    },20);
  }};
  // No storage, network AI, real native bridge, credentials or tab API are accessed.
  globalThis.probeAPI={raw:{permissions:{}},call:async(scope,method)=>{
    if(scope==='storage.local'&&method==='get')return {orionAISettings:{endpoint:'https://synthetic.example/v1',model:'synthetic-demo',maxDepth:8,preserveExisting:false}};
    if(scope==='storage.local')return;
    if(scope==='permissions')return true;
    throw new Error('Synthetic demo refuses browser access.');
  }};
  window.webkit={messageHandlers:{orionNativeTreeBridgeV3:transport}};
  if(scenario==='disconnected')delete window.webkit;
  const OrionAIProviderReal=globalThis.OrionAIProvider;
  globalThis.OrionAIProvider=Object.freeze({completionURL:OrionAIProvider.completionURL,proposePlan:async(config,snapshot,options)=>{
    options.onProgress?.({phase:'catalogue'});
    if(scenario==='generating')await new Promise((resolve,reject)=>{options.onProgress?.({phase:'classify',done:2,total:4});options.signal.addEventListener('abort',()=>reject(Object.assign(new Error('Cancelled'),{name:'AbortError'})),{once:true});});
    if(options.signal.aborted)throw Object.assign(new Error('Cancelled'),{name:'AbortError'});
    let forest;
    if(scenario==='nochanges'||fixture==='deep'){
      const walk=parent=>snapshot.tabs.filter(t=>t.parentKey===parent).sort((a,b)=>a.index-b.index).map(t=>{const children=walk(t.key);return children.length?{parent:t.id,children}:t.id;});forest=walk(null);
    }else forest=snapshot.tabs.filter((t,i)=>i%4===0).map(t=>({parent:t.id,children:snapshot.tabs.slice(-t.id,-t.id+3).map(c=>c.id)}));
    const plan=OrionTreePlan.fromForest(snapshot,forest,{maxDepth:8,preserveExisting:false}),summary=OrionAIProviderReal.summarizePlan(snapshot,plan);
    return {plan,summary,noChanges:summary.changedTabs===0,maxDepth:8};
  }});
  window.OrionDemo=Object.freeze({scenario,fixture,requests,getState:state});
})();
