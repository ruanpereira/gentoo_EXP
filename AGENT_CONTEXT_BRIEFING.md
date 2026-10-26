# 📋 Handover Context: Projeto Gentoo Linux (`gentoo_EXP`)

Este documento serve como **briefing executivo de transferência de contexto** para qualquer agente ou desenvolvedor que assumir a continuidade desta atividade. Ele resume todas as decisões técnicas, dados de hardware coletados, preferências do usuário e o estado do repositório.

---

## 🎯 1. Visão Geral e Objetivo do Projeto

O usuário deseja instalar e manter um sistema **Gentoo Linux** customizado, moderno e reprodutível.
O repositório local `/home/black_aktsu/workspace/gentoo_EXP` será versionado no GitHub sob o nome **`gentoo_EXP`** com dois propósitos fundamentais:
1. **Documentação Viva e Sincronização:** Manter as configurações de `/etc/portage/`, scripts de automação e dotfiles.
2. **Validação Contínua (CI):** Uma esteira no GitHub Actions que roda a cada push em um container oficial Gentoo Stage3 com o binhost oficial `x86-64-v3` para validar que todas as dependências, USE flags e scripts funcionam sem conflito e sem estourar o limite de tempo do GitHub.

---

## 🖥️ 2. Diagnóstico de Hardware da Máquina do Usuário (Executado e Confirmado)

Estes dados foram coletados diretamente do computador onde o Gentoo será operado:

| Componente | Especificação Diagnosticada | Configuração do Gentoo Mapeada |
| :--- | :--- | :--- |
| **Processador** | AMD Ryzen 5 5600XT (6 Cores / 12 Threads @ ~4.76 GHz) | Microarquitetura Zen 3 (`-march=znver3`), `MAKEOPTS="-j12"` |
| **Memória** | 16 GB RAM + 16 GB Swap | Seguro para compilações até `-j12`, usando binários para gigantes |
| **GPU** | AMD Radeon RX 6600 / 6600 XT (Navi 23 / RDNA 2) | `VIDEO_CARDS="amdgpu radeonsi"` no `make.conf` |
| **Rede** | Realtek Semiconductor RTL8125 2.5GbE | Módulo de kernel `r8169`, firmware no `linux-firmware` |

---

## 🧱 3. Decisões Arquiteturais e de Software Fechadas

1. **Init System:** **OpenRC** (sem Systemd).
2. **Profile do Portage:** Padrão estável `23.0` (`default/linux/amd64/23.0`).
3. **Bootloader & Boot:** **GRUB 2** em modo **UEFI** (`GRUB_PLATFORMS="efi-64"`).
4. **Sistema de Arquivos:** **Btrfs** com subvolumes:
   * `@` montado em `/`
   * `@home` montado em `/home`
   * `@var_log` montado em `/var/log` (isolado para não perder logs em reversões)
   * `@snapshots` montado em `/.snapshots`
5. **Snapshots Automáticos do Sistema:** Hook implementado em `/etc/portage/bashrc` que gera snapshots Btrfs de `/` automaticamente antes de qualquer transação do `emerge`.
6. **Segurança & Privilégios:**
   * Utilizar **`doas`** (`app-admin/doas`) em vez de `sudo`.
   * Regra em `/etc/doas.conf`: `permit persist :wheel`.
   * Flags de hardening em binários ativadas (`-fstack-protector-strong`, `-D_FORTIFY_SOURCE=3`, `-Wl,-z,relro,-z,now`).
   * Verificação criptográfica de binários: `FEATURES="binpkg-request-signature getbinpkg parallel-fetch"`.
7. **Serviços de Sistema Ativos no Runlevel Default:**
   * `sysklogd` (logs do sistema)
   * `chronyd` (sincronização de horário)
   * `firewalld` (firewall)
   * `libvirtd` e `virtlogd` (virtualização)
   * `lact` (daemon de controle de GPU)
8. **DNS Quad9 Estrito:**
   * IPv4: `9.9.9.9`, `149.112.112.112`
   * IPv6: `2620:fe::fe`, `2620:fe::9`
   * Criptografia DNS-over-TLS no SO: daemon `stubby` escutando em `127.0.0.1:53`.
   * DNS-over-HTTPS nos navegadores: `https://dns.quad9.net/dns-query`.
9. **Ambiente Gráfico & Wayland:**
   * Totalmente Wayland com suporte a apps legados X11 via **Xwayland**.
   * Window Manager: **`niri`** (tiling scrollable em Rust).
   * Shell e Greeter: **Noctalia Suite** (`noctalia-shell` + `noctalia-greeter` sobre `greetd`).
   * Teste das configurações do Niri no CI via `niri validate` e modo `niri --headless`.
   * Fontes: `media-fonts/noto`, `media-fonts/noto-emoji`, `media-fonts/nerd-fonts`, `media-fonts/fontawesome`.
10. **Navegadores & Senhas:**
    * **Zen Browser:** `www-client/zen-bin` via overlay GURU.
    * **Helium Browser:** AppImage binário oficial de 64 bits (`imputnet/helium-linux`).
    * **KeePassXC:** `app-admin/keepassxc` com importação nativa de cofre JSON do Bitwarden e extensão KeePassXC-Browser.
11. **Desenvolvimento & Produtividade:**
    * **Python & uv:** `dev-lang/python` e `dev-python/uv`.
    * **Editores:** `app-editors/neovim` (compilado) e `app-editors/vscodium-bin` (binário).
    * **LaTeX:** `app-text/texlive-core` (instalação nativa leve).
    * **Diagnóstico:** `btop`, `fastfetch`, `btrfs-assistant`.
12. **Gaming & GPU:**
    * **Steam:** `games-util/steam-launcher` com suporte multilib (`abi_x86_32`).
    * **Protons:** Proton oficial via Steam Play e Proton-CachyOS via `ProtonUp-Qt`.
    * **MangoHud:** Métricas em Wayland/X11.
    * **LACT:** Daemon OpenRC `/etc/init.d/lact` para gerenciamento de curvas de clock, ventoinhas e voltagens da Radeon RX 6600.
13. **Virtualização (QEMU / Libvirt) com Internet Irrestrita via Firewalld:**
    * `firewall_backend = "iptables"` em `/etc/libvirt/network.conf`.
    * `virbr0` e sub-rede `192.168.122.0/24` na zona `trusted` do Firewalld com mascaramento (`masquerade`) ativo.

---

## ⚖️ 4. Estratégia das Duas Abordagens Definida

1. **Modo A (100% Binário para GitHub Actions):**
   * Valida toda a árvore de pacotes, dotfiles e scripts em **3 a 5 minutos** usando o binhost oficial `x86-64-v3` da Fundação Gentoo.
2. **Modo B (Híbrido Inteligente para a Máquina Física):**
   * Compilação nativa com `-march=znver3` para o Kernel (`gentoo-kernel`), Niri, Neovim e ferramentas de sistema.
   * Uso de binários pré-compilados oficiais para pacotes gigantes (`zen-bin`, `vscodium-bin`, `rust-bin`, `helium`).
   * Acompanhamento de tempo de compilação via `genlop -p` e `qlop -t`.

---

## 🔑 5. Informações Pendentes que o Usuário Repassará

Quando o usuário autorizar a execução prática, ele fornecerá:
1. **E-mail e Passphrase da Chave SSH:**  
   Para gerar o par de chaves `~/.ssh/gentoo-aktsu` (`ssh-keygen -t ed25519 -C "<email>" -f ~/.ssh/gentoo-aktsu`).
2. **Dotfiles do Niri:**  
   Arquivo `config.kdl` personalizado que ele já possui para adicionar e testar.
