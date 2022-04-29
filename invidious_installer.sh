#!/usr/bin/env bash


## Author: Tommy Miland (@tmiland) - Copyright (c) 2022


######################################################################
####                   Invidious Installer.sh                     ####
####            Automatic install script for Invidious            ####
####                 Script to install Invidious                  ####
####                   Maintained by @tmiland                     ####
######################################################################

VERSION='1.6.2' # Must stay on line 14 for updater to fetch the numbers

#------------------------------------------------------------------------------#
#
# MIT License
#
# Copyright (c) 2022 Tommy Miland
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#------------------------------------------------------------------------------#
## Uncomment for debugging purpose
#set -o errexit
#set -o pipefail
#set -o nounset
#set -o xtrace
#timestamp
# time_stamp=$(date)
# Detect absolute and full path as well as filename of this script
cd "$(dirname "$0")" || exit
CURRDIR=$(pwd)
SCRIPT_FILENAME=$(basename "$0")
cd - > /dev/null || exit
sfp=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || greadlink -f "${BASH_SOURCE[0]}" 2>/dev/null)
if [ -z "$sfp" ]; then sfp=${BASH_SOURCE[0]}; fi
#SCRIPT_DIR=$(dirname "${sfp}")
# Icons used for printing
ARROW='➜'
DONE='✔'
ERROR='✗'
WARNING='⚠'
# Colors used for printing
RED='\033[0;31m'
#BLUE='\033[0;34m'
BBLUE='\033[1;34m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
# DARKORANGE="\033[38;5;208m"
# CYAN='\033[0;36m'
# DARKGREY="\033[48;5;236m"
NC='\033[0m' # No Color
# Text formatting used for printing
# BOLD="\033[1m"
# DIM="\033[2m"
# UNDERLINED="\033[4m"
# INVERT="\033[7m"
# HIDDEN="\033[8m"
# Script name
SCRIPT_NAME="Invidious Installer.sh"
# Repo name
REPO_NAME="tmiland/invidious-installer"
# Set username
USER_NAME=invidious
# Set userdir
USER_DIR="/home/invidious"
# Set repo Dir
REPO_DIR=$USER_DIR/invidious
# Set config file path
IN_CONFIG=${REPO_DIR}/config/config.yml
# Service name
SERVICE_NAME=invidious.service
# Default branch
IN_BRANCH=master
# Default domain
DOMAIN=${DOMAIN:-}
# Default ip
IP=${IP:-localhost}
# Default port
PORT=${PORT:-3000}
# Default dbname
PSQLDB=${PSQLDB:-invidious}
# Generate db password
PSSQLPASS_GEN=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
# Default dbpass (generated)
PSQLPASS=${PSQLPASS:-$PSSQLPASS_GEN}
# Default https only
HTTPS_ONLY=${HTTPS_ONLY:-n}
# Default external port
EXTERNAL_PORT=${EXTERNAL_PORT:-}
# Default admins
ADMINS=${ADMINS:-}
# Default Captcha Key
CAPTCHA_KEY=${CAPTCHA_KEY:-}
# Default Swap option
SWAP_OPTIONS=${SWAP_OPTIONS:-n}
# Logfile
LOGFILE=invidious_update.log

install_log() {
  exec > >(tee ${LOGFILE}) 2>&1
}

read_sleep() {
    read -rt "$1" <> <(:) || :
}

indexit() {
  cd "${CURRDIR}" || exit
  ./"${SCRIPT_FILENAME}"
}

repoexit() {
  cd ${REPO_DIR} || exit 1
}

# Distro support
ARCH_CHK=$(uname -m)
if [ ! ${ARCH_CHK} == 'x86_64' ]; then
  echo -e "${RED}${ERROR} Error: Sorry, your OS ($ARCH_CHK) is not supported.${NC}"
  exit 1;
fi
shopt -s nocasematch
  if [[ -f /etc/debian_version ]]; then
    DISTRO=$(cat /etc/issue.net)
  elif [[ -f /etc/redhat-release ]]; then
    DISTRO=$(cat /etc/redhat-release)
  elif [[ -f /etc/os-release ]]; then
    DISTRO=$(cat /etc/os-release | grep "PRETTY_NAME" | sed 's/PRETTY_NAME=//g' | sed 's/["]//g' | awk '{print $1}')
  fi
