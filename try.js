(function(){
var de=document.documentElement,TRIES=Array.prototype.slice.call(document.querySelectorAll(".try"));if(!TRIES.length)return;
function lang(){return de.lang==="en"?"en":"es"}
TRIES.forEach(function(el){
var mode=el.getAttribute("data-mode"),fr=el.querySelector("iframe"),wrap=el.querySelector(".pw"),items=el.querySelectorAll(".tk li"),pill=el.querySelector(".ok"),end=el.querySelector(".end"),loaded=false,cur=0,tm=null;
function fit(){var w=wrap.clientWidth,s=Math.min(1,w/402);fr.style.transform="scale("+s+")";wrap.style.height=Math.round(874*s)+"px"}
function reset(){cur=0;Array.prototype.forEach.call(items,function(li,i){li.classList.remove("done");li.classList.toggle("now",i===0)});end.hidden=true;pill.classList.remove("show")}
function load(){reset();fr.src="demo/app.html?preview&nosplash&today=2026-10-20&r="+Date.now()+"#mode="+mode+"&l="+lang();loaded=true}
window.addEventListener("message",function(e){var d=e.data;if(!d||d.type!=="plata-demo"||e.source!==fr.contentWindow)return;
if(d.blocked){el.classList.remove("nudge");void el.offsetWidth;el.classList.add("nudge");return}
if(typeof d.step==="number"){var i=d.step;if(items[i]){items[i].classList.add("done");items[i].classList.remove("now")}if(items[i+1])items[i+1].classList.add("now");
pill.classList.remove("show");void pill.offsetWidth;pill.classList.add("show");clearTimeout(tm);tm=setTimeout(function(){pill.classList.remove("show")},1700);
if(d.done)end.hidden=false}});
el.querySelector(".again").addEventListener("click",load);
fit();window.addEventListener("resize",fit);
if("IntersectionObserver" in window){new IntersectionObserver(function(en,ob){en.forEach(function(x){if(x.isIntersecting&&!loaded){load();ob.disconnect()}})},{rootMargin:"300px"}).observe(el)}else load();
new MutationObserver(function(){if(loaded)load()}).observe(de,{attributes:true,attributeFilter:["lang"]});
});
})();
