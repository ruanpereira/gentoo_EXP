# Plano de Implementação: Gentoo Linux (v3, Btrfs Snapshots, Binário & Compilado)

Este documento estabelece a especificação completa e o plano de implementação do sistema operacional Gentoo Linux sob medida para as preferências definidas, contendo duas trilhas operacionais: **Modo Binário (CI & Bootstrap Rápido)** e **Modo Compilação Otimizada (Hardware Específico)**.

---

## 🧭 1. Resumo das Decisões de Arquitetura

| Componente | Especificação Definida | Detalhes Técnicos |
| :--- | :--- | :--- |
| **Init System** | **OpenRC** | Padrão clássico Gentoo, inicialização leve e determinística |
| **Profile** | **Default 23.0 (amd64)** | `default/linux/amd64/23.0` (sem perfil pré-fabricado desktop/server) |
| **Kernel** | **Distribution Kernel** | `sys-kernel/gentoo-kernel` (ou `-bin` para modo binário) |
| **Bootloader** | **GRUB 2 (UEFI)** | `GRUB_PLATFORMS="efi-64"`, montagem em `/boot` ou `/boot/efi` |
| **Filesystem** | **Btrfs com Subvolumes** | Subvolumes `@`, `@home`, `@var_log`, `@snapshots` |
| **Snapshots** | **Automáticos Pós-`emerge`** | Hook no Portage cria snapshot Btrfs somente após a conclusão da atualização do sistema |
| **Microarquitetura** | **x86-64-v3** | CPU flags AVX/AVX2/BMI2. Suportado nativamente tanto em binário quanto compilação |
| **Binhost Oficial** | **Gentoo v3 Binpackages** | `https://gentoo.osuosl.org/releases/amd64/binpackages/23.0/x86-64-v3/` |
| **Segurança & Assinaturas** | **Hardening & GPG** | `FEATURES="binpkg-request-signature getbinpkg"`, flags seguras de compilação |
| **Licenças** | **Flexível com Proprietários** | `ACCEPT_LICENSE="*"` ou `@FREE @BINARY-REDISTRIBUTABLE` + `/etc/portage/package.license` |
| **Elevação de Acesso** | **doas** | `app-admin/doas` configurado com `permit persist :wheel` |
| **Display Server & WM** | **Wayland + XWayland** | `gui-wm/niri` (tiling/scrollable) com suporte a apps X11 |
| **Desktop Shell & Greeter**| **Noctalia Suite** | `noctalia-shell` + `noctalia-greeter` sobre `gui-libs/greetd` |
| **Navegadores & Senhas**| **Zen, Helium & KeePassXC** | `zen-bin`, `helium` (AppImage/binário oficial) e `keepassxc` |
| **Gaming & GPU** | **Steam, Proton, LACT** | `games-util/steam-launcher`, MangoHud, Proton-CachyOS, `sys-power/lact` |
| **Utilitários & Monitor** | **btop, fastfetch, btrfs-assistant**| Diagnóstico, telemetria e gerenciamento gráfico de snapshots Btrfs |
| **Virtualização & Firewall**| **QEMU, Libvirt & Firewalld** | `app-emulation/libvirt`, `virt-manager`, rede NAT irrestrita via OpenRC |
| **Controle de Versão** | **Git & SSH dedicado** | `dev-vcs/git`, par de chaves Ed25519 nomeado `gentoo-aktsu`, commits via SSH |
| **Logs & NTP** | **sysklogd** & **chrony** | `app-admin/sysklogd` e `net-misc/chrony` habilitados no runlevel `default` |
| **Localização** | **EN / Fortaleza / Console US**| Idioma: `en_US.UTF-8` \| Timezone: `America/Fortaleza` \| Teclado inicial console `us` |

---

## 🔍 2. Repositório Binário `x86-64-v3` no Gentoo (Comparação com CachyOS)