case "$DISTRO" in
  Debian*|Ubuntu*|LinuxMint*|PureOS*|Pop*|Devuan*)
    # shellcheck disable=SC2140
    PKGCMD="apt-get -o Dpkg::Progress-Fancy="1" install -qq"
    LSB=lsb-release
    DISTRO_GROUP=Debian
    ;;
  CentOS*)
    PKGCMD="yum install -y"
    LSB=redhat-lsb
    DISTRO_GROUP=RHEL
    ;;
  Fedora*)
    PKGCMD="dnf install -y"
    LSB=redhat-lsb
    DISTRO_GROUP=RHEL
    ;;
  Arch*|Manjaro*)
    PKGCMD="yes | LC_ALL=en_US.UTF-8 pacman -S"
    LSB=lsb-release
    DISTRO_GROUP=Arch
    ;;
  *) echo -e "${RED}${ERROR} unknown distro: '$DISTRO'${NC}" ; exit 1 ;;
esac
if ! lsb_release -si >/dev/null 2>&1; then
  echo ""
  echo -e "${RED}${ERROR} Looks like ${LSB} is not installed!${NC}"
  echo ""
  read -r -p "Do you want to download ${LSB}? [y/n]? " ANSWER
  echo ""
  case $ANSWER in
    [Yy]* )
      echo -e "${GREEN}${ARROW} Installing ${LSB} on ${DISTRO}...${NC}"
      su -s "$(which bash)" -c "${PKGCMD} ${LSB}" || echo -e "${RED}${ERROR} Error: could not install ${LSB}!${NC}"
      echo -e "${GREEN}${DONE} Done${NC}"
      read_sleep 3
      indexit
      ;;
    [Nn]* )
      exit 1;
      ;;
    * ) echo "Enter Y, N, please." ;;
  esac
fi
SUDO=""
UPDATE=""
INSTALL=""
PKGCHK=""
PGSQL_SERVICE=""
SYSTEM_CMD=""
shopt -s nocasematch
if [[ $DISTRO_GROUP == "Debian" ]]; then
  export DEBIAN_FRONTEND=noninteractive
  SUDO="sudo"
  # shellcheck disable=SC2140
  UPDATE="apt-get -o Dpkg::Progress-Fancy="1" update -qq"
  # shellcheck disable=SC2140
  INSTALL="apt-get -o Dpkg::Progress-Fancy="1" install -qq"
  # shellcheck disable=SC2140
  PKGCHK="dpkg -s"
  # Pre-install packages
  PRE_INSTALL_PKGS="apt-transport-https git curl sudo gnupg"
  # Install packages
  INSTALL_PKGS="crystal libssl-dev libxml2-dev libyaml-dev libgmp-dev libreadline-dev librsvg2-bin postgresql libsqlite3-dev zlib1g-dev libpcre3-dev libevent-dev"
  # PostgreSQL Service
  PGSQL_SERVICE="postgresql"
  # System cmd
  SYSTEM_CMD="systemctl"
  # Postgresql config folder
  pgsql_config_folder=$(find "/etc/postgresql/" -maxdepth 1 -type d -name "*" | sort -V | tail -1)
elif [[ $(lsb_release -si) == "CentOS" ]]; then
  SUDO="sudo"
  UPDATE="yum update -q"
  INSTALL="yum install -y -q"
  PKGCHK="rpm --quiet --query"
  # Pre-install packages
  PRE_INSTALL_PKGS="epel-release git curl sudo dnf-plugins-core"
  # Install packages
  INSTALL_PKGS="crystal openssl-devel libxml2-devel libyaml-devel gmp-devel readline-devel librsvg2-tools sqlite-devel postgresql postgresql-server zlib-devel gcc libevent-devel"
  # PostgreSQL Service
  PGSQL_SERVICE="postgresql"
  # System cmd
  SYSTEM_CMD="systemctl"
  # Postgresql config folder
  pgsql_config_folder=$(find "/etc/postgresql/" -maxdepth 1 -type d -name "*" | sort -V | tail -1)
