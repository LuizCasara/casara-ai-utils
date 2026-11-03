# Terminal (zsh)

Meu terminal, reproduzível em qualquer máquina Windows ou macOS: zsh com Oh My Zsh, prompt
Starship, busca fuzzy (fzf), saltos de pasta (zoxide), `ls`/`cat` com cor (eza/bat), atalhos para
os projetos e as mesmas fontes e cores no Windows Terminal, Ghostty, VS Code, Cursor e Zed.

Os arquivos desta pasta são a **fonte da verdade**. O `setup.sh` instala as ferramentas e liga a
máquina a eles.

## Instalar

```sh
git clone https://github.com/LuizCasara/casara-ai-utils.git ~/casara-ai-utils
~/casara-ai-utils/terminal/setup.sh            # Windows: no Git Bash. macOS: precisa do Homebrew
~/casara-ai-utils/terminal/setup.sh --check    # doctor: mostra o que difere, não altera nada
```

- O script é idempotente: rodar de novo só corrige o que estiver diferente.
- No Windows, rode uma segunda vez num terminal novo, porque o PATH do winget só vale em sessões
  novas. Se a extração do zsh pedir, abra o Git Bash como administrador.
- Tudo o que ele sobrescreve ganha backup `*.bak-<data>` ao lado.
- O clone pode ficar em qualquer pasta. Se ele mudar de lugar, rode o `setup.sh` de novo.

Pasta inicial do Windows Terminal: por padrão, a pasta do usuário. Para usar outra:

```sh
TERMINAL_HOME_DIR='C:\projetos' ~/casara-ai-utils/terminal/setup.sh
```

## Atalhos de projeto

O `projects.zsh` transforma cada pasta registrada num comando. Registre numa camada em
`~/.config/zsh/conf.d/`, ex.: `~/.config/zsh/conf.d/acme.zsh`:

```zsh
project api ~/code/acme/api https://github.com/acme/api.git   # a url é opcional
project web ~/code/acme/web
```

| Comando | Faz |
|---|---|
| `web` | entra na pasta |
| `web run` | sobe o dev server **sem sair da pasta atual** (`npm run dev`; Maven: `mvn spring-boot:run`); a saída também vai para `~/.logs/web.log`, recriado a cada start, para um agente de IA ler os erros |
| `web build` / `web test` | `npm run build` / `npm run test` (Maven: `mvn clean compile` / `mvn test`) |
| `web <script>` | qualquer script do `package.json`, ex.: `web lint` (Tab lista os scripts) |
| `web <comando>` | qualquer comando dentro da pasta, ex.: `web git log`, `api mvn -v` |
| `pdev` | sobe **todos os projetos lado a lado** numa aba nova (painéis no Windows Terminal, janelas no Ghostty) |
| `pdev api web` | o mesmo, só com os projetos escolhidos |
| `pst` | branch e mudanças de todos os projetos de uma vez (só leitura) |

- O tipo de projeto é detectado pelo `pom.xml` ou `package.json` da pasta.
- Pasta que não existe: o comando avisa com o `git clone` certo, se o registro trouxe a url.
- `PROJECTS_LOG_DIR` muda a pasta dos logs.
- A camada é o lugar do que for específico do projeto: variáveis, PATH de CLI de deploy, aliases.

## Referência rápida

### Teclas

| Tecla | Faz |
|---|---|
| `Ctrl+R` | busca fuzzy no histórico (digite pedaços soltos: `mvn sp run`) |
| `Ctrl+T` | escolhe um arquivo e cola o caminho no comando (prévia colorida) |
| `Alt+C` | escolhe uma subpasta e entra nela (prévia em árvore) |
| `Ctrl+Espaço` | aceita a sugestão cinza do histórico (o mesmo que `→`) |

### Ferramentas e atalhos

| Comando | Faz |
|---|---|
| `z <pedaço>` | pula pra uma pasta já visitada, ex.: `z api`, `z docs` |
| `zi` | escolhe a pasta numa lista fuzzy |
| `docs` (só o nome) | entra na pasta, sem `cd` (`AUTO_CD`) |
| `ls` / `ll` / `lt` | lista com ícones / detalhes + status git / árvore de 2 níveis (`lt -L 3` vai mais fundo) |
| `cat arquivo` | mostra com cores (bat); `\cat` chama o original, `bat` sozinho pagina com números de linha |
| `btop` | monitor de CPU, memória, disco, rede e processos (`q` sai, `f` filtra processo) |
| `history` | histórico com data e hora de cada comando |
| ` comando` | espaço na frente: não vai pro histórico (bom pra `curl` com token) |

