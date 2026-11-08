# 📖 Guia Passo a Passo: Instalação do Gentoo Linux Binário (Máquina Real)

Este guia documenta o processo completo para instalar o **Gentoo Linux** utilizando pacotes binários oficiais (Binhost `x86-64-v3`, `getbinpkg` e `gentoo-kernel-bin`) na máquina física real (AMD Ryzen 5 5600XT + AMD Radeon RX 6600).

O modo binário permite inicializar e configurar o sistema completo em **poucos minutos** (10 a 15 min), eliminando longas horas de compilação sem abrir mão da flexibilidade do Gentoo.

---

## 🧭 Especificações da Instalação

* **Arquitetura & CPU:** AMD Ryzen 5 5600XT (Zen 3, compatível com conjunto de instruções `x86-64-v3`, 12 threads)
* **GPU:** AMD Radeon RX 6600 (`VIDEO_CARDS="amdgpu radeonsi"`)
* **Init & Profile:** OpenRC (`default/linux/amd64/23.0`)
* **Binhost Oficial:** Repositório oficial do Gentoo `x86-64-v3` via CDN Anycast (`https://distfiles.gentoo.org/releases/amd64/binpackages/23.0/x86-64-v3/`) com verificação criptográfica GPG (`verify-signature = true`, `location = /var/cache/binhost/gentoo` e `FEATURES="binpkg-request-signature getbinpkg parallel-fetch"`)
* **Kernel:** `sys-kernel/gentoo-kernel-bin` (Distribution Kernel oficial pré-compilado com initramfs automatizado)
* **Sistema de Arquivos:** Btrfs com subvolumes (`@`, `@home`, `@var_log`, `@snapshots`) e compressão transparente `zstd:1`
* **Bootloader:** GRUB 2 em modo UEFI (`GRUB_PLATFORMS="efi-64"`)
* **Display Manager / Greeter:** Ly (`x11-misc/ly` TUI display manager)
* **Ambiente Gráfico:** Niri (Tiling Wayland)

---

## 🛠️ Fase 1: Boot e Particionamento do Disco

Você pode utilizar qualquer LiveUSB moderno com suporte a UEFI (Gentoo Minimal Installation CD, Arch Linux ou CachyOS).

### 1.1. Identificar o disco alvo
```bash
lsblk
# Exemplo assumido: /dev/nvme0n1
```

### 1.2. Criar a tabela GPT e partições (`fdisk` ou `parted`)
* **Partição 1 (EFI):** 1 GiB (`type: EFI System`, FAT32)
* **Partição 2 (Swap):** 16 GiB (`type: Linux swap`)
* **Partição 3 (Raiz Btrfs):** Restante do disco (`type: Linux filesystem`)

```bash
# Formatar partição EFI e Swap
mkfs.vfat -F 32 /dev/nvme0n1p1
mkswap /dev/nvme0n1p2
swapon /dev/nvme0n1p2

# Formatar a partição Btrfs
mkfs.btrfs -L gentoo /dev/nvme0n1p3
```

### 1.3. Criar e montar os subvolumes Btrfs
```bash
mkdir -p /mnt/gentoo
mount /dev/nvme0n1p3 /mnt/gentoo
btrfs subvolume create /mnt/gentoo/@
btrfs subvolume create /mnt/gentoo/@home
btrfs subvolume create /mnt/gentoo/@var_log
btrfs subvolume create /mnt/gentoo/@snapshots
umount /mnt/gentoo

# Opções de montagem com compressão zstd otimizada
MOUNT_OPTS="noatime,compress=zstd:1,space_cache=v2"

mount -o ${MOUNT_OPTS},subvol=@ /dev/nvme0n1p3 /mnt/gentoo
mkdir -p /mnt/gentoo/{boot,efi,home,var/log,.snapshots}
mount -o ${MOUNT_OPTS},subvol=@home /dev/nvme0n1p3 /mnt/gentoo/home
mount -o ${MOUNT_OPTS},subvol=@var_log /dev/nvme0n1p3 /mnt/gentoo/var/log
mount -o ${MOUNT_OPTS},subvol=@snapshots /dev/nvme0n1p3 /mnt/gentoo/.snapshots

# Montar partição EFI em /efi (separado de /boot, que permanece no Btrfs)
# Isso permite que /boot seja coberto por snapshots Btrfs (kernels + initramfs incluídos)
mount /dev/nvme0n1p1 /mnt/gentoo/efi
```

