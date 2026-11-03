#!/usr/bin/env bash
# Teste do apply-settings.mjs numa sandbox: settings falsos de VS Code, Zed e Windows Terminal,
# nunca os da máquina. Garante o contrato do merge: só as chaves de terminal mudam, comentários e
# chaves alheias sobrevivem, o "shell" do Zed é substituído (mesclar o deixaria inválido), o perfil
# zsh do Windows Terminal é criado, há backup, e um segundo --check sai limpo.
# Rodar à mão depois de mexer em lib/apply-settings.mjs. Sai 1 se falhar.
set -uo pipefail

DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PARSER_DIR=${TERMINAL_PARSER_DIR:-$HOME/.cache/terminal-setup}
[[ -d $PARSER_DIR/node_modules/jsonc-parser ]] || { echo "  - teste do merge pulado: falta o jsonc-parser (rode setup.sh)"; exit 0; }

case "$(uname -s)" in MINGW* | MSYS* | CYGWIN*) OS=windows ;; *) OS=macos ;; esac
win() { [[ $OS == windows ]] && cygpath -w "$1" || printf '%s' "$1"; }

S=$(mktemp -d)
trap 'rm -rf "$S"' EXIT
if [[ $OS == windows ]]; then
  CODE=$S/roam/Code/User/settings.json ZED=$S/roam/Zed/settings.json
  WT="$S/local/Microsoft/Windows Terminal/settings.json"
else
  CODE="$S/home/Library/Application Support/Code/User/settings.json" ZED=$S/home/.config/zed/settings.json WT=
fi
mkdir -p "$(dirname "$CODE")" "$(dirname "$ZED")"
cat >"$CODE" <<'EOF'
{
  // comentário que deve sobreviver
  "editor.fontSize": 14,
  "terminal.integrated.profiles.windows": { "PowerShell": { "source": "PowerShell" } },
}
EOF
cat >"$ZED" <<'EOF'
// comentário do zed
{
  "terminal": { "shell": { "program": "pwsh" }, "font_size": 14 },
  "theme": "One Dark",
}
EOF
if [[ -n $WT ]]; then
  mkdir -p "$(dirname "$WT")"
  cat >"$WT" <<'EOF'
{
    "defaultProfile": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
    "profiles": { "defaults": {}, "list": [ { "guid": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}", "name": "PowerShell", "elevate": true } ] }
}
EOF
fi

run() {
  APPDATA=$(win "$S/roam") LOCALAPPDATA=$(win "$S/local") HOME=$S/home \
    node "$(win "$DIR/lib/apply-settings.mjs")" "$(win "$PARSER_DIR")" "$1" "$OS" \
    '' "$([[ $OS == windows ]] && echo 'C:\Program Files\Git\' || true)" TESTE >/dev/null
}

fail=0
bad() { printf '  ✗ merge: %s\n' "$*"; fail=1; }
run check; [[ $? == 3 ]] || bad "--check antes de aplicar deveria acusar diferença (saída 3)"
run apply || bad "apply falhou"
run check || bad "--check depois de aplicar deveria sair limpo (rodar de novo não pode mudar nada)"

# Asserções sobre o resultado, lendo com o mesmo jsonc-parser
(cd "$S" && OS=$OS node - "$(win "$PARSER_DIR")" "$(win "$CODE")" "$(win "$ZED")" "$(win "${WT:-$S/none}")" <<'EOF'
const [parserDir, code, zed, wt] = process.argv.slice(2);
const { readFileSync, existsSync } = require('fs');
const { parse } = require(require('path').join(parserDir, 'node_modules', 'jsonc-parser'));
const read = (f) => readFileSync(f, 'utf8');
const json = (f) => parse(read(f), [], { allowTrailingComma: true });
const win = process.env.OS === 'windows';
const errors = [];
const expect = (ok, msg) => ok || errors.push(msg);

const c = json(code);
expect(read(code).includes('// comentário que deve sobreviver'), 'VS Code: comentário apagado');
expect(c['editor.fontSize'] === 14, 'VS Code: chave alheia alterada');
if (win) {
  expect(c['terminal.integrated.profiles.windows']?.PowerShell, 'VS Code: perfil PowerShell apagado');
  expect(c['terminal.integrated.profiles.windows']?.zsh?.path?.endsWith('zsh.exe'), 'VS Code: perfil zsh ausente');
  expect(c['terminal.integrated.defaultProfile.windows'] === 'zsh', 'VS Code: zsh não é o padrão');
} else {
  expect(c['terminal.integrated.defaultProfile.osx'] === 'zsh', 'VS Code: zsh não é o padrão');
}
expect(existsSync(`${code}.bak-TESTE`), 'VS Code: sem backup');

const z = json(zed);
expect(read(zed).includes('// comentário do zed'), 'Zed: comentário apagado');
expect(z.theme === 'One Dark' && z.terminal.font_size === 14, 'Zed: chave alheia alterada');
expect(z.terminal.font_family, 'Zed: font_family ausente');
if (win) {
  expect(z.terminal.shell?.with_arguments && !('program' in z.terminal.shell),
    'Zed: "shell" mesclado em vez de substituído (program + with_arguments é inválido)');
}

if (win) {
  const w = json(wt);
  const zshGuid = '{94c0ec40-4f63-4524-873e-cbb10b518eda}';
  expect(w.defaultProfile === zshGuid, 'Windows Terminal: zsh não é o perfil padrão');
  expect(w.profiles.list.length === 2, 'Windows Terminal: perfil zsh não criado (ou duplicado)');
  expect(w.profiles.list[0].elevate === true, 'Windows Terminal: campo de outro perfil apagado');
  expect(w.profiles.list[1].startingDirectory === '%USERPROFILE%', 'Windows Terminal: pasta inicial padrão não é a do usuário');
}

if (errors.length) { console.log(errors.map((e) => `  ✗ merge: ${e}`).join('\n')); process.exit(1); }
EOF
) || fail=1

(( fail )) && exit 1
echo "  ✓ merge dos settings: comentários e chaves alheias preservados, idempotente"
