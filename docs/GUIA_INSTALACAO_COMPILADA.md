# 📖 Guia Passo a Passo: Instalação do Gentoo Linux Compilado (Máquina Real)

Este guia documenta o processo completo para instalar o **Gentoo Linux** compilado da fonte (otimizado com `-march=znver3` e `MAKEOPTS="-j12"`) na máquina física real (AMD Ryzen 5 5600XT + AMD Radeon RX 6600).

---

## 🧭 Especificações da Instalação

* **Arquitetura & CPU:** AMD Ryzen 5 5600XT (Zen 3, `-march=znver3`, 12 threads)
* **GPU:** AMD Radeon RX 6600 (`VIDEO_CARDS="amdgpu radeonsi"`)
* **Init & Profile:** OpenRC (`default/linux/amd64/23.0`)
* **Sistema de Arquivos:** Btrfs com subvolumes (`@`, `@home`, `@var_log`, `@snapshots`)
* **Bootloader:** GRUB 2 em modo UEFI (`GRUB_PLATFORMS="efi-64"`)
* **Display Manager / Greeter:** Ly (`x11-misc/ly` TUI display manager)
* **Ambiente Gráfico:** Niri (Tiling Wayland)

---

## 🛠️ Fase 1: Boot e Particionamento do Disco

Você pode usar qualquer LiveUSB moderno com suporte a UEFI (Gentoo Minimal Installation CD, Arch Linux ou CachyOS).

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
mount /dev/nvme0n1p3 /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@snapshots
umount /mnt

# Opções de montagem com compressão zstd otimizada
MOUNT_OPTS="noatime,compress=zstd:1,space_cache=v2"

mount -o ${MOUNT_OPTS},subvol=@ /dev/nvme0n1p3 /mnt
mkdir -p /mnt/{boot,home,var/log,.snapshots}
mount -o ${MOUNT_OPTS},subvol=@home /dev/nvme0n1p3 /mnt/home
mount -o ${MOUNT_OPTS},subvol=@var_log /dev/nvme0n1p3 /mnt/var/log
mount -o ${MOUNT_OPTS},subvol=@snapshots /dev/nvme0n1p3 /mnt/.snapshots

# Montar partição EFI
mount /dev/nvme0n1p1 /mnt/boot
```

---

## 📦 Fase 2: Download do Stage3 e Preparação do Chroot

### 2.1. Baixar o Stage3 oficial (OpenRC)
```bash
cd /mnt
# Obter o último stage3 openrc
wget https://gentoo.osuosl.org/releases/amd64/autobuilds/current-stage3-amd64-openrc/stage3-amd64-openrc-*.tar.xz
tar xpvf stage3-amd64-openrc-*.tar.xz --xattrs-include='*.*' --numeric-owner
rm stage3-amd64-openrc-*.tar.xz
```

### 2.2. Montar sistemas de arquivos virtuais e entrar no Chroot
```bash
cp --dereference /etc/resolv.conf /mnt/etc/
mount --types proc /proc /mnt/proc
mount --rbind /sys /mnt/sys
mount --make-rslave /mnt/sys
mount --rbind /dev /mnt/dev
mount --make-rslave /mnt/dev
mount --bind /run /mnt/run
mount --make-slave /mnt/run

chroot /mnt /bin/bash
source /etc/profile
export PS1="(chroot) ${PS1}"
```

---

## ⚙️ Fase 3: Aplicar as Configurações do Repositório `gentoo_EXP`

### 3.1. Sincronizar Portage inicial
```bash
emerge-webrsync
```

### 3.2. Clonar o repositório dentro do sistema
```bash
emerge --ask dev-vcs/git
git clone https://github.com/ruanpereira/gentoo_EXP.git /root/gentoo_EXP

# Aplicar configurações de /etc/portage
/root/gentoo_EXP/configs/scripts/sync-portage.sh to-system
```

### 3.3. Configurar Timezone, Locales e Keymap
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

## 🧠 Fase 4: Compilação do Kernel Linux e Firmware

Como temos o Ryzen 5 5600XT (12 threads), a compilação do Distribution Kernel é rápida e determinística:

```bash
# Firmware para GPU AMD Radeon RX 6600 e placa de rede Realtek
emerge --ask sys-kernel/linux-firmware

