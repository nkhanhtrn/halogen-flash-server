// CloudFront Function (cloudfront-js-2.0), viewer request, on the peonist.ai
// distribution's default behavior. The origin is the private S3 bucket, so
// CloudFront's default root object covers "/" only: a folder URL such as
// /halogen/ would ask S3 for the key "halogen/" and get AccessDenied.
// This maps /halogen/<dir>/ to its index.html and adds the trailing slash to
// /halogen and to extensionless paths under it. Every other URI passes through
// untouched, so the rest of peonist.ai is unaffected.
function handler(event) {
    var request = event.request;
    var uri = request.uri;
    if (uri === '/halogen') {
        return redirect('/halogen/');
    }
    if (uri.indexOf('/halogen/') !== 0) {
        return request;
    }
    if (uri.charAt(uri.length - 1) === '/') {
        request.uri = uri + 'index.html';
        return request;
    }
    var last = uri.slice(uri.lastIndexOf('/') + 1);
    if (last.indexOf('.') === -1) {
        return redirect(uri + '/');
    }
    return request;
}

function redirect(location) {
    return {
        statusCode: 301,
        statusDescription: 'Moved Permanently',
        headers: { location: { value: location } }
    };
}