elif [[ $(lsb_release -si) == "Fedora" ]]; then
  SUDO="sudo"
  UPDATE="dnf update -q"
  INSTALL="dnf install -y -q"
  PKGCHK="rpm --quiet --query"
  # Pre-install packages
  PRE_INSTALL_PKGS="git curl sudo"
  # Install packages
  INSTALL_PKGS="crystal openssl-devel libxml2-devel libyaml-devel gmp-devel readline-devel librsvg2-tools sqlite-devel postgresql postgresql-server zlib-devel gcc libevent-devel"
  # PostgreSQL Service
  PGSQL_SERVICE="postgresql"
  # System cmd
  SYSTEM_CMD="systemctl"
  # Postgresql config folder
  pgsql_config_folder=$(find "/etc/postgresql/" -maxdepth 1 -type d -name "*" | sort -V | tail -1)
elif [[ $DISTRO_GROUP == "Arch" ]]; then
  SUDO="sudo"
  UPDATE="pacman -Syu"
  INSTALL="pacman -S --noconfirm --needed"
  PKGCHK="pacman -Qs"
  # Pre-install packages
  PRE_INSTALL_PKGS="git curl sudo"
  # Install packages
  INSTALL_PKGS="base-devel shards crystal librsvg postgresql"
  # PostgreSQL Service
  PGSQL_SERVICE="postgresql"
  # System cmd
  SYSTEM_CMD="systemctl"
  # Postgresql config folder
  pgsql_config_folder="/var/lib/postgres/data"
else
  echo -e "${RED}${ERROR} Error: Sorry, your OS is not supported.${NC}"
  exit 1;
fi
# Check if systemd is installed on Devuan
if [[ $(lsb_release -si) == "Devuan" ]]; then
  if ( ! $SYSTEM_CMD 2>/dev/null); then
    echo -e "${RED}${ERROR} Error: Sorry, you need systemd to run this script.${NC}"
    exit 1;
  fi
fi

usage() {
  echo "script usage: $SCRIPT_FILENAME [-l]"
  echo "   [-l] Activate logging"
}

# Make sure that the script runs with root permissions
chk_permissions() {
  if [[ "$EUID" != 0 ]]; then
    echo -e "${RED}${ERROR} This action needs root permissions."
    echo -e "${NC}  Please enter your root password...";
    cd "$CURRDIR" || exit
    su -s "$(which bash)" -c "./$SCRIPT_FILENAME"
    cd - > /dev/null || exit
    exit 0;
  fi
}

ADD_SWAP_URL=https://raw.githubusercontent.com/tmiland/swap-add/master/swap-add.sh

add_swap() {
  if [[ $(command -v 'curl') ]]; then
    # shellcheck disable=SC1090
    source <(curl -sSLf $ADD_SWAP_URL)
  elif [[ $(command -v 'wget') ]]; then
    # shellcheck disable=SC1090
    . <(wget -qO - $ADD_SWAP_URL)
  else
    echo -e "${RED}${ERROR} This script requires curl or wget.\nProcess aborted${NC}"
    exit 0
  fi
  read_sleep 3
  indexit
}

# Show service status - @FalconStats
show_status() {
    declare -a services=(
      "invidious"
      "postgresql"
      )
  #fi
  declare -a serviceName=(
    "Invidious"
    "PostgreSQL"
  )
  declare -a serviceStatus=()

  for service in "${services[@]}"
  do
    serviceStatus+=("$($SYSTEM_CMD is-active "$service")")
  done

  echo ""
  echo "Services running:"

  for i in "${!serviceStatus[@]}"
  do

    if [[ "${serviceStatus[$i]}" == "active" ]]; then
      line+="${GREEN}${NC}${serviceName[$i]}: ${GREEN}● ${serviceStatus[$i]}${NC} "
    else
      line+="${serviceName[$i]}: ${RED}▲ ${serviceStatus[$i]}${NC} "
    fi
  done

  echo -e "$line"
}

