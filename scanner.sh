#!/data/data/com.termux/files/usr/bin/bash
# SCANNER DO MerllenSS - Anti-cheat Free Fire (Termux)

R='\033[31m'; G='\033[32m'; Y='\033[33m'; C='\033[36m'; M='\033[35m'; B='\033[1m'; N='\033[0m'
ALERTAS=0
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
NOMES_FILE="$HOME/.merllenss_nomes.txt"
LOG_FILE="$HOME/merllenss_wo_log.txt"
WORKDIR="$HOME/.merllenss_tmp"
touch "$NOMES_FILE"

ok()    { echo -e "${G}[OK]${N} $1"; }
warn()  { echo -e "${Y}[?]${N}  $1"; }
bad()   { echo -e "${R}[!]${N}  $1"; ALERTAS=$((ALERTAS+1)); }
passo() { echo -e "\n${C}${B}$1${N}"; }
pausar(){ echo; read -rp "ENTER para voltar ao menu..." _; }

# ---------- Visual ----------
centro() { # texto, cor
  local t="$1" cor="$2" w=42
  local pad=$(( (w - ${#t}) / 2 ))
  printf "${C}║${N}%*s${cor}%s${N}%*s${C}║${N}\n" "$pad" "" "$t" $((w - pad - ${#t})) ""
}

banner() {
  clear
  echo -e "${C}╔══════════════════════════════════════════╗${N}"
  centro "" ""
  centro "SCANNER DO MerllenSS" "${M}${B}"
  centro "Anti-cheat  |  Free Fire  |  ADB" "${Y}"
  centro "" ""
  echo -e "${C}╚══════════════════════════════════════════╝${N}"
  echo
}

# ---------- Dependências ----------
checar_deps() {
  local NEED="" par cmd pk
  for par in curl:curl unzip:unzip adb:android-tools; do
    cmd=${par%%:*}; pk=${par##*:}
    command -v "$cmd" >/dev/null 2>&1 || NEED="$NEED $pk"
  done
  if [ -n "$NEED" ]; then
    passo "Instalando:$NEED"
    pkg update -y >/dev/null 2>&1
    pkg install -y $NEED || { echo "Falha ao instalar dependências."; exit 1; }
  fi
}

# ---------- ADB: pareamento ----------
conectado() { adb devices 2>/dev/null | grep -qw "device"; }

parear() {
  passo "PASSO 1 de 3 - Ativar a Depuração sem fio"
  echo "1. Configurações > Sobre o telefone > toque 7x em 'Número da versão'"
  echo "2. Configurações > Opções do desenvolvedor"
  echo "3. Ative 'Depuração sem fio' (conecte ao Wi-Fi antes)"
  echo
  read -rp "Pronto? Aperte ENTER para continuar..." _

  passo "PASSO 2 de 3 - Parear"
  echo "Em 'Depuração sem fio', toque em 'Parear dispositivo com código'."
  echo "Vai aparecer um código de 6 dígitos e um IP:PORTA."
  echo -e "${Y}Dica: use a tela dividida para ver o Termux e a janela juntos.${N}"
  echo

  while true; do
    read -rp "Porta de PAREAMENTO (só o número): " PORTA_P
    [[ "$PORTA_P" =~ ^[0-9]{4,5}$ ]] && break
    echo "Porta inválida, tente de novo."
  done
  while true; do
    read -rp "Código de pareamento (6 dígitos): " CODIGO
    [[ "$CODIGO" =~ ^[0-9]{6}$ ]] && break
    echo "Código inválido, tente de novo."
  done

  echo "Pareando..."
  if adb pair "localhost:$PORTA_P" "$CODIGO" 2>&1 | grep -qi "successfully"; then
    ok "Pareado com sucesso!"
  else
    bad "Falha ao parear. O código expira rápido - gere outro."
    return 1
  fi

  passo "PASSO 3 de 3 - Conectar"
  echo "Volte à tela principal de 'Depuração sem fio'."
  echo "Veja o 'Endereço IP e porta' (porta DIFERENTE da de pareamento)."
  echo
  while true; do
    read -rp "Porta de CONEXÃO: " PORTA_C
    [[ "$PORTA_C" =~ ^[0-9]{4,5}$ ]] && break
    echo "Porta inválida, tente de novo."
  done

  adb connect "localhost:$PORTA_C" >/dev/null 2>&1
  sleep 1
  if conectado; then
    ok "Conectado ao ADB!"
    return 0
  fi
  bad "Não conectou. Confira a porta e o Wi-Fi."
  return 1
}

garantir_conexao() {
  adb start-server >/dev/null 2>&1
  if conectado; then
    ok "ADB já conectado."
    return 0
  fi
  until parear; do
    echo
    read -rp "Tentar de novo? (s/n): " R_
    [[ "$R_" =~ ^[sS]$ ]] || return 1
    banner
  done
}

# ---------- Varredura do celular ----------
sh_() { adb shell "$@" 2>/dev/null; }

scan() {
  ALERTAS=0
  passo "Iniciando varredura do celular..."

  echo -e "\n${B}Proxy${N}"
  P=$(sh_ settings get global http_proxy | tr -d '\r')
  H=$(sh_ settings get global global_http_proxy_host | tr -d '\r')
  if [ -n "$P" ] && [ "$P" != "null" ] && [ "$P" != ":0" ]; then
    bad "Proxy global ativo: $P"
  elif [ -n "$H" ] && [ "$H" != "null" ]; then
    bad "Proxy global configurado: $H"
  else
    ok "Nenhum proxy global detectado"
  fi

  echo -e "\n${B}Apps instalados${N}"
  PADRAO="gameguardian|catchme|lucky.?patcher|vphone|virtualxposed|parallel|dualspace|clone|lsposed|xposed|magisk|kernelsu|apkeditor|hacker|cheat|injector|panel|mod.?menu|sandbox|virtual"
  APPS=$(sh_ pm list packages | tr -d '\r' | grep -iE "$PADRAO")
  if [ -n "$APPS" ]; then
    bad "Pacotes suspeitos:"
    echo "$APPS" | sed 's/package:/     /'
  else
    ok "Nenhum pacote suspeito"
  fi

  echo -e "\n${B}Root${N}"
  if sh_ "ls /system/xbin/su /system/bin/su /sbin/su" | grep -q "/su$"; then
    bad "Binário 'su' encontrado (possível root)"
  else
    ok "Sem sinais de root"
  fi

  echo -e "\n${B}Arquivos${N}"
  ARQ=$(sh_ "find /sdcard -maxdepth 4 -type f \( -iname '*cheat*' -o -iname '*hack*' -o -iname '*aimbot*' -o -iname '*modmenu*' -o -iname '*injector*' -o -iname '*.lua' \) 2>/dev/null | head -n 20" | tr -d '\r')
  if [ -n "$ARQ" ]; then
    bad "Arquivos com nomes suspeitos:"
    echo "$ARQ" | sed 's/^/     /'
  else
    ok "Nenhum arquivo com nome suspeito"
  fi
  for PKG in com.dts.freefireth com.dts.freefiremax; do
    if sh_ "[ -d /sdcard/Android/data/$PKG ] && echo sim" | grep -q sim; then
      N_=$(sh_ "find /sdcard/Android/data/$PKG -type f -mmin -1440 2>/dev/null | wc -l" | tr -d '\r ')
      warn "$PKG: $N_ arquivo(s) modificados nas últimas 24h"
    fi
  done

  echo -e "\n${B}Sistema${N}"
  [ "$(sh_ settings get global development_settings_enabled | tr -d '\r')" = "1" ] && warn "Opções de desenvolvedor ligadas"
  [ "$(sh_ settings get global auto_time | tr -d '\r')" = "0" ] && bad "Data/hora automática DESLIGADA"
  [ "$(sh_ settings get global auto_time_zone | tr -d '\r')" = "0" ] && warn "Fuso horário automático desligado"

  echo
  echo -e "${B}══ Resultado: $ALERTAS alerta(s) ══${N}"
  [ "$ALERTAS" -eq 0 ] && echo "Nada claramente suspeito." || echo "Revise os itens marcados com [!]."
}

# ---------- Lista de nomes ----------
adicionar_nomes() {
  echo "Digite os nomes separados por vírgula (ex: fulano, ciclano, xyz123):"
  read -rp "> " ENT
  echo "$ENT" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' >> "$NOMES_FILE"
  sort -uf "$NOMES_FILE" -o "$NOMES_FILE"
  ok "Lista atualizada: $(wc -l < "$NOMES_FILE") nome(s)"
}

remover_nome() {
  if [ ! -s "$NOMES_FILE" ]; then warn "Lista vazia."; return; fi
  nl -w2 -s') ' "$NOMES_FILE"
  read -rp "Número a remover (ou 'tudo'): " N_
  if [ "$N_" = "tudo" ]; then
    : > "$NOMES_FILE"; ok "Lista limpa."
  elif [[ "$N_" =~ ^[0-9]+$ ]]; then
    sed -i "${N_}d" "$NOMES_FILE"; ok "Removido."
  else
    warn "Opção inválida."
  fi
}

gerenciar_nomes() {
  while true; do
    banner
    passo "LISTA DE NOMES ($(wc -l < "$NOMES_FILE") salvos)"
    echo -e "${B}[1]${N} Ver lista"
    echo -e "${B}[2]${N} Adicionar nomes"
    echo -e "${B}[3]${N} Remover nome / limpar"
    echo -e "${B}[0]${N} Voltar"
    echo
    read -rp "Escolha: " OP
    case "$OP" in
      1) echo; if [ -s "$NOMES_FILE" ]; then nl -w2 -s') ' "$NOMES_FILE"; else warn "Lista vazia."; fi; pausar ;;
      2) adicionar_nomes; pausar ;;
      3) remover_nome; pausar ;;
      0) return ;;
      *) echo "Opção inválida." ;;
    esac
  done
}

# ---------- Análise de arquivo do MediaFire ----------
analisar_arquivo() {
  banner
  passo "ANALISAR ARQUIVO DO MEDIAFIRE"

  if [ ! -s "$NOMES_FILE" ]; then
    warn "Sua lista de nomes está vazia."
    read -rp "Adicionar agora? (s/n): " R_
    [[ "$R_" =~ ^[sS]$ ]] && adicionar_nomes
    [ ! -s "$NOMES_FILE" ] && return
  fi
  echo "Nomes na lista: $(wc -l < "$NOMES_FILE")"
  read -rp "Cole o link do MediaFire: " LINK
  LINK=$(echo "$LINK" | tr -d ' \r\n')
  if [[ ! "$LINK" =~ mediafire\.com ]]; then
    bad "Link inválido (precisa ser do MediaFire)."
    return
  fi

  passo "Buscando o link de download..."
  DIRETO=""; HTML=""
  if [[ "$LINK" =~ ^https?://download[0-9]*\.mediafire\.com/ ]]; then
    DIRETO="$LINK"
  else
    HTML=$(curl -sL --compressed -A "$UA" -H "Accept-Language: en-US,en;q=0.9" "$LINK"); CURL_RC=$?
    if [ -z "$HTML" ]; then
      bad "Não consegui abrir a página (curl código $CURL_RC). Verifique a internet."
    fi
    DIRETO=$(echo "$HTML" | grep -oE "https?://download[0-9]*\.mediafire\.com/[^\"'<> ]+" | head -n1)
    if [ -z "$DIRETO" ]; then
      ESC=$(echo "$HTML" | grep -oE 'data-scrambled-url="[^"]+"' | head -n1 | cut -d'"' -f2)
      [ -n "$ESC" ] && DIRETO=$(echo "$ESC" | base64 -d 2>/dev/null)
    fi
    DIRETO=${DIRETO//&amp;/&}
  fi
  if [ -z "$DIRETO" ]; then
    bad "Não achei o link direto automaticamente."
    echo "  Tamanho da página recebida: ${#HTML} caracteres"
    echo "$HTML" | grep -qiE "captcha|cloudflare|just a moment" && echo "  O MediaFire pediu verificação anti-robô."
    echo
    echo "Alternativa: abra o link no navegador, segure o botão Download,"
    echo "copie o endereço do link (download....mediafire.com) e cole aqui."
    read -rp "Link direto (ENTER cancela): " DIRETO
    DIRETO=$(echo "$DIRETO" | tr -d ' \r\n')
    [ -z "$DIRETO" ] && return
  fi
  ok "Link direto encontrado"

  passo "Baixando..."
  rm -rf "$WORKDIR"; mkdir -p "$WORKDIR/ext"
  curl -fL --progress-bar -A "$UA" -e "https://www.mediafire.com/" -o "$WORKDIR/arquivo" "$DIRETO"
  RC=$?
  if [ "$RC" -ne 0 ]; then
    bad "Falha no download (curl código $RC)."
    rm -rf "$WORKDIR"; return
  fi
  if head -c 300 "$WORKDIR/arquivo" | grep -qi "<html"; then
    bad "O MediaFire devolveu uma página em vez do arquivo (link expirado ou protegido)."
    rm -rf "$WORKDIR"; return
  fi
  ok "Download concluído ($(du -h "$WORKDIR/arquivo" | cut -f1))"

  ALVO="$WORKDIR/arquivo"
  if unzip -tq "$WORKDIR/arquivo" >/dev/null 2>&1; then
    unzip -qq -o "$WORKDIR/arquivo" -d "$WORKDIR/ext" 2>/dev/null
    ALVO="$WORKDIR/ext"
    ok "ZIP extraído ($(find "$ALVO" -type f | wc -l) arquivos)"
  elif head -c 4 "$WORKDIR/arquivo" | grep -aq -e "Rar!" -e "7z"; then
    warn "RAR/7z não é extraído; a busca será no arquivo compactado e pode falhar."
  fi

  read -rp "Buscar apenas palavra inteira? (s/n): " W_
  FLAG="-F"; [[ "$W_" =~ ^[sS]$ ]] && FLAG="-Fw"

  passo "Procurando $(wc -l < "$NOMES_FILE") nome(s)..."
  ENCONTRADOS=()
  while IFS= read -r NOME; do
    [ -z "$NOME" ] && continue
    ARQS=$(grep -rai $FLAG -l -- "$NOME" "$ALVO" 2>/dev/null)
    if [ -n "$ARQS" ]; then
      ENCONTRADOS+=("$NOME")
      bad "Encontrado: ${B}$NOME${N}"
      echo "$ARQS" | head -n 5 | while read -r F; do
        echo -e "     ${Y}${F#$WORKDIR/}${N}"
        grep -ai $FLAG -m2 -- "$NOME" "$F" 2>/dev/null | tr -cd '[:print:]\n' | cut -c1-110 | sed 's/^/        > /'
      done
    fi
  done < "$NOMES_FILE"

  echo
  if [ ${#ENCONTRADOS[@]} -eq 0 ]; then
    ok "Nenhum nome da lista apareceu no arquivo."
  else
    echo -e "${R}${B}${#ENCONTRADOS[@]} nome(s) da lista apareceram no arquivo.${N}"
    read -rp "Aplicar W.O.? (s/n): " WO
    if [[ "$WO" =~ ^[sS]$ ]]; then
      read -rp "Equipe/jogador a punir (opcional): " ALVO_WO
      DATA=$(date '+%d/%m/%Y %H:%M')
      NOMES_J=$(printf '%s, ' "${ENCONTRADOS[@]}" | sed 's/, $//')
      echo "$DATA | ${ALVO_WO:-não informado} | $NOMES_J | $LINK" >> "$LOG_FILE"
      echo
      echo -e "${R}${B}╔══════════ W.O. APLICADO ══════════╗${N}"
      echo -e "  Data:     $DATA"
      echo -e "  Alvo:     ${ALVO_WO:-não informado}"
      echo -e "  Nomes:    $NOMES_J"
      echo -e "${R}${B}╚═══════════════════════════════════╝${N}"
      echo
      echo "Mensagem pronta para copiar:"
      echo "W.O. aplicado em ${ALVO_WO:-(equipe)} - nomes encontrados na análise: $NOMES_J."
      ok "Registrado em $LOG_FILE"
    else
      warn "W.O. não aplicado."
    fi
  fi
  rm -rf "$WORKDIR"
}

ver_registro() {
  banner
  passo "REGISTRO DE W.O."
  if [ -s "$LOG_FILE" ]; then
    echo -e "${B}Data | Alvo | Nomes | Link${N}"
    cat "$LOG_FILE"
  else
    warn "Nenhum W.O. registrado ainda."
  fi
}

# ---------- Menu principal ----------
menu() {
  while true; do
    banner
    echo -e "${B}[1]${N} Varredura do celular (ADB)"
    echo -e "${B}[2]${N} Analisar arquivo do MediaFire"
    echo -e "${B}[3]${N} Lista de nomes"
    echo -e "${B}[4]${N} Ver registro de W.O."
    echo -e "${B}[5]${N} Desconectar ADB e sair"
    echo -e "${B}[0]${N} Sair"
    echo
    read -rp "Escolha: " OP
    case "$OP" in
      1) banner; garantir_conexao && scan; pausar ;;
      2) analisar_arquivo; pausar ;;
      3) gerenciar_nomes ;;
      4) ver_registro; pausar ;;
      5) adb disconnect >/dev/null 2>&1; echo "Desconectado."; exit 0 ;;
      0) exit 0 ;;
      *) echo "Opção inválida."; sleep 1 ;;
    esac
  done
}

banner
checar_deps
menu
