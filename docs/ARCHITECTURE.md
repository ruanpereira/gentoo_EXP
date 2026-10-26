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

* Binhost oficial do Gentoo: `https://gentoo.osuosl.org/releases/amd64/binpackages/23.0/x86-64-v3/`
* Assinatura criptográfica GPG de lançamentos ativada em `FEATURES="binpkg-request-signature getbinpkg"`
* Compilação nativa reservada para o Kernel e componentes de sistema, com pacotes massivos consumidos via binário (`rust-bin`, `zen-bin`, `vscodium-bin`, `steam`).
