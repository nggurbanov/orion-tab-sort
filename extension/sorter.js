(() => {
  "use strict";
  const $=id=>document.getElementById(id);
  const status=$('status'), preview=$('preview');
  let pending=null, snapshot=null, proposal=null, baselineTabs=null, busy=false, canUndo=false, recoveryPlan=null;
  let journalPending=false,journalPhase=null;
  const events=[];
  let nativeMode=false,scopeToken=null,scopeUnavailable=false;
  const scopeTokens=new Map();
  const controls=['refresh','save','read','organize','apply','undo','keep','recoveryPreview','recover','acceptCurrent'];
  function enableControls(){
    controls.forEach(id=>{$(id).disabled=busy;});
    $('apply').disabled=busy||!proposal||journalPending;
    $('acceptCurrent').disabled=busy||canUndo||journalPhase!=='applied';
    $('undo').disabled=busy||!canUndo;
    $('keep').disabled=busy||!canUndo;
    if(canUndo||scopeUnavailable){$('read').disabled=true;$('organize').disabled=true;}
    if(canUndo)$('refresh').disabled=true;
    $('recover').disabled=busy||!recoveryPlan;
    $('window').disabled=busy||canUndo;
  }
  function request(command,payload={}){
    if(pending)return Promise.reject(new Error('Дождись ответа Orion.'));
    const handler=window.webkit?.messageHandlers?.orionNativeTreeBridgeV3;
    if(!handler)return Promise.reject(new Error('Нажми Native Tree Bridge в панели Orion, затем повтори.'));
    return new Promise((resolve,reject)=>{
      const id=`${Date.now()}-${Math.random().toString(36).slice(2)}`;
      const timer=setTimeout(()=>{pending=null;reject(new Error('Orion не ответил. Проверь дерево перед повторным применением.'));},['apply','undo','recover'].includes(command)?120000:30000);
      pending={id,resolve,reject,timer};
      try{handler.postMessage({id,command,payload});}
      catch(error){clearTimeout(timer);pending=null;reject(error);}
    });
  }
  function receive(reply){
    if(!pending||reply?.id!==pending.id)return;
    const call=pending;pending=null;clearTimeout(call.timer);
    canUndo=reply.canUndo===true;
    if(reply.ok===true)call.resolve(reply.result);
    else call.reject(new Error(reply.error||'Ошибка нативного моста.'));
    enableControls();
  }
  window.OrionSorter=Object.freeze({receive,events,focusCurrentWindow});
  function tabRecord({id,windowId,url,title,active,pinned,index}){return{id,windowId,url,title:title||'',active:!!active,pinned:!!pinned,index};}
  async function saveCheckpoint(checkpoint){
    try{await probeAPI.call('storage.local','set',{orionSortCheckpoint:checkpoint});}
    catch(error){if(!nativeMode)throw error;events.push({action:'checkpointUnavailable'});}
  }
  async function windowTabs(){
    if(nativeMode)return [];
    const windowId=Number($('window').value);
    if(!Number.isSafeInteger(windowId))throw new Error('Выбери окно.');
    return (await probeAPI.call('tabs','query',{windowId})).map(tabRecord).sort((a,b)=>a.id-b.id);
  }
  function sameTabs(before,after,checkOrder=false,checkActive=true){
    if(before.length!==after.length)throw new Error('Набор вкладок изменился.');
    before.forEach((tab,i)=>{
      for(const key of ['id','windowId','url','pinned',...(checkActive?['active']:[]),...(checkOrder?['index']:[])]){
        if(tab[key]!==after[i][key])throw new Error(`Состояние вкладок изменилось (${key}).`);
      }
    });
  }
  async function focusCurrentWindow(){
    if(busy||canUndo)return;
    try{
      const focused=nativeMode?(await request('scopes')).find(s=>s.focused):await probeAPI.call('windows','getLastFocused',{});
      if(busy||canUndo||!focused)return;
      const option=Array.from($('window').children).find(o=>Number(o.value)===focused.id);
      if(option){
        const changed=Number($('window').value)!==focused.id||(nativeMode&&scopeToken!==null&&focused.token&&focused.token!==scopeToken);
        if(nativeMode){option.textContent=focused.name+(Number.isSafeInteger(focused.tabCount)?` · вкладок: ${focused.tabCount}`:'');scopeTokens.set(focused.id,focused.token);}
        scopeToken=focused.token??null;
        if(changed){$('window').value=String(focused.id);snapshot=null;proposal=null;recoveryPlan=null;enableControls();preview.textContent=nativeMode?'Группа изменилась. Прочитай её дерево.':'Прочитай дерево выбранного окна.';}
      }
    }catch(error){
      if(nativeMode){scopeUnavailable=true;snapshot=null;proposal=null;recoveryPlan=null;enableControls();status.textContent=error.message;}
    }
  }
  async function refreshWindows(){
    try{
      const scopes=await request('scopes');
      if(Array.isArray(scopes)&&scopes.length&&scopes.every(s=>Number.isSafeInteger(s.id)&&typeof s.name==='string')){
        nativeMode=true;scopeUnavailable=false;
        scopeTokens.clear();scopes.forEach(s=>scopeTokens.set(s.id,s.token));
        const previous=$('window').value;const options=scopes.map(s=>{const o=document.createElement('option');o.value=String(s.id);o.textContent=s.name+(Number.isSafeInteger(s.tabCount)?` · вкладок: ${s.tabCount}`:'');return o;});
        $('window').replaceChildren(...options);
        $('window').value=String(scopes.find(s=>String(s.id)===previous)?.id??scopes.find(s=>s.focused)?.id??scopes[0].id);
        scopeToken=scopeTokens.get(Number($('window').value))??null;
        snapshot=null;proposal=null;recoveryPlan=null;enableControls();
        return;
      }
      if(nativeMode)throw new Error('Orion не предоставил список нативных групп. Обнови список.');
    }catch(error){
      if(nativeMode||!/^Unsupported (?:native )?command$/.test(error.message)){scopeUnavailable=true;snapshot=null;proposal=null;recoveryPlan=null;throw error;}
      // Older installed bridge uses the guarded extension scope route.
    }
    const allTabs=await probeAPI.call('tabs','query',{});
    const ownRoot=probeAPI.raw.runtime.getURL('');
    const groups=new Map();
    for(const tab of allTabs){
      if(tab.url?.startsWith(ownRoot))continue;
      groups.set(tab.windowId,(groups.get(tab.windowId)||0)+1);
    }
    const previous=$('window').value;
    $('window').replaceChildren();
    for(const id of groups.keys()){
      const option=document.createElement('option');option.value=String(id);option.textContent=`Окно ${id}`;
      $('window').append(option);
    }
    if(groups.has(Number(previous)))$('window').value=previous;
    else {
      try {
        const focused=nativeMode?{id:(await request('scopes')).find(s=>s.focused)?.id}:await probeAPI.call('windows','getLastFocused',{});
        if(groups.has(focused.id))$('window').value=String(focused.id);
      }catch{} // Unsupported browser API keeps the first available scope.
    }
    snapshot=null;proposal=null;recoveryPlan=null;enableControls();
  }
  function settings(){return OrionProviderSettings.publicSettings({endpoint:$('endpoint').value,model:$('model').value,maxDepth:Number($('depth').value),preserveExisting:$('preserve').checked});}
  function keyOrigin(endpoint){return OrionAIProvider.completionURL(endpoint).origin;}
  async function loadSavedKey(){
    const origin=keyOrigin($('endpoint').value);
    const initialKey=$('key').value;
    const result=await request('loadKey',{origin});
    if(origin!==keyOrigin($('endpoint').value)||$('key').value!==initialKey)return;
    if(result.found&&!initialKey)$('key').value=result.key;
    $('keyStatus').textContent=result.found?'Ключ сохранён в macOS Keychain.':'Введи ключ и нажми «Сохранить настройки» — он останется в macOS Keychain.';
  }
  async function saveSettings(){
    const value=settings();
    const key=$('key').value.trim();
    if(key){
      const saved=await request('saveKey',{origin:keyOrigin(value.endpoint),key});
      if(saved.saved!==true)throw new Error('Сохранение ключа в macOS Keychain не подтверждено.');
      $('keyStatus').textContent='Ключ сохранён в macOS Keychain.';
    }
    await probeAPI.call('storage.local','set',{orionAISettings:value});
    return value;
  }
  async function capture(recovery=false){
    snapshot=null;proposal=null;recoveryPlan=null;
    baselineTabs=await windowTabs();
    const initial=await request(nativeMode?'captureNative':recovery?'captureRecovery':'capture',{windowId:Number($('window').value),tabs:baselineTabs});
    if(initial.captureToken){
      const token=initial.captureToken;
      try{
        const ids=initial.bindingIDs;
        if(!Array.isArray(ids)||!ids.length||new Set(ids).size!==ids.length||
          ids.some(id=>!baselineTabs.some(tab=>tab.id===id&&!tab.pinned)))throw new Error('Некорректный запрос идентификации дублей.');
        for(const id of ids){
          status.textContent='Проверяю дубли: временно выбираю вкладки. Исходное состояние будет восстановлено.';
          await request('selectIdentity',{token,id});
          await probeAPI.call('tabs','update',id,{active:true});
          const selected=await windowTabs();
          sameTabs(baselineTabs,selected,true,false);
          const active=selected.filter(tab=>tab.active);
          if(active.length!==1||active[0].id!==id)throw new Error('Нативный объект не совпал с ID выбранной вкладки.');
          for(let attempt=0;attempt<3;attempt++){
            try{await request('confirmIdentity',{token,id,activeId:active[0].id});break;}
            catch(error){
              if(attempt===2||!['Selected duplicate URL mismatch','Selected duplicate has no native row'].includes(error.message))throw error;
              await new Promise(resolve=>setTimeout(resolve,1000));
              const refreshed=await windowTabs();sameTabs(baselineTabs,refreshed,true,false);
              const chosen=refreshed.filter(tab=>tab.active);
              if(chosen.length!==1||chosen[0].id!==id)throw new Error('Выбранная вкладка изменилась во время подтверждения дубля.');
            }
          }
        }
        snapshot=await request('finishCapture',{token});
      }catch(error){
        snapshot=null;
        try{await request('cancelCapture',{token});sameTabs(baselineTabs,await windowTabs(),true);}
        catch(restoreError){throw new Error(`${error.message} Восстановление выбора не подтверждено: ${restoreError.message}`);}
        throw error;
      }
    }else snapshot=initial;scopeToken=snapshot.scope?.groupKey??scopeToken;
    OrionTreePlan.indexSnapshot(snapshot);
    sameTabs(baselineTabs,await windowTabs(),true);
    const scopeOption=Array.from($('window').children).find(option=>Number(option.value)===Number($('window').value));
    if(scopeOption)scopeOption.textContent=(nativeMode?snapshot.scope.name:`Окно ${$('window').value}`)+` · вкладок: ${snapshot.tabs.filter(tab=>!tab.pinned).length}`;
    proposal=null;
    $('preview-title').textContent='Текущее дерево';
    preview.textContent=OrionTreePlan.describe(snapshot,OrionTreePlan.undoPlan(snapshot));
    return snapshot;
  }
  async function persistentIdentity(allowRecapture=false){
    if(snapshot?.identityMode==='native-session')return request('nativeSessionIdentity');
    await request('refreshIdentity');
    for(let attempt=0;attempt<8;attempt++){
      await new Promise(resolve=>setTimeout(resolve,1000));
      try{
        const identity=await request('persistentIdentity');
        if(identity.exposureToken){
          status.textContent='Проверяю спящие дубли. Временно открою только одинаковые вкладки, затем верну прежний выбор.';
          const result=await OrionPersistentIdentity.expose({token:identity.exposureToken,ids:identity.bindingIDs,nativeSelections:identity.nativeSelections,windowId:Number($('window').value),beforeTabs:baselineTabs,request,call:(...args)=>probeAPI.call(...args),sameTabs});
          if(result.snapshot.revision!==snapshot.revision){
            proposal=null;
            if(!allowRecapture)throw new Error('После загрузки дублей данные обновились. Нажми «Предложить порядок» ещё раз.');
            await capture();
          }
          baselineTabs=result.tabs.map(tabRecord);
          await request('refreshIdentity');
          continue;
        }
        return identity;
      }
      catch(error){if(!error.message.includes('not fresh yet')||attempt===7)throw error;}
    }
  }
  async function permitEndpoint(endpoint){
    const url=OrionAIProvider.completionURL(endpoint);
    const origin=`${url.protocol}//${url.hostname}/*`;
    const permissions=probeAPI.raw.permissions;
    if(!permissions)throw new Error('Orion не предоставил API разрешений для AI.');
    const allowed=await probeAPI.call('permissions','contains',{origins:[origin]});
    if(!allowed&&!await probeAPI.call('permissions','request',{origins:[origin]}))throw new Error('Доступ к выбранному AI API не разрешён.');
  }
  async function run(action){
    if(busy)return;
    busy=true;enableControls();status.textContent='Выполняется…';
    try{
      if(action==='loadKey'){await loadSavedKey();status.textContent=$('keyStatus').textContent;}
      if(action==='refresh'){await refreshWindows();status.textContent='Список окон обновлён.';}
      if(action==='save'){await saveSettings();status.textContent='Настройки сохранены. Ключ хранится в macOS Keychain и загрузится при следующем открытии.';}
      if(action==='read'){
        await capture();
        const movable=snapshot.tabs.filter(tab=>!tab.pinned).length;
        status.textContent=`Вкладок в дереве: ${movable}, включая спящие. Закреплённые вкладки не сортируются.`;
      }
      if(action==='acceptCurrent'){
        await capture(true);
        await persistentIdentity(true);
        const result=await request('acceptCurrent',{expectedRevision:snapshot.revision});
        if(result.accepted!==true)throw new Error('Архивирование журнала не подтверждено.');
        await saveCheckpoint({phase:'accepted'});
        journalPending=false;journalPhase=null;$('journalNotice').hidden=true;
        status.textContent='Текущее дерево сохранено. Предыдущий журнал находится в архиве. Можно сортировать снова.';
      }
      if(action==='organize'){
        if(journalPending)throw new Error('Сначала выбери: оставить текущее дерево или восстановить прежнее в разделе «Восстановление».');
        const config=await saveSettings();
        await permitEndpoint(config.endpoint);
        if(!snapshot)await capture();
        else sameTabs(baselineTabs,await windowTabs());
        await persistentIdentity(true);
        status.textContent='AI предлагает порядок…';
        const result=await OrionAIProvider.proposePlan({...config,apiKey:$('key').value},snapshot,{...config,requireChanges:true,onProgress:p=>{status.textContent=p.phase==='catalogue'?'AI определяет темы…':p.phase==='classify'?`AI разбирает вкладки: порция ${p.done} из ${p.total}…`:p.phase==='reattach'?`AI проверяет отдельные вкладки: порция ${p.done} из ${p.total}…`:`AI проверяет связность веток: ${p.done} из ${p.total}…`;}});
        if(nativeMode){
          try{const fresh=await request('snapshot');if(fresh.revision!==snapshot.revision)throw new Error('Stale AI snapshot');}
          catch{snapshot=null;throw new Error('Группа или вкладки изменились во время ответа AI. Прочитай дерево заново.');}
        }
        proposal=result.noChanges?null:result.plan;
        $('preview-title').textContent='Предлагаемый порядок';
        preview.textContent=OrionTreePlan.describe(snapshot,result.plan);
        if(result.maxDepth>config.maxDepth)$('depth').value=String(result.maxDepth);
        status.textContent=(result.noChanges?'AI не предложил изменений. Применять нечего.':'Проверь дерево. Вкладки пока не изменены.')+(result.summary?` Изменятся вкладки: ${result.summary.changedTabs}. Веток: ${result.summary.topicBranches}, отдельно: ${result.summary.separateTabs}.`:'')+(result.maxDepth>config.maxDepth?` Глубина увеличена до ${result.maxDepth}, чтобы сохранить существующие ветки.`:'');
      }
      if(action==='recoveryPreview'){
        const journal=await request('recoveryJournal');
        await capture(true);
        const identity=await persistentIdentity();
        recoveryPlan=OrionRecovery.plan(journal,snapshot,identity);
        $('preview-title').textContent='Восстановление исходного дерева';
        preview.textContent=OrionTreePlan.describe(snapshot,recoveryPlan);
        status.textContent='UUID окна и всех вкладок проверены. Проверь исходное дерево перед восстановлением.';
      }
      if(action==='recover'){
        if(!recoveryPlan)throw new Error('Сначала проверь восстановление.');
        sameTabs(baselineTabs,await windowTabs(),true);
        const restored=await request('recover',{plan:recoveryPlan});
        sameTabs(baselineTabs,await windowTabs());
        await saveCheckpoint({phase:'recovered'});
        events.push({action:'recover',snapshot:restored});
        snapshot=null;proposal=null;recoveryPlan=null;
        status.textContent='Исходное дерево восстановлено по UUID. Предыдущий журнал сохранён отдельно.';
      }
      if(action==='apply'){
        if(!proposal||!snapshot)throw new Error('Сначала получи и проверь план.');
        sameTabs(baselineTabs,await windowTabs());
        await persistentIdentity();
        sameTabs(baselineTabs,await windowTabs());
        await saveCheckpoint({before:snapshot,tabs:baselineTabs,plan:proposal,phase:'prepared'});
        const result=await request('apply',{plan:proposal});
        sameTabs(baselineTabs,await windowTabs());
        events.push({action:'apply',snapshot:result,...(nativeMode?{nativeObjectsPreserved:true}:{sameTabIDs:true})});
        await saveCheckpoint({before:snapshot,tabs:baselineTabs,after:result,phase:'applied'});
        proposal=null;
        status.textContent='Дерево применено в боковой панели Orion. Undo доступен в текущей сессии.';
      }
      if(action==='keep'){
        const result=await request('keep');
        if(result.accepted!==true)throw new Error('Сохранение порядка не подтверждено.');
        await saveCheckpoint({phase:'accepted'});
        snapshot=null;proposal=null;recoveryPlan=null;journalPending=false;journalPhase=null;
        status.textContent='Порядок сохранён. Можно переключить группу или сортировать снова. Undo завершён.';
      }
      if(action==='undo'){
        let checkpoint;
        try{checkpoint=(await probeAPI.call('storage.local','get','orionSortCheckpoint')).orionSortCheckpoint;}
        catch(error){if(!nativeMode)throw error;}
        if(!nativeMode&&!checkpoint?.tabs)throw new Error('Не найден исходный снимок вкладок.');
        if(!nativeMode)sameTabs(checkpoint.tabs,await windowTabs());
        const result=await request('undo');
        if(!nativeMode)sameTabs(checkpoint.tabs,await windowTabs(),true);
        events.push({action:'undo',snapshot:result,...(nativeMode?{nativeObjectsPreserved:true}:{sameTabIDs:true}),orderRestored:true});
        await saveCheckpoint({...checkpoint,phase:'undone'});
        snapshot=null;proposal=null;
        $('preview-title').textContent='Текущее дерево';
        preview.textContent='Исходное дерево восстановлено. Прочитай его перед новой сортировкой.';
        status.textContent=nativeMode?'Исходное дерево, порядок и раскрытие восстановлены.':'Исходное дерево, порядок и раскрытие восстановлены. ID вкладок сохранены.';
      }
    }catch(error){
      proposal=null;recoveryPlan=null;
      status.textContent=error.message==='Selected group cannot be matched uniquely to a native window'
        ? 'Не удалось однозначно найти нативное дерево. Проверь выбранное окно и открой в нём View → Show Vertical Tabs Sidebar, затем повтори.'
        : error.message;
    }
    finally{busy=false;enableControls();}
  }
  controls.forEach(id=>$(id).addEventListener('click',()=>run(id)));
  $('endpoint').addEventListener('change',()=>{$('key').value='';$('keyStatus').textContent='';run('loadKey');});
  $('window').addEventListener('change',()=>{snapshot=null;proposal=null;recoveryPlan=null;enableControls();preview.textContent='Прочитай дерево выбранного окна.';});
  async function initialize(){
    try{
      const stored=await probeAPI.call('storage.local','get',['orionAISettings','orionSortCheckpoint']);
      const config=OrionProviderSettings.publicSettings(stored.orionAISettings);
      $('endpoint').value=config.endpoint;$('model').value=config.model;$('depth').value=String(config.maxDepth);$('preserve').checked=config.preserveExisting;
      await refreshWindows();
      if(['prepared','applied'].includes(stored.orionSortCheckpoint?.phase)&&Array.from($('window').children).some(o=>o.value===String(stored.orionSortCheckpoint.before.scope.windowId)))$('window').value=String(stored.orionSortCheckpoint.before.scope.windowId);
      let connectAttempts=0;
      async function connect(){
        if(busy||pending){setTimeout(connect,1000);return;}
        try{
          await request('ping');
          let keyError=null;
          try{await loadSavedKey();}catch(error){keyError=error;$('keyStatus').textContent=error.message;}
          try{
            const journal=await request('recoveryJournal');
            journalPhase=journal.phase;journalPending=['prepared','applied','undoing','rollingBack'].includes(journal.phase);
            $('journalNotice').hidden=!journalPending||canUndo;
            $('journalNotice').textContent=journal.phase==='applied'?'После перезапуска найден журнал прошлой сортировки. Оставь текущее дерево или проверь восстановление прежнего.':'Найдена незавершённая операция. Открой «Восстановление» и проверь журнал.';
          }catch{journalPending=false;journalPhase=null;$('journalNotice').hidden=true;}
          status.textContent=keyError?'Не удалось загрузить ключ: '+keyError.message:journalPending&&!canUndo?'Текущее дерево можно прочитать. В разделе «Восстановление» выбери, что делать с прошлой сортировкой.':canUndo?'Мост подключён. Undo предыдущей сортировки доступен.':'Мост подключён. Выбери окно и прочитай дерево.';
        }catch{
          if(++connectAttempts<20)setTimeout(connect,1000);
        }
      }
      await connect();
    }catch(error){status.textContent=error.message;}
    enableControls();
  }
  initialize();
})();
