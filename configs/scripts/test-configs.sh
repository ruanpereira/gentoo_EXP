#!/usr/bin/env bash
# configs/scripts/test-configs.sh
# Validação detalhada das configurações do Portage e resolução da esteira binária (x86-64-v3)

set -euo pipefail

# Paleta de cores para saída formatada
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()      { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_section() { echo -e "\n${BOLD}${BLUE}=== $1 ===${NC}"; }

echo -e "${BOLD}==========================================================${NC}"
echo -e "${BOLD}   gentoo_EXP - Validação da Esteira Binária (CI/Local)   ${NC}"
echo -e "${BOLD}==========================================================${NC}"

if ! command -v emerge >/dev/null 2>&1; then
    log_error "O comando 'emerge' não foi encontrado. Este script deve ser executado no ambiente Gentoo."
fi

# 1. Validação de Sintaxe do make.conf e binrepos.conf
log_section "1. Validação Sintática das Configurações do Portage"

if [[ ! -f /etc/portage/make.conf ]]; then
    log_error "Arquivo /etc/portage/make.conf não encontrado!"
fi

# Testa importação do make.conf
# shellcheck disable=SC1091
source /etc/portage/make.conf
log_ok "make.conf carregado com sucesso."
echo "      COMMON_FLAGS:    ${COMMON_FLAGS:-não definido}"
echo "      MAKEOPTS:        ${MAKEOPTS:-não definido}"
echo "      FEATURES:        ${FEATURES:-não definido}"
echo "      USE flags:       ${USE:-não definido}"
echo "      VIDEO_CARDS:     ${VIDEO_CARDS:-não definido}"
echo "      GRUB_PLATFORMS:  ${GRUB_PLATFORMS:-não definido}"

# Validar se getbinpkg está habilitado em FEATURES
if [[ "${FEATURES:-}" != *"getbinpkg"* ]]; then
    log_warn "A flag 'getbinpkg' não foi detectada diretamente em FEATURES no make.conf."
else
    log_ok "FEATURES contém 'getbinpkg' para consumo de pacotes binários."
fi

# Validar binrepos.conf
if [[ -f /etc/portage/binrepos.conf/gentoobinhost.conf ]]; then
    log_ok "Arquivo binrepos.conf/gentoobinhost.conf presente."
    grep -E "sync-uri|priority" /etc/portage/binrepos.conf/gentoobinhost.conf || true
else
    log_warn "binrepos.conf/gentoobinhost.conf não encontrado em /etc/portage/binrepos.conf/."
fi

# 2. Verificação de Diretórios e Regras de Pacotes
log_section "2. Estrutura de package.use e package.accept_keywords"

if [[ -d /etc/portage/package.use ]]; then
    log_ok "Arquivos de package.use detectados:"
    ls -1 /etc/portage/package.use | sed 's/^/      - /'
fi

if [[ -d /etc/portage/package.accept_keywords ]]; then
    log_ok "Arquivos de package.accept_keywords detectados:"
    ls -1 /etc/portage/package.accept_keywords | sed 's/^/      - /'
fi

# 3. Teste de Resolução de Binários do Sistema Base (@world)
log_section "3. Simulação de Resolução Binária do Sistema Base (@world)"
log_info "Executando emerge pretend em @world com prioridade a pacotes binários..."

emerge --pretend --verbose --deep --newuse --getbinpkg --binpkg-respect-use=y @world
log_ok "Cálculo de dependências do @world resolvido com sucesso via Binhost!"

# 4. Teste de Resolução dos Pacotes Críticos da Instalação Binária
log_section "4. Verificação de Pacotes Críticos do Sistema Alvo"
log_info "Validando disponibilidade e dependências dos componentes principais..."

TARGET_PKGS=(
    "sys-kernel/gentoo-kernel-bin"
    "sys-kernel/linux-firmware"
    "sys-fs/btrfs-progs"
    "sys-boot/grub"
    "sys-auth/elogind"
    "app-admin/doas"
    "media-libs/mesa"
)

log_info "Simulando resolução para: ${TARGET_PKGS[*]}"
emerge --pretend --quiet --getbinpkg --binpkg-respect-use=y "${TARGET_PKGS[@]}"
log_ok "Todos os pacotes críticos do sistema alvo foram resolvidos sem conflitos!"

echo -e "\n${GREEN}${BOLD}✔ Todas as validações da esteira binária foram concluídas com êxito!${NC}\n"
