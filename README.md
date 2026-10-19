# casara-ai-utils

Utilitários de IA do Luiz Casara. Este repositório é um marketplace de plugins do [Claude Code](https://claude.com/claude-code).

## Plugins

| Plugin | O que faz |
| --- | --- |
| [`mods-do-luiz`](plugins/mods-do-luiz) | Pacote que instala de uma vez 6 mods do Claude Code (veja abaixo). Não contém código: só declara os mods como dependências, então cada um continua vindo do repositório original e recebe as atualizações do autor. |

### Mods incluídos em `mods-do-luiz`

| Mod | Origem | O que faz |
| --- | --- | --- |
| `savvy-progress` | [JohnnyVizz/claude-kit](https://github.com/JohnnyVizz/claude-kit) | Barra de progresso acima do prompt e painel de subagentes |
| `filetree` | [data-goblin/claude-code-filetree](https://github.com/data-goblin/claude-code-filetree) | Árvore de arquivos na lateral, com destaque do que o Claude lê e escreve |
| `cache-tax` | [karanb192/claude-code-mods](https://github.com/karanb192/claude-code-mods) | Avisa o custo de retomar um chat com cache frio e mantém o cache quente (`/keepwarm`) |
| `blast-radius` | [anthropics/claude-code-playground](https://github.com/anthropics/claude-code-playground) | Segura comandos arriscados (`rm -rf`, `git reset --hard`, force push) e mostra o que mudariam |
| `replay-theater` | [anthropics/claude-code-playground](https://github.com/anthropics/claude-code-playground) | Replay das edições de arquivo do último turno, um diff por vez |
| `reflect-mod` | [BayramAnnakov/claude-reflect](https://github.com/BayramAnnakov/claude-reflect) | Detecta correções suas e sugere salvá-las como regras no `CLAUDE.md` |

## Instalação

Requer Claude Code 2.1.287 ou mais novo. Mods rodam no terminal, na aba Code do app Desktop e na extensão do VS Code (2.1.299+); não rodam em sessões WSL do app Desktop.

**1. Adicione os marketplaces dos mods de terceiros.** O `blast-radius` e o `replay-theater` não têm marketplace na raiz do repositório, então o passo deles é diferente:

```bash
claude plugin marketplace add johnnyvizz/claude-kit
claude plugin marketplace add data-goblin/claude-code-filetree
claude plugin marketplace add karanb192/claude-code-mods
claude plugin marketplace add bayramannakov/claude-reflect

git clone https://github.com/anthropics/claude-code-playground.git ~/claude-code-playground
claude plugin marketplace add ~/claude-code-playground/claude-code/mods
```

Não apague a pasta `~/claude-code-playground`: o marketplace local aponta para ela.

**2. Adicione este marketplace e instale o pacote:**

```bash
claude plugin marketplace add LuizCasara/casara-ai-utils
claude plugin install mods-do-luiz@casara-ai-utils --scope user
```

**3. Reinicie a sessão** (ou rode `/reload-plugins`). Para conferir, `/plugin` mostra os mods ativos.

## Avisos

- Um mod é código que roda com as suas permissões, dentro do Claude Code. Revise os repositórios de origem antes de instalar.
- Os mods de terceiros são mantidos pelos autores; o `claude-code-playground` da Anthropic é compartilhado "as-is", sem suporte.
- O `reflect-mod` faz uma chamada pequena de modelo a cada prompt curto e escreve no `CLAUDE.md` só quando você aperta Save.
