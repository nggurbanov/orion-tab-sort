(function(root){
  'use strict';
  const planner=typeof module==='object'&&module.exports?require('./tree-plan.js'):root.OrionTreePlan;
  const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  function identities(snapshot,identity){
    planner.indexSnapshot(snapshot);
    if(!identity||!uuid.test(identity.windowUUID)||identity.revision!==snapshot.revision||!Array.isArray(identity.tabs))throw Error('Нет проверенного соответствия UUID текущему снимку.');
    const byKey=new Map(),byUUID=new Map();
    for(const binding of identity.tabs){
      const tab=snapshot.tabs.find(tab=>tab.key===binding.key&&!tab.pinned);
      if(!tab||!uuid.test(binding.uuid)||byKey.has(binding.key)||byUUID.has(binding.uuid.toLowerCase()))throw Error('Некорректный или неоднозначный UUID вкладки.');
      byKey.set(binding.key,binding.uuid.toLowerCase());byUUID.set(binding.uuid.toLowerCase(),tab);
    }
    if(byKey.size!==snapshot.tabs.filter(tab=>!tab.pinned).length)throw Error('Не все вкладки имеют проверенные UUID.');
    return {byKey,byUUID};
  }
  function plan(journal,current,identity){
    if(!['prepared','applied','undoing','rollingBack'].includes(journal?.phase))throw Error('Журнал не требует восстановления.');
    if(journal.identity?.mode==='native-session'&&(identity?.mode!=='native-session'||journal.identity.sessionKey!==identity.sessionKey))throw Error('Этот журнал относится к другой сессии Orion. Восстановление по временным ID недоступно.');
    const old=identities(journal.before,journal.identity),now=identities(current,identity);
    if(journal.identity.windowUUID.toLowerCase()!==identity.windowUUID.toLowerCase())throw Error('UUID окна изменился.');
    if(old.byUUID.size!==now.byUUID.size||[...old.byUUID.keys()].some(id=>!now.byUUID.has(id)))throw Error('Набор вкладок изменился; автоматическое восстановление запрещено.');
    const pins=s=>JSON.stringify(s.tabs.filter(t=>t.pinned).map(t=>[t.url,t.index,t.active]).sort((a,b)=>a[1]-b[1]));
    if(pins(journal.before)!==pins(current))throw Error('Закреплённые вкладки изменились.');
    const nodes=[];
    for(const tab of journal.before.tabs.filter(tab=>!tab.pinned)){
      const live=now.byUUID.get(old.byKey.get(tab.key));
      if(tab.url!==live.url||tab.active!==live.active)throw Error('Адрес или активная вкладка изменились.');
      const parent=tab.parentKey===null?null:now.byUUID.get(old.byKey.get(tab.parentKey));
      if(tab.parentKey!==null&&!parent)throw Error('Не найден исходный родитель.');
      nodes.push({id:live.id,key:live.key,parentKey:parent?.key??null,index:tab.index,expanded:tab.expanded});
    }
    return {version:1,scope:{...current.scope},expectedRevision:current.revision,nodes,pinnedKeys:current.tabs.filter(t=>t.pinned).map(t=>t.key)};
  }
  const api=Object.freeze({identities,plan});
  if(typeof module==='object'&&module.exports)module.exports=api;else root.OrionRecovery=api;
})(globalThis);
