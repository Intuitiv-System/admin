# This is a basic VCL configuration file for varnish.  See the vcl(7)
# man page for details on VCL syntax and semantics.
#
# Default backend definition.  Set this to point to your content
# server.
#
# INSTALL Varnish 3.0.0 on Debian Squeeze
# curl http://repo.varnish-cache.org/debian/GPG-key.txt | apt-key add -
# echo "deb http://repo.varnish-cache.org/debian/ squeeze varnish-3.0" >> /etc/apt/sources.list
# apt-get update
# apt-get install varnish

backend default {
    .host = "127.0.0.1";
    .port = "8080";
    .connect_timeout = 600s;
    .first_byte_timeout = 30m;
    .between_bytes_timeout = 5m;
}


# Block IPs
#acl forbidden {
#    "192.168.1.50";
#}





# Place the following 2 configuration blocks right after your "backend default {…}" block
# inside your /etc/varnish/default.vcl file (the main Varnish configuration file)

# This Varnish configuration makes use of a custom HTTP header to determin whether
# some user is logged in or not inside Joomla! To allow this, simply append this code
#       // Set user state in headers
#       if (!$user->guest) {
#           JResponse::setHeader('X-Logged-In', 'True', true);
#       } else {
#           JResponse::setHeader('X-Logged-In', 'False', true);
#       }
# on the "function onAfterInitialise(){ ... } function, right after "$user= JFactory::getUser();"
# in the Joomla! cache plugin php file located at /plugins/system/cache/cache.php
# Finally, enable this plugin via the Joomla! backend.
# If you don't want to use the cache plugin, add this code in your template's index.php file.
# Don't forget to prepend it with "$user = JFactory::getUser();"

# The following setup assumes a 5 min cache time - you can safely drop this to 1 min for popular/busy sites



# Include VCL config files
include "dont_cache.vcl";
include "google_analytics.vcl";
include "url_rewriting.vcl";
include "basic_recv.vcl";
include "joomla_specific.vcl";
include "drupal_specific.vcl";


sub vcl_recv {

    #if (client.ip ~ forbidden) {
    #    error 403 "Forbidden";
    #}


    # Check for the custom "x-logged-in" header to identify if the visitor is a guest,
    # then unset any cookie (including session cookies) provided it's not a POST request
    if(req.http.x-logged-in == "False" && req.request != "POST"){
        unset req.http.cookie;
    }

    # Properly handle different encoding types
    if (req.http.Accept-Encoding) {
      if (req.url ~ "\.(jpg|jpeg|png|gif|gz|tgz|bz2|tbz|mp3|ogg|swf)$") {
        # No point in compressing these
        remove req.http.Accept-Encoding;
      } elsif (req.http.Accept-Encoding ~ "gzip") {
        set req.http.Accept-Encoding = "gzip";
      } elsif (req.http.Accept-Encoding ~ "deflate") {
        set req.http.Accept-Encoding = "deflate";
      } else {
        # unknown algorithm (aka crappy browser)
        remove req.http.Accept-Encoding;
      }
    }

    # Cache files with these extensions
    if (req.url ~ "\.(js|css|jpg|JPG|jpeg|JPEG|png|PNG|gif|GIF|gz|tgz|bz2|tbz|mp3|ogg|swf)$") {
        return (lookup);
    }


    # Set how long Varnish will cache content depending on whether your backend is healthy or not
    if (req.backend.healthy) {
        set req.grace = 5m;
    } else {
        set req.grace = 1h;
    }

    return (lookup);
}



sub vcl_pipe {
    # Note that only the first request to the backend will have
    # X-Forwarded-For set.  If you use X-Forwarded-For and want to
    # have it set for all requests, make sure to have:
    # set bereq.http.connection = "close";
    # here.  It is not set by default as it might break some broken web
    # applications, like IIS with NTLM authentication.
    return (pipe);
}



sub vcl_pass {
    return (pass);
}



sub vcl_hash {
    hash_data(req.url);
    if (req.http.host) {
        hash_data(req.http.host);
    } else {
        hash_data(server.ip);
    }
    return (hash);
}



sub vcl_hit {
    return (deliver);
}



