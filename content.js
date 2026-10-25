/* Textos editables de plataapp.net: solo los MUESTRA. El editor vive en el panel privado (dev), nunca en el sitio público,
 * para que el token de administrador no se escriba en este dominio. Cada texto se identifica por un hash de su versión original en español. */
(function(){
var API='https://plata-cloud.xleoricharte.workers.dev',doc=document,items={};
function all(s){return Array.prototype.slice.call(doc.querySelectorAll(s))}
function hash(s){var h=2166136261;for(var i=0;i<s.length;i++){h^=s.charCodeAt(i);h=Math.imul(h,16777619)}return ('00000000'+(h>>>0).toString(16)).slice(-8)}
function lang(){return doc.documentElement.lang==='en'?'en':'es'}
/* HTML permitido en los textos: solo formato básico y enlaces seguros. Se limpia SIEMPRE antes de mostrarlo, venga de donde venga. */
var OK={EM:1,B:1,STRONG:1,I:1,BR:1,A:1};
function clean(h){var d=new DOMParser().parseFromString('<body>'+String(h)+'</body>','text/html').body;(function walk(n){Array.prototype.slice.call(n.childNodes).forEach(function(c){
 if(c.nodeType===3)return;if(c.nodeType!==1){n.removeChild(c);return}
 if(!OK[c.tagName]){walk(c);while(c.firstChild)n.insertBefore(c.firstChild,c);n.removeChild(c);return}
 Array.prototype.slice.call(c.attributes).forEach(function(a){var keep=c.tagName==='A'&&a.name==='href'&&/^(https?:\/\/|mailto:|[\w#\/.?=&-]+$)/i.test(a.value.trim());if(!keep)c.removeAttribute(a.name)});
 if(c.tagName==='A'){c.setAttribute('rel','noopener')}walk(c)})})(d);return d.innerHTML}
function mark(){all('[data-es]').forEach(function(e){if(!e.hasAttribute('data-o'))e.setAttribute('data-o',e.getAttribute('data-es'))})}
function apply(){mark();all('[data-o]').forEach(function(e){var it=items[hash(e.getAttribute('data-o'))];if(!it)return;
 var es=clean(it.es),en=clean(it.en);e.setAttribute('data-es',es);e.setAttribute('data-en',en);e.innerHTML=lang()==='en'?en:es})}
mark();fetch(API+'/content').then(function(r){return r.json()}).then(function(j){items=(j&&j.items)||{};apply()}).catch(function(){});
})();
