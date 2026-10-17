(function(root){
  'use strict';
  async function expose({token,ids,nativeSelections,windowId,beforeTabs,request,call,sameTabs}){
    if(typeof token!=='string'||!Array.isArray(ids)||!ids.length||ids.length>2000||new Set(ids).size!==ids.length||ids.some(id=>!Number.isSafeInteger(id)||id<0))throw Error('Некорректные ID спящих дублей.');
    if(nativeSelections!==undefined&&(!Array.isArray(nativeSelections)||nativeSelections.length!==ids.length||new Set(nativeSelections).size!==nativeSelections.length||nativeSelections.some(i=>!Number.isSafeInteger(i)||i<0)))throw Error('Некорректные нативные кандидаты дублей.');
    const active=beforeTabs.filter(tab=>tab.active);
    if(active.length!==1)throw Error('Не удалось сохранить выбранную вкладку.');
    const originalIDs=new Set(beforeTabs.map(tab=>tab.id)),allowedIDs=new Set([...originalIDs,...ids]);
    const query=async()=> (await call('tabs','query',{windowId})).sort((a,b)=>a.id-b.id);
    const verify=after=>{
      sameTabs(beforeTabs,after.filter(tab=>originalIDs.has(tab.id)),true,false);
      if(after.some(tab=>!allowedIDs.has(tab.id)||tab.windowId!==windowId))throw Error('Набор вкладок изменился при проверке дублей.');
    };
    let failure;
    try{
      for(const id of nativeSelections||ids){
        if(nativeSelections)await request('selectExposure',{token,id});
        else{await request('selectIdentity',{token,id});await call('tabs','update',id,{active:true});}
        const selected=await query();verify(selected);
        const activeTabs=selected.filter(tab=>tab.active);
        if(activeTabs.length!==1||(nativeSelections?!ids.includes(activeTabs[0].id):activeTabs[0].id!==id))throw Error('Orion выбрал другую вкладку вместо спящего дубля.');
        await request('confirmExposure',{token,id,activeId:activeTabs[0].id});
      }
    }catch(error){failure=error;}
    let after,restored;
    try{
      if(!nativeSelections)await call('tabs','update',active[0].id,{active:true});
      if(failure){await request('cancelCapture',{token});}
      else restored=await request('finishExposure',{token});
      after=await query();verify(after);
      sameTabs(beforeTabs,after.filter(tab=>originalIDs.has(tab.id)),true);
      if(!failure&&ids.some(id=>!after.some(tab=>tab.id===id)))throw Error('Orion не сохранил подтверждённые ID дублей.');
    }catch(error){
      try{await request('cancelCapture',{token});}catch{}
      throw Error(`Восстановление выбора после проверки дублей не подтверждено: ${error.message}`);
    }
    if(failure)throw failure;
    return {tabs:after,snapshot:restored};
  }
  const api=Object.freeze({expose});
  if(typeof module==='object'&&module.exports)module.exports=api;else root.OrionPersistentIdentity=api;
})(globalThis);
