#!/usr/bin/env bash
# Teste de fumaça do terminal: sintaxe dos arquivos e o prompt desenhado de verdade, a partir dos
# arquivos desta pasta (não do ~/.zshrc), com o cache de inits vazio, para gerar tudo do zero, e
# sem as camadas da máquina (conf.d próprio, com um projeto de teste).
# Pega o que "zsh -i -c exit" não pega: init que só quebra ao desenhar o prompt (aspas do
# Starship) e glifos Nerd Font perdidos (somem ao passar por editores e heredocs).
# Chamado por ../setup.sh. Sai 1 se falhar.
set -uo pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
command -v cygpath >/dev/null && DIR=$(cygpath -u "$DIR")
fail=0
bad() { printf '  ✗ %s\n' "$*"; fail=1; }

bash -n "$DIR/setup.sh" || bad "sintaxe: setup.sh"
for f in zshrc projects.zsh; do zsh -n "$DIR/$f" || bad "sintaxe: $f"; done
(cd "$DIR" && node --check lib/apply-settings.mjs) || bad "sintaxe: lib/apply-settings.mjs"

tmp=$(mktemp -d)
mkdir -p "$tmp/cache" "$tmp/conf.d" "$tmp/zoxide"
# Projeto de teste = a pasta lib/ (o /tmp do MSYS não é pasta real no Windows e o zoxide reclama)
echo "project demo '$DIR/lib'" >"$tmp/conf.d/demo.zsh"
err=$tmp/err
# Dentro do repo (git), o prompt tem que trazer o ícone de branch; o projeto registrado na camada
# tem que virar comando que roda dentro da pasta dele. _ZO_DATA_DIR: o cd não suja o zoxide da máquina
out=$(cd "$DIR" && ZSH_INIT_CACHE=$tmp/cache ZSH_CONF_D=$tmp/conf.d _ZO_DATA_DIR=$tmp/zoxide zsh -f -i -c \
  "source '$DIR/zshrc'; print -P -- \"\$PROMPT\"; print -r -- \"demo:\$(demo pwd)\"" 2>"$err")
# Sem terminal de verdade o zsh desliga o zle e o fzf avisa ao restaurar as opções: ruído esperado
errors=$(grep -v "can't change option: zle" "$err")
[[ -z $errors ]] || bad "o shell escreveu erro ao subir/desenhar o prompt:"$'\n'"$errors"
[[ $out == *$'\xee\x82\xa0'* ]] || bad "prompt sem o ícone de branch (U+E0A0): glifo perdido ou Starship fora do ar"
[[ $out == *'❯'* ]] || bad "prompt sem o ❯ do Starship"
[[ $out == *"demo:$DIR/lib"* ]] || bad "projeto da camada conf.d não virou comando (projects.zsh)"
rm -rf "$tmp"

(( fail )) && exit 1
echo "  ✓ fumaça: sintaxe ok, prompt desenhado com ícones, camada de projeto carregada"
