sub vcl_recv {

        if (req.restarts == 0) {
        if (req.http.x-forwarded-for) {
            set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
        } else {
            set req.http.X-Forwarded-For = client.ip;
        }
    }
    if (req.request != "GET" && req.request != "HEAD" && req.request != "PUT" && req.request != "POST" && req.request != "TRACE" && req.request != "OPTIONS" && req.request != "DELETE") {
        /* Non-RFC2616 or CONNECT which is weird. */
        return (pipe);
    }
    if (req.request != "GET" && req.request != "HEAD") {
        /* We only deal with GET and HEAD by default */
        return (pass);
    }

    # Forward client's IP to backend
    #remove req.http.X-Forwarded-For;
    #set req.http.X-Forwarded-For = client.ip;
}
