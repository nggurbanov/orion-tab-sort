(function(root){
  "use strict";
  const defaults=Object.freeze({endpoint:"https://openrouter.ai/api/v1",model:"anthropic/claude-sonnet-5.5"});
  function publicSettings(value={}) {
    const endpoint=typeof value.endpoint==="string" ? value.endpoint.trim() : defaults.endpoint;
    const model=typeof value.model==="string" ? value.model.trim() : defaults.model;
    const depth=Number(value.maxDepth ?? 3);
    if(!Number.isInteger(depth)||depth<1||depth>8)throw new Error("Глубина должна быть от 1 до 8.");
    if(!model)throw new Error("Укажи модель AI.");
    const provider=typeof module==="object"&&module.exports ? require("./ai-provider.js") : root.OrionAIProvider;
    provider.completionURL(endpoint);
    return {endpoint,model,maxDepth:depth,preserveExisting:value.preserveExisting!==false};
  }
  const api=Object.freeze({defaults,publicSettings});
  if(typeof module==="object"&&module.exports)module.exports=api;
  else root.OrionProviderSettings=api;
})(globalThis);