if ( $SYSTEM_CMD -q is-active ${SERVICE_NAME}); then
  SHOW_STATUS=$(show_status)
fi

# Show Docker Status
show_docker_status() {

  declare -a container=(
    "invidious_invidious_1"
    "invidious_postgres_1"
  )
  declare -a containerName=(
    "Invidious"
    "PostgreSQL"
  )
  declare -a status=()

  echo ""
  echo "Docker Status:"

  running_containers="$( docker ps )"
  for container_name in "${container[@]}"
  do
    #status+=($(docker ps "$container_name"))
    status+=("$( echo -n "$running_containers" | grep -oP "(?<= )$container_name$" | wc -l )")
  done

  for i in "${!status[@]}"
  do
    # shellcheck disable=SC2128
    if [[ "$status"  = "1" ]] ; then
      line+="${containerName[$i]}: ${GREEN}● running${NC} "
    else
      line+="${containerName[$i]}: ${RED}▲ stopped${NC} "
    fi
  done

  echo -e "$line"
}

# BANNERS

# Header
header() {
  echo -e "${GREEN}\n"
  echo ' ╔═══════════════════════════════════════════════════════════════════╗'
  echo ' ║                        '"${SCRIPT_NAME}"'                     ║'
  echo ' ║               Automatic install script for Invidious              ║'
  echo ' ║                      Maintained by @tmiland                       ║'
  echo ' ║                          version: '${VERSION}'                           ║'
  echo ' ╚═══════════════════════════════════════════════════════════════════╝'
  echo -e "${NC}"
}

# Preinstall banner
show_preinstall_banner() {
  clear
  header
  echo "Thank you for using the ${SCRIPT_NAME} script."
  echo ""
  echo ""
  echo ""
  echo -e "Documentation for this script is available here: ${ORANGE}\n ${ARROW} https://github.com/tmiland/${REPO_NAME}${NC}\n"
}

# Install banner
show_install_banner() {
  #clear
  header
  echo ""
  echo ""
  echo ""
  echo "Thank you for using the ${SCRIPT_NAME} script."
  echo ""
  echo ""
  echo ""
  echo -e "${GREEN}${DONE} Invidious install done.${NC} Now visit http://${IP}:${PORT}"
  echo ""
  echo ""
  echo ""
  echo ""
  echo -e "Documentation for this script is available here: ${ORANGE}\n ${ARROW} https://github.com/tmiland/${REPO_NAME}${NC}\n"
}

# Banner
show_banner() {
  #clear
  header
  echo "Welcome to the ${SCRIPT_NAME} script."
  echo ""
  echo ""
  echo "${SHOW_STATUS} "
  echo ""
  echo ""
  echo ""
  echo -e "Documentation for this script is available here: ${ORANGE}\n ${ARROW} https://github.com/tmiland/${REPO_NAME}${NC}\n"
}

# Exit Script
exit_script() {
  #header
  echo -e "${GREEN}"
  echo    '      ____          _     ___                    '
  echo    '     /  _/___ _  __(_)___/ (_)___  __  _______   '
  echo    '    / // __ \ | / / / __  / / __ \/ / / / ___/   '
  echo    '  _/ // / / / |/ / / /_/ / / /_/ / /_/ (__  )    '
  echo    ' /___/_/ /_/|___/_/\__,_/_/\____/\__,_/____/     '
  echo    '    __  __          __      __              __   '
  echo    '   / / / /___  ____/ /___ _/ /____    _____/ /_  '
  echo    '  / / / / __ \/ __  / __ `/ __/ _ \  / ___/ __ \ '
  echo    ' / /_/ / /_/ / /_/ / /_/ / /_/  __/ (__  ) / / / '
  echo    ' \____/ .___/\__,_/\__,_/\__/\___(_)____/_/ /_/  '
  echo -e '     /_/                                         ' "${NC}"
  #echo -e "${NC}"
  echo -e "
   This script runs on coffee ☕

   ${GREEN}${DONE}${NC} ${BBLUE}Paypal${NC} ${ARROW} ${ORANGE}https://paypal.me/milanddata${NC}
   ${GREEN}${DONE}${NC} ${BBLUE}BTC${NC}    ${ARROW} ${ORANGE}33mjmoPxqfXnWNsvy8gvMZrrcG3gEa3YDM${NC}
  "
  echo -e "Documentation for this script is available here: ${ORANGE}\n${ARROW} https://github.com/tmiland/${REPO_NAME}${NC}\n"
  echo -e "${ORANGE}${ARROW} Goodbye.${NC} ☺"
  echo ""
}

