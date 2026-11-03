// CloudFront viewer-request function (JavaScript runtime 2.0).
//
// Serves the single-page app's shell for client-side routes only:
//   /orders/42              -> /index.html   (no file extension: a route)
//   /assets/app.4f2a9c.js   -> unchanged     (a file: a missing one is a real 404)
//   /assets/anything        -> unchanged     (nothing under /assets/ is ever rewritten)
//   /favicon.ico            -> unchanged
//
// The same rule the app's own nginx config states: a missing chunk must 404,
// never fall back to HTML.
function handler(event) {
  var request = event.request;
  var uri = request.uri;

  if (uri.indexOf('/assets/') === 0) {
    return request;
  }

  var lastSegment = uri.substring(uri.lastIndexOf('/') + 1);
  if (lastSegment.indexOf('.') === -1) {
    request.uri = '/index.html';
  }

  return request;
}