> [!NOTE]
> **Sim! O Gentoo possui repositório oficial `x86-64-v3`**, exatamente com a mesma proposta do repositório `v3` do CachyOS no Arch Linux.
> 
> A Gentoo Foundation mantém árvores binárias oficiais compiladas com instruções modernas (AVX, AVX2, BMI1, BMI2, FMA) para CPUs a partir de Intel Haswell (2013+) e AMD Excavator/Zen (2015+).
> 
> * **Binhost URL (OpenRC):**  
>   `https://gentoo.osuosl.org/releases/amd64/binpackages/23.0/x86-64-v3/`
> * **Assinatura Criptográfica:**  
>   Todos os pacotes são validados pela chave GPG oficial de lançamento do Gentoo (`gentoo-keys`).

---

## 📊 3. Informações Necessárias da Máquina Física para Compilação Nativa

Quando formos configurar o **Modo Compilação Otimizada**, você precisará coletar e repassar os seguintes dados da máquina física:

```bash
# 1. Informações de CPU e instruções suportadas:
lscpu

# 2. Flag de otimização nativa do GCC detectada pelo compilador:
gcc -march=native -Q --help=target | grep -E "march|mtune"

# 3. Quantidade de núcleos / threads para o MAKEOPTS:
nproc

# 4. Memória RAM e Swap disponível (para definir uso de tmpfs/zram na compilação):
free -h

# 5. Placas de vídeo / GPU (para definir VIDEO_CARDS no make.conf):
lspci -nnk | grep -iA3 "vga\|3d\|display"

# 6. Adaptadores de rede e Wi-Fi (para determinar pacotes de linux-firmware necessários):
lspci -nnk | grep -iA3 "network\|ethernet"
```

---

## 📁 4. Estrutura das Configurações do Portage (`configs/portage/`)

### `make.conf` (Híbrido com suporte a v3, Hardening e Binários Assinados)
```make
# Compiler Flags otimizadas para o Ryzen 5 5600XT detectado (Zen 3)
# No modo compilado nativo: -march=znver3 (ou -march=x86-64-v3 para binários)
COMMON_FLAGS="-O2 -pipe -march=znver3 -fstack-protector-strong -D_FORTIFY_SOURCE=3 -Wl,-z,relro -Wl,-z,now"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"

# Paralelismo de Compilação (12 threads do Ryzen 5 5600XT)
MAKEOPTS="-j12"

# Driver de Vídeo Dedicado para AMD Radeon RX 6600 (Navi 23 / RDNA 2)
VIDEO_CARDS="amdgpu radeonsi"

# Recursos do Portage: Verificação GPG de binários e download automático
FEATURES="binpkg-request-signature getbinpkg parallel-fetch"

# URL do Binhost oficial x86-64-v3 para OpenRC Profile 23.0
BINHOST="https://gentoo.osuosl.org/releases/amd64/binpackages/23.0/x86-64-v3/"

# Licenças: Base livre/redistribuível, com permissões para software proprietário
ACCEPT_LICENSE="* -@EULA"

# USE Flags globais sem perfil desktop/server pré-fixado
USE="elogind udev dbus btrfs audit seccomp caps -systemd"

# Configuração de Plataforma GRUB
GRUB_PLATFORMS="efi-64"

# Idioma da saída do sistema
LC_MESSAGES=C.utf8
```

---

## 📸 5. Estratégia de Btrfs com Snapshots por `emerge`

### Subvolumes Recomendados:
* `@` montado em `/`
* `@home` montado em `/home`
* `@var_log` montado em `/var/log` (para que reverter o sistema não perca histórico de logs)
* `@snapshots` montado em `/.snapshots`

### Mecanismo de Snapshot Automático:
Adicionar um hook em `/etc/portage/bashrc` que executa antes e depois de cada compilação/instalação de pacotes:

