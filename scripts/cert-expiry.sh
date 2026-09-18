#!/usr/bin/env bash
# Записывает срок истечения сертификата как метрику для node-exporter.
# Запускается systemd-таймером раз в сутки.

set -euo pipefail

CERT="$(dirname "$0")/../nginx/certs/server.crt"
OUT="$(dirname "$0")/../node-exporter-textfile/cert.prom"

END=$(openssl x509 -in "$CERT" -noout -enddate | cut -d= -f2)
EPOCH=$(date -d "$END" +%s)

cat > "$OUT.tmp" <<EOF
# HELP ssl_cert_expiry_seconds Unix-время истечения сертификата
# TYPE ssl_cert_expiry_seconds gauge
ssl_cert_expiry_seconds{path="nginx/server.crt"} $EPOCH
EOF

mv "$OUT.tmp" "$OUT"