#!/usr/bin/env bash
# Setup de terminal reproduzível: zsh + Oh My Zsh + Starship + fzf/zoxide/eza/bat/btop + RTK,
# Windows Terminal (Windows) ou Ghostty (macOS), e as chaves de terminal do VS Code, Cursor e Zed.
# Preferências e decisões: README.md desta pasta.
#
# Uso:  terminal/setup.sh            aplica (idempotente: rodar de novo não muda nada)
#       terminal/setup.sh --check    só mostra o que está diferente, não altera nada
#
# TERMINAL_HOME_DIR=<pasta>: pasta inicial do perfil zsh do Windows Terminal (padrão: a do usuário).
# Windows: rodar no Git Bash (o zsh ainda não existe na primeira vez).
# macOS:   rodar no zsh/bash nativo; precisa do Homebrew.
set -euo pipefail

MODE=apply
[[ ${1:-} == --check ]] && MODE=check
TERM_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STAMP=$(date +%Y%m%d-%H%M%S)
DIFFS=0

case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*) OS=windows ;;
  Darwin) OS=macos ;;
  *) echo "Sistema não suportado: $(uname -s) (só Windows/Git Bash e macOS)" >&2; exit 1 ;;
esac
# pwd pode devolver C:/... dependendo de como o Git Bash foi aberto; o zsh quer /c/...
[[ $OS == windows ]] && TERM_DIR=$(cygpath -u "$TERM_DIR")

step() { printf '\n== %s\n' "$*"; }
ok() { printf '  ✓ %s\n' "$*"; }
# need <descrição> <comando...>: no --check só registra a diferença; no modo normal executa
need() {
  local what=$1; shift
  DIFFS=$((DIFFS + 1))
  if [[ $MODE == check ]]; then printf '  ✗ %s\n' "$what"; return; fi
  printf '  → %s\n' "$what"
  "$@"
}
backup() { [[ -e $1 ]] && cp "$1" "$1.bak-$STAMP" && printf '    backup: %s\n' "$1.bak-$STAMP"; return 0; }

echo "Setup de terminal ($OS, modo: $MODE) — config em $TERM_DIR"

