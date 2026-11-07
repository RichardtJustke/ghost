#!/usr/bin/env bash
# Voice dictation backend. The shell records the microphone with pw-record and
# then calls:  dictation.sh process <audio.wav> <type|journal>
#
#   type     transcribe and type the text into the focused window
#   journal  transcribe, clean the text up with an LLM and append it to today's
#            journal file
#
# Transcription and cleanup use the Groq API. The key is read from
# $GROQ_API_KEY or ~/.config/ghost/groq_key.
# Optional environment:
#   GHOST_DICTATION_LANG   spoken language (default: pt)
#   GHOST_JOURNAL_DIR      journal folder (default: ~/Documentos/diario)
#   GHOST_DICTATION_MODEL  cleanup model (default: llama-3.3-70b-versatile)
#
# Prints the final text on stdout. On failure prints a short reason on stderr
# and exits non-zero.

set -o pipefail

KEY_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/ghost/groq_key"
LANG_CODE="${GHOST_DICTATION_LANG:-pt}"
JOURNAL_DIR="${GHOST_JOURNAL_DIR:-$HOME/Documentos/diario}"
CLEANUP_MODEL="${GHOST_DICTATION_MODEL:-llama-3.3-70b-versatile}"
API="https://api.groq.com/openai/v1"

fail() { echo "$1" >&2; exit 1; }

api_key() {
    if [ -n "$GROQ_API_KEY" ]; then
        printf '%s' "$GROQ_API_KEY"
    elif [ -r "$KEY_FILE" ]; then
        tr -d '[:space:]' < "$KEY_FILE"
    fi
}

transcribe() {
    local audio="$1" key="$2" resp
    resp=$(curl -sS --max-time 60 "$API/audio/transcriptions" \
        -H "Authorization: Bearer $key" \
        -F "file=@$audio" \
        -F "model=whisper-large-v3-turbo" \
        -F "language=$LANG_CODE" \
        -F "response_format=json") || fail "Sem conexão com a Groq"
    local err
    err=$(jq -r '.error.message // empty' <<< "$resp" 2>/dev/null)
    [ -n "$err" ] && fail "Groq: $err"
    jq -r '.text // empty' <<< "$resp" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

cleanup() {
    local text="$1" key="$2" body resp out
    local prompt='Você recebe uma transcrição de voz em português de uma anotação pessoal de diário.
Reescreva-a com pontuação e parágrafos corretos, removendo vícios de fala ("é...", "tipo", "né", repetições, falsos começos).
Mantenha a primeira pessoa, o tom e TODO o conteúdo; não invente nada e não resuma.
Se houver uma lista de tarefas ou ideias, use tópicos com "- ".
Responda apenas com o texto final, sem comentários.'
    body=$(jq -n --arg m "$CLEANUP_MODEL" --arg s "$prompt" --arg u "$text" \
        '{model: $m, temperature: 0.2, messages: [{role: "system", content: $s}, {role: "user", content: $u}]}')
    resp=$(curl -sS --max-time 60 "$API/chat/completions" \
        -H "Authorization: Bearer $key" -H "Content-Type: application/json" \
        -d "$body") || { printf '%s' "$text"; return; }
    out=$(jq -r '.choices[0].message.content // empty' <<< "$resp" 2>/dev/null)
    # Keep the raw transcription if the cleanup step fails
    if [ -n "$out" ]; then printf '%s' "$out"; else printf '%s' "$text"; fi
}

type_text() {
    local text="$1"
    if command -v wtype >/dev/null 2>&1; then
        wtype -- "$text" && return 0
    fi
    printf '%s' "$text" | wl-copy
    notify-send -a Ghost "Ditado copiado" "Instale o wtype para digitar direto. Por enquanto, cole com Ctrl+V." 2>/dev/null
}

append_journal() {
    local text="$1" file
    mkdir -p "$JOURNAL_DIR" || fail "Não foi possível criar $JOURNAL_DIR"
    file="$JOURNAL_DIR/$(date +%F).md"
    [ -s "$file" ] || printf '# %s\n' "$(date +%F)" > "$file"
    printf '\n## %s\n\n%s\n' "$(date +%H:%M)" "$text" >> "$file"
}

case "$1" in
    process)
        audio="$2"; mode="${3:-type}"
        [ -s "$audio" ] || fail "Nenhum áudio gravado"
        key=$(api_key)
        [ -n "$key" ] || fail "Chave da Groq não encontrada em $KEY_FILE"

        text=$(transcribe "$audio" "$key") || exit 1
        rm -f "$audio"
        [ -n "$text" ] || fail "Não entendi nada, tente de novo"

        if [ "$mode" = journal ]; then
            text=$(cleanup "$text" "$key")
            append_journal "$text"
        else
            type_text "$text"
        fi
        printf '%s\n' "$text"
        ;;
    *)
        echo "uso: dictation.sh process <audio.wav> <type|journal>" >&2
        exit 2
        ;;
esac
