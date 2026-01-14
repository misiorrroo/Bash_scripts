#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

#######################################
# OPIS:
# Skrypt do analizy logów systemd/journalctl.
# - Obsługuje PostgreSQL i inne usługi
# - Filtruje logi wg daty i poziomu istotności
# - Eksport TXT oraz opcjonalnie JSON
# - Tryb interaktywny lub CLI
#######################################

###############
# DOMYŚLNE
###############
DATE="$(date +%F)"
EXPORT_JSON=false
INTERESTING_ONLY=true
INTERACTIVE=true

SERVICES=("postgresql.service")

###############
# WZORCE
###############
ERROR_PATTERN="failed|fatal|panic|segfault|crash|corrupted|out of memory"
WARN_PATTERN="warning|deprecated|retry|timeout|slow|deadlock"
INFO_PATTERN="connected|authentication succeeded|started|ready"

###############
# FUNKCJE
###############

usage() {
cat <<EOF
Użycie:
  $0 [opcje]

Opcje:
  -d YYYY-MM-DD   Data logów (domyślnie: dziś)
  -s "svc1 svc2"  Lista usług systemd
  -j              Eksport JSON
  -n              Tryb nieinteraktywny
  -a              Zapisuj wszystkie logi (bez filtrowania)
  -h              Pomoc

Przykład:
  $0 -d 2026-01-10 -s "postgresql.service nginx.service" -j -n
EOF
exit 0
}

ask() {
    local question="$1"
    local default="$2"
    read -rp "$question [$default]: " answer
    echo "${answer:-$default}"
}

check_service() {
    systemctl -q is-active "$1"
}

validate_date() {
    date -d "$1" "+%F" &>/dev/null
}

###############
# ARGUMENTY CLI
###############
while getopts ":d:s:jnah" opt; do
  case $opt in
    d) DATE="$OPTARG" ;;
    s) read -ra SERVICES <<<"$OPTARG" ;;
    j) EXPORT_JSON=true ;;
    n) INTERACTIVE=false ;;
    a) INTERESTING_ONLY=false ;;
    h) usage ;;
    *) usage ;;
  esac
done

###############
# TRYB INTERAKTYWNY
###############
if $INTERACTIVE; then
    echo "=== SYSTEMD LOG MANAGER ==="

    DATE=$(ask "Podaj datę logów (YYYY-MM-DD)" "$DATE")
    validate_date "$DATE" || { echo "Błędna data"; exit 1; }

    svc_input=$(ask "Podaj usługi systemd (spacja oddziela)" "${SERVICES[*]}")
    read -ra SERVICES <<<"$svc_input"

    json_ans=$(ask "Czy eksportować JSON? (y/n)" "n")
    [[ "$json_ans" =~ ^y|Y$ ]] && EXPORT_JSON=true

    interesting_ans=$(ask "Czy tworzyć tylko ciekawe logi? (y/n)" "y")
    [[ "$interesting_ans" =~ ^n|N$ ]] && INTERESTING_ONLY=false
fi

###############
# KATALOGI
###############
DATA_DIR="data_logi_$DATE"
INTEREST_DIR="logi_ciekawe_$DATE"

mkdir -p "$DATA_DIR"
$INTERESTING_ONLY && mkdir -p "$INTEREST_DIR"

###############
# PRZETWARZANIE
###############
for svc in "${SERVICES[@]}"; do
    echo ">> Analiza: $svc"

    if ! check_service "$svc"; then
        echo "   Usługa nieaktywna – pomijam"
        continue
    fi

    TXT_FILE="$DATA_DIR/${svc}.txt"
    JSON_FILE="$DATA_DIR/${svc}.json"

    journalctl -u "$svc" \
        --since "$DATE 00:00:00" \
        --until "$DATE 23:59:59" > "$TXT_FILE"

    if $EXPORT_JSON; then
        journalctl -u "$svc" \
            --since "$DATE 00:00:00" \
            --until "$DATE 23:59:59" \
            -o json > "$JSON_FILE"
    fi

    if $INTERESTING_ONLY; then
        grep -Ei "$ERROR_PATTERN|$WARN_PATTERN" "$TXT_FILE" \
            > "$INTEREST_DIR/${svc}_istotne.txt" || true
    fi
done

echo "=== GOTOWE ==="
echo "Pełne logi: $DATA_DIR/"
$INTERESTING_ONLY && echo "Ciekawe logi: $INTEREST_DIR/"