# ---------------------------------------------------------------------------
step "Pacotes"
if [[ $OS == windows ]]; then
  command -v winget.exe >/dev/null || { echo "winget não encontrado (instale o App Installer da Microsoft Store)" >&2; exit 1; }
  LINKS=$HOME/AppData/Local/Microsoft/WinGet/Links
  export PATH="/c/Program Files/starship/bin:$LINKS:$PATH"
  winget_install() { winget.exe install --id "$1" -e --silent --accept-source-agreements --accept-package-agreements >/dev/null; }
  # id do winget → como saber se já está instalado
  for pkg in Starship.Starship:starship junegunn.fzf:fzf ajeetdsouza.zoxide:zoxide \
             eza-community.eza:eza sharkdp.bat:bat aristocratos.btop4win:btop; do
    id=${pkg%%:*} bin=${pkg##*:}
    if command -v "$bin" >/dev/null; then ok "$bin"; else need "instalar $bin ($id)" winget_install "$id"; fi
  done
  if reg query 'HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts' 2>/dev/null | grep -q 'JetBrainsMono NF' ||
     reg query 'HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts' 2>/dev/null | grep -q 'JetBrainsMono NF'; then
    ok "JetBrainsMono Nerd Font"
  else
    need "instalar JetBrainsMono Nerd Font" winget_install DEVCOM.JetBrainsMonoNerdFont
  fi
  if command -v node >/dev/null; then ok "node"; else need "instalar node (LTS)" winget_install OpenJS.NodeJS.LTS; fi
else
  command -v brew >/dev/null || {
    echo 'Homebrew não encontrado. Instale (pede senha) e rode de novo:' >&2
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' >&2
    exit 1
  }
  for f in git node starship fzf zoxide eza bat btop; do
    if brew list --formula "$f" >/dev/null 2>&1; then ok "$f"; else need "instalar $f" brew install --quiet "$f"; fi
  done
  for c in font-jetbrains-mono-nerd-font ghostty; do
    if brew list --cask "$c" >/dev/null 2>&1; then ok "$c"; else need "instalar $c" brew install --quiet --cask "$c"; fi
  done
fi

# ---------------------------------------------------------------------------
step "zsh"
if [[ $OS == windows ]]; then
  # O Git for Windows não traz zsh: extrai o pacote do MSYS2 dentro da pasta do Git.
  install_zsh() {
    local probe=/usr/bin/.setup-terminal-probe
    touch "$probe" 2>/dev/null && rm -f "$probe" || {
      echo "    sem permissão em $(cygpath -w /usr/bin): abra o Git Bash como administrador e rode de novo" >&2; exit 1; }
    local pkg tmp
    pkg=$(curl -fsSL https://mirror.msys2.org/msys/x86_64/ |
          grep -o 'zsh-[0-9][^"<>]*-x86_64\.pkg\.tar\.zst' | sort -uV | tail -1)
    tmp=$(mktemp -d)
    curl -fsSL "https://mirror.msys2.org/msys/x86_64/$pkg" -o "$tmp/$pkg"
    # tar.exe do Windows (bsdtar) já descompacta zstd; o tar do Git não
    "$WINDIR/System32/tar.exe" -xf "$(cygpath -w "$tmp/$pkg")" -C "$(cygpath -w /)" usr
    rm -rf "$tmp"
    echo "    $pkg instalado"
  }
  if [[ -x /usr/bin/zsh ]]; then ok "zsh ($(/usr/bin/zsh --version))"; else need "instalar zsh (pacote do MSYS2)" install_zsh; fi
else
  ok "zsh nativo ($(zsh --version))"
fi

# ---------------------------------------------------------------------------
step "Oh My Zsh e plugins"
# autocrlf desligado: com CRLF o `omz update` faz autostash de todos os arquivos e o pop conflita
clone() { git clone --quiet --depth 1 -c core.autocrlf=false -c core.eol=lf "$1" "$2"; }
if [[ -d $HOME/.oh-my-zsh ]]; then ok "oh-my-zsh"; else need "clonar oh-my-zsh" clone https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"; fi
OMZ=$HOME/.oh-my-zsh
fix_omz_eol() { git -C "$OMZ" config core.autocrlf false && git -C "$OMZ" config core.eol lf; }
if [[ -d $OMZ/.git ]]; then
  if [[ $(git -C "$OMZ" config core.autocrlf) == false && $(git -C "$OMZ" config core.eol) == lf ]]; then
    ok "oh-my-zsh sem conversão CRLF"
  else
    need "desligar a conversão CRLF no git do oh-my-zsh (evita conflito no omz update)" fix_omz_eol
  fi
  # Estado deixado por um omz update que falhou: não é corrigido aqui, descartar muda a árvore do OMZ
  if [[ -n $(git -C "$OMZ" ls-files -u) ]] || git -C "$OMZ" stash list | grep -q autostash; then
    DIFFS=$((DIFFS + 1))
    echo "  ✗ oh-my-zsh com merge/autostash pendente (o shell abre com erro). Se o diff é só CRLF:" >&2
    echo "    git -C ~/.oh-my-zsh reset --hard HEAD && git -C ~/.oh-my-zsh stash drop" >&2
  fi
fi
for p in zsh-autosuggestions zsh-syntax-highlighting; do
  dest=$HOME/.oh-my-zsh/custom/plugins/$p
  if [[ -d $dest ]]; then ok "$p"; else need "clonar $p" clone "https://github.com/zsh-users/$p.git" "$dest"; fi
done

# ---------------------------------------------------------------------------
step "RTK"
install_rtk() {
  local base=https://github.com/rtk-ai/rtk/releases/latest/download tmp
  tmp=$(mktemp -d)
  mkdir -p "$HOME/.local/bin"
  if [[ $OS == windows ]]; then
    curl -fsSL "$base/rtk-x86_64-pc-windows-msvc.zip" -o "$tmp/rtk.zip"
    unzip -qo "$tmp/rtk.zip" -d "$tmp" && cp "$(find "$tmp" -name rtk.exe | head -1)" "$HOME/.local/bin/"
  else
    local arch; [[ $(uname -m) == arm64 ]] && arch=aarch64 || arch=x86_64
    curl -fsSL "$base/rtk-$arch-apple-darwin.tar.gz" | tar -xz -C "$tmp"
    cp "$(find "$tmp" -name rtk -type f | head -1)" "$HOME/.local/bin/" && chmod +x "$HOME/.local/bin/rtk"
  fi
  rm -rf "$tmp"
}
if PATH="$HOME/.local/bin:$PATH" command -v rtk >/dev/null; then ok "rtk ($(PATH="$HOME/.local/bin:$PATH" rtk --version))"; else need "instalar rtk (release do GitHub)" install_rtk; fi

# ---------------------------------------------------------------------------
step "Arquivos de config"
LOADER="# Gerado por casara-ai-utils/terminal/setup.sh. Não edite aqui: a config vive em
# $TERM_DIR (ver README.md lá). Camadas de projeto: ~/.config/zsh/conf.d/*.zsh
# Ajustes só desta máquina: ~/.zshrc.local
source \"$TERM_DIR/zshrc\"
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local"
write_loader() { backup "$HOME/.zshrc"; printf '%s\n' "$LOADER" > "$HOME/.zshrc"; }
if [[ -f $HOME/.zshrc && $(cat "$HOME/.zshrc") == "$LOADER" ]]; then ok "~/.zshrc é o loader"; else need "gravar loader em ~/.zshrc" write_loader; fi

# O Starship lê a config desta pasta via STARSHIP_CONFIG; uma ~/.config/starship.toml solta só confunde
retire_starship() { mv "$HOME/.config/starship.toml" "$HOME/.config/starship.toml.bak-$STAMP"; echo "    movido para starship.toml.bak-$STAMP"; }
if [[ -f $HOME/.config/starship.toml ]]; then need "aposentar ~/.config/starship.toml (a config agora é a desta pasta)" retire_starship; else ok "starship.toml desta pasta"; fi

mkdir_confd() { mkdir -p "$HOME/.config/zsh/conf.d"; }
if [[ -d $HOME/.config/zsh/conf.d ]]; then ok "~/.config/zsh/conf.d (camadas de projeto)"; else need "criar ~/.config/zsh/conf.d (camadas de projeto)" mkdir_confd; fi

if [[ $OS == macos ]]; then
  GHOSTTY=$HOME/.config/ghostty/config
  INCLUDE="config-file = $TERM_DIR/ghostty.conf"
  add_ghostty() { mkdir -p "${GHOSTTY%/*}"; backup "$GHOSTTY"; printf '%s\n' "$INCLUDE" >> "$GHOSTTY"; }
  if grep -qxF "$INCLUDE" "$GHOSTTY" 2>/dev/null; then ok "Ghostty inclui ghostty.conf"; else need "incluir ghostty.conf em $GHOSTTY" add_ghostty; fi
fi

# ---------------------------------------------------------------------------
step "Terminal e editores (chaves de terminal)"
if command -v node >/dev/null; then
  # jsonc-parser edita os settings preservando comentários; fica num cache, fora dos repos
  PARSER_DIR=${TERMINAL_PARSER_DIR:-$HOME/.cache/terminal-setup}
  install_parser() {
    mkdir -p "$PARSER_DIR"
    [[ -f $PARSER_DIR/package.json ]] || echo '{"private":true}' > "$PARSER_DIR/package.json"
    npm install --prefix "$PARSER_DIR" --silent --no-audit --no-fund --ignore-scripts jsonc-parser@3 >/dev/null
  }
  [[ -d $PARSER_DIR/node_modules/jsonc-parser ]] || need "instalar jsonc-parser em $PARSER_DIR" install_parser
  win() { [[ $OS == windows ]] && cygpath -w "$1" || printf '%s' "$1"; }
  if [[ ! -d $PARSER_DIR/node_modules/jsonc-parser ]]; then
    # Só acontece no --check, que não instala nada
    echo "  ✗ settings não verificados: falta o jsonc-parser (rode sem --check)"
  else
    set +e
    node "$(win "$TERM_DIR/lib/apply-settings.mjs")" "$(win "$PARSER_DIR")" "$MODE" "$OS" \
      "$([[ -n ${TERMINAL_HOME_DIR:-} ]] && win "$TERMINAL_HOME_DIR" || true)" \
      "$([[ $OS == windows ]] && cygpath -w / || true)" "$STAMP"
    rc=$?
    set -e
    if [[ $rc == 3 ]]; then DIFFS=$((DIFFS + 1))
    elif [[ $rc != 0 ]]; then echo "  ! falha ao aplicar settings (código $rc)" >&2; exit $rc
    fi
  fi
else
  DIFFS=$((DIFFS + 1))
  echo "  ✗ node indisponível nesta sessão: abra um terminal novo e rode de novo"
fi

# ---------------------------------------------------------------------------
step "Fumaça (prompt desenhado a partir desta pasta)"
SMOKE_OK=1
if command -v zsh >/dev/null && [[ -d $HOME/.oh-my-zsh ]]; then
  "$TERM_DIR/lib/smoke.sh" || { SMOKE_OK=; DIFFS=$((DIFFS + 1)); }
else
  echo "  - pulado: zsh ou Oh My Zsh ainda não instalados (rode sem --check)"
fi

# ---------------------------------------------------------------------------
echo
if [[ -z $SMOKE_OK && $MODE == apply ]]; then
  echo "Setup aplicado, mas o teste de fumaça falhou (acima): o terminal novo vai abrir com erro." >&2
  exit 1
fi
if [[ $MODE == check ]]; then
  if (( DIFFS )); then echo "$DIFFS item(ns) diferente(s). Rode sem --check para aplicar."; exit 1; fi
  echo "Tudo igual à config desta pasta."
else
  echo "Pronto. Abra um terminal novo (e reinicie os editores) para carregar."
  if [[ $OS == windows ]]; then
    echo "Primeira vez nesta máquina? Rode de novo num terminal novo: o PATH do winget só vale em sessões novas."
  fi
fi