---

## 📦 Fase 2: Download do Stage3 e Preparação do Chroot

### 2.1. Baixar o Stage3 oficial (OpenRC com suporte a `x86-64-v3`)
Como o Ryzen 5 5600XT possui suporte a AVX2, FMA3 e BMI2 (`x86-64-v3`), podemos utilizar o tarball otimizado de arquitetura v3 ou o stage3 OpenRC padrão:

```bash
cd /mnt/gentoo

# Tenta baixar o stage3 x86-64-v3 OpenRC (ou stage3 amd64 openrc padrão) via CDN distfiles
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-x86-64-v3-openrc/stage3-amd64-x86-64-v3-openrc-*.tar.xz || \
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-openrc/stage3-amd64-openrc-*.tar.xz

# Descompactar preservando atributos e xattrs
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
rm stage3-*.tar.xz
```

### 2.2. Geração do Fstab e Entrada no Chroot (`arch-chroot`)
Antes de entrar no chroot, copie o DNS e gere automaticamente o arquivo `/etc/fstab` com os UUIDs de todos os subvolumes e partições montados utilizando o utilitário `genfstab` (disponível no LiveUSB do Arch Linux/CachyOS via `arch-install-scripts`):

> [!IMPORTANT]
> O `genfstab` captura **apenas as partições que estão montadas no momento da execução**. Certifique-se de que a partição EFI já está montada em `/mnt/gentoo/efi` antes de prosseguir — caso contrário ela não será incluída no `fstab` gerado e o sistema não conseguirá montar a EFI no boot.
>
> Se necessário, monte-a agora:
> ```bash
> # Verificar se a EFI já está montada
> mount | grep /mnt/gentoo/efi
>
> # Se não estiver, montar (ajuste o dispositivo conforme seu disco)
> mount /dev/nvme0n1p1 /mnt/gentoo/efi
> ```

```bash
# Copiar configuração de DNS
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

# Gerar o /etc/fstab automaticamente por UUID
genfstab -U /mnt/gentoo >> /mnt/gentoo/etc/fstab

# Entrar no chroot
arch-chroot /mnt/gentoo
source /etc/profile
export PS1="(chroot) ${PS1}"
```

---

## ⚙️ Fase 3: Aplicar as Configurações do Repositório `gentoo_EXP` e Binhost

### 3.1. Sincronizar o repositório Portage inicial
```bash
emerge-webrsync
```

### 3.2. Clonar o repositório dentro do sistema
```bash
emerge --ask --getbinpkg dev-vcs/git
git clone https://github.com/ruanpereira/gentoo_EXP.git /root/gentoo_EXP
```

### 3.3. Executar o bootstrap binário automatizado
O repositório já inclui um script dedicado que configura o `make.conf`, adiciona o `/etc/portage/binrepos.conf/gentoobinhost.conf`, ajusta flags e atualiza o sistema utilizando o binhost:

```bash
# Executa a configuração completa e atualização do @world via binhost:
/root/gentoo_EXP/configs/scripts/bootstrap-binary.sh
```

> **Nota (Alternativa Manual):** Se preferir aplicar manualmente sem o script:
> ```bash
> /root/gentoo_EXP/configs/scripts/sync-portage.sh to-system
> emerge --verbose --update --deep --newuse --getbinpkg @world
> ```

### 3.4. Configurar Timezone, Locales e Keymap
```bash
echo "America/Fortaleza" > /etc/timezone
emerge --config sys-libs/timezone-data

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "pt_BR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set en_US.UTF-8
env-update && source /etc/profile

sed -i 's/keymap=".*"/keymap="us"/' /etc/conf.d/keymaps
```

---

## 🧠 Fase 4: Kernel Linux Pré-compilado (`gentoo-kernel-bin`) e Firmware

