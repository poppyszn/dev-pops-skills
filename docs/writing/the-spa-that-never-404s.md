# The single-page app that never returns a 404

*A draft write-up of a bug that ships in a lot of S3 + CloudFront setups. The facts are checked against AWS documentation (dated in `skills/terraform/references/sources.md`).*

The standard advice for hosting a single-page app on CloudFront is to add two custom error responses: when the origin returns 403 or 404, answer with `/index.html` and a 200. It makes deep links like `/orders/42` work, because S3 has no file by that name and the app's router should take over.

It also quietly breaks your error handling in three ways.

**1. It is distribution-wide.** `CustomErrorResponses` belongs to the distribution, not to a cache behavior. You can't say "only for routes". Every 403 and 404 from the origin, for any path, becomes the app shell with a 200.

**2. So a missing asset looks like a working page.** Deploy a build, miss a file, or hit a stale cached HTML pointing at a chunk you just deleted, and the request for `/assets/app.4f2a9c.js` returns HTML. The browser fails on `Unexpected token '<'`. Monitoring sees only 200s. Nothing is down, and the site doesn't work.

**3. A broken bucket policy hides too.** S3 answers 404 for a missing key only if the caller has `s3:ListBucket`; without it, S3 answers 403 to avoid revealing which keys exist. Get the policy wrong and every request is a 403. With the catch-all rule, the whole site is "up", serving the shell, with every asset failing silently.

## The fix: route in a function, not in an error page

A CloudFront Function on the viewer-request event can make the decision before the origin is asked, using only the path:

```js
function handler(event) {
  var request = event.request;
  var uri = request.uri;

  if (uri.indexOf('/assets/') === 0) {
    return request;               // a missing asset must stay a 404
  }

  var lastSegment = uri.substring(uri.lastIndexOf('/') + 1);
  if (lastSegment.indexOf('.') === -1) {
    request.uri = '/index.html';  // no extension: a client-side route
  }

  return request;
}
```

Paths with no file extension become the app shell. Anything under `/assets/` or with an extension is passed through unchanged, so a missing file is a real 404 and a broken bucket policy shows up as real 403s. No distribution-wide error responses are configured.

## Check yours in ten seconds

```bash
curl -sI https://your-site.example/assets/does-not-exist.js | head -1
```

It should be a `404`. If it's `200` with `content-type: text/html`, your site has this bug.

*Template: `skills/terraform/assets/modules/static_site/`. Reference and the reasoning: `skills/terraform/references/static-site.md`.*
