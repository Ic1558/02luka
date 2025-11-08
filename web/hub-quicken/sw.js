self.addEventListener('install', e=>{
  e.waitUntil(caches.open('hub-qk-v1').then(c=>c.addAll(['./','index.html','style.css','app.js'])));
});
self.addEventListener('fetch', e=>{
  const u = new URL(e.request.url);
  if(u.pathname.endsWith('.json')){
    // network first, fallback cache
    e.respondWith(fetch(e.request).then(r=>{
      const rr = r.clone(); caches.open('hub-qk-v1').then(c=>c.put(e.request, rr)); return r;
    }).catch(()=>caches.match(e.request)));
  }
});
