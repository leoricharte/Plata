(function(){
var MODAL='<div class="ov" id="ov" hidden role="dialog" aria-modal="true" aria-labelledby="ovt"><div class="sheet"><h2 id="ovt" data-es="Instálala en tu computadora" data-en="Install it on your computer">Instálala en tu computadora</h2><p data-es="Plata es una web app: ábrela en tu navegador y crea un acceso directo para abrirla como cualquier otra app." data-en="Plata is a web app: open it in your browser and create a shortcut to launch it like any other app.">Plata es una web app: ábrela en tu navegador y crea un acceso directo para abrirla como cualquier otra app.</p><ol><li data-es="<b>Edge:</b> menú ⋯ › Aplicaciones › «Instalar este sitio como una aplicación»." data-en="<b>Edge:</b> ⋯ menu › Apps › “Install this site as an app”."><b>Edge:</b> menú ⋯ › Aplicaciones › «Instalar este sitio como una aplicación».</li><li data-es="<b>Chrome:</b> menú ⋮ › Transmitir, guardar y compartir › «Instalar página como aplicación»." data-en="<b>Chrome:</b> ⋮ menu › Cast, save and share › “Install page as app”."><b>Chrome:</b> menú ⋮ › Transmitir, guardar y compartir › «Instalar página como aplicación».</li><li data-es="<b>Safari (Mac):</b> menú Archivo › «Añadir al Dock»." data-en="<b>Safari (Mac):</b> File menu › “Add to Dock”."><b>Safari (Mac):</b> menú Archivo › «Añadir al Dock».</li></ol><div class="row"><a class="btn" id="go" href="app/" data-es="Abrir Plata" data-en="Open Plata">Abrir Plata</a><button class="ghost" id="cl" type="button" data-es="Cancelar" data-en="Cancel">Cancelar</button></div></div></div>';
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
Array.prototype.forEach.call(document.querySelectorAll("a[data-try]"),function(a){if(a.id==="go")return;a.addEventListener("click",function(e){if(!(window.matchMedia&&matchMedia("(min-width:900px) and (hover:hover) and (pointer:fine)").matches))return;e.preventDefault();open()})});
document.getElementById("cl").addEventListener("click",close);
ov.addEventListener("click",function(e){if(e.target===ov)close()});
document.addEventListener("keydown",function(e){if(e.key==="Escape"&&!ov.hidden)close()});
Array.prototype.forEach.call(document.querySelectorAll("[data-copy]"),function(b){b.addEventListener("click",function(){var el=document.getElementById(b.getAttribute("data-copy"));if(!el)return;var txt=el.textContent.trim(),done=function(){var o=b.innerHTML;b.textContent=L==="es"?"¡Copiado!":"Copied!";setTimeout(function(){b.innerHTML=o},1400)};if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(txt).then(done,function(){});else done()})});
})();