# Check Git repo
chk_git_repo() {
  # Check if the folder is a git repo
  if [[ -d "${REPO_DIR}/.git" ]]; then
    echo ""
    echo -e "${RED}${ERROR} Looks like Invidious is already installed!${NC}"
    echo ""
    echo -e "${ORANGE}${WARNING} If you want to reinstall, please remove Invidious first!${NC}"
    echo ""
    read_sleep 3
    #indexit
    exit 0
  fi
}

# Set permissions
set_permissions() {
  ${SUDO} chown -R $USER_NAME:$USER_NAME $USER_DIR
  ${SUDO} chmod -R 755 $USER_DIR
}

# Update config
update_config() {

  # Update config.yml with new info from user input
  BAKPATH="/home/backup/$USER_NAME/config"
  # Lets change the default password
  OLDPASS="password: kemal"
  NEWPASS="password: $PSQLPASS"
  # Lets change the default database name
  OLDDBNAME="dbname: invidious"
  NEWDBNAME="dbname: $PSQLDB"
  # Lets change the default domain
  OLDDOMAIN="domain:"
  NEWDOMAIN="domain: $DOMAIN"
  # Lets change https_only value
  OLDHTTPS="https_only: false"
  NEWHTTPS="https_only: $HTTPS_ONLY"
  # Lets change external_port
  OLDEXTERNAL="external_port:"
  NEWEXTERNAL="external_port: $EXTERNAL_PORT"
  DPATH="${IN_CONFIG}"
  BPATH="$BAKPATH"
  TFILE="/tmp/config.yml"
  [ ! -d $BPATH ] && mkdir -p $BPATH || :
  for f in $DPATH
  do # shellcheck disable=SC2166
    if [ -f $f -a -r $f ]; then
      /bin/cp -f $f $BPATH
      echo -e "${GREEN}${ARROW} Updating config.yml with new info...${NC}"
      # Add external_port: to config on line 13
      sed -i "11i\external_port:" "$f" > $TFILE
      sed -i "12i\check_tables: true" "$f" > $TFILE
      sed -i "13i\port: $PORT" "$f" > $TFILE
      sed -i "14i\host_binding: $IP" "$f" > $TFILE
      sed -i "15i\admins: \n- $ADMINS" "$f" > $TFILE
      sed -i "17i\captcha_key: $CAPTCHA_KEY" "$f" > $TFILE
      sed -i "18i\captcha_api_url: https://api.anti-captcha.com" "$f" > $TFILE
      sed "s/$OLDPASS/$NEWPASS/g; s/$OLDDBNAME/$NEWDBNAME/g; s/$OLDDOMAIN/$NEWDOMAIN/g; s/$OLDHTTPS/$NEWHTTPS/g; s/$OLDEXTERNAL/$NEWEXTERNAL/g;" "$f" > $TFILE &&
      mv $TFILE "$f"
    else
      echo -e "${RED}${ERROR} Error: Cannot read $f"
    fi
  done

  if [[ -e $TFILE ]]; then
    /bin/rm $TFILE
  else
    echo -e "${GREEN}${DONE} Done.${NC}"
  fi
  # Done updating config.yml with new info!
  # Source: https://www.cyberciti.biz/faq/unix-linux-replace-string-words-in-many-files/
}

