# Gentoo Linux - Setup, Configurações e Automação (`gentoo_EXP`)

Este repositório documenta o processo completo de instalação, personalização e manutenção de um sistema operacional **Gentoo Linux** com **OpenRC**, **Wayland** e esteira de validação contínua (CI) via **GitHub Actions**.

---

## 🧭 Especificações do Sistema

| Componente | Especificação Definida |
| :--- | :--- |
| **Processador Alvo** | AMD Ryzen 5 5600XT (Zen 3, `-march=znver3`, `MAKEOPTS="-j12"`) |
| **Placa de Vídeo** | AMD Radeon RX 6600 (Navi 23, `VIDEO_CARDS="amdgpu radeonsi"`) |
| **Init & Profile** | OpenRC \| Profile Padrão `default/linux/amd64/23.0` |
| **Filesystem & Snapshots**| Btrfs (`@`, `@home`, `@var_log`, `@snapshots`) com snapshots automáticos por `emerge` |
| **Ambiente Gráfico** | Wayland Nativo com **Niri** (WM Tiling) + **Noctalia Suite** (Shell & Greeter) |
| **Navegadores & Senhas** | Zen Browser (`zen-bin`), Helium Browser (AppImage) e KeePassXC |
| **Rede & DNS** | Firewalld, Libvirt/QEMU com trânsito irrestrito e DNS Quad9 estrito (IPv4, IPv6, DoT e DoH) |
| **Desenvolvimento** | Neovim, VSCodium (`vscodium-bin`), LaTeX (`texlive-core`), Python e `uv` |
| **Gaming & GPU** | Steam (multilib 32-bit), Proton oficial, Proton-CachyOS, MangoHud e daemon LACT |
| **Controle de Versão** | Git com autenticação SSH dedicada (`gentoo-aktsu`) |

---

## 📂 Estrutura do Repositório

```text
gentoo_EXP/
├── .github/
│   └── workflows/
│       └── ci-gentoo.yml            # Pipeline de validação binária contínua no GitHub Actions
├── configs/
│   ├── portage/                    # Espelho fiel de /etc/portage/
│   │   ├── make.conf               # CFLAGS (znver3/v3), MAKEOPTS (-j12), FEATURES
│   │   ├── bashrc                  # Hook automático de snapshots Btrfs
│   │   ├── package.use/            # USE flags por pacote
│   │   ├── package.accept_keywords/# Desmascaramento (~amd64)
│   │   └── package.license         # Licenças aceitas
│   └── scripts/
│       ├── sync-portage.sh         # Sincroniza /etc/portage <-> repositório
│       └── test-configs.sh         # Script de validação para CI ou container
├── docs/                           # Documentação passo a passo detalhada
├── .gitignore                      # Exclusão de arquivos pesados e temporários
├── AGENT_CONTEXT_BRIEFING.md       # Contexto executivo completo de handover
└── README.md                       # Visão geral do repositório
```

---

## 🤖 Validação Contínua (GitHub Actions)

O repositório possui uma esteira automatizada em `.github/workflows/ci-gentoo.yml` que roda dentro do container oficial `gentoo/stage3:latest`, consumindo o binhost oficial `x86-64-v3` para validar todas as configurações em **3 a 5 minutos**, garantindo que nenhum pacote ou USE flag quebre as regras do sistema.
