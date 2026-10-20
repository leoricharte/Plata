(function(){
var MODAL='<div class="ov" id="ov" hidden role="dialog" aria-modal="true" aria-labelledby="ovt"><div class="sheet"><h2 id="ovt" data-es="Instálala desde dentro" data-en="Install it from inside">Instálala desde dentro</h2><p data-es="Plata es una web app. Primero toca «Abrir Plata»; ya dentro de la app, agrégala a tu pantalla de inicio para que se abra como cualquier app." data-en="Plata is a web app. First tap “Open Plata”; once you&#x27;re inside the app, add it to your home screen so it opens like any other app.">Plata es una web app. Primero toca «Abrir Plata»; ya dentro de la app, agrégala a tu pantalla de inicio para que se abra como cualquier app.</p><ol><li data-es="Ya dentro de Plata, en Safari, toca el botón Compartir." data-en="Once inside Plata, in Safari, tap the Share button.">Ya dentro de Plata, en Safari, toca el botón Compartir.</li><li data-es="Elige «Agregar a pantalla de inicio»." data-en="Choose “Add to Home Screen”.">Elige «Agregar a pantalla de inicio».</li><li data-es="Toca «Agregar»." data-en="Tap “Add”.">Toca «Agregar».</li></ol><p class="dnote" data-es="Actualmente Plata se ve en modo móvil únicamente. Pronto traeremos una versión de escritorio." data-en="Plata currently works in mobile mode only. A desktop version is coming soon.">Actualmente Plata se ve en modo móvil únicamente. Pronto traeremos una versión de escritorio.</p><p class="alt" data-es="En Android (Chrome): menú ⋮ y luego «Instalar app»." data-en="On Android (Chrome): the ⋮ menu, then “Install app”.">En Android (Chrome): menú ⋮ y luego «Instalar app».</p><div class="row"><a class="btn" id="go" href="app/" data-es="Abrir Plata" data-en="Open Plata">Abrir Plata</a><button class="ghost" id="cl" type="button" data-es="Cancelar" data-en="Cancel">Cancelar</button></div></div></div>';
var wrap=document.createElement("div");wrap.innerHTML=MODAL;document.body.appendChild(wrap.firstChild);
var de=document.documentElement,L=null;try{L=localStorage.getItem("plata.lang")}catch(e){}
if(L!=="es"&&L!=="en"){var n=(navigator.languages&&navigator.languages[0])||navigator.language||"es";L=String(n).toLowerCase().indexOf("es")===0?"es":"en"}
function set(l){L=l;de.lang=l;var t=de.getAttribute("data-t-"+l);if(t)document.title=t;var d=de.getAttribute("data-d-"+l),m=document.querySelector('meta[name="description"]');if(m&&d)m.setAttribute("content",d);
Array.prototype.forEach.call(document.querySelectorAll("[data-es]"),function(e){var v=e.getAttribute("data-"+l);if(v!==null)e.innerHTML=v});
Array.prototype.forEach.call(document.querySelectorAll("img[data-src-es]"),function(e){e.src=e.getAttribute("data-src-"+l)});
var b=document.getElementById("lg");if(b)b.textContent=l==="es"?"EN":"ES"}
set(L);
document.getElementById("lg").addEventListener("click",function(){var n=L==="es"?"en":"es";try{localStorage.setItem("plata.lang",n)}catch(e){}set(n)});
var ov=document.getElementById("ov"),last=null;
function open(){last=document.activeElement;ov.hidden=false;document.getElementById("go").focus()}
function close(){ov.hidden=true;if(last&&last.focus)last.focus()}
Array.prototype.forEach.call(document.querySelectorAll("a[data-try]"),function(a){if(a.id==="go")return;a.addEventListener("click",function(e){e.preventDefault();open()})});
document.getElementById("cl").addEventListener("click",close);
ov.addEventListener("click",function(e){if(e.target===ov)close()});
document.addEventListener("keydown",function(e){if(e.key==="Escape"&&!ov.hidden)close()});
Array.prototype.forEach.call(document.querySelectorAll("[data-copy]"),function(b){b.addEventListener("click",function(){var el=document.getElementById(b.getAttribute("data-copy"));if(!el)return;var txt=el.textContent.trim(),done=function(){var o=b.innerHTML;b.textContent=L==="es"?"¡Copiado!":"Copied!";setTimeout(function(){b.innerHTML=o},1400)};if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(txt).then(done,function(){});else done()})});
})();