# Systemd install
systemd_install() {
  # Setup Systemd Service
  shopt -s nocasematch
  if [[ $DISTRO_GROUP == "RHEL" ]]; then
    cp ${REPO_DIR}/${SERVICE_NAME} /etc/systemd/system/${SERVICE_NAME}
  else
    cp ${REPO_DIR}/${SERVICE_NAME} /lib/systemd/system/${SERVICE_NAME}
  fi
  #${SUDO} sed -i "s/invidious -o invidious.log/invidious -b ${ip} -p ${port} -o invidious.log/g" /lib/systemd/system/${SERVICE_NAME}
  # Enable invidious start at boot
  ${SUDO} $SYSTEM_CMD enable ${SERVICE_NAME}
  # Reload Systemd
  ${SUDO} $SYSTEM_CMD daemon-reload
  # Restart Invidious
  ${SUDO} $SYSTEM_CMD start ${SERVICE_NAME}
  if ( $SYSTEM_CMD -q is-active ${SERVICE_NAME})
  then
    echo -e "${GREEN}${DONE} Invidious service has been successfully installed!${NC}"
    ${SUDO} $SYSTEM_CMD status ${SERVICE_NAME} --no-pager
    read_sleep 5
  else
    echo -e "${RED}${ERROR} Invidious service installation failed...${NC}"
    ${SUDO} journalctl -u ${SERVICE_NAME}
    read_sleep 5
  fi
}

logrotate_install() {
  if [ -d /etc/logrotate.d ]; then
    echo "Adding logrotate configuration..."
    echo "/home/invidious/invidious/invidious.log {
    rotate 4
    weekly
    notifempty
    missingok
    compress
    minsize 1048576
}" | ${SUDO} tee /etc/logrotate.d/invidious.logrotate
    chmod 0644 /etc/logrotate.d/invidious.logrotate
    echo " (done)"
  fi
}

# Get Crystal
get_crystal() {
  shopt -s nocasematch
  if [[ $DISTRO_GROUP == "Debian" ]]; then
    if [[ ! -e /etc/apt/sources.list.d/crystal.list ]]; then
      curl -fsSL https://crystal-lang.org/install.sh | ${SUDO} bash
    fi
  elif [[ $DISTRO_GROUP == "RHEL" ]]; then
    if [[ ! -e /etc/yum.repos.d/crystal.repo ]]; then
      curl -fsSL https://crystal-lang.org/install.sh | ${SUDO} bash
    fi
  elif [[ $(lsb_release -si) == "Darwin" ]]; then
    exit 1;
  elif [[ $DISTRO_GROUP == "Arch" ]]; then
    echo "Arch/Manjaro Linux... Skipping manual crystal install"
  else
    echo -e "${RED}${ERROR} Error: Sorry, your OS is not supported.${NC}"
    exit 1;
  fi
}

# Create new config.yml
create_config() {
if [ ! -f "$IN_CONFIG" ]; then
  echo "channel_threads: 1
feed_threads: 1
db:
  user: kemal
  password: kemal
  host: localhost
  port: 5432
  dbname: invidious
full_refresh: false
https_only: false
domain:" | ${SUDO} tee ${IN_CONFIG}
fi
}

# Backup config file
backupConfig() {
  # Set config backup path
  ConfigBakPath="/home/backup/$USER_NAME/config"
  # If directory is not created
  [ ! -d $ConfigBakPath ] && mkdir -p $ConfigBakPath || :
  configBackup=${IN_CONFIG}
  backupConfigFile=$(date +%F).config.yml
  /bin/cp -f $configBackup $ConfigBakPath/$backupConfigFile
}

# Checkout Master branch to branch master (to avoid detached HEAD state)
GetMaster() {
  create_config
  backupConfig
  git checkout origin/${IN_BRANCH} -B ${IN_BRANCH}
}

# Ask user to update yes/no
if [ $# != 0 ]; then
  while getopts ":l" opt; do
    case $opt in
      l)
        install_log
        ;;
      \?)
        echo -e "${RED}\n ${ERROR} Error! Invalid option: -$OPTARG${NC}" >&2
        usage
        ;;
      :)
        echo -e "${RED}${ERROR} Error! Option -$OPTARG requires an argument.${NC}" >&2
        exit 1
        ;;
    esac
  done
fi

