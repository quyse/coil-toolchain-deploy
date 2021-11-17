addEventListener('fetch', (event) => {
  return event.respondWith(handleRequest(event.request))
});

const handleRequest = async (request) => {
  if(request.method != 'HEAD' && request.method != 'GET') {
    return new Response(null, {
      status: 405
    });
  }

  const url = new URL(request.url);

  let file = manifest.files[url.pathname.substr(1)];
  if(file == null && manifest.defaultPath != null) {
    file = manifest.files[manifest.defaultPath];
  }
  if(file == null) {
    return new Response(null, {
      status: 404
    });
  }

  return await fetch(`${BASE_URL}${file.path}`);
};

// manifest will be appended by terraform module
