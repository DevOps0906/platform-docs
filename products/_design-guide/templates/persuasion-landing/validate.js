const fs=require('fs'),path=require('path');
const dir=process.argv[2]||require('path').join(__dirname,'data');
const ICONS='i-bulb i-list i-pen i-checkbox i-print i-doc i-layers i-stamp i-map i-cube i-move i-grid i-send2 i-users i-book i-shield i-calc i-scale i-video i-chart i-mic i-store i-star i-bell i-cart i-image i-news i-heart i-clock i-search i-link i-play i-upload i-globe i-chat i-lock i-rocket i-box'.split(' ');
function packCost(n,packs){ n=Math.min(Math.ceil(n),200000); if(n<=0) return 0; const dp=new Array(n+1); dp[0]=0;
 for(let i=1;i<=n;i++){ let b=Infinity; for(const p of packs){ const c=dp[Math.max(0,i-p[0])]+p[1]; if(c<b) b=c;} dp[i]=b;} return dp[n]; }
const H={max:Math.max,min:Math.min,ceil:Math.ceil,floor:Math.floor,round:Math.round,won:n=>Math.round(n).toLocaleString('ko-KR')+'원',fmt1:n=>(Math.round(n*10)/10).toLocaleString('ko-KR'),pack:packCost,parseInt:parseInt};
function evalCalc(c,over){
  const v={}; c.groups.forEach(g=>g[1].forEach(f=>{v[f[0]]=Array.isArray(f[3])?f[3][0]:f[3];}));
  Object.assign(v,over||{});
  const scope=Object.assign({},H,v);
  const ev=e=>Function(...Object.keys(scope),'return ('+e+');')(...Object.values(scope));
  (c.derived||[]).forEach(d=>{scope[d[0]]=ev(d[1]);});
  return c.rows.map(r=>[r[0],ev(r[1]),ev(r[2]),ev(r[3])]);
}
module.exports={evalCalc};
if(require.main===module){
let bad=0;
for(const f of fs.readdirSync(dir).filter(f=>f.endsWith('.json')).sort()){
  const P=JSON.parse(fs.readFileSync(path.join(dir,f),'utf8')); const e=[];
  ['key','name','short','accent','pill','big','chips','join','head','sub','cta','formula','personas','cause','flow','alts','table','nonfit','evidence','ledger','stages','calc','insight','source'].forEach(k=>{if(!(k in P)) e.push('missing '+k);});
  if(P.key+'.json'!==f) e.push('key mismatch');
  if(!/^#[0-9a-f]{6}$/i.test(P.accent)) e.push('accent');
  if(P.short.length>12) e.push('short>12');
  P.personas.forEach((p,i)=>{ const l=P.ledger[i]; if(!l||l[0]!==p.id) e.push('persona id '+i); else if(l[1]!==p.scene) e.push('persona scene '+i); if(!ICONS.includes(p.icon)) e.push('icon '+p.icon);});
  P.flow.forEach(f=>{ if(!ICONS.includes(f[1])) e.push('flow icon '+f[1]); if(typeof f[3]!=='boolean') e.push('flow approve type');});
  if(P.alts.length!==4) e.push('alts!=4');
  P.alts.forEach(a=>{ if(!Array.isArray(a)) e.push('alt not array');});
  const evIds=P.evidence.map(x=>x[0]);
  if(!P.table.some(r=>r[2][0]==='t'||r[2][0]==='x')) e.push('ours all o');
  P.table.forEach(r=>{ if(r[1].length!==4) e.push('row alts '+r[0]); if(r[2][0]==='o'&&!r[3]) e.push('o without ev '+r[0]); if(r[3]&&!evIds.includes(r[3])&&/-E-/.test(r[3])) e.push('ev id unknown '+r[3]); [...r[1],r[2]].forEach(c=>{if(!'otxn'.includes(c[0])) e.push('mark '+c[0]);});});
  P.ledger.forEach(l=>{ if(!['draft','hold'].includes(l[4])) e.push('status '+l[4]);});
  // 2판 필드(선택). 있으면 검사한다
  const altNames=P.alts.map(a=>Array.isArray(a)?a[0]:a);
  const inR=v=>typeof v==='number'&&v>=0&&v<=10;
  if(P.features){ if(P.features.length<4||P.features.length>9) e.push('features 4~9'); P.features.forEach(f=>{ if(!ICONS.includes(f.icon)) e.push('feature icon '+f.icon); if(!f.title||!f.sum||!Array.isArray(f.points)||f.points.length<2) e.push('feature shape '+f.title); }); }
  if(P.outputs){ P.outputs.forEach(o=>{ if(!Array.isArray(o)||o.length!==3) e.push('output shape'); }); }
  if(P.faq){ if(P.faq.length<4) e.push('faq<4'); P.faq.forEach(q=>{ if(!Array.isArray(q)||q.length!==2) e.push('faq shape'); }); }
  if(P.competitors){
    if(!P.market) e.push('competitors without market');
    if(P.competitors.length<4||P.competitors.length>6) e.push('competitors 4~6');
    P.competitors.forEach(c=>{ const id='comp '+c.name;
      if(!altNames.includes(c.cat)) e.push(id+' cat not in alts: '+c.cat);
      if(!/^https:\/\//.test(c.url||'')) e.push(id+' url');
      if(!/^\d{4}-\d{2}-\d{2}$/.test(c.checked||'')) e.push(id+' checked');
      if(!Array.isArray(c.strengths)||c.strengths.length<2) e.push(id+' strengths<2');
      if(!Array.isArray(c.weaknesses)||c.weaknesses.length<1) e.push(id+' weaknesses<1');
      if(!Array.isArray(c.xy)||!inR(c.xy[0])||!inR(c.xy[1])) e.push(id+' xy');
      if(!Array.isArray(c.src)||!c.src.length) e.push(id+' src');
      ['price','for','vs','region'].forEach(k=>{ if(!c[k]) e.push(id+' '+k); });
    });
  }
  if(!P.voice) e.push('voice missing'); else { const VV=P.voice; if(!VV.lead||!Array.isArray(VV.say)||!VV.say.length||!Array.isArray(VV.items)||!VV.items.length) e.push('voice shape'); (VV.say||[]).forEach(x=>{ if(!Array.isArray(x)||x.length!==2) e.push('voice say shape'); }); (VV.items||[]).forEach(x=>{ if(!Array.isArray(x)||x.length!==3) e.push('voice item shape'); }); }
  if(P.wizard){ const W=P.wizard; if(!W.title||!Array.isArray(W.steps)||!W.steps.length) e.push('wizard shape'); (W.steps||[]).forEach((st,i)=>{ ['name','user','system','credit'].forEach(k=>{ if(st[k]===undefined||st[k]==='') e.push('wizard step '+i+' '+k); }); if(st.icon&&!ICONS.includes(st.icon)) e.push('wizard icon '+st.icon); }); }
  if(P.tables){ Object.entries(P.tables).forEach(([k,T])=>{ if(!Array.isArray(T.cols)||!Array.isArray(T.rows)) e.push('table '+k+' shape'); else T.rows.forEach((r,i)=>{ if(r.length!==T.cols.length) e.push('table '+k+' row '+i+' cols'); }); }); }
  if(P.journey){ const JN=P.journey, TYPES=['scene','cause','flow','steps','features','voice','outputs','market','verdict','nonfit','evidence','ledger','validate','insight','plans','calc','faq','table'], ids=new Set();
    if(!JN.name) e.push('journey name'); if(!Array.isArray(JN.stages)||JN.stages.length<3||JN.stages.length>7) e.push('journey stages 3~7');
    (JN.stages||[]).forEach(st=>{ if(!st.no||!st.label||!st.q) e.push('journey stage shape '+st.label); if(st.icon&&!ICONS.includes(st.icon)) e.push('journey icon '+st.icon);
      (st.pages||[]).forEach(pg=>{ const t=pg.type||pg.id; if(!pg.id||!/^[A-Za-z0-9_-]+$/.test(pg.id)) e.push('journey page id '+pg.id); if(ids.has(pg.id)) e.push('journey dup id '+pg.id); ids.add(pg.id);
        if(['home','guide'].includes(pg.id)) e.push('journey reserved id '+pg.id); if(!TYPES.includes(t)) e.push('journey type '+t); if(!pg.title) e.push('journey page title '+pg.id);
        if(t==='features'&&pg.pick&&pg.pick.some(i=>!P.features||!P.features[i])) e.push('journey pick '+pg.id);
        if(t==='steps'&&(!P.wizard||(pg.range&&(pg.range[0]<0||pg.range[1]>=P.wizard.steps.length||pg.range[0]>pg.range[1])))) e.push('journey range '+pg.id);
        if(t==='table'&&(!P.tables||!P.tables[pg.data])) e.push('journey table data '+pg.id); }); }); }
  if(P.market){ const m=P.market; if(!m.line||!m.lead||!m.axes||!Array.isArray(m.ours)||!inR(m.ours[0])||!inR(m.ours[1])) e.push('market shape'); if(m.axes&&(!m.axes.xname||!m.axes.yname||m.axes.x.length!==2||m.axes.y.length!==2)) e.push('market axes'); if(!Array.isArray(m.gaps)||m.gaps.length<2) e.push('market gaps<2'); }
  try{ const rows=evalCalc(P.calc); rows.forEach(r=>{ if(typeof r[1]!=='number'||!isFinite(r[1])) e.push('cost NaN '+r[0]); if(typeof r[2]!=='string'||typeof r[3]!=='string') e.push('str type '+r[0]);});
    console.log(f.padEnd(24), rows.map(r=>r[0]+'='+H.won(r[1])).join(' | '));
  }catch(x){ e.push('calc err '+x.message); }
  if(e.length){bad++; console.log('  !!',e.join('; '));}
}
console.log(bad?'FAIL '+bad:'ALL OK');
}