```bash
# /etc/portage/bashrc (ou hook pré/pós-instalação)
pre_pkg_setup() {
    if [[ ! -f /tmp/.portage_snapshot_taken ]]; then
        DATE=$(date +%Y%m%d_%H%M%S)
        btrfs subvolume snapshot -r / "/.snapshots/pre-emerge-${DATE}" 2>/dev/null || true
        touch /tmp/.portage_snapshot_taken
    fi
}

post_pkg_postinst() {
    # Limpeza de flag temporária
    rm -f /tmp/.portage_snapshot_taken
}
```

---

## 🛠️ 6. Configurações de Sistema Específicas

### Elevação com `doas` (`/etc/doas.conf`)
```text
permit persist :wheel
```

### Daemon de Horário (`chrony`) e Logs (`sysklogd`)
```bash
rc-update add sysklogd default
rc-update add chronyd default
```

### Timezone e Localização
```bash
echo "America/Fortaleza" > /etc/timezone
emerge --config sys-libs/timezone-data

# Locales em /etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "pt_BR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set en_US.UTF-8

# Teclado no Console OpenRC (/etc/conf.d/keymaps)
keymap="us"              # Layout padrão inicial no boot do terminal (TTY)
# Configuração de chaveamento de teclado será definida no ambiente gráfico Wayland (Niri/Noctalia) posteriormente.
```

---

## 🎨 7. Ecossistema Wayland: Niri, Noctalia, Zen Browser e KeePassXC

### 7.1. Compositor & Shell
* **Window Manager:** `gui-wm/niri` (tiling/scrollable em Rust) com flag `USE="xwayland"` para compatibilidade com apps legados.
* **Desktop Shell & Greeter:** `noctalia-shell` + `noctalia-greeter` integrado via `gui-libs/greetd`.
* **Instalação das Fontes do Sistema:**
  ```bash
  emerge --ask \
    media-fonts/noto \
    media-fonts/noto-emoji \
    media-fonts/nerd-fonts \
    media-fonts/fontawesome
  ```

### 7.2. Validação das Configurações do Niri no GitHub Actions
> [!TIP]
> **Sim, é totalmente possível testar suas configs do Niri no CI!**
> 
> O Niri possui suporte nativo para validação e execução headless:
> 1. **Validação de Sintaxe e Regras:** `niri validate -c configs/niri/config.kdl` (garante que nenhum bind, regra de janela ou parâmetro esteja quebrado).
> 2. **Teste Headless:** O CI pode instanciar o Niri em modo sem tela (`niri --headless`) dentro do runner, disparando e fechando o processo para garantir que a sessão inicia sem *panics* ou erros de inicialização de IPC.

### 7.3. Zen Browser no Gentoo
O Zen Browser está disponível no repositório de overlays oficial da comunidade (**GURU**) como pacote binário oficial:
```bash
eselect repository enable guru
emaint sync -r guru
echo "www-client/zen-bin ~amd64" >> /etc/portage/package.accept_keywords/zen
emerge --ask www-client/zen-bin
```

### 7.4. Helium Browser no Gentoo
> [!NOTE]
> **Sim, é totalmente possível utilizar o Helium Browser no Gentoo!**
> 
> O Helium (`imputnet/helium-linux`) é um fork minimalista e focado em privacidade do Chromium com *uBlock Origin* embutido. Como compilar o Chromium do zero demanda horas de CPU, a forma oficial e recomendada pelos desenvolvedores é a versão binária empacotada / AppImage nativo:
> ```bash
> # Download do release binário oficial x86_64:
> HELIUM_VER=$(curl -s https://api.github.com/repos/imputnet/helium-linux/releases/latest | grep "tag_name" | cut -d '"' -f 4)
> wget "https://github.com/imputnet/helium-linux/releases/download/${HELIUM_VER}/helium-${HELIUM_VER}-x86_64.AppImage" -O /usr/local/bin/helium
> chmod +x /usr/local/bin/helium
> ```
> O navegador funciona de forma rápida e integrada com suporte completo a Wayland (`--ozone-platform-hint=auto`).

