sub vcl_recv {

    ### Don't cache these domains ###

    # !!!!!! WARNING : req.http.host DOESN'T HAVE TO BE EMPTY !!!!!

    # Think to update domains list in vcl_deliver too at the end of this file !!!
    if (req.http.host ~ "(plip)") {
        if (req.http.x-forwarded-for) {
            set req.http.X-Forwarded-For = req.http.X-Forwarded-For + ", " + client.ip;
        } else {
            set req.http.X-Forwarded-For = client.ip;
        }
        return (pass);
    }
    ### END: Don't cache these domains ###

    ### Exclude robots.txt ###
    if (req.url ~ "^/robots.txt$") {
        return (pass);
    }

}


sub vcl_deliver {

    # !!!!!! WARNING : req.http.host DOESN'T HAVE TO BE EMPTY !!!!!

    # Don't cache domains list
    if (req.http.host ~ "(plip)") {
        set resp.http.X-Cache = "EXCLUDED";
    }
}
