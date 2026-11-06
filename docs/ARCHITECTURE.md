# 🏛️ Arquitetura do Sistema - Gentoo Linux (`gentoo_EXP`)

Este documento consolida a arquitetura técnica, escolhas de software e direcionamento de configuração implementadas para a máquina alvo.

---

## 🖥️ 1. Hardware Alvo

* **Processador:** AMD Ryzen 5 5600XT (6 Cores / 12 Threads @ ~4.76 GHz - Microarquitetura Zen 3)
* **Placa de Vídeo:** AMD Radeon RX 6600 / 6600 XT (Navi 23 / RDNA 2)
* **Memória:** 16 GB RAM + 16 GB Swap
* **Rede:** Realtek RTL8125 2.5GbE

---

## ⚙️ 2. Sistema Base e Inicialização

* **Init System:** OpenRC (`sys-apps/openrc`)
* **Profile Padrão:** `default/linux/amd64/23.0`
* **Bootloader:** GRUB 2 em modo UEFI (`GRUB_PLATFORMS="efi-64"`)
* **Elevação de Privilégios:** `doas` (`app-admin/doas`) com permissão persistente para o grupo `wheel`
* **Logs & Horário:** `sysklogd` e `chrony` habilitados no runlevel `default`

---

## 💾 3. Sistema de Arquivos e Snapshots (Btrfs)

* Subvolumes organizados:
  * `@` -> `/`
  * `@home` -> `/home`
  * `@var_log` -> `/var/log` (isolado para persistência de logs em caso de rollback)
  * `@snapshots` -> `/.snapshots`
* Hook automático em `/etc/portage/bashrc` garantindo snapshot read-only antes de transações do `emerge`.

---

## 🚀 4. Repositório Binário `x86-64-v3`

* Binhost oficial do Gentoo: `https://distfiles.gentoo.org/releases/amd64/binpackages/23.0/x86-64-v3/` (via CDN Anycast Fastly)
* Repositório configurado em `/etc/portage/binrepos.conf/gentoobinhost.conf` com `location = /var/cache/binhost/gentoo` e `verify-signature = true`
* Assinatura criptográfica GPG de lançamentos ativada em `FEATURES="binpkg-request-signature getbinpkg parallel-fetch"`
* Compilação nativa reservada para o Kernel e componentes de sistema, com pacotes massivos consumidos via binário (`rust-bin`, `zen-bin`, `vscodium-bin`, `steam`).

---

## 🔀 5. Estratégia de Modos de Instalação

O repositório suporta dois perfis de Portage isolados e versionados:

1. **Modo Binário Puro (`configs/portage/`):**
   - Ativa `FEATURES="getbinpkg"` globalmente no `make.conf`.
   - Utiliza `gentoo-kernel-bin` e consome pacotes pré-compilados `x86-64-v3` para instalação em minutos.

2. **Modo Compilado Híbrido (`configs/portage-compiled/`):**
   - Compilação nativa com `-march=znver3` e `MAKEOPTS="-j12"`.
   - `FEATURES="parallel-fetch"` no `make.conf` (sem `getbinpkg` global).
   - Exceções cirúrgicas via `/etc/portage/package.env/binpkg` e `/etc/portage/env/binpkg.conf`:
     - `www-client/zen-bin`: navegador moderno pré-compilado;
     - `games-util/steam-launcher`: launcher de jogos;
     - `dev-lang/rust-bin`: evita 1-2h de compilação da toolchain Rust sem perda de performance.
   - Bloqueio via `package.mask/rust` (`dev-lang/rust`) para garantir que o Portage resolva dependências Rust diretamente pelo `rust-bin`.
