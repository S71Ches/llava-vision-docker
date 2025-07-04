#!/usr/bin/env bash
set -eo pipefail

echo "[entrypoint] 🚀 Запуск vision-entrypoint.sh…"

# Проверка переменных
: "${CF_HOSTNAME:?❌ ERROR: CF_HOSTNAME не задан}"
: "${MODEL_PATH:?❌ ERROR: MODEL_PATH не задан}"

PORT="${PORT:-8000}"
WORKERS="${WORKERS:-1}"

# 1) Запускаем cloudflared
echo "[entrypoint] 🌐 Запуск cloudflared…"
cloudflared tunnel --cred-file /workspace/credentials.json run VISION_TUNNEL \
  > /tmp/cloudflared.log 2>&1 &

sleep 3
if ! pgrep -f "cloudflared" > /dev/null; then
  echo "❌ cloudflared не запустился. Логи:"
  cat /tmp/cloudflared.log
  exit 1
fi

echo "[entrypoint] ✅ Cloudflare Tunnel: https://${CF_HOSTNAME}"
echo "[entrypoint] ✅ Модель: ${MODEL_PATH}"

# 2) Запуск uvicorn
exec uvicorn server:app \
     --host 0.0.0.0 \
     --port "${PORT}" \
     --workers "${WORKERS}"
