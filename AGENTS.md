# Diretrizes para Agentes de IA (`AGENTS.md`)

Este arquivo contém instruções operacionais de alta prioridade para agentes automatizados que realizam alterações no repositório `gentoo_EXP`.

## 🚨 Regras Restritas
1. **NÃO crie nem altere keybinds:** O arquivo `configs/niri/cfg/keybinds.kdl` não deve receber novas teclas de atalho a menos que o usuário solicite expressamente na mensagem.
2. **Mantenha os dois perfis do Portage sincronizados:** Qualquer pacote ou USE flag adicionada em `configs/portage/` deve ser obrigatoriamente replicada em `configs/portage-compiled/`.
3. **Pacotes binários no modo compilado:** Pacotes que terminam em `-bin` ou são proprietários devem estar em `configs/portage-compiled/package.env/binpkg`.
4. **Validação de Sintaxe:** Antes de commitar, execute:
   ```bash
   for s in configs/scripts/*.sh; do bash -n "$s" || exit 1; done
   ```
5. **Consulte o briefing completo:** Leia [AGENT_CONTEXT_BRIEFING.md](AGENT_CONTEXT_BRIEFING.md) para detalhes de arquitetura, hardware e decisões de design.
