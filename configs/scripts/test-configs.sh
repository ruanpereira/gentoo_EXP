#!/usr/bin/env bash
# configs/scripts/test-configs.sh
# Validação das configurações do Portage e resolução de dependências no binhost

set -euo pipefail

echo "=========================================================="
echo "  gentoo_EXP - Validação de Configurações e Resolução CI  "
echo "=========================================================="

if ! command -v emerge >/dev/null 2>&1; then
    echo "[ERROR] O comando 'emerge' não está disponível neste ambiente."
    exit 1
fi

echo "[1/3] Verificando sintaxe básica do make.conf..."
source /etc/portage/make.conf
echo "      COMMON_FLAGS: ${COMMON_FLAGS:-não definido}"
echo "      MAKEOPTS:     ${MAKEOPTS:-não definido}"
echo "      USE flags:    ${USE:-não definido}"
echo "      FEATURES:     ${FEATURES:-não definido}"

echo "[2/3] Verificando diretórios de package.use e package.accept_keywords..."
[[ -d /etc/portage/package.use ]] && ls -la /etc/portage/package.use
[[ -d /etc/portage/package.accept_keywords ]] && ls -la /etc/portage/package.accept_keywords

echo "[3/3] Executando simulação de cálculo de dependências (@world) via binhost..."
emerge --pretend --verbose --deep --newuse --getbinpkg @world

echo "[OK] Todas as validações de configuração foram executadas com sucesso!"
