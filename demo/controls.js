(async()=>{
 'use strict';
 const p=new URLSearchParams(location.search),scenario=p.get('scenario')||'idle',desiredMode=scenario==='preview'?'advanced':p.get('mode')||'auto',bar=document.createElement('aside');bar.className='demo-controls';bar.setAttribute('aria-label','Synthetic demo controls');
 const title=document.createElement('p');title.textContent='Synthetic demo · no Orion or network AI';bar.append(title);
 for(const [key,label,values]of [['scenario','Scenario',['idle','generating','preview','applied','nochanges','disconnected','recovery']],['fixture','Fixture',['outline','long','deep']],['theme','Theme',['light','dark']],['mode','Mode',['auto','advanced']]]){
  const wrapper=document.createElement('label');wrapper.textContent=label;const select=document.createElement('select');select.id='demo-'+key;
  for(const value of values){const o=document.createElement('option');o.value=value;o.textContent=value;select.append(o);}select.value=key==='mode'?desiredMode:p.get(key)||values[0];select.addEventListener('change',()=>{p.set(key,select.value);location.search=p.toString();});wrapper.append(select);bar.append(wrapper);
 }
 document.body.prepend(bar);
 for(let attempt=0;attempt<100&&window.OrionSorter.getState().busy;attempt++)await new Promise(r=>setTimeout(r,20));
 if(desiredMode==='advanced')window.OrionSorter.setMode('advanced');
 if(['generating','preview','applied','nochanges'].includes(scenario)){
  if(scenario==='applied')window.OrionSorter.setMode('auto');
  const work=window.OrionSorter.run('organize');
  if(scenario!=='generating'){await work;if(scenario==='applied'&&desiredMode==='advanced')window.OrionSorter.setMode('advanced');}
  else for(let attempt=0;attempt<100&&window.OrionSorter.getState().phase!=='generating';attempt++)await new Promise(r=>setTimeout(r,20));
 }
 window.OrionDemoReady=true;
})();
