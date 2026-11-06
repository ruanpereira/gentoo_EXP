#!/usr/bin/env bash
# configs/scripts/sync-portage.sh
# Sincroniza configurações entre /etc/portage/ e o repositório gentoo_EXP.
# Suporta dois perfis:
#   binary   (padrão): configs/portage/           — modo binário x86-64-v3
#   compiled:          configs/portage-compiled/  — modo compilado híbrido (-march=znver3)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_PORTAGE="/etc/portage"

ACTION="${1:-to-repo}"
MODE="${2:-binary}"

case "${MODE}" in
    binary)
        REPO_PORTAGE="$(cd "${SCRIPT_DIR}/../portage" && pwd)"
        ;;
    compiled)
        REPO_PORTAGE="$(cd "${SCRIPT_DIR}/../portage-compiled" && pwd)"
        ;;
    *)
        echo "[ERROR] Modo inválido: '${MODE}'. Use 'binary' ou 'compiled'."
        exit 1
        ;;
esac

echo "[INFO] Modo: ${MODE} | Perfil: ${REPO_PORTAGE}"

case "${ACTION}" in
    "to-repo")
        echo "[INFO] Sincronizando /etc/portage -> repositório (${MODE})..."
        mkdir -p "${REPO_PORTAGE}/package.use" \
                 "${REPO_PORTAGE}/package.accept_keywords" \
                 "${REPO_PORTAGE}/binrepos.conf"

        [[ -f "${SYSTEM_PORTAGE}/make.conf" ]]        && cp "${SYSTEM_PORTAGE}/make.conf"        "${REPO_PORTAGE}/make.conf"
        [[ -f "${SYSTEM_PORTAGE}/bashrc" ]]           && cp "${SYSTEM_PORTAGE}/bashrc"           "${REPO_PORTAGE}/bashrc"
        [[ -f "${SYSTEM_PORTAGE}/package.license" ]]  && cp "${SYSTEM_PORTAGE}/package.license"  "${REPO_PORTAGE}/package.license"
        [[ -d "${SYSTEM_PORTAGE}/binrepos.conf" ]]    && cp -r "${SYSTEM_PORTAGE}/binrepos.conf/"* "${REPO_PORTAGE}/binrepos.conf/" || true
        [[ -d "${SYSTEM_PORTAGE}/package.use" ]]      && cp -r "${SYSTEM_PORTAGE}/package.use/"* "${REPO_PORTAGE}/package.use/" || true
        [[ -d "${SYSTEM_PORTAGE}/package.accept_keywords" ]] && cp -r "${SYSTEM_PORTAGE}/package.accept_keywords/"* "${REPO_PORTAGE}/package.accept_keywords/" || true

        # Modo compilado: sincroniza também package.env, env/ e package.mask
        if [[ "${MODE}" == "compiled" ]]; then
            mkdir -p "${REPO_PORTAGE}/package.env" "${REPO_PORTAGE}/env" "${REPO_PORTAGE}/package.mask"
            [[ -d "${SYSTEM_PORTAGE}/package.env" ]] && cp -r "${SYSTEM_PORTAGE}/package.env/"* "${REPO_PORTAGE}/package.env/" || true
            [[ -d "${SYSTEM_PORTAGE}/env" ]]         && cp -r "${SYSTEM_PORTAGE}/env/"*         "${REPO_PORTAGE}/env/"         || true
            [[ -d "${SYSTEM_PORTAGE}/package.mask" ]] && cp -r "${SYSTEM_PORTAGE}/package.mask/"* "${REPO_PORTAGE}/package.mask/" || true
        fi

        echo "[OK] Sincronização para repositório (${MODE}) concluída."
        ;;
    "to-system")
        echo "[INFO] Sincronizando repositório -> /etc/portage (${MODE}, requer root)..."
        if [[ $EUID -ne 0 ]]; then
            if command -v doas >/dev/null 2>&1; then
                exec doas "$0" to-system "${MODE}"
            elif command -v sudo >/dev/null 2>&1; then
                exec sudo "$0" to-system "${MODE}"
            else
                echo "[ERROR] É necessário root para aplicar em /etc/portage."
                exit 1
            fi
        fi

        mkdir -p "${SYSTEM_PORTAGE}/package.use" \
                 "${SYSTEM_PORTAGE}/package.accept_keywords" \
                 "${SYSTEM_PORTAGE}/binrepos.conf"

        cp "${REPO_PORTAGE}/make.conf"       "${SYSTEM_PORTAGE}/make.conf"
        [[ -f "${REPO_PORTAGE}/bashrc" ]]    && cp "${REPO_PORTAGE}/bashrc"    "${SYSTEM_PORTAGE}/bashrc"
        [[ -f "${REPO_PORTAGE}/package.license" ]] && cp "${REPO_PORTAGE}/package.license" "${SYSTEM_PORTAGE}/package.license"
        cp -r "${REPO_PORTAGE}/binrepos.conf/"* "${SYSTEM_PORTAGE}/binrepos.conf/" || true
        cp -r "${REPO_PORTAGE}/package.use/"*   "${SYSTEM_PORTAGE}/package.use/"   || true
        cp -r "${REPO_PORTAGE}/package.accept_keywords/"* "${SYSTEM_PORTAGE}/package.accept_keywords/" || true

        # Modo compilado: aplica também package.env, env/ e package.mask
        if [[ "${MODE}" == "compiled" ]]; then
            mkdir -p "${SYSTEM_PORTAGE}/package.env" "${SYSTEM_PORTAGE}/env" "${SYSTEM_PORTAGE}/package.mask"
            cp -r "${REPO_PORTAGE}/package.env/"* "${SYSTEM_PORTAGE}/package.env/" || true
            cp -r "${REPO_PORTAGE}/env/"*         "${SYSTEM_PORTAGE}/env/"         || true
            [[ -d "${REPO_PORTAGE}/package.mask" ]] && cp -r "${REPO_PORTAGE}/package.mask/"* "${SYSTEM_PORTAGE}/package.mask/" || true
        fi

        echo "[OK] Sincronização para /etc/portage (${MODE}) concluída."
        ;;
    *)
        echo "Uso: $0 [to-repo|to-system] [binary|compiled]"
        exit 1
        ;;
esac
