#!/usr/bin/env bash
# Weekly PoE news digest → Obsidian + Telegram
set -euo pipefail

ENV_FILE="/home/snrx/dev/poe-news/.env"

if [ -f "$ENV_FILE" ]; then
  # shellcheck source=/dev/null
  source "$ENV_FILE"
fi

export TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
export TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
export OBSIDIAN_VAULT="/home/snrx/ObsidianVault"
DATE_TAG="$(date +%Y-%m-%d)"

if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
  notify-send "PoE Weekly News" "❌ TELEGRAM_BOT_TOKEN или TELEGRAM_CHAT_ID не заданы" --urgency=critical
  exit 1
fi

opencode run \
  --allow-read \
  --allow-write \
  --allow-bash \
  "Найди свежие новости Path of Exile 1 за последнюю неделю.
Источники: https://www.pathofexile.com/news и https://www.pathofexile.com/forum.

Сделай краткий дайджест на русском языке (3-5 пунктов).

Шаг 1 — Obsidian:
  Файл: \$OBSIDIAN_VAULT/poe/poe-news-${DATE_TAG}.md
  Формат:
  # PoE News ${DATE_TAG}
  - [Заголовок](ссылка) — краткое описание

Шаг 2 — Telegram:
  Используй curl с переменными окружения \$TELEGRAM_BOT_TOKEN и \$TELEGRAM_CHAT_ID:
  curl -s -X POST \"https://api.telegram.org/bot\$TELEGRAM_BOT_TOKEN/sendMessage\" \
    -d chat_id=\"\$TELEGRAM_CHAT_ID\" \
    -d text=\"📰 *PoE News* ${DATE_TAG}%0A%0A<текст дайджеста>\" \
    -d parse_mode=Markdown

Выполни всё сам, не спрашивай подтверждения."