### Aliases dos plugins (os mais úteis)

| Alias | Comando |
|---|---|
| `gst` / `gss` | `git status` / `git status --short` |
| `gd` / `gdca` | `git diff` / `git diff --cached` |
| `glog` | `git log --oneline --decorate --graph` |
| `gsw` / `gswc` | `git switch` / `git switch --create` |
| `gco` / `gcb` / `gcm` | `git checkout` / `checkout -b` / checkout da branch principal |
| `ga` / `gaa` / `gc` | `git add` / `git add --all` / `git commit --verbose` |
| `gl` / `gp` / `gstp` | `git pull` / `git push` / `git stash pop` |
| `npmrd` / `npmrb` / `npmt` | `npm run dev` / `npm run build` / `npm test` |
| `mvnt` / `mvnct` / `mvncp` | `mvn test` / `mvn clean test` / `mvn clean package` |

Lista completa: `alias | grep <prefixo>` (ex.: `alias | grep '^g'`).

### Símbolos do prompt

```
web on  feat/login [!?⇡1] via  v24.15.0 took 3s
❯
```

| Símbolo | Significado |
|---|---|
| ` main` | branch atual |
| `!` | arquivo modificado, ainda fora do stage |
| `+` | mudança no stage (já passou pelo `git add`) |
| `?` | arquivo novo, não rastreado |
| `✘` | arquivo deletado |
| `»` | arquivo renomeado |
| `=` | conflito de merge |
| `$` | tem stash guardado |
| `⇡2` / `⇣3` | 2 commits pra enviar / 3 pra puxar do remoto |
| `⇕⇡1⇣2` | branch divergiu do remoto (dos dois lados) |
| sem `[...]` | repo limpo e sincronizado |
| ` v24` / `☕ v21` | versão do Node / do Java usados naquela pasta (`🅼` = projeto Maven) |
| `took 3s` | duração do último comando; à direita, a data e a hora em que ele terminou |
| `❯` verde / vermelho | último comando deu certo / falhou |

## O que fica onde

| Arquivo | Papel |
|---|---|
| `zshrc` | PATH, Oh My Zsh, histórico, opções, eza/bat, fzf, inits, workarounds; carrega as camadas |
| `projects.zsh` | `project`, `pst`, `pdev` (só funções: os projetos vêm das camadas) |
| `starship.toml` | prompt (lido via `STARSHIP_CONFIG`) |
| `ghostty.conf` | terminal no macOS (incluído por `~/.config/ghostty/config`) |
| `setup.sh` | instala e liga tudo; `--check` = doctor |
| `lib/apply-settings.mjs` | aplica as chaves de terminal nos settings do Windows Terminal, VS Code, Cursor e Zed |
| `lib/smoke.sh` | teste de fumaça: sintaxe + prompt desenhado de verdade (com ícones) + camada de projeto, cache vazio |
| `lib/test-apply-settings.sh` | testa o merge dos settings numa sandbox (comentários e chaves alheias preservados, idempotente) |

Na máquina:

| Onde | O quê |
|---|---|
| `~/.zshrc` | só um **loader** de 4 linhas que faz `source` do `zshrc` daqui; editar um arquivo desta pasta vale no próximo shell |
| `~/.config/zsh/conf.d/*.zsh` | camadas de projeto, carregadas em ordem alfabética (fora do git, ou no repo do projeto) |
| `~/.zshrc.local` | ajuste que só faz sentido nesta máquina, carregado por último |

**Regra:** mudança de terminal se faz aqui (e no `setup.sh`, se envolver instalar algo), nunca em
`~/.zshrc` ou `~/.config/` direto. Senão a outra máquina não recebe. Depois de mexer, rode
`lib/smoke.sh` (e `lib/test-apply-settings.sh`, se mexeu no `apply-settings.mjs`).

## O que o setup entrega

| | Windows | macOS |
|---|---|---|
| Shell | zsh do MSYS2 extraído no Git for Windows | zsh nativo |
| Pacotes | winget | Homebrew |
| Terminal | Windows Terminal, perfil `zsh` (padrão) | Ghostty |
| Fonte | JetBrainsMono Nerd Font (`JetBrainsMono NF`) | JetBrainsMono Nerd Font |

