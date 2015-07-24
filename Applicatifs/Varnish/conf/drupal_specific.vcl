sub vcl_recv {

        ######  DRUPAL  ######
    if (req.http.host ~ "(itk\.itdev\.lan)") {
        # Use anonymous, cached pages if all backends are down.
        if (!req.backend.healthy) {
            unset req.http.Cookie;
        }

        # Allow the backend to serve up stale content if it is responding slowly.
        set req.grace = 6h;

        # Pipe these paths directly to Apache for streaming.
        #if (req.url ~ "^/admin/content/backup_migrate/export") {
        #  return (pipe);
        #}

        # Do not cache these paths.
        if (req.url ~ "^/status\.php$" ||
            req.url ~ "^/update\.php$" ||
            req.url ~ "^/admin$" ||
            req.url ~ "^/admin/.*$" ||
            req.url ~ "^/flag/.*$" ||
            req.url ~ "^.*/ajax/.*$" ||
            req.url ~ "^.*/ahah/.*$") {
            return (pass);
        }

        # Do not allow outside access to cron.php or install.php.
        #if (req.url ~ "^/(cron|install)\.php$" && !client.ip ~ internal) {
            # Have Varnish throw the error directly.
            #  error 404 "Page not found.";
            # Use a custom error page that you've defined in Drupal at the path "404".
            # set req.url = "/404";
        #}

        # Always cache the following file types for all users. This list of extensions
        # appears twice, once here and again in vcl_fetch so make sure you edit both
        # and keep them equal.
        if (req.url ~ "(?i)\.(pdf|asc|dat|txt|doc|docx|xls|xlsx|ppt|pptx|tgz|zip|csv|png|gif|jpeg|jpg|ico|swf|css|js)(\?.*)?$") {
            unset req.http.Cookie;
        }

        # Custom Sylvain
        if (req.http.Cookie ~ "(roundcube_sessid|ci_session|PHPSESSID|JSESSIONID|S{1,2}ESS[a-z0-9]+|NO_CACHE)=") {
            /* Session Not cacheable by default */
            return (pass);
        }
        
        # Remove all cookies that Drupal doesn't need to know about. We explicitly
        # list the ones that Drupal does need, the SESS and NO_CACHE. If, after
        # running this code we find that either of these two cookies remains, we
        # will pass as the page cannot be cached.
        if (req.http.Cookie) {
            # 1. Append a semi-colon to the front of the cookie string.
            # 2. Remove all spaces that appear after semi-colons.
            # 3. Match the cookies we want to keep, adding the space we removed
            #    previously back. (\1) is first matching group in the regsuball.
            # 4. Remove all other cookies, identifying them by the fact that they have
            #    no space after the preceding semi-colon.
            # 5. Remove all spaces and semi-colons from the beginning and end of the
            #    cookie string.
            set req.http.Cookie = ";" + req.http.Cookie;
            set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
            #### If you have problem with sessions, try to comment this line and uncomment the following one
            set req.http.Cookie = regsuball(req.http.Cookie, ";(PHPSESSID|JSESSIONID|SESS[a-z0-9]+|SSESS[a-z0-9]+|NO_CACHE)=", "; \1=");
            #set req.http.Cookie = regsuball(req.http.Cookie, ";(SESS[a-z0-9]+|SSESS[a-z0-9]+|NO_CACHE)=", "; \1=");
            set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
            set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");

            if (req.http.Cookie == "") {
                # If there are no remaining cookies, remove the cookie header. If there
                # aren't any cookie headers, Varnish's default behavior will be to cache
                # the page.
                unset req.http.Cookie;
            }
            else {
                # If there is any cookies left (a session or NO_CACHE cookie), do not
                # cache the page. Pass it on to Apache directly.
                return (pass);
            }
        }
    }
    ######  END: DRUPAL  ######
}



sub vcl_fetch {

        if (req.http.host ~ "(itk\.itdev\.lan)") {
        # Don't allow static files to set cookies.
        # (?i) denotes case insensitive in PCRE (perl compatible regular expressions).
        # This list of extensions appears twice, once here and again in vcl_recv so
        # make sure you edit both and keep them equal.
        if (req.url ~ "(?i)\.(pdf|asc|dat|txt|doc|docx|xls|xlsx|ppt|pptx|tgz|zip|csv|png|gif|jpeg|jpg|ico|swf|css|js)(\?.*)?$") {
                unset beresp.http.set-cookie;
        }
    }
}
