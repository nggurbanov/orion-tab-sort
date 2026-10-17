const {test}=require('node:test');
const assert=require('node:assert/strict');
const settings=require('../extension/provider-settings.js');
test('public settings never persist supplied secrets or extra fields',()=>{
  const value=settings.publicSettings({apiKey:'secret',password:'secret',extra:{apiKey:'secret'}});
  assert.deepEqual(value,{endpoint:'https://openrouter.ai/api/v1',model:'anthropic/claude-sonnet-5.5',maxDepth:3,preserveExisting:true});
  assert.equal(JSON.stringify(value).includes('secret'),false);
});
test('validates settings before saving a selected endpoint',()=>{
  assert.throws(()=>settings.publicSettings({endpoint:'https://ai.example/?key=secret'}));
  assert.throws(()=>settings.publicSettings({maxDepth:99}));
  assert.throws(()=>settings.publicSettings({model:' '}));
});