### 7.5. Migração Bitwarden -> KeePassXC
A migração é **100% direta, segura e nativa**:
1. **Instalação:** `emerge --ask app-admin/keepassxc`
2. **Exportação no Bitwarden:** *Cofre -> Configurações -> Exportar Cofre* (selecione o formato `.json`).
3. **Importação no KeePassXC:** Vá em *Banco de Dados -> Importar -> Do Bitwarden (JSON)*. O KeePassXC mapeia automaticamente todas as credenciais, URLs, notas seguras, campos personalizados e chaves TOTP (2FA).
4. **Integração no Zen Browser:** Habilite o suporte ao *KeePassXC-Browser* nas configurações do KeePassXC e instale a extensão no Zen Browser. As senhas serão preenchidas automaticamente sem depender de servidores em nuvem.

---

## 🔑 8. Controle de Versão: Git e Chave SSH (`gentoo-aktsu`)

Todos os commits e sincronizações com o GitHub serão autenticados via SSH com par de chaves dedicado:

### 8.1. Instalação do Git
```bash
emerge --ask dev-vcs/git
```

### 8.2. Geração da Chave SSH (`gentoo-aktsu`)
```bash
# Será gerada com o e-mail e passphrase que você repassar:
ssh-keygen -t ed25519 -C "seu-email@exemplo.com" -f ~/.ssh/gentoo-aktsu
```

### 8.3. Configuração de Host SSH (`~/.ssh/config`)
Garante que qualquer interação com o `github.com` utilize a chave dedicada com permissões restritas (`chmod 600 ~/.ssh/config`):
```text
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/gentoo-aktsu
    IdentitiesOnly yes
```

### 8.4. Configuração Global do Git
```bash
git config --global user.name "gentoo-aktsu"
git config --global user.email "seu-email@exemplo.com"
git config --global init.defaultBranch main

# Configurar o repositório local para utilizar a URL SSH:
git remote set-url origin git@github.com:seu-usuario/gentoo_EXP.git
```

---

## 🎮 9. Stack de Jogos e Controle de GPU

### 9.1. Steam e Suporte Multilib (32-bit)
A Steam requer suporte a binários de 32 bits no Gentoo:
```bash
# Habilita suporte multilib para bibliotecas essenciais de jogos
echo "games-util/steam-launcher ~amd64" >> /etc/portage/package.accept_keywords/steam
echo "games-util/steam-launcher steamruntime" >> /etc/portage/package.use/steam

emerge --ask games-util/steam-launcher
```

### 9.2. Proton Oficial e Proton-CachyOS
* **Proton Oficial / Experimental:** Gerenciado diretamente pela interface nativa da Steam (*Steam Play*).
* **Proton-CachyOS (Patches de performance e Wine moderno):** Instalado e atualizado via **`games-util/protonup-qt`** (disponível no GURU) ou baixado direto nos builds oficiais do CachyOS em `~/.steam/root/compatibilitytools.d/`.

### 9.3. MangoHud (Métricas na Tela em Wayland/X11)
```bash
echo "games-util/mangohud ~amd64" >> /etc/portage/package.accept_keywords/mangohud
echo "games-util/mangohud wayland" >> /etc/portage/package.use/mangohud
emerge --ask games-util/mangohud
```

### 9.4. LACT (Controle, Overclock e Monitoramento de GPU)
O **LACT** (*Linux AMD/Intel/Nvidia Control Tool*) necessita de um daemon em segundo plano com privilégios de root para controlar voltagens, fans e clocks:
```bash
# Instalação do LACT (disponível no overlay GURU)
emerge --ask app-misc/lact

# Serviço OpenRC dedicado para o daemon do LACT:
cat << 'EOF' > /etc/init.d/lact
#!/sbin/openrc-run
description="LACT GPU Control Daemon"
command="/usr/bin/lact"
command_args="daemon"
command_background=true
pidfile="/run/lact.pid"
EOF
chmod +x /etc/init.d/lact

rc-update add lact default
rc-service lact start
```

