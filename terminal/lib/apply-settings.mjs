// Aplica as chaves de terminal nos settings (JSONC) do Windows Terminal, VS Code, Cursor e Zed.
// Chamado por ../setup.sh; não rodar direto.
//
// Uso: node apply-settings.mjs <jsonc-parser-dir> <check|apply> <windows|macos> <startDir> <gitRoot> <stamp>
//   jsonc-parser-dir: pasta onde o setup instalou o pacote jsonc-parser (node_modules dentro dela)
//   startDir: pasta inicial do perfil zsh do Windows Terminal; vazio = pasta do usuário
//   gitRoot: raiz do Git for Windows (ex.: C:\Program Files\Git); vazio no macOS
//   stamp: sufixo dos backups, o mesmo que o setup usa nos outros arquivos
//
// Só define as chaves listadas aqui: nunca apaga nem reescreve o resto do arquivo, e preserva
// comentários e formatação (jsonc-parser é a biblioteca que o próprio VS Code usa).

import { createRequire } from 'node:module';
import { existsSync, readFileSync, writeFileSync, copyFileSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';

const [parserDir, mode, platform, startDir, gitRoot, stamp] = process.argv.slice(2);
const { parse, modify, applyEdits, format, findNodeAtLocation, parseTree } =
  createRequire(join(parserDir, 'package.json'))('jsonc-parser');

const home = homedir();
const isWin = platform === 'windows';
const appData = isWin ? process.env.APPDATA : join(home, 'Library', 'Application Support');
const localAppData = process.env.LOCALAPPDATA ?? '';

// Nome da família da Nerd Font: o pacote do winget registra "JetBrainsMono NF";
// o cask do Homebrew, "JetBrainsMono Nerd Font".
const nerdFont = isWin ? 'JetBrainsMono NF' : 'JetBrainsMono Nerd Font';
const zshExe = isWin ? join(gitRoot, 'usr', 'bin', 'zsh.exe') : '/bin/zsh';

// GUID fixo do perfil zsh: o mesmo em toda máquina, para o setup achar e atualizar o perfil
const WT_ZSH_GUID = '{94c0ec40-4f63-4524-873e-cbb10b518eda}';

// Marca uma chave cujo valor-objeto substitui o atual em vez de ser mesclado nele
const REPLACE = Symbol('replace');

const vscodeLike = (dir) => ({
  name: dir,
  file: join(appData, dir, 'User', 'settings.json'),
  keys: isWin
    ? [
        [['terminal.integrated.defaultProfile.windows'], 'zsh'],
        [['terminal.integrated.profiles.windows', 'zsh'], { path: zshExe, args: ['-l', '-i'], icon: 'terminal-bash' }],
        [['terminal.integrated.fontFamily'], "'JetBrainsMono NF', 'JetBrainsMono Nerd Font', monospace"],
      ]
    : [
        [['terminal.integrated.defaultProfile.osx'], 'zsh'],
        [['terminal.integrated.fontFamily'], "'JetBrainsMono Nerd Font', 'JetBrainsMono NF', monospace"],
      ],
});

const targets = [
  vscodeLike('Code'),
  vscodeLike('Cursor'),
  {
    name: 'Zed',
    file: isWin ? join(appData, 'Zed', 'settings.json') : join(home, '.config', 'zed', 'settings.json'),
    keys: [
      // No macOS o Zed já usa o shell de login (zsh). REPLACE: as variantes de "shell"
      // ("system", { program }, { with_arguments }) são exclusivas; mesclar geraria config inválida.
      ...(isWin ? [[['terminal', 'shell'], { with_arguments: { program: zshExe, args: ['-l', '-i'] } }, REPLACE]] : []),
      [['terminal', 'font_family'], nerdFont],
    ],
  },
];

if (isWin) {
  const wtProfile = {
    guid: WT_ZSH_GUID,
    name: 'zsh',
    commandline: `"${zshExe}" -l -i`,
    startingDirectory: startDir || '%USERPROFILE%',
    font: { face: nerdFont, size: 10, weight: 'bold' },
    colorScheme: 'Tango Dark',
    cursorShape: 'bar',
    padding: '8, 8, 8, 8',
    hidden: false,
  };
  // Windows Terminal da Store e o instalado sem Store guardam o settings em lugares diferentes
  for (const file of [
    join(localAppData, 'Packages', 'Microsoft.WindowsTerminal_8wekyb3d8bbwe', 'LocalState', 'settings.json'),
    join(localAppData, 'Microsoft', 'Windows Terminal', 'settings.json'),
  ]) {
    targets.push({ name: 'Windows Terminal', file, wtProfile });
  }
}

// Recuo do próprio arquivo (VS Code usa 2 espaços, Cursor e Windows Terminal 4), pelo primeiro
// nível indentado
const fmtFor = (text) => {
  const indent = text.match(/\n( +|\t)"/)?.[1] ?? '    ';
  return {
    insertSpaces: indent[0] !== '\t',
    tabSize: indent[0] === '\t' ? 1 : indent.length,
    eol: text.includes('\r\n') ? '\r\n' : '\n',
  };
};

// modify() insere o valor sem o recuo do contexto; format() só no trecho editado o alinha sem
// mexer no resto do arquivo
function edit(text, path, value, extra = {}) {
  const formattingOptions = fmtFor(text);
  const edits = modify(text, path, value, { formattingOptions, ...extra });
  let out = applyEdits(text, edits);
  for (const e of edits) {
    out = applyEdits(out, format(out, { offset: e.offset, length: e.content.length }, formattingOptions));
  }
  return out;
}
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);

// Chave a chave: só gera edição quando o valor atual difere
function editsFor(text, keys) {
  const current = parse(text, [], { allowTrailingComma: true });
  const pending = [];
  for (const [path, value, how] of keys) {
    const now = path.reduce((o, k) => (o == null ? undefined : o[k]), current);
    const want = how !== REPLACE && value !== null && typeof value === 'object' && !Array.isArray(value) && now && typeof now === 'object'
      ? { ...now, ...value } // objeto: mescla, preserva campos extras que a pessoa tenha
      : value;
    if (!same(now, want)) pending.push([path, want]);
  }
  return pending;
}

function wtKeys(text, profile) {
  const tree = parseTree(text, [], { allowTrailingComma: true });
  const list = findNodeAtLocation(tree, ['profiles', 'list']);
  if (!list || list.type !== 'array') return { error: 'formato de "profiles" não reconhecido' };
  const items = parse(text, [], { allowTrailingComma: true }).profiles.list;
  let idx = items.findIndex((p) => p.guid?.toLowerCase() === profile.guid);
  if (idx < 0) idx = items.findIndex((p) => p.name === 'zsh');
  const keys = [[['defaultProfile'], profile.guid]];
  if (idx < 0) return { keys, insert: profile };
  // Perfil existente: só os campos portáteis; imagem de fundo, elevate etc. ficam como estão
  for (const [k, v] of Object.entries(profile)) keys.push([['profiles', 'list', idx, k], v]);
  return { keys };
}

let differs = 0;
for (const t of targets) {
  if (!existsSync(t.file)) {
    if (t.name !== 'Windows Terminal') console.log(`  - ${t.name}: não instalado, pulando`);
    continue;
  }
  let text = readFileSync(t.file, 'utf8');
  let pending;
  let insert;
  if (t.wtProfile) {
    const r = wtKeys(text, t.wtProfile);
    if (r.error) { console.log(`  ! ${t.name}: ${r.error}; ajuste à mão`); continue; }
    pending = editsFor(text, r.keys);
    insert = r.insert;
  } else {
    pending = editsFor(text, t.keys);
  }
  if (!pending.length && !insert) { console.log(`  ✓ ${t.name}: ok`); continue; }
  differs++;
  const what = [...pending.map(([p]) => p.join('.')), ...(insert ? ['perfil zsh (novo)'] : [])];
  if (mode === 'check') { console.log(`  ✗ ${t.name}: diferente → ${what.join(', ')}`); continue; }

  copyFileSync(t.file, `${t.file}.bak-${stamp}`);
  if (insert) {
    const len = parse(text, [], { allowTrailingComma: true }).profiles.list.length;
    text = edit(text, ['profiles', 'list', len], insert, { isArrayInsertion: true });
  }
  for (const [path, value] of pending) text = edit(text, path, value);
  writeFileSync(t.file, text);
  console.log(`  ✓ ${t.name}: atualizado (${what.join(', ')}); backup ao lado`);
}
process.exitCode = mode === 'check' && differs ? 3 : 0;
