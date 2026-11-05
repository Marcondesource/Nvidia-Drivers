#!/usr/bin/env bash
# ============================================================================
# Setup.sh — Instalador NVIDIA Drivers (GTX 550Ti) — Arch Linux
#
# Uso:
#   ./Setup.sh                   → pede a senha de sudo via dialog
#   ./Setup.sh 'suasenha'        → usa a senha passada como parâmetro ($1)
#   DRY_RUN=1 ./Setup.sh [...]   → modo teste: não executa nada de verdade
# ============================================================================

# ------------------------------ Configurações ------------------------------
LOG="$(mktemp /tmp/nvidia-setup.XXXXXX.log)"
TOTAL_STEPS=8
DRY="${DRY_RUN:-0}"
PID=""
SENHA="${1:-}"
REAL_USER="${SUDO_USER:-$USER}"

# suporte a execução com sudo: ./Setup.sh (normal) ou sudo ./Setup.sh
IS_ROOT=0
[ "$(id -u)" -eq 0 ] && IS_ROOT=1

# Frames do spinner (Animation.sh)
FRAMES=("◜" "◠" "◝" "◞" "◡" "◟")

# Pacotes (arrays)
UTILS=(base-devel git linux-headers)
XORG=(xorg-server xorg-xinit xorg-fonts-misc xorg-xrandr xsel)
NVIDIA=(nvidia-580xx-dkms nvidia-580xx-utils nvidia-580xx-settings lib32-nvidia-580xx-utils)

BACKTITLE="Nvidia-Drivers — GTX 550 Ti"
[ "$DRY" = "1" ] && BACKTITLE="$BACKTITLE  [DRY_RUN: nada será executado]"

cleanup() {
    local rc=$?
    [ -n "$PID" ] && kill "$PID" 2>/dev/null
    unset SENHA
    # mantém o log em caso de erro (ou em DRY_RUN) para poder ser inspecionado
    if [ "$rc" -eq 0 ] && [ "$DRY" != "1" ]; then
        rm -f "$LOG"
    fi
}
trap cleanup EXIT

# ------------------------------ Dependências -------------------------------
if ! command -v dialog >/dev/null 2>&1; then
    echo "Erro: o pacote 'dialog' é necessário. Instale com: sudo pacman -S dialog"
    exit 1
fi

# --------------------------- Senha (Sudo.sh) -------------------------------
pedir_senha() {
    if ! SENHA="$(dialog --clear --stdout --passwordbox "$1" 0 0)"; then
        clear
        echo "Cancelado pelo usuário."
        exit 1
    fi
}

valida_senha() {
    [ "$DRY" = "1" ] && return 0   # no modo teste não há sudo real
    if [ "$IS_ROOT" = "1" ]; then
        # com sudo: valida a senha do usuário real — o sudo interno do
        # makepkg/yay roda como ele e usa o timestamp em cache
        printf '%s\n' "$SENHA" | sudo -u "$REAL_USER" sudo -S -v 2>/dev/null \
            && sudo -u "$REAL_USER" sudo -n true 2>/dev/null
    else
        sudo -k
        printf '%s\n' "$SENHA" | sudo -S -v 2>/dev/null && sudo -n true 2>/dev/null
    fi
}

# Senha: parâmetro $1 → se vazio, pede via dialog
if [ -z "$SENHA" ]; then
    pedir_senha "Digite sua senha de sudo:"
fi

# Valida a senha (do $1 ou digitada); se errada, pede de novo (até 3 tentativas)
tentativas=0
until valida_senha; do
    tentativas=$((tentativas + 1))
    if [ "$tentativas" -ge 3 ]; then
        dialog --msgbox "Senha incorreta após 3 tentativas. Abortando." 0 0
        exit 1
    fi
    pedir_senha "Senha incorreta. Digite sua senha de sudo:"
done

# ------------------------------- Helpers -----------------------------------
log_cmd() {
    printf '%s\n' "[DRY_RUN] $*"
    sleep 1
}

# Todo sudo do script passa por aqui: usa a senha da variável ($SENHA),
# nunca faz requisição ao usuário. Rodando com sudo, executa direto.
sudorun() {
    if [ "$DRY" = "1" ]; then
        if [ "$IS_ROOT" = "1" ]; then log_cmd "$*"; else log_cmd "sudo $*"; fi
        return 0
    fi
    if [ "$IS_ROOT" = "1" ]; then
        "$@"
    else
        printf '%s\n' "$SENHA" | sudo -S -p '' "$@"
    fi
}

# Comandos que rodam como o usuário real (git, makepkg, yay...)
exec_as_user() {
    if [ "$DRY" = "1" ]; then
        if [ "$IS_ROOT" = "1" ]; then log_cmd "sudo -H -u $REAL_USER $*"; else log_cmd "$*"; fi
        return 0
    fi
    if [ "$IS_ROOT" = "1" ]; then
        sudo -H -u "$REAL_USER" "$@"
    else
        "$@"
    fi
}

