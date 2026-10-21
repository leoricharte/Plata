(function(){
var URL="https://forms.gle/FAt51YAz6k7JPQcC7",de=document.documentElement;
function L(){return de.lang==="en"?"en":"es"}
var T={es:{h:"¿Nos cuentas cómo te va con Plata?",p:"Tu opinión nos ayuda a mejorarla. Son unos 3 minutos.",n:"Al continuar, aceptas que la información que envíes en el formulario sí se recopila y autorizas a Estudio 2² y a Plata a usarla para mejorar la app.",gf:"Este botón lleva a Google Forms",go:"Continuar al formulario",x:"Cerrar"},
en:{h:"How is Plata working out for you?",p:"Your feedback helps us improve it. It takes about 3 minutes.",n:"By continuing, you agree that the information you submit in the form is collected, and you authorize Estudio 2² and Plata to use it to improve the app.",gf:"This button takes you to Google Forms",go:"Continue to the form",x:"Close"}};
var css=".fbov .sheet{text-align:center}.fbov .fbi{width:52px;height:52px;border-radius:16px;background:var(--soft);color:var(--accent);display:grid;place-items:center;margin:0 auto 14px}.fbov .fbn{text-wrap:balance;font-size:13px;line-height:1.45;color:var(--mute);margin:0 0 16px;padding:12px 14px;border-radius:14px;background:var(--soft)}.fbov .btn{margin-bottom:4px}.fbov .fbg{display:flex;align-items:center;justify-content:center;gap:6px;font-size:13px;color:var(--mute);margin:2px 0 6px}";
var st=document.createElement("style");st.textContent=css;document.head.appendChild(st);
var ov=null,prev=null;
function close(){if(!ov)return;ov.hidden=true;document.removeEventListener("keydown",key);if(prev&&prev.focus)prev.focus()}
function key(e){if(e.key==="Escape")close()}
function build(){var t=T[L()];
ov=document.createElement("div");ov.className="ov fbov";ov.hidden=true;ov.setAttribute("role","dialog");ov.setAttribute("aria-modal","true");
ov.innerHTML='<div class="sheet"><div class="fbi"><svg width="26" height="26" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12.0006 18.26L4.94715 22.2082L6.52248 14.2799L0.587891 8.7918L8.61493 7.84006L12.0006 0.5L15.3862 7.84006L23.4132 8.7918L17.4787 14.2799L19.054 22.2082L12.0006 18.26ZM12.0006 15.968L16.2473 18.3451L15.2988 13.5717L18.8719 10.2674L14.039 9.69434L12.0006 5.27502L9.96214 9.69434L5.12921 10.2674L8.70231 13.5717L7.75383 18.3451L12.0006 15.968Z"/></svg></div><h2></h2><p></p><div class="fbn"></div><div class="row"><a class="btn" target="_blank" rel="noopener"></a><div class="fbg"><svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M3.06364 7.50914C4.70909 4.24092 8.09084 2 12 2C14.6954 2 16.959 2.99095 18.6909 4.60455L15.8227 7.47274C14.7864 6.48185 13.4681 5.97727 12 5.97727C9.39542 5.97727 7.19084 7.73637 6.40455 10.1C6.2045 10.7 6.09086 11.3409 6.09086 12C6.09086 12.6591 6.2045 13.3 6.40455 13.9C7.19084 16.2636 9.39542 18.0227 12 18.0227C13.3454 18.0227 14.4909 17.6682 15.3864 17.0682C16.4454 16.3591 17.15 15.3 17.3818 14.05H12V10.1818H21.4181C21.5364 10.8363 21.6 11.5182 21.6 12.2273C21.6 15.2727 20.5091 17.8363 18.6181 19.5773C16.9636 21.1046 14.7 22 12 22C8.09084 22 4.70909 19.7591 3.06364 16.4909C2.38638 15.1409 2 13.6136 2 12C2 10.3864 2.38638 8.85911 3.06364 7.50914Z"/></svg><span></span></div><button type="button" class="ghost"></button></div></div>';
document.body.appendChild(ov);
ov.addEventListener("click",function(e){if(e.target===ov)close()});
ov.querySelector(".ghost").addEventListener("click",close);
ov.querySelector(".btn").addEventListener("click",function(){setTimeout(close,150)});}
function fill(){var t=T[L()];ov.querySelector("h2").textContent=t.h;ov.querySelector("p").textContent=t.p;ov.querySelector(".fbn").textContent=t.n;var b=ov.querySelector(".btn");b.textContent=t.go;b.href=URL;ov.querySelector(".fbg span").textContent=t.gf;ov.querySelector(".ghost").textContent=t.x}
function open(e){if(e)e.preventDefault();if(!ov)build();fill();prev=document.activeElement;ov.hidden=false;document.addEventListener("keydown",key);setTimeout(function(){ov.querySelector(".btn").focus()},30)}
document.addEventListener("click",function(e){var a=e.target.closest&&e.target.closest("[data-feedback]");if(a)open(e)});
new MutationObserver(function(){if(ov)fill()}).observe(de,{attributes:true,attributeFilter:["lang"]});
})();
