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

### 2.1. Baixar o Stage3 oficial (OpenRC)
```bash
cd /mnt/gentoo
# Obter o último stage3 openrc via CDN distfiles
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/current-stage3-amd64-openrc/stage3-amd64-openrc-*.tar.xz
tar xpvf stage3-amd64-openrc-*.tar.xz --xattrs-include='*.*' --numeric-owner
rm stage3-amd64-openrc-*.tar.xz
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

## ⚙️ Fase 3: Aplicar as Configurações do Repositório `gentoo_EXP`

### 3.1. Sincronizar Portage inicial
```bash
emerge-webrsync
```

### 3.2. Clonar o repositório e aplicar configurações do modo compilado híbrido
```bash
emerge --ask dev-vcs/git
git clone https://github.com/ruanpereira/gentoo_EXP.git /root/gentoo_EXP

# Aplicar configurações do modo compilado híbrido em /etc/portage
/root/gentoo_EXP/configs/scripts/sync-portage.sh to-system compiled
```

> [!NOTE]
> O modo **compilado híbrido** usa `configs/portage-compiled/` em vez de `configs/portage/`.
> Diferenças em relação ao modo binário:
> - `make.conf` sem `getbinpkg` global — tudo compila nativamente com `-march=znver3`
> - `package.env/binpkg` + `env/binpkg.conf`: exceções binárias para pacotes sem valor de recompilação:
>   - `www-client/zen-bin` — navegador pré-empacotado (sem ebuild fonte)
>   - `games-util/steam-launcher` — launcher proprietário
>   - `dev-lang/rust-bin` — toolchain Rust (~1h de compilação, binário oficial idêntico)

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

### 5.1. Ferramentas de Sistema de Arquivos e Verificação do `/etc/fstab`
Como o `/etc/fstab` foi gerado na Fase 2.2 com o utilitário `genfstab`, todos os UUIDs dos subvolumes Btrfs (`@`, `@home`, `@var_log`, `@snapshots`), partição EFI (`/efi`) e Swap já estão mapeados.

Instale as ferramentas de suporte a filesystem e valide o conteúdo do arquivo:

```bash
emerge --ask sys-fs/btrfs-progs sys-fs/dosfstools

# Visualizar e conferir o fstab gerado:
cat /etc/fstab
```

### 5.2. Instalação do GRUB 2 (UEFI)
```bash
emerge --ask sys-boot/grub
grub-install --target=x86_64-efi --efi-directory=/efi --boot-directory=/boot --bootloader-id=Gentoo
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

### 6.1. Habilitar o Repositório Comunitário GURU
Tanto o compositor **Niri** quanto o display manager **Ly** são mantidos no overlay comunitário oficial do Gentoo (**GURU**). Como as palavras-chave desmascaradas (`~amd64`) já foram aplicadas na Fase 3, habilite e sincronize o repositório:

```bash
# Habilitar o gerenciador de repositórios e o overlay GURU
emerge --ask app-eselect/eselect-repository
eselect repository enable guru
emaint sync -r guru
```

### 6.2. Drivers Gráficos, Mesa, Niri e Display Manager Ly
Instale a stack gráfica, compositor e o greeter:

```bash
emerge --ask media-libs/mesa x11-libs/libxkbcommon gui-wm/niri x11-misc/ly

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
umount -l /mnt/gentoo/dev{/shm,/pts,} 2>/dev/null || true
umount -R /mnt/gentoo
reboot
```

Ao reiniciar, seu Gentoo inicializará o display manager **Ly** no TTY2. Basta selecionar a sessão **Niri**, inserir seu login e senha para entrar diretamente no ambiente Wayland sobre Btrfs com snapshots automáticos por transação.
