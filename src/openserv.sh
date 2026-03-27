#!/bin/bash

DIR="$HOME/.openserv/config"
PIDDIR="$HOME/.openserv/pids"

# ── Helpers ────────────────────────────────────────────────────────────────────

port_live()  { lsof -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; }
pid_on_port(){ lsof -tiTCP:"$1" -sTCP:LISTEN 2>/dev/null | head -1; }
open_url()   { (xdg-open "$1" &>/dev/null &); }
hyperlink()  { printf '\e]8;;%s\e\\%s\e]8;;\e\\' "$2" "$1"; }

get_port() { grep -oP '(?<=--(port|p) )\d+|(?<=:)\d+(?=\s|$)|(?<=port=)\d+' "$1" | grep -v '^0$' | head -1; }

pidfile()  { echo "$PIDDIR/$1.pid"; }
save_pid() { echo "$2" > "$(pidfile "$1")"; }
get_pid()  { local f="$(pidfile "$1")"; [ -f "$f" ] && cat "$f"; }
del_pid()  { rm -f "$(pidfile "$1")"; }

wait_port() {
    local port="$1" i=0
    while [ $i -lt 20 ]; do
        port_live "$port" && return 0
        sleep 1; i=$((i+1)); printf "."
    done; return 1
}

load_scripts() {
    files=("$DIR"/*.sh)
    [ ! -e "${files[0]}" ] && echo -e "\e[1;31m✗ No scripts found in $DIR\e[0m" && exit 1
}

# Pick a model with fzf or numbered menu; sets $selected
pick_model() {
    local prompt="$1" pool=("${@:2}")
    local names=()
    for f in "${pool[@]}"; do names+=("$(basename "$f" .sh)"); done

    if command -v fzf >/dev/null 2>&1; then
        selected=$(printf "%s\n" "${names[@]}" | fzf --prompt="$prompt" \
            --border --height=40% --layout=reverse \
            --preview "cat $DIR/{}.sh" --preview-window=right:60% \
            --color=hl:cyan,hl+:green,prompt:yellow)
        [ -z "$selected" ] && exit 0
    else
        echo -e "\e[1;34mModels:\e[0m\n"
        for i in "${!names[@]}"; do
            local port; port=$(get_port "${pool[$i]}")
            local info=""; [ -n "$port" ] && info=" \e[2m(port $port)\e[0m"
            echo -e "  \e[1;33m$((i+1)))\e[0m ${names[$i]}$info"
        done
        echo; read -rp "Select: " choice
        if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#pool[@]}" ]; then
            echo -e "\e[1;31m✗ Invalid selection\e[0m"; exit 1
        fi
        selected="${names[$((choice-1))]}"
    fi
}

# ── Header ─────────────────────────────────────────────────────────────────────

print_header() {
    clear
    local c="\e[38;2;205;144;119m" r="\e[0m"
    echo -e "${c} ██████╗ ██████╗ ███████╗███╗   ██╗    ███████╗███████╗██████╗ ██╗   ██╗${r}"
    echo -e "${c}██╔═══██╗██╔══██╗██╔════╝████╗  ██║    ██╔════╝██╔════╝██╔══██╗██║   ██║${r}"
    echo -e "${c}██║   ██║██████╔╝█████╗  ██╔██╗ ██║    ███████╗█████╗  ██████╔╝██║   ██║${r}"
    echo -e "${c}██║   ██║██╔═══╝ ██╔══╝  ██║╚██╗██║    ╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝${r}"
    echo -e "${c}╚██████╔╝██║     ███████╗██║ ╚████║    ███████║███████╗██║  ██║ ╚████╔╝ ${r}"
    echo -e "${c} ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═══╝    ╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝ ${r}"
    echo -e "        ${c}Open Serv CLI${r}\n"
}

# ── Commands ───────────────────────────────────────────────────────────────────

cmd_list() {
    print_header; load_scripts
    echo -e "\e[1;34m┌─ Available Models ─────────────────────────────\e[0m"
    for f in "${files[@]}"; do
        local name port live
        name=$(basename "$f" .sh); port=$(get_port "$f")
        live=""; port_live "$port" && live=" \e[1;32m● live\e[0m"
        echo -e "  \e[1m$name\e[0m \e[2m${port:+(port $port)}\e[0m$live"
    done
    echo -e "\e[1;34m└────────────────────────────────────────────────\e[0m\n"
}

cmd_start() {
    print_header; load_scripts
    pick_model "🚀 Start model: " "${files[@]}"

    local port; port=$(get_port "$DIR/$selected.sh")

    if [ -n "$port" ] && port_live "$port"; then
        local url="http://localhost:$port"
        echo -e "\n\e[1;33m⚠ $selected already running on port $port\e[0m"
        echo -e "  $(hyperlink "→ $url" "$url")\n"
        read -rp "Open in browser? [y/N] " a; [[ "$a" =~ ^[Yy]$ ]] && open_url "$url"
        exit 0
    fi

    local log="$PIDDIR/$selected.log"
    echo -e "\n\e[1;32m▶ Starting:\e[0m \e[1m$selected\e[0m\n"
    nohup bash "$DIR/$selected.sh" >"$log" 2>&1 &
    local pid=$!

    sleep 0.3
    if ! kill -0 "$pid" 2>/dev/null; then
        echo -e "\e[1;31m✗ Failed to start. Check: $log\e[0m"; exit 1
    fi
    save_pid "$selected" "$pid"

    if [ -n "$port" ]; then
        printf "\e[2m  Waiting for port $port\e[0m"
        if wait_port "$port"; then
            local url="http://localhost:$port"
            echo -e "\n\n  \e[1;32m✅ $selected is running!\e[0m"
            echo -e "  \e[2mPort:\e[0m \e[1;36m$port\e[0m  \e[2mPID:\e[0m \e[2m$pid\e[0m"
            echo -e "  \e[2mURL:\e[0m  \e[1;34m$(hyperlink "→ $url" "$url")\e[0m"
            echo -e "  \e[2mLog:\e[0m  \e[2m$log\e[0m\n"
            read -rp "  Open in browser? [y/N] " a; [[ "$a" =~ ^[Yy]$ ]] && open_url "$url"
        else
            echo -e "\n\n  \e[1;33m⚠ Port $port didn't open after 20s\e[0m"
            echo -e "  Still loading? Log: \e[2m$log\e[0m"
        fi
    else
        sleep 2
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "  \e[1;32m✅ $selected started (PID $pid)\e[0m — port unknown\n  Log: \e[2m$log\e[0m"
        else
            echo -e "  \e[1;31m✗ Process exited. Check: $log\e[0m"
        fi
    fi
    echo
}

cmd_status() {
    print_header; load_scripts
    local run=0 total=0
    echo -e "\e[1;34m┌─ Model Status ─────────────────────────────────\e[0m"
    for f in "${files[@]}"; do
        local name port; name=$(basename "$f" .sh); port=$(get_port "$f"); total=$((total+1))
        if [ -z "$port" ]; then
            echo -e "  \e[2m⚪ $name (no port detected)\e[0m"; continue
        fi
        if port_live "$port"; then
            run=$((run+1))
            local pid url; pid=$(pid_on_port "$port"); url="http://localhost:$port"
            echo -e "  \e[1;32m● $name\e[0m  \e[1;36mport $port\e[0m \e[2m· PID ${pid:-?}\e[0m"
            echo -e "      \e[1;34m$(hyperlink "→ $url" "$url")\e[0m"
        else
            echo -e "  \e[2m⚪ $name  port $port · stopped\e[0m"
            del_pid "$name"
        fi
    done
    echo -e "\e[1;34m└────────────────────────────────────────────────\e[0m"
    [ "$run" -eq 0 ] \
        && echo -e "\n  \e[2mNo models running. Use 'openserv start'.\e[0m\n" \
        || echo -e "\n  \e[1;32m$run\e[0m/\e[1m$total\e[0m running\n"
}

cmd_stop() {
    print_header; load_scripts
    local running_files=()
    for f in "${files[@]}"; do
        local name port pid
        name=$(basename "$f" .sh); port=$(get_port "$f"); pid=$(get_pid "$name")
        { [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; } || { [ -n "$port" ] && port_live "$port"; } \
            && running_files+=("$f") || del_pid "$name"
    done
    [ ${#running_files[@]} -eq 0 ] && echo -e "\e[1;33m⚠ No models running.\e[0m\n" && exit 0

    pick_model "🛑 Stop model: " "${running_files[@]}"
    local port; port=$(get_port "$DIR/$selected.sh")
    echo -e "\n\e[1;33m⏳ Stopping $selected...\e[0m"

    local pid; pid=$(get_pid "$selected")
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && kill "$pid" 2>/dev/null && sleep 1

    if [ -n "$port" ]; then
        while port_live "$port"; do
            local fp; fp=$(pid_on_port "$port")
            [ -n "$fp" ] && kill -9 "$fp" 2>/dev/null && sleep 1 || break
        done
    fi

    port_live "$port" \
        && echo -e "\e[1;31m✗ Could not stop $selected (port $port still active)\e[0m\n" \
        || echo -e "\e[1;32m✅ $selected stopped\e[0m\n"
    del_pid "$selected"
}

cmd_logs() {
    print_header; load_scripts
    pick_model "📋 View logs: " "${files[@]}"
    local log="$PIDDIR/$selected.log"
    if [ ! -f "$log" ]; then
        echo -e "\e[1;33m⚠ No log for $selected yet\e[0m\n"; exit 0
    fi
    echo -e "\e[1;34m── Logs: $selected ──────────────────────────────\e[0m"
    echo -e "\e[2m$log  (Ctrl+C to exit)\e[0m\n"
    tail -f "$log"
}

cmd_help() {
    print_header
    echo -e "\e[1;34m┌─ Commands ──────────────────────────────────────\e[0m"
    echo -e "  \e[1;32mopenserv start\e[0m   · Launch a model"
    echo -e "  \e[1;32mopenserv status\e[0m  · Show running models"
    echo -e "  \e[1;32mopenserv stop\e[0m    · Stop a running model"
    echo -e "  \e[1;32mopenserv list\e[0m    · List all models"
    echo -e "  \e[1;32mopenserv logs\e[0m    · Tail model logs"
    echo -e "\e[1;34m└────────────────────────────────────────────────\e[0m"
    echo -e "\n  Config: \e[2m$DIR\e[0m   PIDs/logs: \e[2m$PIDDIR\e[0m\n"
}

# ── Entry point ────────────────────────────────────────────────────────────────

case "$1" in
    ""|start)        cmd_start  ;;
    list)            cmd_list   ;;
    status)          cmd_status ;;
    stop)            cmd_stop   ;;
    logs|log)        cmd_logs   ;;
    -h|--help|help)  cmd_help   ;;
    *) print_header; echo -e "\e[1;31m✗ Unknown command: $1\e[0m\n"; cmd_help ;;
esac
