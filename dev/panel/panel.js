
/* Panel privado de Plata. Vive en su propio dominio (dev), NUNCA en plataapp.net ni en la app: así un fallo en el sitio público no puede leer el token,
 * y el token nunca se escribe en el dominio público. El token solo vive en memoria mientras la pestaña está abierta. */
if(/(^|\.)plataapp\.net$/.test(location.hostname)){document.body.innerHTML='<div class="w"><h1>Panel</h1><p class="sub">Este panel no funciona en plataapp.net. Ábrelo desde el panel privado o desde tu computadora.</p></div>';throw new Error('dominio público')}
var API=(/^(localhost|127\.0\.0\.1)$/.test(location.hostname)&&new URLSearchParams(location.search).get('api'))||'https://plata-cloud.xleoricharte.workers.dev',SITE='https://plataapp.net/',tok='',$=function(i){return document.getElementById(i)};
function msg(t){$('msg').textContent=t||''}
function call(path,method,body){return fetch(API+path,{method:method||'GET',headers:Object.assign({Authorization:'Bearer '+tok},body?{'Content-Type':'application/json'}:{}),body:body?JSON.stringify(body):undefined}).then(function(r){return r.json().catch(function(){return{}}).then(function(j){if(!r.ok||j.ok===false){var e=new Error(j.error||('error '+r.status));e.code=r.status;if(r.status===401&&tok)lockNow('exp');throw e}return j})})}
function when(id){var n=parseInt(id.split('-')[0],36);return n?new Date(n).toLocaleString([], {day:'numeric',month:'short',year:'numeric',hour:'numeric',minute:'2-digit'}):id}
function esc(s){return String(s==null?'':s).replace(/[&<>"']/g,function(c){return{'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]})}
function save(name,obj){var a=document.createElement('a');a.href=URL.createObjectURL(new Blob([JSON.stringify(obj,null,2)],{type:'application/json'}));a.download=name;document.body.appendChild(a);a.click();a.remove()}
function card(id,st,rec){
  var del=st.deleted,rev=st.reviewed,d=rec&&rec.data||{};
  var n=function(x){return Array.isArray(x)?x.length:0}; // la copia la manda cualquiera: nada de ella entra al HTML sin pasar por número o esc()
  var sum=del?'Datos eliminados de los servidores.':rec?(n(d.transactions)+' movimientos · '+n(d.accounts)+' cuentas · '+n(d.cards)+' tarjetas · '+esc(rec.plat||'plataforma desconocida')+' · build '+(Number(rec.build)||'?')):'';
  var el=document.createElement('div');el.className='card';
  el.innerHTML='<div class="t">'+esc(when(id))+(del?'<span class="pill del">Eliminada</span>':rev?'<span class="pill ok">Revisada '+esc(rev)+'</span>':'<span class="pill">Pendiente</span>')+'</div><div class="m">'+sum+'</div><div class="row"></div>';
  var row=el.querySelector('.row');
  function btn(t,c,fn){var b=document.createElement('button');b.textContent=t;b.className=c;b.onclick=function(){b.disabled=true;fn(b)};row.appendChild(b)}
  if(!del)btn('Descargar','',function(b){call('/review/get?id='+encodeURIComponent(id)).then(function(j){save('plata-revision-'+id+'.json',j.data);msg('Descargada.')}).catch(fail).then(function(){b.disabled=false})});
  if(!del&&!rev)btn('Marcar como revisada','g',function(b){call('/review/mark?id='+encodeURIComponent(id),'POST').then(load).catch(fail)});
  if(!del)btn('Eliminar del servidor','d',function(b){if(!confirm('¿Eliminar esta copia del servidor? Esto no se puede deshacer. Descárgala antes si la necesitas.')){b.disabled=false;return}call('/review/delete?id='+encodeURIComponent(id),'POST').then(load).catch(fail)});
  return el}
function fail(e){msg(e.code===401?'La sesión venció. Entra de nuevo.':e.code===403&&e.message==='role'?'Tu rol no permite esto.':e.code===429?'Demasiados intentos. Espera unos minutos.':'No se pudo: '+e.message)}
function load(){
  if(!tok)return;
  msg('Cargando…');
  call('/review/list').then(function(l){
    var ids=l.ids.slice().reverse(),box=$('list');box.innerHTML='';
    if(!ids.length){msg('Todavía no hay copias.');return}
    msg(ids.length+(ids.length==1?' copia':' copias')+'.');
    return Promise.all(ids.map(function(id){
      return call('/review/status?id='+encodeURIComponent(id)).then(function(st){
        if(st.deleted)return[id,st,null];
        return call('/review/get?id='+encodeURIComponent(id)).then(function(r){return[id,st,r]})})
    })).then(function(rs){rs.forEach(function(x){box.appendChild(card(x[0],x[1],x[2]))})})
  }).catch(fail)}
var ROLE='',NAME='',EXP=0,clock=null,hiddenAt=0;
function lockNow(why){tok='';ROLE='';if(clock)clearInterval(clock);var u=new URL(location.href);u.searchParams.set('s',why||'out');location.replace(u.toString())}
function startClock(){var el=$('sinfo');function t(){var left=EXP-Date.now();if(left<=0){lockNow('exp');return}var m=Math.floor(left/60000),s=Math.floor(left%60000/1000);el.textContent=NAME+' · '+ROLE+' · vence en '+m+':'+String(s).padStart(2,'0');el.style.color=left<300000?'var(--warn)':''}t();clock=setInterval(t,1000)}
document.addEventListener('visibilitychange',function(){if(!ROLE)return;if(document.hidden)hiddenAt=Date.now();else if(hiddenAt&&Date.now()-hiddenAt>600000)lockNow('idle')});
function unlock(){if(!$('tabs').hidden)return;$('tabs').hidden=false;['lcard','scold0','fn'].forEach(function(i){var e=$(i);if(e)e.hidden=true});document.querySelector('.scold').hidden=true;$('sub').textContent=document.documentElement.lang==='en'||$('go').textContent==='Enter'?'Signed in.':'Sesión iniciada.';document.querySelector('.w').style.maxWidth='980px';
 var dev=ROLE==='dev';['tR','tW','tZ','tP','tT','tL'].forEach(function(i){$(i).hidden=!dev});
 if(!dev){$('esv').textContent='Enviar a revisión';$('pub').textContent='Enviar a revisión';$('ers').textContent='Pedir volver al original';$('legacy').hidden=true;$('sub').textContent='Sesión mod: tus cambios no se publican hasta que un dev los apruebe.'}
 if(dev){tab('R');load()}else tab('N');loadPosts()}
function enter(){var t=$('tok').value.trim();if(!t){msg('Escribe tu token.');return}
 msg('Entrando…');$('go').disabled=true;
 fetch(API+'/admin/session',{method:'POST',headers:{Authorization:'Bearer '+t}}).then(function(r){return r.json().catch(function(){return{}}).then(function(j){if(!r.ok||!j.session){var e=new Error(j.error||('error '+r.status));e.code=r.status;throw e}return j})})
 .then(function(j){$('tok').value='';t='';tok=j.session;ROLE=j.role;NAME=j.name||j.role;EXP=j.exp;msg('');unlock();startClock()})
 .catch(function(e){msg(e.code===401?'El token no es correcto.':e.code===429?'Demasiados intentos. Espera unos minutos.':e.code===403?'Este panel no puede abrir sesión desde aquí.':'No se pudo entrar: '+e.message)}).then(function(){$('go').disabled=false})}
$('lo').onclick=function(){var t=tok;tok='';fetch(API+'/admin/logout',{method:'POST',headers:{Authorization:'Bearer '+t}}).catch(function(){}).then(function(){lockNow('out')})};
$('go').onclick=enter;$('tok').addEventListener('keydown',function(e){if(e.key==='Enter')enter()});

/* ---------- Novedades ---------- */
function inl(t){t=esc(t);t=t.replace(/`([^`]+)`/g,'<code>$1</code>');t=t.replace(/\*\*([^*]+)\*\*/g,'<b>$1</b>');t=t.replace(/\*([^*]+)\*/g,'<i>$1</i>');t=t.replace(/\[([^\]]+)\]\((https?:\/\/[^\s)]+|mailto:[^\s)]+|[A-Za-z0-9_\-.\/#?=&]+)\)/g,'<a href="$2" target="_blank" rel="noopener">$1</a>');return t}
function md(src){var out=[];String(src).replace(/\r/g,'').split(/\n{2,}/).forEach(function(b){b=b.trim();if(!b)return;var ls=b.split('\n');
 if(/^## /.test(b)&&ls.length===1)out.push('<h3>'+inl(b.slice(3))+'</h3>');
 else if(ls.every(function(l){return /^- /.test(l)}))out.push('<ul>'+ls.map(function(l){return '<li>'+inl(l.slice(2))+'</li>'}).join('')+'</ul>');
 else if(ls.every(function(l){return /^> ?/.test(l)}))out.push('<blockquote>'+ls.map(function(l){return inl(l.replace(/^> ?/,''))}).join('<br>')+'</blockquote>');
 else out.push('<p>'+ls.map(inl).join('<br>')+'</p>')});return out.join('')}
var editId=null,img=null,curImg='',posts=[];
function today(){var d=new Date(),z=function(v){return String(v).padStart(2,'0')};return d.getFullYear()+'-'+z(d.getMonth()+1)+'-'+z(d.getDate())}
var LANG='es';
function fmtDate(d){try{var x=new Date(d+'T12:00:00');return isNaN(x)?'':x.toLocaleDateString(LANG==='en'?'en':'es',{day:'numeric',month:'long',year:'numeric'})}catch(e){return d}}
function pv(){var en=LANG==='en',t=(en?$('tie'):$('ti')).value.trim(),b=(en?$('boe'):$('bo')).value,by=(en&&$('bye').value.trim())||$('by').value.trim(),tg=(en&&$('tge').value.trim())||$('tg').value,cover=img&&img!=='remove'?img:curImg,
 tags=tg.split(',').map(function(x){return x.trim()}).filter(Boolean).slice(0,6),d=fmtDate($('dt').value),meta=(by?'<b>'+esc(by)+'</b>'+($('vf').checked?' <span class="ck" title="Verificado">✓</span>':''):'')+(by&&d?' · ':'')+esc(d);
 $('pv').innerHTML=(cover?'<div class="pc"><img alt="" src="'+esc(cover)+'"></div>':'')+'<div class="pb">'+(tags.length?'<div class="tags">'+tags.map(function(x){return '<span>'+esc(x)+'</span>'}).join('')+'</div>':'')+(t?'<h2>'+esc(t)+'</h2>':'')+(meta?'<div class="by">'+meta+'</div>':'')+(b.trim()?'<div class="bd">'+md(b)+'</div>':(t?'':'<div class="emp">'+(en?'The preview appears here.':'La vista previa aparece aquí.')+'</div>'))+'</div>';
 $('pvl').textContent=en?'English':'Español';
 var w=($('bo').value.trim().match(/\S+/g)||[]).length;$('cnt').textContent=w+(w===1?' palabra':' palabras')+(w?' · ~'+Math.max(1,Math.round(w/200))+' min de lectura':'')}
function setLang(l){LANG=l;$('paES').hidden=l!=='es';$('enb').hidden=l!=='en';$('lgES').classList.toggle('on',l==='es');$('lgEN').classList.toggle('on',l==='en');pv()}
$('lgES').onclick=function(){setLang('es')};$('lgEN').onclick=function(){setLang('en')};
['tie','boe','bye','tge'].forEach(function(i){$(i).addEventListener('input',function(){if(this.value.trim())$('en').checked=true;pv()})});['by','dt','tg','vf'].forEach(function(i){$(i).addEventListener('input',pv);$(i).addEventListener('change',pv)});
function tab(n){var w=document.querySelector('.w');if(w&&!$('tabs').hidden)w.style.maxWidth=n==='N'?'1180px':'980px';$('pR').hidden=n!=='R';$('pN').hidden=n!=='N';$('pW').hidden=n!=='W';$('pE').hidden=n!=='E';$('pZ').hidden=n!=='Z';$('pP').hidden=n!=='P';$('pT').hidden=n!=='T';$('pL').hidden=n!=='L';$('tT').classList.toggle('on',n==='T');$('tL').classList.toggle('on',n==='L');$('tP').classList.toggle('on',n==='P');$('tZ').classList.toggle('on',n==='Z');$('tE').classList.toggle('on',n==='E');$('tR').classList.toggle('on',n==='R');$('tN').classList.toggle('on',n==='N');$('tW').classList.toggle('on',n==='W')}
$('tR').onclick=function(){tab('R')};$('tN').onclick=function(){tab('N')};$('tW').onclick=function(){tab('W');loadW()};$('tP').onclick=function(){tab('P');loadProps()};$('tT').onclick=function(){tab('T');loadTeam()};$('tL').onclick=function(){tab('L');loadLog()};$('prf').onclick=loadProps;$('tZ').onclick=function(){tab('Z');if(window.nazcaPanelOpen)window.nazcaPanelOpen()};
var EP=[['Inicio',''],['Cómo usar','como-usar.html'],['Escritorio','escritorio.html'],['Cloud','cloud.html'],['Transparencia','transparencia.html'],['Prensa','prensa.html'],['Novedades','novedades.html'],['Ayuda','ayuda.html'],['Merch','merch.html']];
/* Textos de la web: se lee el HTML público de cada página, se listan sus textos [data-es] y se editan aquí. Cada texto se identifica por un hash
 * de su versión original en español (igual que content.js en el sitio). Nada del sitio se ejecuta aquí: solo se lee como texto. */
var CT={},ETX=[],EED=null;
function fnv(s){var h=2166136261;for(var i=0;i<s.length;i++){h^=s.charCodeAt(i);h=Math.imul(h,16777619)}return ('00000000'+(h>>>0).toString(16)).slice(-8)}
var OKT={EM:1,B:1,STRONG:1,I:1,BR:1,A:1};
function clean(h){var d=new DOMParser().parseFromString('<body>'+String(h)+'</body>','text/html').body;(function walk(n){[].slice.call(n.childNodes).forEach(function(c){if(c.nodeType===3)return;if(c.nodeType!==1){n.removeChild(c);return}
 if(!OKT[c.tagName]){walk(c);while(c.firstChild)n.insertBefore(c.firstChild,c);n.removeChild(c);return}
 [].slice.call(c.attributes).forEach(function(a){var keep=c.tagName==='A'&&a.name==='href'&&/^(https?:\/\/|mailto:|[\w#\/.?=&-]+$)/i.test(a.value.trim());if(!keep)c.removeAttribute(a.name)});walk(c)})})(d);return d.innerHTML}
function plainOf(h){var d=document.createElement('div');d.innerHTML=clean(h);return d.textContent.trim()}
function loadCT(){return fetch(API+'/content').then(function(r){return r.json()}).then(function(j){CT=j.items||{}})}
function renderE(){var q=$('eq').value.trim().toLowerCase(),box=$('elist');box.innerHTML='';
 ETX.filter(function(x){return !q||(plainOf(x.es)+' '+plainOf(x.en)+' '+(CT[x.k]?plainOf(CT[x.k].es):'')).toLowerCase().indexOf(q)>=0}).forEach(function(x){
  var it=CT[x.k],el=document.createElement('div');el.className='card';
  el.innerHTML='<div class="m">'+(it?'<span class="pill ok" style="margin:0 6px 0 0">Editado</span>':'')+esc(x.k)+'</div><div class="t" style="margin-top:6px;font-weight:600"></div><div class="m" style="margin-top:4px"></div><div class="row"></div>';
  el.querySelector('.t').textContent=plainOf(it?it.es:x.es);el.querySelectorAll('.m')[1].textContent=plainOf(it?it.en:x.en);
  var b=document.createElement('button');b.className='g';b.textContent='Editar';b.onclick=function(){editE(x)};el.querySelector('.row').appendChild(b);box.appendChild(el)})}
function editE(x){EED=x;var it=CT[x.k];$('eform').hidden=false;$('efo').textContent='Original: '+plainOf(x.es);$('ees').value=it?it.es:x.es;$('een').value=it?it.en:x.en;$('ers').hidden=!it;$('emsg').textContent='';pvE();$('eform').scrollIntoView({behavior:'smooth'})}
function pvE(){$('epv').innerHTML='<p>'+clean($('ees').value)+'</p><p>'+clean($('een').value)+'</p>'}
['ees','een'].forEach(function(i){$(i).addEventListener('input',pvE)});
$('ecx').onclick=function(){$('eform').hidden=true;EED=null};
$('esv').onclick=function(){var x=EED;if(!x)return;var es=$('ees').value.trim(),en=$('een').value.trim()||es;$('emsg').textContent='Guardando…';
 call('/content','POST',{k:x.k,orig:x.es.slice(0,160),es:es,en:en}).then(function(j){if(j&&j.proposed){$('emsg').textContent='Enviado a revisión: un dev lo aprueba antes de publicarse.';return}CT[x.k]={es:es,en:en};$('eform').hidden=true;renderE()}).catch(function(e){$('emsg').textContent=e.message==='html'?'Ese HTML no está permitido: usa solo <b>, <i>, <em>, <strong>, <br> y <a href="…">.':e.code===401?'La sesión venció.':e.message==='full'?'Hay demasiadas propuestas sin revisar.':'No se pudo guardar: '+e.message})};
$('ers').onclick=function(){var x=EED;if(!x||!confirm('¿Volver al texto original de esta frase?'))return;call('/content?k='+x.k,'DELETE').then(function(j){if(j&&j.proposed){$('emsg').textContent='Enviado a revisión.';return}delete CT[x.k];$('eform').hidden=true;renderE()}).catch(function(e){$('emsg').textContent='No se pudo: '+e.message})};
$('eq').addEventListener('input',renderE);
function pageE(path){$('elist').innerHTML='<div class="card m">Cargando…</div>';$('eform').hidden=true;
 Promise.all([fetch(SITE+path,{cache:'no-store'}).then(function(r){if(!r.ok)throw new Error('http '+r.status);return r.text()}),loadCT()]).then(function(rs){
  var d=new DOMParser().parseFromString(rs[0],'text/html'),seen={};ETX=[];
  [].forEach.call(d.querySelectorAll('[data-es]'),function(e){var es=e.getAttribute('data-es'),k=fnv(es);if(seen[k])return;seen[k]=1;ETX.push({k:k,es:es,en:e.getAttribute('data-en')||es})});
  $('eq').hidden=false;renderE()}).catch(function(e){$('elist').innerHTML='';var c=document.createElement('div');c.className='card m';c.textContent='No se pudo leer la página: '+e.message;$('elist').appendChild(c)})}
$('tE').onclick=function(){tab('E');if($('epg').children.length)return;EP.forEach(function(x,i){var b=document.createElement('button');b.type='button';b.className='g';b.textContent=x[0];b.onclick=function(){[].forEach.call($('epg').children,function(c){c.classList.add('g')});b.classList.remove('g');pageE(x[1])};$('epg').appendChild(b)});$('epg').children[0].click()};
/* ---------- Lista de espera ---------- */
var wl=[];
function wdate(t){var d=new Date(t),z=function(v){return String(v).padStart(2,'0')};return d.getFullYear()+'-'+z(d.getMonth()+1)+'-'+z(d.getDate())}
function loadW(){$('wmsg').textContent='Cargando…';call('/waitlist/export').then(function(r){wl=r.list||[];renderW();$('wmsg').textContent=''}).catch(function(e){$('wmsg').textContent='No se pudo cargar: '+e.message})}
function renderW(){var n=wl.filter(function(x){return x.inv}).length;$('wsum').textContent=wl.length+' en la lista · '+n+' autorizados · '+(wl.length-n)+' pendientes.';
 var box=$('wl');box.innerHTML='';wl.slice().sort(function(a,b){return (a.inv?1:0)-(b.inv?1:0)||a.t-b.t}).forEach(function(x){
  var c=document.createElement('div');c.className='card';c.style.cssText='display:flex;align-items:center;gap:12px;padding:12px 16px';
  c.innerHTML='<input type="checkbox" class="wk" style="width:20px;height:20px;margin:0" data-e="'+esc(x.email)+'"><div style="flex:1;min-width:0"><div class="t" style="overflow:hidden;text-overflow:ellipsis">'+esc(x.email)+'</div><div class="m">#'+(x.n||'?')+' · '+wdate(x.t)+' · '+esc((x.lang||'es').toUpperCase())+(x.mail?' · correo enviado '+wdate(x.mail):'')+'</div></div><span class="pill">'+(x.inv?'Autorizado':'Pendiente')+'</span>';
  var p=c.querySelector('.pill');p.style.cssText=x.inv?'background:color-mix(in srgb,var(--accent) 16%,transparent);color:var(--accent)':'background:color-mix(in srgb,var(--warn) 14%,transparent);color:var(--warn)';
  box.appendChild(c)})}
function wsel(){return [].slice.call(document.querySelectorAll('.wk:checked')).map(function(i){return i.getAttribute('data-e')})}
function wact(body,ask){var em=wsel();if(!em.length){$('wmsg').textContent='Marca al menos un correo.';return}
 if(ask&&!confirm(ask.replace('N',em.length)))return;body.emails=em;$('wmsg').textContent='Procesando…';
 call('/admin/invite','POST',body).then(function(r){var t=r.invited+' actualizados.';if(body.send)t+=(r.mailOn?' '+r.mailed+' correos enviados.':' El servidor no tiene el correo configurado (RESEND_API_KEY): se autorizó sin enviar.')+(r.mailFailed&&r.mailFailed.length?' Fallaron: '+r.mailFailed.join(', ')+'.':'');
  loadW();setTimeout(function(){$('wmsg').textContent=t},400)}).catch(function(e){$('wmsg').textContent='No se pudo: '+e.message})}
$('wsel').onclick=function(){var ks=[].slice.call(document.querySelectorAll('.wk'));ks.forEach(function(k){var x=wl.filter(function(w){return w.email===k.getAttribute('data-e')})[0];k.checked=!!x&&!x.inv})};
$('wmail').onclick=function(){wact({send:true},'¿Autorizar a N personas y enviarles el correo de invitación?')};
$('wauth').onclick=function(){wact({})};
$('wrev').onclick=function(){wact({revoke:true},'¿Quitar el acceso a N personas?')};

['ti','bo'].forEach(function(i){$(i).addEventListener('input',pv)});

document.querySelectorAll('.tb').forEach(function(tb){var ta=$(tb.getAttribute('data-for'));tb.addEventListener('click',function(e){var b=e.target.closest('button');if(!b)return;var s=ta.selectionStart,en=ta.selectionEnd,v=ta.value,sel=v.slice(s,en),m=b.getAttribute('data-m'),l=b.getAttribute('data-l');
 if(m){var p=m.split('|');ta.value=v.slice(0,s)+p[0]+(sel||'texto')+p[1]+v.slice(en);ta.focus();ta.setSelectionRange(s+p[0].length,s+p[0].length+(sel||'texto').length)}
 else{var a=v.lastIndexOf('\n',s-1)+1,z=v.indexOf('\n',en);if(z<0)z=v.length;var seg=v.slice(a,z).split('\n').map(function(x){return l+x}).join('\n');ta.value=v.slice(0,a)+seg+v.slice(z);ta.focus()}
 pv()})});
function showImg(src){$('cv').innerHTML=src?'<img alt="" src="'+esc(src)+'">':'Sin imagen';$('imx').hidden=!src;if(typeof pv==='function'&&$('pv'))pv()}
$('im').onchange=function(){var f=this.files[0];if(!f)return;var u=URL.createObjectURL(f),i=new Image();i.onload=function(){var c=document.createElement('canvas');c.width=1920;c.height=1080;var x=c.getContext('2d'),r=Math.max(1920/i.width,1080/i.height),w=i.width*r,h=i.height*r;x.fillStyle='#fff';x.fillRect(0,0,1920,1080);x.drawImage(i,(1920-w)/2,(1080-h)/2,w,h);
 var q=.88,d=c.toDataURL('image/jpeg',q);while(d.length>2400000&&q>.4){q-=.08;d=c.toDataURL('image/jpeg',q)}img=d;showImg(d);pv();URL.revokeObjectURL(u)};i.onerror=function(){$('msg2').textContent='No se pudo leer esa imagen.'};i.src=u};
$('imx').onclick=function(){img=curImg?'remove':null;curImg='';$('im').value='';showImg('')};
function resetForm(){editId=null;img=null;curImg='';['ti','bo','tie','boe','alt','tg','bye','tge'].forEach(function(i){$(i).value=''});$('en').checked=false;setLang('es');$('dt').value=today();$('vf').checked=false;try{$('by').value=localStorage.getItem('plata.admin.by')||''}catch(e){$('by').value=''}$('im').value='';showImg('');$('edt').textContent='Nuevo artículo';$('pub').textContent=ROLE==='mod'?'Enviar a revisión':'Publicar';$('cx').hidden=true;pv()}
$('cx').onclick=function(){resetForm();$('msg2').textContent=''};
function edit(p){editId=p.id;img=null;$('ti').value=p.title_es;$('bo').value=p.body_es;$('tie').value=p.title_en||'';$('boe').value=p.body_en||'';$('en').checked=!!(p.title_en&&p.body_en);setLang('es');$('alt').value=p.alt||'';$('tg').value=p.tag||'';$('bye').value=p.by_en||'';$('tge').value=p.tag_en||'';$('by').value=p.by;$('dt').value=p.date;$('vf').checked=!!p.vf;curImg=p.hasImg?API+'/posts/img?id='+encodeURIComponent(p.id)+'&v='+Number(p.v):'';showImg(curImg);$('edt').textContent='Editando artículo';$('pub').textContent='Guardar cambios';$('cx').hidden=false;$('ed').scrollIntoView({behavior:'smooth'});pv()}
$('pub').onclick=function(){
 if(!tok){$('msg2').textContent='Entra de nuevo.';return}
 var b={id:editId,title_es:$('ti').value,body_es:$('bo').value,title_en:$('en').checked?$('tie').value:'',body_en:$('en').checked?$('boe').value:'',alt:$('alt').value,tag:$('tg').value,tag_en:$('en').checked?$('tge').value:'',by:$('by').value,by_en:$('en').checked?$('bye').value:'',date:$('dt').value,vf:$('vf').checked};
 if(img)b.img=img;
 if(!b.title_es.trim()||!b.body_es.trim()||!b.by.trim()){$('msg2').textContent='Faltan el título, el texto o la firma.';return}
 $('pub').disabled=true;$('msg2').textContent='Publicando…';
 call('/posts','POST',b).then(function(j){try{localStorage.setItem('plata.admin.by',b.by)}catch(e){}resetForm();if(j&&j.proposed){$('msg2').textContent='Enviado a revisión: un dev lo aprueba antes de publicarse.';return}$('msg2').textContent='Listo: publicado en Novedades.';loadPosts()}).catch(function(e){$('msg2').textContent=e.code===401?'La sesión venció.':'No se pudo publicar: '+e.message}).then(function(){$('pub').disabled=false})};
function loadPosts(){fetch(API+'/posts').then(function(r){return r.json()}).then(function(j){posts=j.posts||[];legacyBox();var box=$('plist');box.innerHTML='';
 if(!posts.length){box.innerHTML='<div class="card m">Todavía no hay artículos creados desde aquí.</div>';return}
 posts.forEach(function(p){var el=document.createElement('div');el.className='card';el.innerHTML='<div class="t">'+esc(p.title_es)+'</div><div class="m">'+esc(p.date)+' · por '+esc(p.by)+(p.title_en?' · ES/EN':' · ES')+'</div><div class="row"></div>';
  var row=el.querySelector('.row');var e=document.createElement('button');e.className='g';e.textContent='Editar';e.onclick=function(){edit(p)};row.appendChild(e);
  var d=document.createElement('button');d.className='d';d.textContent='Eliminar';d.onclick=function(){if(!confirm('¿Eliminar este artículo de Novedades? No se puede deshacer.'))return;call('/posts?id='+encodeURIComponent(p.id),'DELETE').then(function(j){if(j&&j.proposed){$('msg2').textContent='Enviado a revisión.';return}loadPosts()}).catch(function(er){$('msg2').textContent=er.code===401?'La sesión venció.':'No se pudo: '+er.message})};row.appendChild(d);box.appendChild(el)})}).catch(function(){})}
resetForm();
function ago(t){if(!t)return 'nunca';var m=Math.round((Date.now()-t)/60000);return m<1?'ahora':m<60?'hace '+m+' min':m<1440?'hace '+Math.round(m/60)+' h':'hace '+Math.round(m/1440)+' d'}
function loadTeam(){call('/admin/users').then(function(j){var box=$('tlist');box.innerHTML='';(j.items||[]).forEach(function(u){var el=document.createElement('div');el.className='card';var l=document.createElement('div');var t=document.createElement('div');t.className='t';t.textContent=u.name;var pl=document.createElement('span');pl.className='pill'+(u.rev?' del':' ok');pl.textContent=u.rev?'sin acceso':u.role;t.appendChild(pl);var m=document.createElement('div');m.className='m';m.textContent='Última entrada: '+ago(u.last)+' · creada por '+(u.by||'?');l.appendChild(t);l.appendChild(m);el.appendChild(l);
 var b=document.createElement('button');b.className=u.rev?'g':'d';b.textContent=u.rev?'Reactivar':'Quitar acceso';b.onclick=function(){if(!u.rev&&!confirm('¿Quitarle el acceso a '+u.name+'? Su sesión se cierra al instante.'))return;b.disabled=true;call('/admin/users/revoke?id='+encodeURIComponent(u.id)+(u.rev?'&undo=1':''),'POST',{}).then(loadTeam).catch(function(e){b.disabled=false;$('tmsg').textContent='No se pudo: '+e.message})};el.appendChild(b);box.appendChild(el)});
 if(!(j.items||[]).length)box.innerHTML='<div class="card m">Todavía no hay personas con token propio. Mientras tanto se entra con los tokens compartidos del Worker (quedan en el registro como «root» y «mod compartido»).</div>'}).catch(function(e){$('tmsg').textContent='No se pudo: '+e.message})}
$('tcb').onclick=function(){var n=$('tn').value.trim();if(!n){$('tmsg').textContent='Escribe un nombre.';return}$('tcb').disabled=true;$('tmsg').textContent='Creando…';
 call('/admin/users','POST',{name:n,role:$('tr').value}).then(function(j){$('tn').value='';$('tmsg').textContent='';$('tonm').textContent=n;$('tok2').textContent=j.token;$('tout').hidden=false;loadTeam()}).catch(function(e){$('tmsg').textContent=e.message==='full'?'Ya hay demasiadas personas (máximo 40).':'No se pudo: '+e.message}).then(function(){$('tcb').disabled=false})};
$('tcp').onclick=function(){var t=$('tok2').textContent;(navigator.clipboard?navigator.clipboard.writeText(t):Promise.reject()).then(function(){$('tcp').textContent='Copiado'}).catch(function(){$('tcp').textContent='Selecciónalo y cópialo a mano'})};
$('tcl').onclick=function(){$('tok2').textContent='';$('tout').hidden=true;$('tcp').textContent='Copiar'};
var LOG=[];
function renderLog(){var f=$('lflt').value,tb=$('ltb');tb.innerHTML='';LOG.filter(function(e){return !f||e.who===f}).forEach(function(e){var tr=document.createElement('tr');[[new Date(e.t).toLocaleString([], {day:'numeric',month:'short',hour:'numeric',minute:'2-digit'}),'w0'],[e.who+(e.role?' · '+e.role:''),''],[e.act,''],[e.d||'','w0'],[e.ip||'','w0']].forEach(function(c,i){var td=document.createElement('td');td.textContent=c[0];if(c[1])td.className=c[1];if(i===1)td.style.fontWeight='600';tr.appendChild(td)});tb.appendChild(tr)})}
function loadLog(){$('lmsg').textContent='Cargando…';call('/admin/audit?n=300').then(function(j){LOG=j.items||[];var who={};LOG.forEach(function(e){who[e.who]=1});var cur=$('lflt').value;$('lflt').innerHTML='<option value="">Todas las personas</option>'+Object.keys(who).map(function(w){return '<option>'+esc(w)+'</option>'}).join('');$('lflt').value=who[cur]?cur:'';$('lmsg').textContent=LOG.length?'Últimos '+LOG.length+' eventos de '+j.count+'.':'Todavía no hay actividad.';renderLog()}).catch(function(e){$('lmsg').textContent='No se pudo: '+e.message})}
$('lrf').onclick=loadLog;$('lflt').onchange=renderLog;
function loadProps(){var box=$('pbox');$('pmsg').textContent='Cargando…';call('/admin/proposals').then(function(j){box.innerHTML='';var it=j.items||[];$('pmsg').textContent=it.length?it.length+(it.length===1?' propuesta pendiente.':' propuestas pendientes.'):'No hay propuestas pendientes.';$('tP').textContent='Propuestas'+(it.length?' ('+it.length+')':'');it.forEach(function(p){box.appendChild(propCard(p))})}).catch(function(e){$('pmsg').textContent='No se pudo: '+e.message})}
function propCard(p){var b=p.b||{},q=new URLSearchParams(p.q||''),el=document.createElement('div');el.className='card';
 var K={'content':'Texto de la web','content-del':'Volver al texto original','post':'Artículo de Novedades','post-del':'Eliminar artículo'}[p.kind]||p.kind;
 var t=document.createElement('div');t.className='t';t.textContent=K;var pl=document.createElement('span');pl.className='pill';pl.textContent=when(p.id);t.appendChild(pl);el.appendChild(t);
 function line(l,v){if(!v)return;var d=document.createElement('div');d.className='m';d.style.marginTop='6px';d.style.whiteSpace='pre-wrap';var bb=document.createElement('b');bb.style.color='var(--ink)';bb.textContent=l+': ';d.appendChild(bb);d.appendChild(document.createTextNode(String(v).slice(0,700)));el.appendChild(d)}
 line('De',p.by);if(p.kind==='content'){line('Clave',b.k);line('Original',b.orig);line('Español',b.es);line('Inglés',b.en)}
 else if(p.kind==='content-del')line('Clave',q.get('k'));
 else if(p.kind==='post'){line('Título',b.title_es);line('Texto',b.body_es);line('Título (EN)',b.title_en);line('Texto (EN)',b.body_en);line('Por',b.by);line('Fecha',b.date);if(b.img)line('Imagen',b.img==='remove'?'quitar':'incluye una imagen')}
 else if(p.kind==='post-del')line('Artículo',q.get('id'));
 var row=document.createElement('div');row.className='row';el.appendChild(row);
 function btn(tx,c,act){var x=document.createElement('button');x.textContent=tx;if(c)x.className=c;x.onclick=function(){x.disabled=true;call('/admin/proposals/decide?id='+encodeURIComponent(p.id)+'&do='+act,'POST',{}).then(loadProps).catch(function(e){x.disabled=false;$('pmsg').textContent=act==='approve'&&e.message==='html'?'No se puede aprobar: contiene HTML no permitido. Recházala.':'No se pudo: '+e.message})};row.appendChild(x)}
 btn('Aprobar y publicar','','approve');btn('Rechazar','d','reject');return el}

var LEGACY=[{"id": "legacy-secciones", "date": "2026-10-20", "title_es": "Nuevas secciones en el sitio", "body_es": "Ahora puedes leer [cómo usar Plata](como-usar.html), nuestra página de [transparencia](transparencia.html), el [kit de prensa](prensa.html) y la sección de [ayuda](ayuda.html).", "title_en": "New sections on the site", "body_en": "You can now read [how to use Plata](como-usar.html), our [transparency](transparencia.html) page, the [press kit](prensa.html) and the [help](ayuda.html) section.", "by": "el equipo de Plata", "by_en": "the Plata team", "vf": true, "tag": "Sitio", "tag_en": "Site"}, {"id": "legacy-primera-beta", "date": "2026-10-20", "title_es": "¡La primera beta de Plata ya está para probar!", "body_es": "Llevan varios días desde que empecé a subir las versiones y he estado compartiendo con amigos y todo pero finalmente puedo decir que la beta es pública realmente ya que también tenemos dominio!\n\nLa verdad es que es el primer paso público que diría que tenemos así que no podría estar más feliz de compartir eso por aquí y acá con ustedes :)\n\nSi habrán errores, pero cualquier cosa estaré respondiendo en [devs@plataapp.net](mailto:devs@plataapp.net) lo que encuentres y espero poder subir en unos días el form para testers.\n\nnos vimos.", "title_en": "", "body_en": "", "by": "Leonardo Richarte", "by_en": "", "vf": true, "tag": "Beta 1, Lanzamiento", "tag_en": ""}];
function legacyBox(){var have={};posts.forEach(function(x){have[x.id]=1});var miss=LEGACY.filter(function(x){return !have[x.id]});var b=$('legacy');b.hidden=!miss.length||ROLE!=='dev';if(miss.length)$('legacyn').textContent=miss.length}
$('legacyb').onclick=function(){var miss=LEGACY.filter(function(x){return !posts.some(function(y){return y.id===x.id})}),i=0,b=this;b.disabled=true;
 (function next(){if(i>=miss.length){b.disabled=false;$('msg2').textContent='Listo: los artículos existentes ya se pueden editar aquí.';loadPosts();return}
  call('/posts','POST',miss[i++]).then(next).catch(function(e){b.disabled=false;$('msg2').textContent='No se pudo importar: '+e.message})})()};
(function(){var q=(location.search.match(/[?&]lang=(es|en)/)||[])[1],es=q?q==='es':/^es/i.test(navigator.language||'es');
if(!es){$('sub').textContent='Private tools for the Plata team.';$('tok').placeholder='Your admin token';$('go').textContent='Enter'}
$('scb').textContent=es?'ACCESO RESTRINGIDO':'RESTRICTED ACCESS';
var SW=new URLSearchParams(location.search).get('s');if(SW)msg(SW==='out'?'Sesión cerrada.':SW==='idle'?'La sesión se cerró por inactividad. Entra de nuevo.':'La sesión venció (dura 1 hora). Entra de nuevo.');
$('sct').textContent=es?'¿Qué fue mano?':'What’s up, bro?';
var P=es?['Esta es la puertaza gigante que dice en rojo <b>ACCESO RESTRINGIDO</b>.','Aquí guardamos todos nuestros más oscuros pensamientos, cables sueltos, un par de cositas, ideas que todavía no salen y nuestros sueños más bonitos. También, cafés que se enfriaron y un par de cosas que ni recordamos.','Si no eres del equipo, ¿cómo carajo llegaste aquí? ¿Encontraste esta dirección y entraste a ver qué pasaba? Pues pasó esto: <b>nada</b>. No hay botón oculto, ni descuentos, nada.','Ni intentes probar contraseñas: el token es tan largo que lo tenemos guardado en un rollo de papel higiénico. (Lo chévere es que no puedes verificar si eso es real o no).','Safa nomás, ve a registrar esos movimientos a Plata.']:['This is the giant door that says <b>RESTRICTED ACCESS</b> in red.','This is where we keep all our darkest thoughts, loose cables, a couple of little things, ideas that haven’t come out yet and our most beautiful dreams. Also, cold coffees and a couple of things we don’t even remember.','If you’re not on the team, how the heck did you get here? Did you find this address and come in to see what would happen? This is what happened: <b>nothing</b>. No hidden button, no discounts, nothing.','Don’t even try guessing passwords: the token is so long we keep it written on a roll of toilet paper. (The cool part is you can’t check whether that’s true or not.)','Just go away and log those transactions in Plata.'];
$('scp').innerHTML=P.map(function(t,i){return '<p'+(i===P.length-1?' class="last"':'')+'>'+t+'</p>'}).join('');
$('fn').textContent=es?'Y si sí eres del equipo y no puedes entrar, avisa a Leo nomás. No dejaremos ni correo porque, ¿para qué? Esa huevada es demasiado performativa.':'And if you’re on the team and can’t get in, just tell Leo. We won’t leave an email either because, why? That stuff is way too performative.';
$('sca').textContent=es?'Volver a Plata →':'Back to Plata →'})();