# Marcador de etapa, lido pela barra de progresso
step() {
    echo "PROGRESS:$1|$2"
    echo ">>> $2"
}

# ------------------- Instalação (Drivers.sh, isolado) ----------------------
instalar_drivers() {
    set -e
    local tmpdir
    tmpdir="$(mktemp -d)"
    sudorun chown -R "$REAL_USER":"$REAL_USER" "$tmpdir"

    # descomenta apenas dentro do bloco [multilib]
    step 1 "Habilitando multilib no pacman.conf"
    sudorun sed -i '/\[multilib\]/,/^\[/ { s/^#\[multilib\]/[multilib]/; /^#Include = \/etc\/pacman.d\/mirrorlist/ s/^#// }' /etc/pacman.conf

    step 2 "Atualizando repositórios (pacman -Syu)"
    sudorun pacman -Syu --noconfirm

    step 3 "Instalando pacotes base e Xorg"
    sudorun pacman -S --noconfirm "${UTILS[@]}" "${XORG[@]}"

    step 4 "Baixando e compilando o yay (AUR)"
    exec_as_user git clone https://aur.archlinux.org/yay.git "$tmpdir/yay"
    exec_as_user sh -c "cd '$tmpdir/yay' && makepkg -si --noconfirm"

    step 5 "Limpando arquivos temporários"
    exec_as_user rm -rf "$tmpdir"

    step 6 "Instalando drivers NVIDIA (AUR)"
    exec_as_user yay -S --noconfirm "${NVIDIA[@]}"

    step 7 "Colocando nouveau em blacklist"
    sudorun sh -c 'echo "blacklist nouveau" > /etc/modprobe.d/blacklist-nouveau.conf'

    step 8 "Gerando initramfs (mkinitcpio -P)"
    sudorun mkinitcpio -P
}

# ---------------- Barra de progresso (dialog + Animation.sh) ---------------
# Instalação isolada em background; todo o log vai para $LOG,
# o terminal mostra apenas o dialog --gauge animado.
instalar_drivers >> "$LOG" 2>&1 &
PID=$!

idx=0
{
    while kill -0 "$PID" 2>/dev/null; do
        msg="Preparando instalação..."
        pct=0
        ultimo="$(grep '^PROGRESS:' "$LOG" 2>/dev/null | tail -n 1)"
        if [ -n "$ultimo" ]; then
            passo="${ultimo#PROGRESS:}"
            passo="${passo%%|*}"
            msg="${ultimo#*|}"
            pct=$(( passo * 100 / TOTAL_STEPS ))
        fi
        frame="${FRAMES[$(( idx % ${#FRAMES[@]} ))]}"
        idx=$(( idx + 1 ))
        printf 'XXX\n%d\n%s %s\nXXX\n' "$pct" "$frame" "$msg"
        sleep 0.1
    done
    printf 'XXX\n100\n✔ Instalação finalizada\nXXX\n'
} | dialog --clear --backtitle "$BACKTITLE" \
           --title "Instalação dos Drivers NVIDIA" \
           --gauge "Iniciando..." 12 60 0

# ------------------------------- Resultado ---------------------------------
if kill -0 "$PID" 2>/dev/null; then
    # dialog fechado antes da instalação terminar → cancelado
    kill "$PID" 2>/dev/null
    wait "$PID" 2>/dev/null
    dialog --msgbox "Instalação cancelada pelo usuário." 0 0
    clear
    exit 1
fi

wait "$PID"
RC=$?

if [ "$RC" -eq 0 ]; then
    ESCOLHA="$(dialog --clear --title "Concluído" \
        --menu "Instalação concluída com sucesso!\nO que deseja fazer? (Recomendado: reiniciar)" 12 60 2 \
        1 "Reiniciar a máquina (recomendado)" \
        2 "Sair do script" \
        3>&1 1>&2 2>&3)" || ESCOLHA="2"
    if [ "$ESCOLHA" = "1" ]; then
        clear
        echo "Reiniciando em 10 segundos (Ctrl+C para cancelar)..."
        sleep 10
        sudorun systemctl reboot
    fi
else
    [ "$IS_ROOT" = "1" ] && chmod 644 "$LOG"
    ERROS="$(grep -iE 'erro|error|falha|failed|fatal|não foi possível|command not found|permissão negada|permission denied' "$LOG" | tail -n 15)"
    [ -z "$ERROS" ] && ERROS="$(tail -n 15 "$LOG")"
    dialog --title "Erro na instalação (código $RC)" \
        --msgbox "Ocorreram erros durante a instalação.\n\n$ERROS\n\nLog completo: $LOG" 0 0
fi

if [ "$DRY" = "1" ]; then
    echo "[DRY_RUN] Log disponível em: $LOG"
fi

clear
exit "$RC"