---

## 💻 10. Utilitários do Sistema, Virtualização e Firewall (OpenRC)

### 10.1. Diagnóstico, Utilitários e Desenvolvimento
Instalação dos pacotes solicitados:
```bash
emerge --ask \
  sys-process/btop \
  app-misc/fastfetch \
  sys-fs/btrfs-assistant \
  net-firewall/firewalld \
  app-editors/neovim \
  app-editors/vscodium-bin \
  app-text/texlive-core \
  dev-lang/python \
  dev-python/uv
```
* **Python & uv:** Interpretador Python nativo (`dev-lang/python`) e `uv` (`dev-python/uv`), gerenciador ultrarrápido em Rust para substituição do `pip`/`venv`.
* **VSCodium:** Versão binária oficial (`app-editors/vscodium-bin` via GURU) para evitar compilar todo o Electron do zero.
* **Neovim:** Editor nativo moderno (`app-editors/neovim`), compilado em ~30 segundos.
* **LaTeX (TexLive básico):** `app-text/texlive-core` provê `pdflatex`, bibliotecas essenciais e fontes sem baixar gigabytes de documentação desnecessária.
* **Btrfs Assistant:** Interface GUI completa para visualizar subvolumes, status de espaço e restaurar snapshots Btrfs.
* **Firewalld:** Serviço ativado no OpenRC:
  ```bash
  rc-update add firewalld default
  rc-service firewalld start
  ```

### 10.2. Virtualização: QEMU + Libvirt (com Internet Irrestrita via Firewalld)
Para garantir que as máquinas virtuais acessem a internet perfeitamente sob OpenRC e Firewalld:

1. **Instalação do QEMU e Virt-Manager:**
   ```bash
   emerge --ask app-emulation/qemu app-emulation/libvirt app-emulation/virt-manager
   ```

2. **Configuração de backend de firewall do Libvirt:**
   ```bash
   echo 'firewall_backend = "iptables"' >> /etc/libvirt/network.conf
   ```

3. **Permissões de usuário:**
   ```bash
   usermod -aG libvirt,kvm usuario
   ```

4. **Ativação dos serviços no OpenRC (equivalente aos sockets/services do systemd):**
   ```bash
   rc-update add virtlogd default
   rc-update add libvirtd default
   rc-service virtlogd start
   rc-service libvirtd start
   ```

5. **Inicialização automática da rede virtual padrão:**
   ```bash
   virsh net-autostart default
   virsh net-start default
   ```

6. **Regras no Firewalld (Equivalente ao trânsito irrestrito do UFW):**
   Diferente do UFW, no Firewalld adicionamos a interface de bridge do libvirt (`virbr0`) e a sub-rede `192.168.122.0/24` diretamente à zona `trusted` com *masquerading* habilitado, garantindo rota completa sem bloqueios:
   ```bash
   # Permitir interface virbr0 e sub-rede do QEMU na zona trusted:
   firewall-cmd --permanent --zone=trusted --add-interface=virbr0
   firewall-cmd --permanent --zone=trusted --add-source=192.168.122.0/24

   # Habilitar masquerading (NAT) para saída à Internet:
   firewall-cmd --permanent --zone=trusted --add-masquerade

   # Aplicar alterações no firewall:
   firewall-cmd --reload
   ```

### 10.3. Configuração de DNS Quad9 (IPv4, IPv6, DoT e DoH)

Para assegurar privacidade e proteção contra domínios maliciosos em todo o sistema:

1. **Servidores Primários do Sistema (`/etc/resolv.conf`):**
   ```text
   # Quad9 IPv4
   nameserver 9.9.9.9
   nameserver 149.112.112.112

   # Quad9 IPv6
   nameserver 2620:fe::fe
   nameserver 2620:fe::9

   options edns0 single-request-reopen
   ```

