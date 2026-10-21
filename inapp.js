(function(){
var ua=navigator.userAgent||"";
var named=/Instagram|FBAN|FBAV|FB_IAB|FBIOS|Messenger|TikTok|musical_ly|Bytedance|Snapchat|LinkedInApp|Pinterest|MicroMessenger|Line\/|GSA\/|KAKAOTALK|Threads/i.test(ua);
var android=/Android/i.test(ua),ios=/iPhone|iPad|iPod/i.test(ua);
var standalone=(window.navigator.standalone===true)||(window.matchMedia&&matchMedia("(display-mode: standalone)").matches);
var wv=(android&&/; wv\)/.test(ua))||(ios&&!/Safari\//.test(ua)&&!standalone);
if(standalone||(!named&&!wv))return;
try{if(sessionStorage.getItem("plata.inapp")==="1")return}catch(e){}
var es=/^es/i.test(navigator.language||"es");
try{var sl=localStorage.getItem("plata.lang");if(sl)es=sl==="es"}catch(e){}
var TS={es:{t:"Ábrela en tu navegador",b:"Aquí dentro Plata puede cerrarse y no guardar tus datos. Ábrela en "+(ios?"Safari":"Chrome")+(ios?": toca ••• o el ícono de compartir y elige «Abrir en Safari».":"."),o:"Abrir en Chrome",c:"Copiar enlace",k:"¡Copiado!",x:"Continuar de todos modos"},en:{t:"Open it in your browser",b:"In here, Plata can close and not save your data. Open it in "+(ios?"Safari":"Chrome")+(ios?": tap ••• or the share icon and choose “Open in Safari”.":"."),o:"Open in Chrome",c:"Copy link",k:"Copied!",x:"Continue anyway"}};
var T=es?TS.es:TS.en;
var url=location.href;
var css=document.createElement("style");
css.textContent=".iab{position:fixed;left:12px;right:12px;bottom:calc(12px + env(safe-area-inset-bottom,0px));z-index:2147483000;max-width:460px;margin:0 auto;background:#fff;color:#111;border:1px solid rgba(0,0,0,.12);border-radius:22px;padding:16px 16px 12px;box-shadow:0 12px 40px rgba(0,0,0,.28);font:500 14px/1.4 Inter,-apple-system,system-ui,sans-serif}@media (prefers-color-scheme:dark){.iab{background:#1b1f1d;color:#f3f3f3;border-color:rgba(255,255,255,.14)}}.iab b{display:block;font-size:16px;margin-bottom:4px}.iab p{margin:0 0 12px;opacity:.82}.iab .r{display:flex;flex-wrap:wrap;gap:8px}.iab button{font:600 14px/1 Inter,-apple-system,system-ui,sans-serif;border:0;border-radius:999px;padding:11px 16px;cursor:pointer;background:#22B573;color:#fff}.iab button.g{background:transparent!important;color:inherit;opacity:.7;padding:11px 8px;flex:1 0 100%;text-align:center;white-space:normal}.iab button{flex:1 1 auto}";
document.head.appendChild(css);
var d=document.createElement("div");d.className="iab";d.setAttribute("role","dialog");
d.innerHTML="<b></b><p></p><div class=r></div>";
d.firstChild.textContent=T.t;d.children[1].textContent=T.b;
var r=d.children[2];
function btn(txt,cls,fn){var x=document.createElement("button");x.type="button";x.textContent=txt;if(cls)x.className=cls;x.addEventListener("click",fn);r.appendChild(x);return x}
if(android)btn(T.o,"",function(){var u=url.replace(/^https?:\/\//,"");location.href="intent://"+u+"#Intent;scheme=https;package=com.android.chrome;end"});
var cp=btn(T.c,"",function(){
 function ok(){copied=true;cp.textContent=T.k}
 try{navigator.clipboard.writeText(url).then(ok,fb)}catch(e){fb()}
 function fb(){var a=document.createElement("textarea");a.value=url;a.style.position="fixed";a.style.opacity="0";document.body.appendChild(a);a.select();try{document.execCommand("copy");ok()}catch(e){}a.remove()}
});
btn(T.x,"g",function(){try{sessionStorage.setItem("plata.inapp","1")}catch(e){}d.remove()});
var bo=null,bc=null,bx=null,copied=false;
function ren(l){T=TS[l]||TS.es;d.firstChild.textContent=T.t;d.children[1].textContent=T.b;if(bo)bo.textContent=T.o;if(bc)bc.textContent=copied?T.k:T.c;if(bx)bx.textContent=T.x}
function show(){document.body.appendChild(d);var bs=r.querySelectorAll("button");bx=bs[bs.length-1];bc=bs[bs.length-2];bo=android?bs[0]:null;var hl=document.documentElement.lang;if(hl==="es"||hl==="en")ren(hl);try{new MutationObserver(function(){var l=document.documentElement.lang;if(l==="es"||l==="en")ren(l)}).observe(document.documentElement,{attributes:true,attributeFilter:["lang"]})}catch(e){}}
if(document.body)show();else document.addEventListener("DOMContentLoaded",show);
})();