Diferente do modo compilado, o pacote `sys-kernel/gentoo-kernel-bin` é baixado instantaneamente já compilado pelos mantenedores do Gentoo, gerando o initramfs via Dracut de forma 100% automática:

```bash
# Firmware para GPU AMD Radeon RX 6600 e interface Realtek 2.5GbE
emerge --ask --getbinpkg sys-kernel/linux-firmware

# Distribution Kernel pré-compilado oficial (instalação instantânea)
emerge --ask --getbinpkg sys-kernel/gentoo-kernel-bin
```

---

## 🥾 Fase 5: Fstab, Bootloader (GRUB UEFI) e Ferramentas Base

### 5.1. Ferramentas de Sistema de Arquivos e Verificação do `/etc/fstab`
Como o `/etc/fstab` foi gerado na Fase 2.2 com o utilitário `genfstab`, todos os UUIDs dos subvolumes Btrfs (`@`, `@home`, `@var_log`, `@snapshots`), partição EFI (`/efi`) e Swap já estão mapeados.

Instale as ferramentas de suporte a filesystem e valide o conteúdo do arquivo:

```bash
# Instalar utilitários de filesystem
emerge --ask --getbinpkg sys-fs/btrfs-progs sys-fs/dosfstools

# Visualizar e conferir o fstab gerado:
cat /etc/fstab
```

### 5.2. Instalação do GRUB 2 (UEFI)
```bash
emerge --ask --getbinpkg sys-boot/grub
grub-install --target=x86_64-efi --efi-directory=/efi --boot-directory=/boot --bootloader-id=Gentoo
grub-mkconfig -o /boot/grub/grub.cfg
```

### 5.3. Rede, Daemons de Sistema, Sessões e Elevação com `doas`
```bash
# Daemons base, gerenciamento de assentos (elogind) e ferramentas essenciais
emerge --ask --getbinpkg app-admin/sysklogd net-misc/chrony net-misc/dhcpcd net-firewall/firewalld sys-auth/elogind app-admin/doas

rc-update add sysklogd default
rc-update add chronyd default
rc-update add dhcpcd default
rc-update add firewalld default
rc-update add elogind boot

# Configurar permissões do doas
echo "permit persist :wheel" > /etc/doas.conf
chmod 400 /etc/doas.conf
```

---

## 🎨 Fase 6: Ambiente Wayland (Niri), Display Manager (Ly) e Configurações

### 6.1. Habilitar o Repositório Comunitário GURU
O compositor **Niri**, o display manager **Ly**, o utilitário **brightnessctl**, o **xwayland-satellite** e o cliente Discord **Vesktop** (`net-im/vesktop-bin`) são mantidos no repositório comunitário oficial do Gentoo (**GURU**). Como as palavras-chave `~amd64` já foram adicionadas em `/etc/portage/package.accept_keywords/` na Fase 3, basta habilitar e sincronizar o GURU:

```bash
# Habilitar gerenciador de repositórios e sincronizar o overlay GURU
emerge --ask --getbinpkg app-eselect/eselect-repository
eselect repository enable guru
emaint sync -r guru
```

### 6.2. Drivers Gráficos, Mesa, Niri, Display Manager Ly, XWayland e Utilitários
Instale a stack gráfica, interface e suporte a apps X11 legados. Componentes base e drivers Mesa serão obtidos via binários rápidos; Niri, Ly, brightnessctl e xwayland-satellite serão instalados/compilados utilizando as definições do overlay GURU:

```bash
emerge --ask --getbinpkg media-libs/mesa x11-libs/libxkbcommon gui-wm/niri x11-misc/ly app-misc/brightnessctl gui-apps/xwayland-satellite x11-base/xwayland

# Garantir a sessão Wayland para que o Ly detecte o Niri automaticamente
mkdir -p /usr/share/wayland-sessions
cat << 'EOF' > /usr/share/wayland-sessions/niri.desktop
[Desktop Entry]
Name=Niri
Comment=Scrollable-tiling Wayland compositor
Exec=niri-session
Type=Application
DesktopNames=niri
EOF

# Habilitar o serviço do Ly no OpenRC
rc-update add ly default

# ⚠️ GARANTIR FUNCIONALIDADE (Evitar conflito de TTY):
# Por padrão, o Ly roda no tty2. O OpenRC executa um agetty no tty2 por padrão no /etc/inittab.
# Se ambos rodarem simultaneamente no mesmo TTY, ocorrerá conflito de input e tela preta.
# Desative o agetty no tty2 comentando a linha c2:
sed -i 's/^c2:/#c2:/' /etc/inittab
rc-update del agetty.tty2 default 2>/dev/null || true
```