install_invidious() {
  ## get total free memory size in megabytes(MB)
  free=$(free -mt | grep Total | awk '{print $4}')
  chk_git_repo

  show_preinstall_banner

  if [[ "$free" -le 2048  ]]; then
    echo -e "${ORANGE}Advice: Free memory: $free MB is less than recommended to build Invidious${NC}"
    case $SWAP_OPTIONS in
      [Yy]* )
        add_swap
        ;;
      [Nn]* )
        return 0
        ;;
    esac
  fi

  case $HTTPS_ONLY in
    [Yy]* )
      HTTPS_ONLY=true
      EXTERNAL_PORT=443
      ;;
    [Nn]* )
      HTTPS_ONLY=false
      EXTERNAL_PORT=
      ;;
  esac

  PSQLDB=$(printf '%s\n' $PSQLDB | LC_ALL=C tr '[:upper:]' '[:lower:]')

  echo -e "${GREEN}\n"
  echo -e "Install options: \n"
  echo -e " ${DONE} branch        : $IN_BRANCH"
  echo -e " ${DONE} domain        : $DOMAIN"
  echo -e " ${DONE} ip address    : $IP"
  echo -e " ${DONE} port          : $PORT"
  if [ ! -z "$EXTERNAL_PORT" ]; then
    echo -e " ${DONE} external port : $EXTERNAL_PORT"
  fi
  echo -e " ${DONE} dbname        : $PSQLDB"
  echo -e " ${DONE} dbpass        : $PSQLPASS"
  echo -e " ${DONE} https only    : $HTTPS_ONLY"
  if [ ! -z "$ADMINS" ]; then
    echo -e " ${DONE} admins        : $ADMINS"
  fi
  if [ ! -z "$CAPTCHA_KEY" ]; then
    echo -e " ${DONE} captcha key   : $CAPTCHA_KEY"
  fi
  echo -e " ${NC}"
  echo ""
  echo ""

  # Setup Dependencies
  if ! ${PKGCHK} $PRE_INSTALL_PKGS >/dev/null 2>&1; then
    ${UPDATE}
    for i in $PRE_INSTALL_PKGS; do
      ${INSTALL} $i 2> /dev/null # || exit 1
    done
  fi

  get_crystal

  if ! ${PKGCHK} $INSTALL_PKGS >/dev/null 2>&1; then
    ${SUDO} ${UPDATE}
    for i in $INSTALL_PKGS; do
      ${SUDO} ${INSTALL} $i 2> /dev/null # || exit 1 #--allow-unauthenticated
    done
  fi

  # Setup Repository
  # https://stackoverflow.com/a/51894266
  grep $USER_NAME /etc/passwd >/dev/null 2>&1
  if [ ! $? -eq 0 ] ; then
    echo -e "${ORANGE}${ARROW} User $USER_NAME Not Found, adding user${NC}"
    ${SUDO} useradd -m $USER_NAME
  fi

  # If directory is not created
  if [[ ! -d $USER_DIR ]]; then
    echo -e "${ORANGE}${ARROW} Folder Not Found, adding folder${NC}"
    mkdir -p $USER_DIR
  fi

  set_permissions

  echo -e "${ORANGE}${ARROW} Downloading Invidious from GitHub${NC}"
  #sudo -i -u $USER_NAME
  cd $USER_DIR || exit 1
  sudo -i -u invidious \
    git clone https://github.com/iv-org/invidious
  repoexit
  # Checkout
  GetMaster

  echo -e "${GREEN}${ARROW} Done${NC}"
  set_permissions

  cd - || exit

  if [[ $DISTRO_GROUP == "RHEL" ]]; then
    if ! ${PKGCHK} ${PGSQL_SERVICE} >/dev/null 2>&1; then
      if [[ $(lsb_release -si) == "CentOS" ]]; then
        ${SUDO} yum config-manager --set-enabled powertools
        ${SUDO} dnf --enablerepo=powertools install libyaml-devel
      fi

      if [[ -d /var/lib/pgsql/data ]]; then
        if [[ -d /var/lib/pgsql/data.bak ]]; then
          ${SUDO} rm -rf /var/lib/pgsql/data.bak
        fi
          ${SUDO} mv -f /var/lib/pgsql/data /var/lib/pgsql/data.bak
          ${SUDO} /usr/bin/postgresql-setup --initdb
      else
        ${SUDO} /usr/bin/postgresql-setup --initdb
      fi
      ${SUDO} chmod 775 /var/lib/pgsql/data/postgresql.conf
      ${SUDO} chmod 775 /var/lib/pgsql/data/pg_hba.conf
      read_sleep 1
      ${SUDO} sed -i "s/#port = 5432/port = 5432/g" /var/lib/pgsql/data/postgresql.conf
      cp -rp /var/lib/pgsql/data/pg_hba.conf /var/lib/pgsql/data/pg_hba.conf.bak
      echo "# Database administrative login by Unix domain socket
