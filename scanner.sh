#!/data/data/com.termux/files/usr/bin/bash
# Scanner anti-cheat Free Fire (Termux) - com assistente de pareamento ADB

R='\033[31m'; G='\033[32m'; Y='\033[33m'; C='\033[36m'; B='\033[1m'; N='\033[0m'
ALERTAS=0

ok()   { echo -e "${G}[OK]${N} $1"; }
warn() { echo -e "${Y}[?]${N}  $1"; }
bad()  { echo -e "${R}[!]${N}  $1"; ALERTAS=$((ALERTAS+1)); }
passo(){ echo -e "\n${C}${B}$1${N}"; }

banner() {
  clear
  echo -e "${C}${B}"
  echo "╔══════════════════════════════╗"
  echo "║   SCANNER FREE FIRE - ADB    ║"
  echo "╚══════════════════════════════╝"
  echo -e "${N}"
}

# ---------- Dependências ----------
checar_deps() {
  if ! command -v adb >/dev/null 2>&1; then
    passo "Instalando android-tools..."
    pkg update -y >/dev/null 2>&1
    pkg install android-tools -y || { echo "Falha ao instalar o adb."; exit 1; }
  fi
}

conectado() { adb devices 2>/dev/null | grep -qw "device"; }

# ---------- Assistente de pareamento ----------
parear() {
  passo "PASSO 1 de 3 — Ativar a Depuração sem fio"
  echo "1. Configurações > Sobre o telefone > toque 7x em 'Número da versão'"
  echo "2. Configurações > Opções do desenvolvedor"
  echo "3. Ative 'Depuração sem fio' (conecte ao Wi-Fi antes)"
  echo
  read -rp "Pronto? Aperte ENTER para continuar..." _

  passo "PASSO 2 de 3 — Parear"
  echo "Em 'Depuração sem fio', toque em 'Parear dispositivo com código'."
  echo "Vai aparecer um código de 6 dígitos e um IP:PORTA."
  echo -e "${Y}Dica: use a tela dividida para ver o Termux e a janela ao mesmo tempo.${N}"
  echo

  while true; do
    read -rp "Porta de PAREAMENTO (só o número, ex: 41234): " PORTA_P
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
    bad "Falha ao parear. O código expira rápido — gere outro e tente de novo."
    return 1
  fi

  passo "PASSO 3 de 3 — Conectar"
  echo "Volte à tela principal de 'Depuração sem fio'."
  echo "Veja o 'Endereço IP e porta' (a porta é DIFERENTE da de pareamento)."
  echo
  while true; do
    read -rp "Porta de CONEXÃO (ex: 37891): " PORTA_C
    [[ "$PORTA_C" =~ ^[0-9]{4,5}$ ]] && break
    echo "Porta inválida, tente de novo."
  done

  adb connect "localhost:$PORTA_C" >/dev/null 2>&1
  sleep 1
  if conectado; then
    ok "Conectado ao ADB!"
    return 0
  fi
  bad "Não conectou. Confira a porta e se o Wi-Fi está ligado."
  return 1
}

garantir_conexao() {
  adb start-server >/dev/null 2>&1
  if conectado; then
    ok "ADB já conectado, pulando pareamento."
    return 0
  fi
  until parear; do
    echo
    read -rp "Tentar de novo? (s/n): " R_
    [[ "$R_" =~ ^[sS]$ ]] || exit 1
    banner
  done
}

# ---------- Scan ----------
sh_() { adb shell "$@" 2>/dev/null; }

scan() {
  ALERTAS=0
  passo "Iniciando varredura..."

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

# ---------- Menu ----------
menu() {
  while true; do
    echo
    echo "1) Rodar varredura"
    echo "2) Desconectar ADB e sair"
    echo "3) Sair"
    read -rp "Escolha: " OP
    case "$OP" in
      1) scan ;;
      2) adb disconnect >/dev/null 2>&1; echo "Desconectado."; exit 0 ;;
      3) exit 0 ;;
      *) echo "Opção inválida." ;;
    esac
  done
}

banner
checar_deps
garantir_conexao
scan
menu