2. **Bloqueio de Sobrescrita pelo DHCP (`/etc/resolvconf.conf` ou NetworkManager):**
   ```ini
   # Evita que o roteador/DHCP sobrescreva o DNS da Quad9
   resolv_conf_options="edns0 single-request-reopen"
   name_servers="9.9.9.9 149.112.112.112 2620:fe::fe 2620:fe::9"
   ```

3. **Criptografia Global no SO via DNS-over-TLS (DoT):**
   Instalação do daemon leve **Stubby** (`net-dns/stubby`):
   * Aponta para `tls://dns.quad9.net` na porta 853 com autenticação de certificado TLS.
   * Roda localmente em `127.0.0.1:53` sob OpenRC (`rc-update add stubby default`).

4. **DNS-over-HTTPS (DoH) nos Navegadores (Zen e Helium):**
   * Configurado nas preferências de rede/segurança com o endpoint oficial:
     `https://dns.quad9.net/dns-query`

---

## 🤖 11. Comparativo das Duas Abordagens: CI (100% Binário) vs Máquina Física (Híbrido)

### 11.1. Modo A: 100% Binário (Para GitHub Actions / CI)
* **Objetivo:** Validação contínua do sistema, scripts e dotfiles sem estourar tempo de CPU.
* **Mecanismo:** `gentoo/stage3:latest` + `FEATURES="getbinpkg binpkg-request-signature"` + Binhost oficial `x86-64-v3`.
* **Tempo de Execução:** Entre **3 a 5 minutos** por workflow.

---

### 11.2. Modo B: Híbrido Inteligente (Para a sua Máquina Física - Ryzen 5 5600XT)
* **Objetivo:** Máxima performance onde importa (Kernel e aplicações de uso frequente com `-march=znver3`), sem perder tempo compilando navegadores ou engines gigantes.

#### O que é compilado da fonte (`-march=znver3`):
* Kernel Linux (`sys-kernel/gentoo-kernel` com flags de áudio/GPU/btrfs)
* Compositor e Window Manager (`gui-wm/niri`)
* Editores e CLI (`app-editors/neovim`, `fastfetch`, `btop`, `git`, ferramentas de sistema)

#### O que usa binário pré-compilado:
* Navegadores e Electron: `zen-bin`, `helium` (AppImage), `vscodium-bin`
* Toolchains pesados: `dev-lang/rust-bin` (evita 45 min de compilação)
* Jogos: `games-util/steam-launcher` (binários nativos de 32/64 bits)

---

## ⏱️ 12. Métrica e Detecção de "Pacotes Gigantes" em Tempo Real

No Gentoo, existe uma infraestrutura pronta para você medir e decidir dinamicamente se quer compilar ou usar binário:

### 12.1. Ferramentas Nativas de Telemetria (`qlop` e `genlop`)
O Portage registra cada segundo de compilação no log do sistema (`/var/log/emerge.log`). Instalamos o utilitário leve:
```bash
emerge --ask app-portage/portage-utils app-portage/genlop
```

* **Estimar tempo antes de compilar:**
  ```bash
  genlop -p <nome-do-pacote>
  ```
  *(Calcula o tempo previsto com base na velocidade média dos núcleos do seu Ryzen 5600XT).*

* **Consultar tempo gasto em compilações passadas:**
  ```bash
  qlop -t <nome-do-pacote>
  ```

* **Acompanhar compilação em andamento em outro terminal:**
  ```bash
  qlop -c
  ```
  *(Exibe a porcentagem estimada e tempo restante para o pacote que está sendo compilado no momento).*

### 12.2. A Métrica de Classificação de "Pacote Gigante"
Definimos um pacote como gigante quando ele se enquadra em pelo menos um destes critérios:
1. **Tempo de Compilação > 15-20 minutos** em 12 threads.
2. **Consumo de Memória > 2 GB por thread de compilação** (ex: LLVM, Chromium ou WebKit, que com 12 threads poderiam estourar os 16 GB de RAM e forçar swap).
3. **Existência de variante `-bin` oficial mantida no Gentoo** (`rust-bin`, `vscodium-bin`, `zen-bin`).

