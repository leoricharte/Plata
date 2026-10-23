/* Editor de textos oculto de plataapp.net. Entrada: 5 toques seguidos en el pie de página, o añadir #editar a la URL. Pide el token del equipo. */
(function(){
var API='https://plata-cloud.xleoricharte.workers.dev',doc=document,de=doc.documentElement,tok='',editing=false,items={};
function $(s,r){return (r||doc).querySelector(s)}
function all(s){return Array.prototype.slice.call(doc.querySelectorAll(s))}
function hash(s){var h=2166136261;for(var i=0;i<s.length;i++){h^=s.charCodeAt(i);h=Math.imul(h,16777619)}return ('00000000'+(h>>>0).toString(16)).slice(-8)}
function lang(){return de.lang==='en'?'en':'es'}
function api(p,m,b){return fetch(API+p,{method:m||'GET',headers:Object.assign(tok?{Authorization:'Bearer '+tok}:{},b?{'Content-Type':'application/json'}:{}),body:b?JSON.stringify(b):undefined}).then(function(r){return r.json().catch(function(){return{}}).then(function(j){if(!r.ok||j.ok===false){var e=new Error(j.error||r.status);e.code=r.status;throw e}return j})})}
/* HTML permitido en los textos: solo formato básico y enlaces seguros */
var OK={EM:1,B:1,STRONG:1,I:1,BR:1,A:1,SPAN:0};
function clean(h){var d=new DOMParser().parseFromString('<body>'+h+'</body>','text/html').body;(function walk(n){Array.prototype.slice.call(n.childNodes).forEach(function(c){
 if(c.nodeType===3)return;if(c.nodeType!==1){n.removeChild(c);return}
 if(!OK[c.tagName]){walk(c);while(c.firstChild)n.insertBefore(c.firstChild,c);n.removeChild(c);return}
 Array.prototype.slice.call(c.attributes).forEach(function(a){var keep=c.tagName==='A'&&a.name==='href'&&/^(https?:|mailto:|[\w#\/.?=&-]+$)/i.test(a.value.trim());if(!keep)c.removeAttribute(a.name)});
 if(c.tagName==='A'){c.setAttribute('rel','noopener')}walk(c)})})(d);return d.innerHTML}
/* originales y cambios guardados */
function mark(){all('[data-es]').forEach(function(e){if(!e.hasAttribute('data-o'))e.setAttribute('data-o',e.getAttribute('data-es'))})}
function apply(){mark();all('[data-o]').forEach(function(e){var k=hash(e.getAttribute('data-o')),it=items[k];if(!it)return;e.setAttribute('data-es',it.es);e.setAttribute('data-en',it.en);var v=e.getAttribute('data-'+lang());if(v!==null)e.innerHTML=v})}
function load(){mark();return fetch(API+'/content').then(function(r){return r.json()}).then(function(j){items=j.items||{};apply()}).catch(function(){})}
/* interfaz */
var css=doc.createElement('style');css.textContent=':root{--pe-bg:#fff;--pe-ink:#1C1C1E;--pe-mute:#8E8E93;--pe-fill:#F2F2F7;--pe-line:rgba(60,60,67,.14);--pe-g:#22B573}@media(prefers-color-scheme:dark){:root:not([data-theme=light]){--pe-bg:#1C1C1E;--pe-ink:#F2F2F7;--pe-fill:#2C2C2E;--pe-line:rgba(255,255,255,.12)}}'
+'.pe-bar{position:fixed;left:50%;bottom:calc(16px + env(safe-area-inset-bottom));transform:translateX(-50%);z-index:99999;display:flex;gap:6px;align-items:center;background:var(--pe-bg);color:var(--pe-ink);border:1px solid var(--pe-line);border-radius:999px;padding:6px 6px 6px 16px;font:600 14px/1 Inter,-apple-system,system-ui,sans-serif;box-shadow:0 8px 30px rgba(0,0,0,.18);-webkit-backdrop-filter:blur(20px);backdrop-filter:blur(20px)}.pe-bar button{font:600 14px/1 Inter,-apple-system,system-ui,sans-serif;background:var(--pe-g);color:#fff;border:0;border-radius:999px;padding:10px 16px;cursor:pointer}.pe-bar button.g{background:var(--pe-fill);color:var(--pe-ink)}'
+'.pe-pen{position:absolute;z-index:99998;width:28px;height:28px;border-radius:50%;background:var(--pe-bg);border:1px solid var(--pe-line);box-shadow:0 4px 14px rgba(0,0,0,.14);cursor:pointer;display:flex;align-items:center;justify-content:center;padding:0}.pe-pen svg{width:15px;height:15px;fill:var(--pe-g)}.pe-ed [data-o]{outline:1.5px dashed rgba(34,181,115,.55);outline-offset:3px;border-radius:6px}'
+'.pe-ov{position:fixed;inset:0;z-index:100000;background:rgba(0,0,0,.38);-webkit-backdrop-filter:blur(8px);backdrop-filter:blur(8px);display:flex;align-items:flex-end;justify-content:center;font-family:Inter,-apple-system,system-ui,sans-serif}@media(min-width:700px){.pe-ov{align-items:center;padding:16px}}'
+'.pe-box{background:var(--pe-bg);color:var(--pe-ink);border-radius:28px 28px 0 0;padding:10px 20px calc(20px + env(safe-area-inset-bottom));width:100%;max-width:520px;max-height:92vh;overflow:auto;box-shadow:0 20px 60px rgba(0,0,0,.3)}@media(min-width:700px){.pe-box{border-radius:28px}}.pe-box:before{content:"";display:block;width:36px;height:5px;border-radius:3px;background:var(--pe-line);margin:0 auto 14px}'
+'.pe-box h3{margin:0 0 4px;font-size:22px;font-weight:800;letter-spacing:-.02em}.pe-sub{font-size:14px;color:var(--pe-mute);margin:0 0 14px;line-height:1.4}'
+'.pe-seg{display:flex;background:var(--pe-fill);border-radius:12px;padding:3px;margin:0 0 12px}.pe-seg button{flex:1;border:0;background:transparent;color:var(--pe-mute);font:600 14px/1 Inter,-apple-system,system-ui,sans-serif;padding:9px;border-radius:9px;cursor:pointer}.pe-seg button.on{background:var(--pe-bg);color:var(--pe-ink);box-shadow:0 1px 4px rgba(0,0,0,.12)}'
+'.pe-box input,.pe-box textarea{width:100%;box-sizing:border-box;border:0;border-radius:14px;padding:14px;font:16px/1.45 Inter,-apple-system,system-ui,sans-serif;background:var(--pe-fill);color:var(--pe-ink);outline:0}.pe-box textarea{min-height:120px;resize:vertical}.pe-box input:focus,.pe-box textarea:focus{box-shadow:0 0 0 2px var(--pe-g)}'
+'.pe-row{display:flex;flex-direction:column;gap:8px;margin-top:16px}.pe-row button{font:600 16px/1 Inter,-apple-system,system-ui,sans-serif;border-radius:14px;border:0;background:var(--pe-fill);color:var(--pe-ink);padding:16px;cursor:pointer}.pe-row button.p{background:var(--pe-g);color:#fff}.pe-row button.d{color:#FF3B30}.pe-m{font-size:13px;color:var(--pe-mute);margin-top:10px;min-height:16px;text-align:center}';
doc.head.appendChild(css);
var PEN='<svg viewBox="0 0 24 24"><path d="M15.7 3.3l5 5L8.6 20.4 3 21l.6-5.6L15.7 3.3zm0 2.8L5.5 16.3l-.3 2.5 2.5-.3L17.9 8.3l-2.2-2.2z"/></svg>';
function modal(html){var o=doc.createElement('div');o.className='pe-ov';o.innerHTML='<div class="pe-box">'+html+'</div>';doc.body.appendChild(o);o.addEventListener('mousedown',function(e){if(e.target===o)o.remove()});return o}
function esc(s){return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/"/g,'&quot;')}
function login(){var o=modal('<h3>Editor de textos</h3><p class="pe-sub">Solo para el equipo de Plata.</p><input type="password" id="pe-t" placeholder="Token de administrador" autocomplete="off"><div class="pe-row"><button class="p" id="pe-go">Entrar</button><button id="pe-x">Cancelar</button></div><div class="pe-m" id="pe-mm"></div>');
 var t=$('#pe-t',o);t.focus();function go(){tok=t.value.trim();$('#pe-mm',o).textContent='Comprobando…';api('/content/ping').then(function(){o.remove();start()}).catch(function(e){tok='';$('#pe-mm',o).textContent=e.code===401?'Token incorrecto.':'No se pudo comprobar.'})}
 $('#pe-go',o).onclick=go;t.addEventListener('keydown',function(e){if(e.key==='Enter')go()});$('#pe-x',o).onclick=function(){o.remove()}}
var pens=[];
function place(){mark();pens.forEach(function(p){p.el.remove()});pens=[];if(!editing)return;
 all('[data-o]').forEach(function(e){var r=e.getBoundingClientRect();if(!r.width||!r.height)return;var cs=getComputedStyle(e);if(cs.visibility==='hidden'||cs.display==='none')return;
  var b=doc.createElement('button');b.type='button';b.className='pe-pen';b.setAttribute('aria-label','Editar texto');b.innerHTML=PEN;b.style.left=(window.scrollX+r.right-12)+'px';b.style.top=(window.scrollY+r.top-12)+'px';
  b.addEventListener('click',function(ev){ev.preventDefault();ev.stopPropagation();edit(e)});doc.body.appendChild(b);pens.push({el:b})})}
function edit(e){var k=hash(e.getAttribute('data-o')),es=e.getAttribute('data-es'),en=e.getAttribute('data-en')||'';
 var o=modal('<h3>Editar texto</h3><p class="pe-sub">Puedes usar &lt;em&gt;, &lt;b&gt;, &lt;br&gt; y enlaces. Lo demás se limpia.</p><div class="pe-seg"><button type="button" id="pe-ses" class="on">Español</button><button type="button" id="pe-sen">English</button></div><textarea id="pe-es">'+esc(es)+'</textarea><textarea id="pe-en" hidden>'+esc(en)+'</textarea><div class="pe-row"><button class="p" id="pe-s">Guardar</button>'+(items[k]?'<button class="d" id="pe-r">Restaurar original</button>':'')+'<button id="pe-c">Cancelar</button></div><div class="pe-m" id="pe-mm"></div>');
 function sg(l){$('#pe-es',o).hidden=l!=='es';$('#pe-en',o).hidden=l!=='en';$('#pe-ses',o).classList.toggle('on',l==='es');$('#pe-sen',o).classList.toggle('on',l==='en');$('#pe-'+l,o).focus()}
 $('#pe-ses',o).onclick=function(){sg('es')};$('#pe-sen',o).onclick=function(){sg('en')};sg(lang());
 $('#pe-c',o).onclick=function(){o.remove()};
 $('#pe-s',o).onclick=function(){var a=clean($('#pe-es',o).value),b=clean($('#pe-en',o).value);if(!a.trim()){$('#pe-mm',o).textContent='El texto en español no puede quedar vacío.';return}
  $('#pe-mm',o).textContent='Guardando…';api('/content','POST',{k:k,orig:e.getAttribute('data-o').slice(0,160),es:a,en:b||a}).then(function(){items[k]={es:a,en:b||a};apply();o.remove();place()}).catch(function(x){$('#pe-mm',o).textContent=x.code===401?'La sesión no es válida.':'No se pudo guardar.'})};
 var r=$('#pe-r',o);if(r)r.onclick=function(){if(!confirm('¿Volver al texto original de esta frase?'))return;api('/content?k='+k,'DELETE').then(function(){delete items[k];e.setAttribute('data-es',e.getAttribute('data-o'));var ev=new CustomEvent('x');location.reload()}).catch(function(){$('#pe-mm',o).textContent='No se pudo restaurar.'})}}
function start(){editing=true;de.classList.add('pe-ed');var bar=doc.createElement('div');bar.className='pe-bar';bar.innerHTML='<span>Modo edición</span><button class="g" id="pe-lg">Idioma</button><button id="pe-end">Salir</button>';doc.body.appendChild(bar);
 $('#pe-end',bar).onclick=function(){editing=false;de.classList.remove('pe-ed');bar.remove();place()};
 $('#pe-lg',bar).onclick=function(){var b=$('#lg');if(b)b.click();setTimeout(place,80)};
 place();window.addEventListener('resize',place);setInterval(function(){if(editing)place()},1500)}
function entry(){if(editing||$('.pe-ov'))return;tok?start():login()}
/* entrada oculta: 5 toques seguidos en el pie, o #editar */
var taps=0,tt=0;doc.addEventListener('click',function(e){var f=e.target.closest&&e.target.closest('footer');if(!f||e.target.closest('a,button'))return;var n=Date.now();taps=n-tt<1500?taps+1:1;tt=n;if(taps>=5){taps=0;entry()}});
if(location.hash==='#editar'&&!(window.self!==window.top))setTimeout(entry,300);
var emb=false;try{emb=window.self!==window.top&&location.hash==='#editar'&&sessionStorage.getItem('pe.t')}catch(e){}
if(emb){tok=emb;load().then(function(){api('/content/ping').then(function(){start();var b=$('.pe-bar');if(b)b.style.display='none'}).catch(function(){})})}else load()})();
