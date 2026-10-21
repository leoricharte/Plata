(function(){
var URL="https://forms.gle/FAt51YAz6k7JPQcC7",de=document.documentElement;
function L(){return de.lang==="en"?"en":"es"}
var T={es:{h:"¿Nos cuentas cómo te va con Plata?",p:"Tu opinión nos ayuda a mejorarla. Son unos 3 minutos.",n:"Al continuar, aceptas que la información que envíes en el formulario sí se recopila y autorizas a Estudio 2² y a Plata a usarla para mejorar la app.",go:"Continuar al formulario",x:"Cerrar"},
en:{h:"How is Plata working out for you?",p:"Your feedback helps us improve it. It takes about 3 minutes.",n:"By continuing, you agree that the information you submit in the form is collected, and you authorize Estudio 2² and Plata to use it to improve the app.",go:"Continue to the form",x:"Close"}};
var css=".fbov .sheet{text-align:center}.fbov .fbi{width:52px;height:52px;border-radius:16px;background:var(--soft);color:var(--accent);display:grid;place-items:center;margin:0 auto 14px}.fbov .fbn{font-size:12.5px;line-height:1.4;color:var(--mute);margin:0 4px 18px}.fbov .btn{margin-bottom:4px}";
var st=document.createElement("style");st.textContent=css;document.head.appendChild(st);
var ov=null,prev=null;
function close(){if(!ov)return;ov.hidden=true;document.removeEventListener("keydown",key);if(prev&&prev.focus)prev.focus()}
function key(e){if(e.key==="Escape")close()}
function build(){var t=T[L()];
ov=document.createElement("div");ov.className="ov fbov";ov.hidden=true;ov.setAttribute("role","dialog");ov.setAttribute("aria-modal","true");
ov.innerHTML='<div class="sheet"><div class="fbi"><svg width="26" height="26" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12.0006 18.26L4.94715 22.2082L6.52248 14.2799L0.587891 8.7918L8.61493 7.84006L12.0006 0.5L15.3862 7.84006L23.4132 8.7918L17.4787 14.2799L19.054 22.2082L12.0006 18.26ZM12.0006 15.968L16.2473 18.3451L15.2988 13.5717L18.8719 10.2674L14.039 9.69434L12.0006 5.27502L9.96214 9.69434L5.12921 10.2674L8.70231 13.5717L7.75383 18.3451L12.0006 15.968Z"/></svg></div><h2></h2><p></p><div class="fbn"></div><div class="row"><a class="btn" target="_blank" rel="noopener"></a><button type="button" class="ghost"></button></div></div>';
document.body.appendChild(ov);
ov.addEventListener("click",function(e){if(e.target===ov)close()});
ov.querySelector(".ghost").addEventListener("click",close);
ov.querySelector(".btn").addEventListener("click",function(){setTimeout(close,150)});}
function fill(){var t=T[L()];ov.querySelector("h2").textContent=t.h;ov.querySelector("p").textContent=t.p;ov.querySelector(".fbn").textContent=t.n;var b=ov.querySelector(".btn");b.textContent=t.go;b.href=URL;ov.querySelector(".ghost").textContent=t.x}
function open(e){if(e)e.preventDefault();if(!ov)build();fill();prev=document.activeElement;ov.hidden=false;document.addEventListener("keydown",key);setTimeout(function(){ov.querySelector(".btn").focus()},30)}
document.addEventListener("click",function(e){var a=e.target.closest&&e.target.closest("[data-feedback]");if(a)open(e)});
new MutationObserver(function(){if(ov)fill()}).observe(de,{attributes:true,attributeFilter:["lang"]});
})();
