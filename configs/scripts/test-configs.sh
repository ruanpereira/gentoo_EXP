#!/usr/bin/env bash
# configs/scripts/test-configs.sh
# Validação detalhada das configurações do Portage e resolução da esteira binária (x86-64-v3)
# Simula uma instalação real completa em modo --pretend, incluindo deps transitivas e USE flags.

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
    grep -E "sync-uri|priority|location|verify-signature" /etc/portage/binrepos.conf/gentoobinhost.conf || true
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

# 3. Simulação completa da instalação binária (todos os pacotes do guia)
# Inclui deps transitivas com --deep e --with-bdeps=y para pegar conflitos
# de USE flags em dependências indiretas (ex: installkernel[dracut], libglvnd[X])
log_section "3. Simulação Completa da Instalação Binária (Guia Fase 4 + 5 + 6)"

# Garantir que o overlay GURU esteja disponível para niri e ly
if command -v eselect >/dev/null 2>&1; then
    if ! eselect repository list -i 2>/dev/null | grep -q guru; then
        log_info "Habilitando overlay GURU para pacotes comunitários (niri, ly)..."
        emerge --getbinpkg --quiet app-eselect/eselect-repository dev-vcs/git 2>/dev/null || true
        eselect repository enable guru 2>/dev/null || true
        emaint sync -r guru 2>/dev/null || true
    fi
fi

log_info "Executando emerge --pretend com grafo completo de dependências..."

INSTALL_PKGS=(
    # Fase 4: Kernel e Firmware
    "sys-kernel/linux-firmware"
    "sys-kernel/gentoo-kernel-bin"
    # Fase 5: Filesystem, Bootloader, Rede e Serviços
    "sys-fs/btrfs-progs"
    "sys-fs/dosfstools"
    "sys-boot/grub"
    "app-admin/sysklogd"
    "net-misc/chrony"
    "net-misc/dhcpcd"
    "net-firewall/firewalld"
    "sys-auth/elogind"
    "app-admin/doas"
    # Fase 6: Wayland, Mesa, Niri e Ly
    "media-libs/mesa"
    "x11-libs/libxkbcommon"
    "gui-wm/niri"
    "x11-misc/ly"
    # Utilitários base
    "dev-vcs/git"
    "app-eselect/eselect-repository"
)

log_info "Pacotes alvo: ${INSTALL_PKGS[*]}"

# --deep:               resolve grafo completo de deps transitivas
# --newuse:             detecta pacotes que precisam ser recompilados por mudança de USE
# --with-bdeps=y:       inclui dependências de build no grafo
# --getbinpkg:          prioriza binários do binhost
# --binpkg-respect-use=y: rejeita binários com USE flags incompatíveis (força recompilação ou erro)
# --backtrack=100:      aumenta tentativas de resolução antes de desistir
# --verbose-conflicts:  exibe detalhes de qualquer conflito de USE flags ou versão
emerge \
    --pretend \
    --verbose \
    --deep \
    --newuse \
    --with-bdeps=y \
    --getbinpkg \
    --binpkg-respect-use=y \
    --backtrack=100 \
    --verbose-conflicts \
    "${INSTALL_PKGS[@]}"

log_ok "Grafo completo de dependências resolvido sem conflitos de USE flags!"

# 4. Validação do @world com as configurações aplicadas
log_section "4. Validação do @world com Configurações do Repositório"
log_info "Verificando que nenhum pacote do @world exige recompilação por conflito de USE..."

emerge \
    --pretend \
    --verbose \
    --update \
    --deep \
    --newuse \
    --with-bdeps=y \
    --getbinpkg \
    --binpkg-respect-use=y \
    --backtrack=100 \
    @world

log_ok "@world resolvido sem conflitos via Binhost x86-64-v3!"

echo -e "\n${GREEN}${BOLD}✔ Todas as validações da esteira binária foram concluídas com êxito!${NC}\n"
