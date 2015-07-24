sub vcl_recv {

        ######  JOOMLA  ######
    if (req.http.host ~ "(siac\.itdev\.lan)") {
        # Proxy (pass) any request that goes to the backend admin,
        # the banner component links or any post requests
        # You can add more pages or entire URL structure in the end of the "if"
        if(req.http.cookie ~ "userID" || req.url ~ "^/administrator" || req.url ~ "^/component/banners" || req.request == "POST") {
            return (pass);
        }
    }
    ######  END: JOOMLA  ######
}
