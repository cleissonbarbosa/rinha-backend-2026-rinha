#!/bin/sh
# Smoke test: sobe o compose, espera /ready e exercita POST /fraud-score.
set -e

URL="http://localhost:9999"

echo ">> make rinha-check"
make rinha-check

echo ">> docker compose up --build -d"
docker compose up --build -d

echo ">> aguardando $URL/ready"
ok=0
i=1
while [ "$i" -le 40 ]; do
  if curl -fs "$URL/ready" >/dev/null 2>&1; then
    ok=1
    break
  fi
  sleep 3
  i=$((i + 1))
done
if [ "$ok" -ne 1 ]; then
  echo "!! servico nao ficou pronto"
  docker compose logs --tail=80
  exit 1
fi
echo "   /ready OK"

PAYLOAD='{"id":"tx-1329056812","transaction":{"amount":41.12,"installments":2,"requested_at":"2026-03-11T18:45:53Z"},"customer":{"avg_amount":82.24,"tx_count_24h":3,"known_merchants":["MERC-003","MERC-016"]},"merchant":{"id":"MERC-016","mcc":"5411","avg_amount":60.25},"terminal":{"is_online":false,"card_present":true,"km_from_home":29.23},"last_transaction":null}'

echo ">> POST $URL/fraud-score"
RESP=$(curl -fs -X POST "$URL/fraud-score" -H 'Content-Type: application/json' -d "$PAYLOAD")
echo "   resposta: $RESP"

case "$RESP" in
  *fraud_score*approved* | *approved*fraud_score*)
    echo ">> smoke OK"
    ;;
  *)
    echo "!! resposta inesperada"
    docker compose logs --tail=80
    exit 1
    ;;
esac
