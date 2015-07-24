sub vcl_recv {

        # Remove has_js and Google Analytics __* cookies.
    #if (req.http.Cookie) {
        #Remove has_js and Google Analytics __* cookies.
        set req.http.Cookie = regsuball(req.http.Cookie, "(^|;\s*)(_[_a-z]+|has_js)=[^;]*", "");
    #}
}