> **Dica:** O Portage busca pacotes binários no binhost oficial. Caso algum pacote possua USE flags personalizadas exclusivas que não batam com o binhost oficial, o Portage compilará apenas aquele pacote pontualmente em segundo plano graças aos 12 threads do Ryzen 5 5600XT.

### 6.3. Subsistema de Áudio (PipeWire + WirePlumber) e Mixer (Pavucontrol)
O subsistema de som é inteiramente operado pelo **PipeWire** em conjunto com o gerenciador de sessões **WirePlumber**, fornecendo emulação de ALSA e PulseAudio (`pipewire-pulse`). A interface gráfica de controle é o **Pavucontrol**:

```bash
emerge --ask --getbinpkg media-video/pipewire media-video/wireplumber media-sound/pavucontrol
```

> **Nota (OpenRC):** No Gentoo com OpenRC, o PipeWire é iniciado por sessão de usuário. As configurações em `configs/niri/cfg/autostart.kdl` já invocam automaticamente o `gentoo-pipewire-launcher` na inicialização do Niri.

### 6.4. Compartilhamento de Tela (OBS/Navegadores) e Comunicação (Vesktop)
Para viabilizar captura de tela e áudio no Niri via PipeWire (para OBS Studio, Discord e navegadores), instale o XDG Desktop Portal com backend GNOME e o cliente Vesktop:

```bash
# Instalar XDG Desktop Portal, backend GNOME e Vesktop
emerge --ask --getbinpkg sys-apps/xdg-desktop-portal sys-apps/xdg-desktop-portal-gnome net-im/vesktop-bin

# Configurar roteamento do portal para o Niri
mkdir -p /etc/xdg/xdg-desktop-portal
cat << 'EOF' > /etc/xdg/xdg-desktop-portal/niri-portals.conf
[preferred]
default=gnome
org.freedesktop.impl.portal.ScreenCast=gnome
EOF
```

### 6.5. Criação do Usuário e Aplicação dos Dotfiles do Niri
```bash
# Criar usuário com permissões completas de hardware, vídeo, áudio, pipewire e sessões (seat)
useradd -m -G wheel,audio,pipewire,video,input,seat -s /bin/bash usuario
passwd usuario

mkdir -p /home/usuario/.config/niri
cp -r /root/gentoo_EXP/configs/niri/* /home/usuario/.config/niri/
chown -R usuario:usuario /home/usuario/.config
```

---

## 🔍 Fase 7: Validação e Testes das Configurações

Antes de reiniciar, você pode executar o script de teste de integridade incluído no repositório:

```bash
/root/gentoo_EXP/configs/scripts/test-configs.sh
```

Este comando verifica a sintaxe do `make.conf`, valida os diretórios do Portage e simula o cálculo de dependências do binhost sem erros.

---

## 🚀 Fase 8: Conclusão e Reinicialização

```bash
# Sair do chroot e desmontar partições de forma limpa
exit
umount -l /mnt/gentoo/dev{/shm,/pts,} 2>/dev/null || true
umount -R /mnt/gentoo
reboot
```

Ao reiniciar, seu Gentoo estará operacional em minutos, equipado com:
* Display Manager **Ly** no TTY2 com seleção imediata da sessão Wayland **Niri**;
* Binhost oficial `x86-64-v3` pronto para instalar softwares pesados (`rust-bin`, `vscodium-bin`, `zen-bin`, `steam`) em segundos;
* Distribution Kernel binário gerenciado automaticamente com Dracut;
* Snapshots automáticos Btrfs via hook em `/etc/portage/bashrc` a cada execução do `emerge`;
* Gerenciamento de assento e sessões aceleradas via `elogind` e Mesa Radeon RX 6600.
