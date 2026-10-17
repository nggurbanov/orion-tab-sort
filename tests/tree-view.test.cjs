const {test}=require('node:test');
const assert=require('node:assert/strict');
const tree=require('../extension/tree-view.js'),planner=require('../extension/tree-plan.js');
function fixture(){return {scope:{windowId:1},revision:'synthetic',tabs:Array.from({length:8},(_,i)=>({id:i+1,key:String(i+1),title:i<2?'Duplicate':'Level '+(i+1),url:i<2?'https://example.org/same':'https://example.org/'+i,parentKey:i?String(i):null,index:0,pinned:false,active:i===0,expanded:true}))};}
test('filter preserves ancestors all the way to depth eight without changing the plan',()=>{
 const snapshot=fixture(),plan=planner.undoPlan(snapshot),before=JSON.stringify(plan),rows=tree.rows(snapshot,plan,'Level 8');let n=rows[0],depth=1;while(n.children.length){depth++;n=n.children[0];}assert.equal(depth,8);assert.equal(n.title,'Level 8');assert.equal(JSON.stringify(plan),before);
});
test('duplicate titles and URLs remain distinct identity rows with occurrence hints',()=>{
 const s=fixture(),rows=tree.rows(s,planner.undoPlan(s));assert.notEqual(rows[0].key,rows[0].children[0].key);assert.equal(rows[0].duplicate,true);assert.equal(rows[0].children[0].duplicate,true);
});
test('changed marker reflects a different parent or sibling index and URLs are parsed only locally',()=>{
 const s=fixture(),plan=planner.fromForest(s,[1,2,3,4,5,6,7,8],{preserveExisting:false});const rows=tree.rows(s,plan);assert.equal(rows[1].changed,true);assert.equal(rows[0].domain,'example.org/same');assert.deepEqual(tree.rows(s,plan,'does not exist'),[]);
});

class Element{
 constructor(tag,doc){this.tagName=tag;this.ownerDocument=doc;this.children=[];this.attributes={};this.hidden=false;this.text='';}
 set textContent(value){this.text=value;this.children=[];}get textContent(){return this.text+this.children.map(c=>c.textContent).join('');}
 setAttribute(k,v){this.attributes[k]=v;}append(...children){this.children.push(...children);}replaceChildren(...children){this.children=children;this.text='';}addEventListener(k,fn){this[k]=fn;}
}
function documentFixture(){const doc={createElement:tag=>new Element(tag,doc),createElementNS:(ns,tag)=>new Element(tag,doc)};return doc;}
function walk(node){return [node,...node.children.flatMap(walk)];}
test('actual tree renderer uses safe text nodes and local SVGs, with functional preview-only collapse',()=>{
 const doc=documentFixture(),container=doc.createElement('div'),s=fixture();s.tabs[0].title='<img src="https://private.example" onerror="alert(1)">';const before=JSON.stringify(s);
 tree.render(container,s,planner.undoPlan(s),{proposed:true});const nodes=walk(container);
 assert.ok(container.textContent.includes('<img src='));assert.ok(nodes.some(n=>n.tagName==='svg'));assert.equal(nodes.some(n=>n.tagName==='img'||n.attributes.src),false);
 const button=nodes.find(n=>n.tagName==='button');assert.equal(button.attributes['aria-expanded'],'true');button.click();assert.equal(button.attributes['aria-expanded'],'false');button.click();assert.equal(button.attributes['aria-expanded'],'true');assert.equal(JSON.stringify(s),before);
});
test('English markup represents every supported depth and exposes live status and only a proposal Cancel',()=>{
 const html=require('node:fs').readFileSync(require.resolve('../extension/sorter.html'),'utf8');
 const depth=html.match(/<select id="depth">([\s\S]*?)<\/select>/)[1];assert.deepEqual([...depth.matchAll(/value="(\d+)"/g)].map(m=>Number(m[1])),[1,2,3,4,5,6,7,8]);assert.match(html,/<html lang="en">/);assert.match(html,/id="status" role="status"/);assert.match(html,/id="cancel"[^>]*hidden>Cancel generation/);assert.equal((html.match(/id="cancel"/g)||[]).length,1);
});