### 12.3. Controle Dinâmico via Portage
Você pode decidir no momento da instalação:
* Se quiser baixar binário pronto:
  ```bash
  emerge --ask --getbinpkg <pacote>
  ```
* Se quiser forçar compilação nativa da fonte:
  ```bash
  emerge --ask --buildpkg --usepkg=n <pacote>
  ```

---

## 🚀 13. Repositório GitHub (`gentoo_EXP`), Estrutura de Pastas e Automação de CI

### 13.1. Identificação do Repositório
* **Nome do Repositório:** `gentoo_EXP`
* **Visibilidade:** Público ou Privado
* **Autenticação de Push:** Exclusivamente via SSH com a chave `gentoo-aktsu` (`git@github.com:<usuario>/gentoo_EXP.git`)

### 13.2. Estrutura de Pastas para a Instalação Binária e CI
```text
gentoo_EXP/
├── .github/
│   └── workflows/
│       └── ci-gentoo.yml            # Pipeline de validação binária contínua
├── configs/
│   ├── portage/                    # Configurações replicáveis em /etc/portage/
│   │   ├── make.conf               # CFLAGS (znver3/v3), MAKEOPTS (-j12), FEATURES
│   │   ├── bashrc                  # Hook automático de snapshots Btrfs
│   │   ├── package.use/            # USE flags por pacote (steam, mangohud, wayland)
│   │   ├── package.accept_keywords/# Desmascaramento (~amd64) para zen, lact, etc.
│   │   └── package.license         # Licenças aceitas
│   └── scripts/
│       ├── bootstrap-binary.sh     # Script para instalação rápida via binhost oficial
│       └── sync-system.sh          # Sincroniza configurações locais <-> repositório
├── docs/                           # Documentação das decisões de arquitetura
├── .gitignore                      # Regras para evitar arquivos pesados e temporários
└── README.md                       # Documentação principal derivada deste plano
```

### 13.3. Conteúdo Definido para o `.gitignore`
```gitignore
# Arquivos de imagem e tarballs pesados
*.iso
*.tar.xz
*.tar.gz
*.tar.bz2
*.img
*.qcow2

# Árvore temporária de compilação e caches do Portage
distfiles/
packages/
rootfs/
tmp/
.cache/

# Ambientes virtuais Python (uv / venv)
.venv/
__pycache__/
*.pyc

# Chaves privadas e credenciais (NUNCA commitadas)
*.key
*.priv
id_ed25519
id_rsa
gentoo-aktsu
!gentoo-aktsu.pub

# Metadados de editores e OS
.DS_Store
Thumbs.db
*.swp
*~
.idea/
.vscode/
```

### 13.4. Workflow do GitHub Actions (`.github/workflows/ci-gentoo.yml`)
Este workflow roda em container oficial Gentoo Stage3 com o binhost oficial ativado, validando todas as configurações em poucos minutos:
```yaml
name: Gentoo CI - Validação Binária & Regras

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  validate-binary-install:
    runs-on: ubuntu-latest
    container:
      image: gentoo/stage3:latest
    steps:
      - name: Checkout do Repositório
        uses: actions/checkout@v4

      - name: Sincronização Leve do Portage
        run: emerge-webrsync

      - name: Aplicar Configurações e USE Flags
        run: |
          cp configs/portage/make.conf /etc/portage/make.conf
          mkdir -p /etc/portage/package.use /etc/portage/package.accept_keywords
          cp -r configs/portage/package.use/* /etc/portage/package.use/ || true
          cp -r configs/portage/package.accept_keywords/* /etc/portage/package.accept_keywords/ || true

      - name: Validar Resolução de Pacotes e Binários Oficiais (@world)
        run: |
          emerge --pretend --verbose --deep --newuse --getbinpkg @world
```