- **Oh My Zsh** sem tema, com os plugins `git npm mvn gh zsh-autosuggestions zsh-syntax-highlighting`.
  O git do `~/.oh-my-zsh` fica com `core.autocrlf false`: com CRLF o `omz update` faz autostash
  de tudo e o pop conflita, deixando marcadores `<<<<<<<` em `tools/check_for_upgrade.sh`. O
  `--check` avisa se sobrar merge/autostash pendente.
- **Starship**: pasta, branch, status do git, versões de Node/Java, `❯` vermelho em erro. À
  direita de cada prompt: duração e data/hora em que o comando anterior terminou. Escondidos:
  usuário, host, versão do pacote, região AWS.
- **fzf**, **zoxide**, **eza**, **bat**, **btop** e **node** (usado pelo setup e pelos atalhos
  de projeto).
- **[RTK](https://github.com/rtk-ai/rtk)** em `~/.local/bin`: proxy que comprime a saída de
  comandos antes de ela chegar ao contexto de um agente de IA (`rtk git diff`, `rtk grep`...).
- Opções: `AUTO_CD`, `HIST_IGNORE_SPACE`, `EXTENDED_HISTORY`, histórico de 50 mil linhas
  compartilhado entre sessões.
- **Editores**: só as chaves de terminal (shell zsh e Nerd Font) no VS Code, Cursor e Zed; o
  resto dos settings não é tocado.
- **Windows Terminal**: perfil `zsh` com GUID fixo, só campos portáteis (comando, fonte, Tango
  Dark, cursor barra, padding, pasta inicial). Imagem de fundo, ícone e `elevate` ficam a cargo de
  cada máquina: o script define as chaves dele e não apaga as outras.

## Decisões e porquês

- **Arquivos + script, não só documento.** "Igual em outra máquina" só é confiável executando, e
  os workarounds abaixo ficam no código, não na memória de alguém.
- **Camadas.** A config daqui não sabe nada de projeto nenhum; cada projeto entra por um arquivo
  em `conf.d/`. A máquina tem o `~/.zshrc.local`.
- **Loader em vez de symlink ou cópia.** Symlink no Windows exige modo desenvolvedor e o Git Bash
  cria cópia em silêncio sem ele; cópia diverge.
- **Ferramentas sempre na versão mais recente.** Os workarounds que dependem de bug se desligam
  sozinhos quando o upstream corrige.
- **Inits em cache** (`~/.cache/zsh-init/`): no Windows criar processo é caro; gerar o init de
  starship, fzf e zoxide a cada shell custava ~300 ms. O cache se regenera quando o binário muda.
- **Plugin `docker` fora**: custava ~60 ms de abertura.

### Workarounds (Windows)

| Problema | Correção | Some quando |
|---|---|---|
| Starship gera `''/c/Program Files/...''` no init: as aspas quebram no espaço e o prompt falha com `no such file or directory: /c/Program` | o `_cached_init` troca o caminho absoluto por `starship` (está no PATH) | o Starship citar o caminho direito (a troca vira no-op) |
| zoxide 0.10 gera `cygpath -w "\builtin pwd -L"` (sem `$( )`): todo `cd` gravaria `C:\builtin pwd -L` | `__zoxide_pwd` reescrito em zsh puro, só se o init gerado tiver o bug | automático: o teste olha o init gerado |
| `eza.exe` chamado do zsh sem caminho não lista nada | `_eza` passa `.` quando não há caminho (neutro no macOS) | — |
| O walker do `fzf.exe` devolve caminhos com `\` | `Ctrl+T`/`Alt+C` listam com `find` (ignora `.git`, `node_modules`, `.next`, `target`) | — |
| `btop` (btop4win, console nativo) sai com `No tty detected!` num pty do MSYS (terminal do VS Code, mintty) | a função `btop` roda via `winpty` quando o `tty` é `/dev/pty*` | — |
| `node.exe` não entende `/c/...` | o `projects.zsh` lê o `package.json` pelo stdin | — |
| Glifos Nerd Font somem ao passar por alguns editores e heredocs | o `lib/smoke.sh` confere o ícone de branch no prompt desenhado; para inserir glifo, `perl -CSD -Mutf8` com `\x{e0a0}` | — |

Ainda sem teste real num Mac: o ramo macOS do script, o `ghostty.conf` e o `pdev` via
`open -na Ghostty.app`. Rode `--check` no primeiro Mac e corrija aqui o que falhar.
