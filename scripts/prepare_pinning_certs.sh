openssl s_client \
  -servername badssl.com \
  -connect badssl.com:443 < /dev/null 2>/dev/null \
  | openssl x509 -noout -fingerprint -sha256 > dio/test/_pinning.txt 2>/dev/null
openssl s_client \
  -servername httpbin.org \
  -connect httpbin.org:443 < /dev/null 2>/dev/null \
  | openssl x509 -noout -fingerprint -sha256 > plugins/http2_adapter/test/_pinning_http2.txt 2>/dev/null
