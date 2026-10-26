#!/usr/bin/env bash
# configs/scripts/sync-portage.sh
# Sincroniza configurações entre /etc/portage/ e o repositório gentoo_EXP

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_PORTAGE="$(cd "${SCRIPT_DIR}/../portage" && pwd)"
SYSTEM_PORTAGE="/etc/portage"

ACTION="${1:-to-repo}"

case "${ACTION}" in
    "to-repo")
        echo "[INFO] Sincronizando /etc/portage -> repositório..."
        mkdir -p "${REPO_PORTAGE}/package.use" \
                 "${REPO_PORTAGE}/package.accept_keywords" \
                 "${REPO_PORTAGE}/binrepos.conf"

        [[ -f "${SYSTEM_PORTAGE}/make.conf" ]] && cp "${SYSTEM_PORTAGE}/make.conf" "${REPO_PORTAGE}/make.conf"
        [[ -f "${SYSTEM_PORTAGE}/bashrc" ]] && cp "${SYSTEM_PORTAGE}/bashrc" "${REPO_PORTAGE}/bashrc"
        [[ -f "${SYSTEM_PORTAGE}/package.license" ]] && cp "${SYSTEM_PORTAGE}/package.license" "${REPO_PORTAGE}/package.license"
        [[ -d "${SYSTEM_PORTAGE}/binrepos.conf" ]] && cp -r "${SYSTEM_PORTAGE}/binrepos.conf/"* "${REPO_PORTAGE}/binrepos.conf/" || true
        [[ -d "${SYSTEM_PORTAGE}/package.use" ]] && cp -r "${SYSTEM_PORTAGE}/package.use/"* "${REPO_PORTAGE}/package.use/" || true
        [[ -d "${SYSTEM_PORTAGE}/package.accept_keywords" ]] && cp -r "${SYSTEM_PORTAGE}/package.accept_keywords/"* "${REPO_PORTAGE}/package.accept_keywords/" || true
        echo "[OK] Sincronização para repositório concluída."
        ;;
    "to-system")
        echo "[INFO] Sincronizando repositório -> /etc/portage (requer privilégios)..."
        if [[ $EUID -ne 0 ]]; then
            if command -v doas >/dev/null 2>&1; then
                exec doas "$0" to-system
            elif command -v sudo >/dev/null 2>&1; then
                exec sudo "$0" to-system
            else
                echo "[ERROR] É necessário root para aplicar em /etc/portage."
                exit 1
            fi
        fi
        mkdir -p "${SYSTEM_PORTAGE}/package.use" \
                 "${SYSTEM_PORTAGE}/package.accept_keywords" \
                 "${SYSTEM_PORTAGE}/binrepos.conf"

        cp "${REPO_PORTAGE}/make.conf" "${SYSTEM_PORTAGE}/make.conf"
        cp "${REPO_PORTAGE}/bashrc" "${SYSTEM_PORTAGE}/bashrc"
        cp "${REPO_PORTAGE}/package.license" "${SYSTEM_PORTAGE}/package.license"
        cp -r "${REPO_PORTAGE}/binrepos.conf/"* "${SYSTEM_PORTAGE}/binrepos.conf/" || true
        cp -r "${REPO_PORTAGE}/package.use/"* "${SYSTEM_PORTAGE}/package.use/" || true
        cp -r "${REPO_PORTAGE}/package.accept_keywords/"* "${SYSTEM_PORTAGE}/package.accept_keywords/" || true
        echo "[OK] Sincronização para /etc/portage concluída."
        ;;
    *)
        echo "Uso: $0 [to-repo|to-system]"
        exit 1
        ;;
esac
