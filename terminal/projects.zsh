# zsh — atalhos de projeto. Carregado por ./zshrc. Sozinho só define funções: os projetos são
# registrados numa camada (~/.config/zsh/conf.d/*.zsh), uma linha por pasta:
#
#   project api ~/code/acme/api https://github.com/acme/api.git   # url opcional: vira dica de clone
#   project web ~/code/acme/web
#
# Cada registro vira um comando com o nome do alias:
#   api                 entra na pasta
#   api run             servidor de dev sem sair da pasta atual (npm run dev / mvn spring-boot:run);
#                       a saída também vai para $PROJECTS_LOG_DIR/<alias>.log, recriado a cada start
#   api build | test    npm run build / test; no Maven, mvn clean compile / mvn test
#   api <script>        qualquer script do package.json (Tab lista)
#   api <comando>       qualquer comando dentro da pasta, ex.: api git log
# pst: branch e mudanças de todos os projetos · pdev [aliases]: um painel por projeto rodando "run"

typeset -ga _project_aliases        # ordem de registro: é a ordem do pst e do pdev
typeset -gA _project_dirs _project_remotes
: ${PROJECTS_LOG_DIR:=$HOME/.logs}

project() {
  (( $# >= 2 )) || { print -u2 "uso: project <alias> <pasta> [url do git clone]"; return 1 }
  local a=$1
  (( ${_project_aliases[(Ie)$a]} )) || _project_aliases+=($a)
  _project_dirs[$a]=${~2:A}
  _project_remotes[$a]=$3
  functions[$a]="_project $a \"\$@\""
  compdef _project_complete $a
}

# Pasta que não existe: avisa com o git clone certo, se o registro trouxe a url
_project_require() {
  local dir=$_project_dirs[$1] remote=$_project_remotes[$1]
  [[ -d $dir ]] && return
  print -u2 "$1: $dir não existe${remote:+ — git clone $remote $dir}"
  return 1
}

# package.json via stdin: o node do Windows não entende caminhos /c/...
_project_scripts() {
  node -e "console.log(Object.keys(JSON.parse(require('fs').readFileSync(0,'utf8')).scripts||{}).join('\n'))" < $1/package.json
}

# Servidor de dev: a saída aparece no terminal e também vai para o log (para um agente de IA ler
# os erros sem subir outro servidor). FORCE_COLOR: com o pipe, o node acha que não há terminal.
_project_tee() {
  local log=$PROJECTS_LOG_DIR/$1.log; shift
  mkdir -p ${log:h}
  FORCE_COLOR=1 "$@" 2>&1 | tee $log
}

_project() {
  local a=$1; shift
  _project_require $a || return
  local dir=$_project_dirs[$a]
  (( $# )) || { cd $dir; return }
  local cmd=$1; shift
  (
    cd $dir || return
    if [[ -f pom.xml ]]; then
      case $cmd in
        run)   _project_tee $a mvn spring-boot:run "$@" ;;
        build) mvn clean compile "$@" ;;
        test)  mvn test "$@" ;;
        *)     $cmd "$@" ;;
      esac
      return
    fi
    if [[ -f package.json ]]; then
      [[ $cmd == run ]] && { _project_tee $a npm run dev ${1:+--} "$@"; return }
      local scripts=(${(f)"$(_project_scripts $dir)"})
      (( ${scripts[(Ie)$cmd]} )) && { npm run $cmd ${1:+--} "$@"; return }
    fi
    $cmd "$@"
  )
}

_project_complete() {
  local dir=$_project_dirs[$words[1]]
  if (( CURRENT == 2 )); then
    local -a cmds=(run build test)
    [[ -f $dir/package.json ]] && cmds+=(${(f)"$(_project_scripts $dir)"})
    compadd -a cmds
  else
    _files -W $dir
  fi
}

# pst: branch e mudanças de todos os projetos registrados que existem (só leitura)
pst() {
  local a
  for a in $_project_aliases; do
    [[ -d $_project_dirs[$a] ]] || continue
    print -P "%F{cyan}== $a%f"
    git -C $_project_dirs[$a] status -sb 2>&1 | head -6
  done
}

# pdev [aliases]: um painel/janela por projeto rodando "<alias> run" (padrão: todos os registrados).
# Quando o servidor para, o painel vira um zsh normal.
#   Windows: aba nova no Windows Terminal (perfil zsh do setup), painéis lado a lado
#   macOS:   uma janela do Ghostty por projeto
# trap: sem ele, Ctrl+C no servidor aborta o "zsh -c" inteiro e fecha o painel
_pdev_pane() { trap : INT; $1 run; trap - INT; exec zsh -l -i }
pdev() {
  local -a names=($@) args
  (( $#names )) || names=($_project_aliases)
  (( $#names )) || { print -u2 "pdev: nenhum projeto registrado (veja o comando project)"; return 1 }
  local a
  for a in $names; do
    [[ -n $_project_dirs[$a] ]] || { print -u2 "pdev: projeto desconhecido: $a (registrados: $_project_aliases)"; return 1 }
    _project_require $a || return
  done
  if [[ -n $_is_windows ]]; then
    local zsh_win=$(cygpath -w $commands[zsh])
    for a in $names; do
      # ";" separa subcomandos do wt: o primeiro abre a aba, os demais dividem
      (( $#args )) && args+=(\; split-pane -V) || args+=(new-tab)
      args+=(-p zsh --title $a -d $(cygpath -w $_project_dirs[$a]) $zsh_win -l -i -c "_pdev_pane $a")
    done
    wt.exe -w 0 $args
  else
    for a in $names; do
      open -na Ghostty.app --args --title=$a --working-directory=$_project_dirs[$a] \
        -e zsh -l -i -c "_pdev_pane $a"
    done
  fi
}