sub vcl_miss {
    return (fetch);
}



sub vcl_fetch {
    # Check for the custom "x-logged-in" header to identify if the visitor is a guest,
    # then unset any cookie (including session cookies) provided it's not a POST request
    if(req.request != "POST" && beresp.http.x-logged-in == "False") {
        unset beresp.http.Set-Cookie;
    }

    # Allow items to be stale if needed (this value should be the same as with "set req.grace"
    # inside the sub vcl_recv {…} block (the 2nd part of the if/else statement)
    set beresp.grace = 1h;

    # Serve pages from the cache should we get a sudden error and re-check in one minute
    if (beresp.status == 503 || beresp.status == 502 || beresp.status == 501 || beresp.status == 500) {
      set beresp.grace = 60s;
      return (restart);
    }

    # Unset the "etag" header (suggested)
    unset beresp.http.etag;

    # This is Joomla! specific: fix stupid "no-cache" header sent by Joomla! even
    # when caching is on - make sure to replace 300 with the number of seconds that
    # you want the browser to cache content
    if(beresp.http.Cache-Control == "no-cache" || beresp.http.Cache-Control == ""){
        set beresp.http.Cache-Control = "max-age=300, public, must-revalidate";
    }

    # This is how long Varnish will cache content
    set beresp.ttl = 180m;

    ### To modify the Server informations in Headers page
    unset beresp.http.Server;
    set beresp.http.Server = "Well...";


    return (deliver);
}



sub vcl_deliver {
    
    # desactivation du Cache navigateur pour palier aux problèmes de connexion nécessitant un refresh de la page
    if (req.url !~ "(?i)\.(pdf|asc|dat|txt|doc|xls|ppt|tgz|csv|png|gif|jpeg|jpg|ico|swf|css|js)(\?.*)?$") {
        set resp.http.Cache-Control = "no-cache, must-revalidate, post-check=0, pre-check=0";
    }
    if (resp.http.Vary !~ "Cookie") {
        set resp.http.Vary = resp.http.Vary + ", Cookie";
        set resp.http.Vary = regsub(resp.http.Vary, "^,\s*", "");
    }

    ### DEBUG MODE !!! ###
    # You can optionally set a reponse header so it's easier for you to debug if Varnish really didn't cache objects for the host

    if (obj.hits > 0) {
        set resp.http.X-Varnish-Cache = "HIT";
    }
    else {
        set resp.http.X-Varnish-Cache = "MISS";
    }

    ### To hide VARNISH Informations In HTTP Headers ###
    #remove resp.http.X-Varnish;
    #remove resp.http.Via;
    #remove resp.http.Age;
    #remove resp.http.X-Powered-By;
}

sub vcl_error {
    #unset obj.http.Server;
    #set obj.http.Server = "Go Away";


    ###### DO NOT UNCOMMENT #######
    # In the event of an error, show friendlier messages.
    # Redirect to some other URL in the case of a homepage failure.
    #if (req.url ~ "^/?$") {
    #  set obj.status = 302;
    # set obj.http.Location = "http://backup.example.com/";
    #}
    ###############################


    # Otherwise redirect to the homepage, which will likely be in the cache.
    #set obj.http.Content-Type = "text/html; charset=utf-8";
    #synthetic {"
    #<html>
    #<head>
    #<title>Page Unavailable</title>
    #<style>
    #    body { background: #303030; text-align: center; color: white; }
    #    #page { border: 1px solid #CCC; width: 500px; margin: 100px auto 0; padding: 30px; background: #323232; }
    #    a, a:link, a:visited { color: #CCC; }
    #    .error { color: #222; }
    #</style>
    #</head>
    #<body onload="setTimeout(function() { window.location = '/' }, 5000)">
    #    <div id="page">
    #        <h1 class="title">Page Unavailable</h1>
    #        <p>The page you requested is temporarily unavailable.</p>
    #        <p>We're redirecting you to the <a href="/">homepage</a> in 5 seconds.</p>
    #        <div class="error">(Error "} + obj.status + " " + obj.response + {")</div>
    #    </div>
    #</body>
    #</html>
    #"};
    #return (deliver);
}
