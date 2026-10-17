// Config arrives on stdin. The report never contains the config or credentials.
const fs = require('node:fs');
const provider = require('../extension/ai-provider.js');
const planner = require('../extension/tree-plan.js');
const snapshot = {scope:{windowId:0,groupKey:'synthetic-smoke'},revision:'synthetic',tabs:[
  {id:1,key:'test-1',title:'React documentation',url:'https://react.dev',parentKey:null,index:0,pinned:false,expanded:true,active:true},
  {id:2,key:'test-2',title:'React useState reference',url:'https://react.dev/reference/react/useState',parentKey:'test-1',index:0,pinned:false,expanded:false,active:false},
  {id:3,key:'test-3',title:'React useEffect reference',url:'https://react.dev/reference/react/useEffect',parentKey:null,index:1,pinned:false,expanded:false,active:false},
  {id:4,key:'test-4',title:'Orion browser help',url:'https://help.kagi.com/orion/',parentKey:null,index:2,pinned:false,expanded:false,active:false},
  {id:5,key:'test-5',title:'Orion vertical tabs',url:'https://help.kagi.com/orion/features/vertical-tabs.html',parentKey:null,index:3,pinned:false,expanded:false,active:false}
]};
(async()=>{
  let config;
  const rejected=[];
  try {
    config=JSON.parse(fs.readFileSync(0,'utf8'));
    const result=await provider.proposePlan(config,snapshot,{onInvalidProposal:event=>rejected.push(event)});
    const report={time:new Date().toISOString(),ok:true,model:config.model,syntheticTabsOnly:true,
      forest:result.forest,attempts:result.attempts,rejected,validPlan:true,preview:planner.describe(snapshot,result.plan)};
    if(process.argv[2])fs.writeFileSync(process.argv[2],JSON.stringify(report,null,2)+'\n');
    process.stdout.write(JSON.stringify(report,null,2)+'\n');
  } catch(error) {
    const report={ok:false,syntheticTabsOnly:true,error:error.message,rejected};
    if(process.argv[2])fs.writeFileSync(process.argv[2],JSON.stringify(report,null,2)+'\n');
    process.stdout.write(JSON.stringify(report)+'\n');
    process.exitCode=1;
  } finally { if(config)config.apiKey=''; }
})();
