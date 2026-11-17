#!/usr/bin/env bash
set +e
S=${SITE:-https://starskyaviation.co.uk}; H=$(echo "$S" | sed -E 's#https?://##; s#/.*##'); O=out; mkdir -p $O
{
echo "== DNS"; dig +short A $H; dig +short AAAA $H; dig +short www.$H; echo "-- NS"; dig +short NS $H; echo "-- MX"; dig +short MX $H; echo "-- TXT"; dig +short TXT $H; dig +short TXT _dmarc.$H; echo "-- CAA"; dig +short CAA $H
echo "== WHOIS/IP"; for ip in $(dig +short A $H); do curl -s ipinfo.io/$ip; echo; done
echo "== Redirect chains"; for u in http://$H https://$H http://www.$H https://www.$H; do echo "-- $u"; curl -sIL -o /dev/null -w '%{url_effective} %{http_code} redirs=%{num_redirects}\n' --max-time 30 $u; curl -sI --max-time 30 $u | grep -iE '^(HTTP|location)'; done
echo "== Homepage headers"; curl -sSIL --max-time 30 https://$H/
echo "== GET headers + timing"; curl -s -o /dev/null -D - -w 'dns=%{time_namelookup} connect=%{time_connect} tls=%{time_appconnect} ttfb=%{time_starttransfer} total=%{time_total} size=%{size_download} http=%{http_version}\n' -H 'Accept-Encoding: gzip, br' https://$H/
echo "== TTFB x5"; for i in 1 2 3 4 5; do curl -s -o /dev/null -w '%{time_starttransfer}\n' https://$H/; done
echo "== Compression"; curl -s -o /dev/null -w 'gzip size=%{size_download}\n' -H 'Accept-Encoding: gzip' https://$H/; curl -s -o /dev/null -w 'none size=%{size_download}\n' https://$H/
echo "== HTTP/2,3"; curl -sI --http2 https://$H/ -o /dev/null -w '%{http_version}\n'; curl -sI https://$H/ | grep -i alt-svc
echo "== Paths"; for p in robots.txt sitemap.xml sitemap_index.xml wp-sitemap.xml wp-login.php wp-admin/ wp-json/ wp-json/wp/v2/users xmlrpc.php readme.html license.txt wp-content/debug.log wp-config.php.bak .env .git/HEAD .git/config .htaccess .DS_Store server-status phpinfo.php info.php admin/ administrator/ login/ user/login api/ graphql .well-known/security.txt humans.txt ads.txt manifest.json site.webmanifest favicon.ico 404-test-$RANDOM backup.zip composer.json package.json web.config crossdomain.xml; do printf "%-28s %s\n" $p "$(curl -s -o /dev/null -w '%{http_code} %{size_download}B %{content_type}' --max-time 20 https://$H/$p)"; done
echo "== robots.txt"; curl -s https://$H/robots.txt | head -60
echo "== sitemap"; curl -s https://$H/sitemap.xml | head -c 6000; echo; curl -s https://$H/sitemap_index.xml | head -c 3000; echo; curl -s https://$H/wp-sitemap.xml | head -c 3000
echo "== wp-json users"; curl -s https://$H/wp-json/wp/v2/users | head -c 1500; echo
echo "== wp-json root namespaces"; curl -s https://$H/wp-json/ | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("name"),d.get("description"),d.get("url")); print(d.get("namespaces"))' 2>&1 | head -5
echo "== 404 page"; curl -s -o /dev/null -w '%{http_code}\n' https://$H/this-page-does-not-exist-xyz
echo "== OPTIONS/TRACE"; curl -s -X OPTIONS -i https://$H/ | head -15; curl -s -X TRACE -o /dev/null -w 'TRACE %{http_code}\n' https://$H/
echo "== TLS cert"; echo | openssl s_client -servername $H -connect $H:443 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
for v in tls1 tls1_1 tls1_2 tls1_3; do printf "%s: " $v; echo | timeout 10 openssl s_client -$v -servername $H -connect $H:443 2>&1 | grep -qE 'Cipher is [A-Z0-9]' && echo SUPPORTED || echo no; done
echo "== Ports (common)"; for port in 21 22 25 80 110 143 443 465 587 993 995 2082 2083 2086 2087 3306 5432 8080 8443; do timeout 3 bash -c "</dev/tcp/$H/$port" 2>/dev/null && echo "$port open"; done
} > $O/probe.txt 2>&1
