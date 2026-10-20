(function(){
var nav=document.querySelector(".nav");if(!nav)return;
var bg=nav.querySelector(".burger");
function closeAll(){Array.prototype.forEach.call(nav.querySelectorAll(".dd.open"),function(d){d.classList.remove("open");var t=d.querySelector(".mt");if(t)t.setAttribute("aria-expanded","false")})}
if(bg)bg.addEventListener("click",function(){var o=!nav.classList.contains("open");nav.classList.toggle("open",o);bg.setAttribute("aria-expanded",o?"true":"false")});
Array.prototype.forEach.call(nav.querySelectorAll(".dd .mt"),function(t){t.addEventListener("click",function(e){e.stopPropagation();var d=t.parentNode,o=!d.classList.contains("open");closeAll();d.classList.toggle("open",o);t.setAttribute("aria-expanded",o?"true":"false")})});
document.addEventListener("click",function(e){if(!nav.contains(e.target)){closeAll();nav.classList.remove("open");if(bg)bg.setAttribute("aria-expanded","false")}});
document.addEventListener("keydown",function(e){if(e.key==="Escape"){closeAll();nav.classList.remove("open");if(bg)bg.setAttribute("aria-expanded","false")}});
Array.prototype.forEach.call(nav.querySelectorAll(".sub a"),function(a){a.addEventListener("click",function(){closeAll();nav.classList.remove("open")})});
})();