# Compilação nativa do Kernel com Distribution Kernel
emerge --ask sys-kernel/gentoo-kernel
```

---

## 🥾 Fase 5: Fstab, Bootloader (GRUB UEFI) e Ferramentas Base

### 5.1. Configurar `/etc/fstab` com UUIDs
```bash
emerge --ask sys-fs/btrfs-progs sys-apps/dosfstools

# Obtenha os UUIDs via 'blkid' e configure /etc/fstab:
# UUID=<uuid-nvme0n1p3>  /            btrfs  noatime,compress=zstd:1,subvol=@          0 0
# UUID=<uuid-nvme0n1p3>  /home        btrfs  noatime,compress=zstd:1,subvol=@home      0 0
# UUID=<uuid-nvme0n1p3>  /var/log     btrfs  noatime,compress=zstd:1,subvol=@var_log   0 0
# UUID=<uuid-nvme0n1p3>  /.snapshots  btrfs  noatime,compress=zstd:1,subvol=@snapshots 0 0
# UUID=<uuid-nvme0n1p1>  /boot        vfat   umask=0077                                0 2
# UUID=<uuid-nvme0n1p2>  none         swap   sw                                        0 0
```

### 5.2. Instalação do GRUB 2 (UEFI)
```bash
emerge --ask sys-boot/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Gentoo
grub-mkconfig -o /boot/grub/grub.cfg
```

### 5.3. Rede, Daemons de Sistema, Sessões e Elevação com `doas`
```bash
# Serviços base e gerenciamento de assentos de sessão (elogind)
emerge --ask app-admin/sysklogd net-misc/chrony net-misc/dhcpcd net-firewall/firewalld sys-auth/elogind app-admin/doas

rc-update add sysklogd default
rc-update add chronyd default
rc-update add dhcpcd default
rc-update add firewalld default
rc-update add elogind boot

# Configurar doas
echo "permit persist :wheel" > /etc/doas.conf
chmod 400 /etc/doas.conf
```

---

## 🎨 Fase 6: Ambiente Wayland (Niri), Display Manager (Ly) e Configurações

### 6.1. Drivers Gráficos, Mesa e Niri
```bash
emerge --ask media-libs/mesa x11-libs/libxkbcommon gui-wm/niri

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
```

### 6.2. Instalação e Configuração do Display Manager Ly
O **Ly** é um display manager TUI leve e minimalista mantido no overlay oficial da comunidade (GURU).

```bash
# Habilitar o gerenciador de repositórios e o overlay GURU
emerge --ask app-eselect/eselect-repository
eselect repository enable guru
emaint sync -r guru

# Instalar o Ly
emerge --ask x11-misc/ly

# Habilitar o serviço do Ly no OpenRC
rc-update add ly default

# ⚠️ GARANTIR FUNCIONALIDADE (Evitar conflito de TTY):
# Por padrão, o Ly roda no tty2. O OpenRC executa um agetty no tty2 por padrão no /etc/inittab.
# Se ambos rodarem simultaneamente no mesmo TTY, haverá conflito de tela/teclado.
# Desative o agetty no tty2 comentando a linha c2:
sed -i 's/^c2:/#c2:/' /etc/inittab
rc-update del agetty.tty2 default 2>/dev/null || true
```

### 6.3. Criação de Usuário e Dotfiles do Niri
```bash
# Adicionar usuário aos grupos essenciais (incluindo 'seat' e 'video' para Wayland/Ly)
useradd -m -G wheel,audio,video,input,seat -s /bin/bash usuario
passwd usuario

mkdir -p /home/usuario/.config/niri
cp -r /root/gentoo_EXP/configs/niri/* /home/usuario/.config/niri/
chown -R usuario:usuario /home/usuario/.config
```

---

## 🚀 Fase 7: Conclusão e Reinicialização

```bash
# Sair do chroot e desmontar partições
exit
umount -l /mnt/dev{/shm,/pts,}
umount -R /mnt
reboot
```

Ao reiniciar, seu Gentoo inicializará o display manager **Ly** no TTY2. Basta selecionar a sessão **Niri**, inserir seu login e senha para entrar diretamente no ambiente Wayland sobre Btrfs com snapshots automáticos por transação.