local   all             postgres                                peer

# TYPE  DATABASE        USER            ADDRESS                 METHOD

# local is for Unix domain socket connections only
local   all             all                                     peer
# IPv4 local connections:
host    all             all             127.0.0.1/32            md5
# IPv6 local connections:
host    all             all             ::1/128                 md5
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            md5
host    replication     all             ::1/128                 md5" | ${SUDO} tee /var/lib/pgsql/data/pg_hba.conf
      ${SUDO} chmod 600 /var/lib/pgsql/data/postgresql.conf
      ${SUDO} chmod 600 /var/lib/pgsql/data/pg_hba.conf
    fi
  fi
  if [[ $DISTRO_GROUP == "Arch" ]]; then
    if [[ ! -d /var/lib/postgres/data ]]; then
      ${SUDO} mkdir ${pgsql_config_folder}
    fi
    if [[ -d ${pgsql_config_folder} ]]; then
      su - postgres -c "initdb --locale en_US.UTF-8 -D '/var/lib/postgres/data'"
    fi
  fi

  if [[ -d ${pgsql_config_folder}/main ]]; then
    ${SUDO} -u postgres sed -i "s/local   all             all                                     peer/local   all             all                                     md5/g" ${pgsql_config_folder}/main/pg_hba.conf
  fi
  ${SUDO} $SYSTEM_CMD enable ${PGSQL_SERVICE}
  read_sleep 1
  ${SUDO} $SYSTEM_CMD restart ${PGSQL_SERVICE}
  read_sleep 1
  # Create users and set privileges
  echo -e "${ORANGE}${ARROW} Creating user kemal with password $PSQLPASS ${NC}"
  ${SUDO} -u postgres psql -c "CREATE USER kemal WITH PASSWORD '$PSQLPASS';"
  echo -e "${ORANGE}${ARROW} Creating database $PSQLDB with owner kemal${NC}"
  ${SUDO} -u postgres psql -c "CREATE DATABASE $PSQLDB WITH OWNER kemal;"
  echo -e "${ORANGE}${ARROW} Grant all on database $PSQLDB to user kemal${NC}"
  ${SUDO} -u postgres psql -c "GRANT ALL ON DATABASE $PSQLDB TO kemal;"
  # Import db files
  if [[ -d ${REPO_DIR}/config/sql ]]; then
    for file in ${REPO_DIR}/config/sql/*; do
      echo -e "${ORANGE}${ARROW} Running $file ${NC}"
      ${SUDO} -i -u postgres PGPASSWORD="$PSQLPASS" psql -U kemal -d $PSQLDB -f $file
    done
  fi
  echo -e "${GREEN}${DONE} Finished Database section${NC}"

  update_config
  # Crystal complaining about permissions on CentOS and somewhat Debian
  # So before we build, make sure permissions are set.
  set_permissions
  repoexit
  shards install --production
  crystal build src/invidious.cr --release
  check_exit_status
  if [[ $DISTRO_GROUP == "RHEL" ]]; then
    # Set SELinux to permissive on RHEL
    ${SUDO} setenforce 0
  fi
  systemd_install
  # Not figured out why yet, so let's set permissions after as well...
  set_permissions
  logrotate_install
  show_install_banner
  read_sleep 5
  #indexit
}

# Start Script
  chk_permissions
  show_banner
# Install Invidious
  install_invidious
  exit_script
  exit