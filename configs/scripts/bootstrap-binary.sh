#!/usr/bin/env bash
# configs/scripts/bootstrap-binary.sh
# Script de bootstrap para instalação rápida do Gentoo Linux via Binhost oficial x86-64-v3

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PORTAGE_CONFIG_DIR="${REPO_ROOT}/configs/portage"

# Cores para feedback no terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Verificar privilégios de root
if [[ $EUID -ne 0 ]]; then
    if command -v doas >/dev/null 2>&1; then
        log_info "Executando via doas..."
        exec doas "$0" "$@"
    elif command -v sudo >/dev/null 2>&1; then
        log_info "Executando via sudo..."
        exec sudo "$0" "$@"
    else
        log_error "Este script precisa ser executado como root (ou via doas/sudo)."
    fi
fi

log_info "Iniciando bootstrap binário do Gentoo Linux (x86-64-v3)..."

# 1. Backup das configurações existentes em /etc/portage
if [[ -d /etc/portage ]]; then
    BACKUP_DIR="/etc/portage.backup.$(date +%Y%m%d_%H%M%S)"
    log_info "Criando backup de /etc/portage em ${BACKUP_DIR}..."
    cp -r /etc/portage "${BACKUP_DIR}"
    log_ok "Backup concluído."
fi

# 2. Criar diretórios de configuração do Portage
log_info "Criando diretórios estruturados em /etc/portage/..."
mkdir -p /etc/portage/package.use \
         /etc/portage/package.accept_keywords \
         /etc/portage/binrepos.conf \
         /.snapshots

# 3. Aplicar arquivos do repositório
log_info "Instalando configurações do repositório..."
cp "${PORTAGE_CONFIG_DIR}/make.conf" /etc/portage/make.conf
cp "${PORTAGE_CONFIG_DIR}/bashrc" /etc/portage/bashrc
cp "${PORTAGE_CONFIG_DIR}/package.license" /etc/portage/package.license
cp -r "${PORTAGE_CONFIG_DIR}/binrepos.conf/"* /etc/portage/binrepos.conf/ || true
cp -r "${PORTAGE_CONFIG_DIR}/package.use/"* /etc/portage/package.use/ || true
cp -r "${PORTAGE_CONFIG_DIR}/package.accept_keywords/"* /etc/portage/package.accept_keywords/ || true
log_ok "Configurações aplicadas com sucesso em /etc/portage/."

# 4. Sincronização do Portage
if command -v emerge-webrsync >/dev/null 2>&1; then
    log_info "Sincronizando snapshot inicial do Portage via emerge-webrsync..."
    emerge-webrsync
elif command -v emerge >/dev/null 2>&1; then
    log_info "Sincronizando Portage via emerge --sync..."
    emerge --sync
else
    log_warn "emerge não encontrado no PATH atual. Verifique se o ambiente Gentoo chroot/sistema está montado."
fi

# 5. Atualização do conjunto @world com pacotes binários
if command -v emerge >/dev/null 2>&1; then
    log_info "Verificando e atualizando @world utilizando o binhost x86-64-v3..."
    emerge --verbose --update --deep --newuse --getbinpkg @world
    log_ok "Atualização do @world finalizada com sucesso!"
fi

log_ok "Bootstrap binário concluído com êxito!"
