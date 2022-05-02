#!/usr/bin/env bash
# shellcheck disable=SC2059

## Author: Tommy Miland (@tmiland) - Copyright (c) 2022


######################################################################
####                   Invidious Installer.sh                     ####
####            Automatic install script for Invidious            ####
####                 Script to install Invidious                  ####
####                   Maintained by @tmiland                     ####
######################################################################

VERSION='1.6.3' # Must stay on line 14 for updater to fetch the numbers

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
#CURRDIR=$(pwd)
#SCRIPT_FILENAME=$(basename "$0")
cd - > /dev/null || exit
sfp=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || greadlink -f "${BASH_SOURCE[0]}" 2>/dev/null)
if [ -z "$sfp" ]; then sfp=${BASH_SOURCE[0]}; fi
#SCRIPT_DIR=$(dirname "${sfp}")
# Icons used for printing
ARROW='➜'
DONE='✔'
ERROR='✗'
#WARNING='⚠'
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
LOGFILE=invidious_installer.log
# Console output level; ignore debug level messages.
VERBOSE=0

usage() {
  # shellcheck disable=SC2046
  printf "Usage: %s %s [options]\\n" "${CYAN}" $(basename "$0")
  echo
  echo "  If called without arguments, installs Invidious."
  echo
  printf "  ${YELLOW}--help|-h${NORMAL}               display this help and exit\\n"
  printf "  ${YELLOW}--verbose|-v${NORMAL}            increase verbosity\\n"
  echo
}

while [ $# != 0 ]; do
  case $1 in
  --help | -h)
    usage
    exit 0
    ;;
  --verbose | -v)
    shift
    VERBOSE=1
    ;;
  *)
    printf "Unrecognized option: $1\\n\\n"
    usage
    exit 1
    ;;
  esac
done

# Include functions
if [[ -f ./src/slib.sh ]]; then
  . ./src/slib.sh
else
  SLIB_URL=https://github.com/tmiland/invidious-installer/raw/main/scr/slib.sh
  if [[ $(command -v 'curl') ]]; then
    # shellcheck disable=SC1090
    source <(curl -sSLf $SLIB_URL)
  elif [[ $(command -v 'wget') ]]; then
    # shellcheck disable=SC1090
    . <(wget -qO - $SLIB_URL)
  else
    echo -e "${RED}${ERROR} This script requires curl or wget.\nProcess aborted${NORMAL}"
    exit 0
  fi
fi

# Setup slog
# shellcheck disable=SC2034
LOG_PATH="$LOGFILE"
# Setup run_ok
# shellcheck disable=SC2034
RUN_LOG="$LOGFILE"
# Exit on any failure during shell stage
# shellcheck disable=SC2034
RUN_ERRORS_FATAL=1

# Console output level; ignore debug level messages.
if [ "$VERBOSE" = "1" ]; then
  # shellcheck disable=SC2034
  LOG_LEVEL_STDOUT="DEBUG"
else
  # shellcheck disable=SC2034
  LOG_LEVEL_STDOUT="INFO"
fi
# Log file output level; catch literally everything.
# shellcheck disable=SC2034
LOG_LEVEL_LOG="DEBUG"

# log_fatal calls log_error
log_fatal() {
  log_error "$1"
}

fatal() {
  echo
  log_fatal "Fatal Error Occurred: $1"
  printf "${RED}Cannot continue installation.${NORMAL}\\n"
  log_fatal "If you are unsure of what went wrong, you may wish to review the log"
  log_fatal "in $LOGFILE"
  exit 1
}

success() {
  log_success "$1 Succeeded."
}

# install_log() {
#   exec > >(tee ${LOGFILE}) 2>&1
# }

read_sleep() {
    read -rt "$1" <> <(:) || :
}

# repoexit() {
#   cd ${REPO_DIR} >/dev/null 2>&1 || exit 1
# }
# Start with a clean log
if [[ -f $LOGFILE ]]; then
  rm $LOGFILE
fi
# Distro support
ARCH_CHK=$(uname -m)
if [ ! "${ARCH_CHK}" == 'x86_64' ]; then
  echo -e "${RED}${ERROR} Error: Sorry, your OS ($ARCH_CHK) is not supported.${NORMAL}"
  exit 1;
fi
shopt -s nocasematch
  if [[ -f /etc/debian_version ]]; then
    DISTRO=$(cat /etc/issue.net)
  elif [[ -f /etc/redhat-release ]]; then
    DISTRO=$(cat /etc/redhat-release)
  elif [[ -f /etc/os-release ]]; then
    DISTRO=$(cat < /etc/os-release | grep "PRETTY_NAME" | sed 's/PRETTY_NAME=//g' | sed 's/["]//g' | awk '{print $1}')
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
  *) echo -e "${RED}${ERROR} unknown distro: '$DISTRO'${NORMAL}" ; exit 1 ;;
esac
if ! lsb_release -si >/dev/null 2>&1; then
  echo ""
  echo -e "${RED}${ERROR} Looks like ${LSB} is not installed!${NORMAL}"
  echo ""
  read -r -p "Do you want to download ${LSB}? [y/n]? " ANSWER
  echo ""
  case $ANSWER in
    [Yy]* )
      echo -e "${GREEN}${ARROW} Installing ${LSB} on ${DISTRO}...${NORMAL}"
      su -s "$(which bash)" -c "${PKGCMD} ${LSB}" || echo -e "${RED}${ERROR} Error: could not install ${LSB}!${NORMAL}"
      echo -e "${GREEN}${DONE} Done${NORMAL}"
      read_sleep 3
      #indexit
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
  echo -e "${RED}${ERROR} Error: Sorry, your OS is not supported.${NORMAL}"
  exit 1;
fi
# Check if systemd is installed on Devuan
if [[ $(lsb_release -si) == "Devuan" ]]; then
  if ( ! $SYSTEM_CMD 2>/dev/null); then
    echo -e "${RED}${ERROR} Error: Sorry, you need systemd to run this script.${NORMAL}"
    exit 1;
  fi
fi

# usage() {
#   echo "script usage: $SCRIPT_FILENAME [-l]"
#   echo "   [-l] Activate logging"
# }

# Make sure that the script runs with root permissions
chk_permissions() {
  if [[ $EUID -ne 0 ]]; then
  	echo -e "Sorry, you need to run this as root"
  	exit 1
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
    echo -e "${RED}${ERROR} This script requires curl or wget.\nProcess aborted${NORMAL}"
    exit 0
  fi
  read_sleep 3
  #indexit
}
## get total free memory size in megabytes(MB)
free=$(free -mt | grep Total | awk '{print $4}')
if [[ "$free" -le 2048  ]]; then
  echo -e "${YELLOW}Advice: Free memory: $free MB is less than recommended to build Invidious${NORMAL}"
  case $SWAP_OPTIONS in
    [Yy]* )
      add_swap
      ;;
    [Nn]* )
      return 0
      ;;
  esac
fi

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
      line+="${GREEN}${NORMAL}${serviceName[$i]}: ${GREEN}● ${serviceStatus[$i]}${NORMAL} "
    else
      line+="${serviceName[$i]}: ${RED}▲ ${serviceStatus[$i]}${NORMAL} "
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
      line+="${containerName[$i]}: ${GREEN}● running${NORMAL} "
    else
      line+="${containerName[$i]}: ${RED}▲ stopped${NORMAL} "
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
  echo -e "${NORMAL}"
}

# Preinstall banner
show_preinstall_banner() {
  clear
  header
  echo "Thank you for using the ${SCRIPT_NAME} script."
  echo ""
  echo ""
  echo ""
  echo -e "Documentation for this script is available here: ${YELLOW}\n ${ARROW} https://github.com/tmiland/${REPO_NAME}${NORMAL}\n"
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
  echo -e "${GREEN}${DONE} Invidious install done.${NORMAL} Now visit http://${IP}:${PORT}"
  echo ""
  echo ""
  echo ""
  echo ""
  echo -e "Documentation for this script is available here: ${YELLOW}\n ${ARROW} https://github.com/tmiland/${REPO_NAME}${NORMAL}\n"
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
  echo -e "Documentation for this script is available here: ${YELLOW}\n ${ARROW} https://github.com/tmiland/${REPO_NAME}${NORMAL}\n"
}

# Exit Script
exit_script() {
  #header
  echo -e "${GREEN}"
  echo    '      ____           _     ___                         '
  echo    '     /  _/___ _   __(_)___/ (_)___  __  _______        '
  echo    '     / // __ \ | / / / __  / / __ \/ / / / ___/        '
  echo    '   _/ // / / / |/ / / /_/ / / /_/ / /_/ (__  )         '
  echo    '  /___/_/_/_/|___/_/\__,_/_/\____/\__,_/____/     __   '
  echo    '     /  _/___  _____/ /_____ _/ / /__  __________/ /_  '
  echo    '     / // __ \/ ___/ __/ __ `/ / / _ \/ ___/ ___/ __ \ '
  echo    '   _/ // / / (__  ) /_/ /_/ / / /  __/ /  (__  ) / / / '
  echo    '  /___/_/ /_/____/\__/\__,_/_/_/\___/_(_)/____/_/ /_/  '
  echo -e '                                                       ' "${NORMAL}"
  echo -e "
   This script runs on coffee ☕

   ${GREEN}${DONE}${NORMAL} ${BBLUE}Paypal${NORMAL} ${ARROW} ${YELLOW}https://paypal.me/milanddata${NORMAL}
   ${GREEN}${DONE}${NORMAL} ${BBLUE}BTC${NORMAL}    ${ARROW} ${YELLOW}33mjmoPxqfXnWNsvy8gvMZrrcG3gEa3YDM${NORMAL}
  "
  echo -e "Documentation for this script is available here: ${YELLOW}\n${ARROW} https://github.com/tmiland/${REPO_NAME}${NORMAL}\n"
  echo -e "${YELLOW}${ARROW} Goodbye.${NORMAL} ☺"
  echo ""
}

# Check Git repo
chk_git_repo() {
  # Check if the folder is a git repo
  if [[ -d "${REPO_DIR}/.git" ]]; then
    echo ""
    log_fatal "Looks like Invidious is already installed!"
    echo ""
    log_warning "If you want to reinstall, please remove Invidious first!"
    echo ""
    read_sleep 3
    #indexit
    exit 0
  fi
}

# Set permissions
set_permissions() {
  ${SUDO} chown -R $USER_NAME:$USER_NAME $USER_DIR >>"${RUN_LOG}" 2>&1
  ${SUDO} chmod -R 755 $USER_DIR >>"${RUN_LOG}" 2>&1
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
      echo -e "${GREEN}${ARROW} Updating config.yml with new info...${NORMAL}"
      # Add external_port: to config on line 13
      sed -i "11i\external_port:" "$f" > $TFILE
      sed -i "12i\check_tables: true" "$f" > $TFILE
      sed -i "13i\port: $PORT" "$f" > $TFILE
      sed -i "14i\host_binding: $IP" "$f" > $TFILE
      sed -i "15i\admins: \n- $ADMINS" "$f" > $TFILE
      sed -i "17i\captcha_key: $CAPTCHA_KEY" "$f" > $TFILE
      sed -i "18i\captcha_api_url: https://api.anti-captcha.com" "$f" > $TFILE
      sed "s/$OLDPASS/$NEWPASS/g; s/$OLDDBNAME/$NEWDBNAME/g; s/$OLDDOMAIN/$NEWDOMAIN/g; s/$OLDHTTPS/$NEWHTTPS/g; s/$OLDEXTERNAL/$NEWEXTERNAL/g;" "$f" > $TFILE &&
      mv $TFILE "$f" >>"${RUN_LOG}" 2>&1
    else
      log_fatal "Error: Cannot read $f"
    fi
  done

  if [[ -e $TFILE ]]; then
    /bin/rm $TFILE >>"${RUN_LOG}" 2>&1
  else
    log_success "Done."
  fi
  # Done updating config.yml with new info!
  # Source: https://www.cyberciti.biz/faq/unix-linux-replace-string-words-in-many-files/
}

# Systemd install
systemd_install() {
  # Setup Systemd Service
  shopt -s nocasematch
  if [[ $DISTRO_GROUP == "RHEL" ]]; then
    cp ${REPO_DIR}/${SERVICE_NAME} /etc/systemd/system/${SERVICE_NAME} >>"${RUN_LOG}" 2>&1
  else
    cp ${REPO_DIR}/${SERVICE_NAME} /lib/systemd/system/${SERVICE_NAME} >>"${RUN_LOG}" 2>&1
  fi
  # Enable invidious start at boot
  ${SUDO} $SYSTEM_CMD enable ${SERVICE_NAME} >>"${RUN_LOG}" 2>&1
  # Reload Systemd
  ${SUDO} $SYSTEM_CMD daemon-reload >>"${RUN_LOG}" 2>&1
  # Restart Invidious
  ${SUDO} $SYSTEM_CMD start ${SERVICE_NAME} >>"${RUN_LOG}" 2>&1
  if ( $SYSTEM_CMD -q is-active ${SERVICE_NAME})
  then
    log_success "Invidious service has been successfully installed!"
    ${SUDO} $SYSTEM_CMD status ${SERVICE_NAME} --no-pager >>"${RUN_LOG}" 2>&1
    read_sleep 5
  else
    log_fatal "Invidious service installation failed..."
    ${SUDO} journalctl -u ${SERVICE_NAME} >>"${RUN_LOG}" 2>&1
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
}" | ${SUDO} tee /etc/logrotate.d/invidious.logrotate >>"${RUN_LOG}" 2>&1
    chmod 0644 /etc/logrotate.d/invidious.logrotate >>"${RUN_LOG}" 2>&1
    log_success "Done"
  fi
}

# Get Crystal
get_crystal() {
  shopt -s nocasematch
  if [[ $DISTRO_GROUP == "Debian" ]]; then
    if [[ ! -e /etc/apt/sources.list.d/crystal.list ]]; then
      curl -fsSL https://crystal-lang.org/install.sh | ${SUDO} bash >>"${RUN_LOG}" 2>&1
    fi
  elif [[ $DISTRO_GROUP == "RHEL" ]]; then
    if [[ ! -e /etc/yum.repos.d/crystal.repo ]]; then
      curl -fsSL https://crystal-lang.org/install.sh | ${SUDO} bash >>"${RUN_LOG}" 2>&1
    fi
  elif [[ $(lsb_release -si) == "Darwin" ]]; then
    exit 1;
  elif [[ $DISTRO_GROUP == "Arch" ]]; then
    echo "Arch/Manjaro Linux... Skipping manual crystal install" >>"${RUN_LOG}" 2>&1
  else
    log_fatal "Error: Sorry, your OS is not supported."
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
domain:" | ${SUDO} tee ${IN_CONFIG} >>"${RUN_LOG}" 2>&1
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
  /bin/cp -f $configBackup $ConfigBakPath/"$backupConfigFile" >>"${RUN_LOG}" 2>&1
}

# Checkout Master branch to branch master (to avoid detached HEAD state)
GetMaster() {
  create_config
  backupConfig
  git checkout origin/${IN_BRANCH} -B ${IN_BRANCH} >>"${RUN_LOG}" 2>&1
}

install_invidious() {

  chk_git_repo

  show_preinstall_banner

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

  # Check for localhost in /etc/hosts
  grep localhost /etc/hosts >/dev/null
  if [ "$?" != 0 ]; then
    log_warning "There is no localhost entry in /etc/hosts. This is required, so one will be added."
    run_ok "echo 127.0.0.1 localhost >> /etc/hosts" "Editing /etc/hosts"
    if [ "$?" -ne 0 ]; then
      log_error "Failed to configure a localhost entry in /etc/hosts."
      log_error "This may cause problems, but we'll try to continue."
    fi
  fi

  PSQLDB=$(printf '%s\n' "$PSQLDB" | LC_ALL=C tr '[:upper:]' '[:lower:]')
  log_info "Started installation log in $LOGFILE"
  printf "${YELLOW}▣${CYAN}□□□${NORMAL} Phase ${YELLOW}1${NORMAL} of ${GREEN}4${NORMAL}: Setup packages\\n"
  #log_debug "${GREEN}\n"
  log_debug "Install options: \n"
  log_debug " ${DONE} branch        : $IN_BRANCH"
  log_debug " ${DONE} domain        : $DOMAIN"
  log_debug " ${DONE} ip address    : $IP"
  log_debug " ${DONE} port          : $PORT"
  if [ ! -z "$EXTERNAL_PORT" ]; then
    log_debug " ${DONE} external port : $EXTERNAL_PORT"
  fi
  log_debug " ${DONE} dbname        : $PSQLDB"
  log_debug " ${DONE} dbpass        : $PSQLPASS"
  log_debug " ${DONE} https only    : $HTTPS_ONLY"
  if [ ! -z "$ADMINS" ]; then
    log_debug " ${DONE} admins        : $ADMINS"
  fi
  if [ ! -z "$CAPTCHA_KEY" ]; then
    log_debug " ${DONE} captcha key   : $CAPTCHA_KEY"
  fi
  #log_debug " ${NORMAL}"
  # echo ""
  # echo ""

  # Setup Dependencies
  log_debug "Configuring package manager for ${DISTRO_GROUP} .."
  if ! ${PKGCHK} "$PRE_INSTALL_PKGS" >/dev/null 2>&1; then
    run_ok "${UPDATE}" "Updating packages"
    for i in $PRE_INSTALL_PKGS; do
      run_ok "${INSTALL} $i" "Installing $i" # 2> /dev/null # || exit 1
    done
  fi

  run_ok "get_crystal" "Installing Crystal packages"

  if ! ${PKGCHK} "$INSTALL_PKGS" >/dev/null 2>&1; then
    run_ok "${SUDO} ${UPDATE}" "Updating packages"
    for i in $INSTALL_PKGS; do
      run_ok "${SUDO} ${INSTALL} ${i}" "Installing $i" # 2> /dev/null # || exit 1 #--allow-unauthenticated
    done
  fi
  log_success "Package Setup Success"

  # Setup Repository
  log_debug "Phase 2 of 4: Repository Configuration"
  printf "${GREEN}▣${YELLOW}▣${CYAN}□□${NORMAL} Phase ${YELLOW}2${NORMAL} of ${GREEN}4${NORMAL}: Setup Repository\\n"
  # https://stackoverflow.com/a/51894266
  # grep $USER_NAME /etc/passwd >/dev/null 2>&1
  # if [ ! $? -eq 0 ] ; then
    #echo -e "${YELLOW}${ARROW} User $USER_NAME Not Found, adding user${NORMAL}"
  if ! id -u "$USER_NAME" >/dev/null 2>&1; then
    log_debug "Checking if $USER_NAME exists"
    ${SUDO} useradd -m $USER_NAME >>"${RUN_LOG}" 2>&1
  fi

  # If directory is not created
  if [[ ! -d $USER_DIR ]]; then
    #echo -e "${YELLOW}${ARROW} Folder Not Found, adding folder${NORMAL}"
    log_debug "Checking if $USER_DIR exists"
    mkdir -p $USER_DIR >>"${RUN_LOG}" 2>&1
  fi

  run_ok "set_permissions" "Setting folder permissions"
  log_debug "Downloading Invidious from GitHub"
  cd "${USER_DIR}" >>"${RUN_LOG}" 2>&1 || exit 1
  run_ok "sudo -i -u invidious \
    git clone https://github.com/iv-org/invidious" "Cloning Invidious from GitHub"
  cd "${REPO_DIR}" >>"${RUN_LOG}" 2>&1 || exit 1
  # Checkout
  run_ok "GetMaster" "Checking out master branch"
  log_debug "Download Done"
  run_ok "set_permissions" "Setting folder permissions again to be sure"
  log_success "Repository Setup Success"
  cd - >/dev/null 2>&1 || exit

  # Setup Repository
  log_debug "Phase 3 of 4: Database Configuration"
  printf "${GREEN}▣▣${YELLOW}▣${CYAN}□${NORMAL} Phase ${YELLOW}3${NORMAL} of ${GREEN}4${NORMAL}: Setup Database\\n"
  if [[ $DISTRO_GROUP == "RHEL" ]]; then
    if ! ${PKGCHK} ${PGSQL_SERVICE} >/dev/null 2>&1; then
      if [[ $(lsb_release -si) == "CentOS" ]]; then
        ${SUDO} yum config-manager --set-enabled powertools >>"${RUN_LOG}" 2>&1
        ${SUDO} dnf --enablerepo=powertools install libyaml-devel >>"${RUN_LOG}" 2>&1
      fi

      if [[ -d /var/lib/pgsql/data ]]; then
        if [[ -d /var/lib/pgsql/data.bak ]]; then
          ${SUDO} rm -rf /var/lib/pgsql/data.bak >>"${RUN_LOG}" 2>&1
        fi
          ${SUDO} mv -f /var/lib/pgsql/data /var/lib/pgsql/data.bak >>"${RUN_LOG}" 2>&1
          ${SUDO} /usr/bin/postgresql-setup --initdb >>"${RUN_LOG}" 2>&1
      else
        ${SUDO} /usr/bin/postgresql-setup --initdb >>"${RUN_LOG}" 2>&1
      fi
      ${SUDO} chmod 775 /var/lib/pgsql/data/postgresql.conf >>"${RUN_LOG}" 2>&1
      ${SUDO} chmod 775 /var/lib/pgsql/data/pg_hba.conf >>"${RUN_LOG}" 2>&1
      read_sleep 1
      ${SUDO} sed -i "s/#port = 5432/port = 5432/g" /var/lib/pgsql/data/postgresql.conf >>"${RUN_LOG}" 2>&1
      cp -rp /var/lib/pgsql/data/pg_hba.conf /var/lib/pgsql/data/pg_hba.conf.bak >>"${RUN_LOG}" 2>&1
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
host    replication     all             ::1/128                 md5" | ${SUDO} tee /var/lib/pgsql/data/pg_hba.conf >>"${RUN_LOG}" 2>&1
      ${SUDO} chmod 600 /var/lib/pgsql/data/postgresql.conf >>"${RUN_LOG}" 2>&1
      ${SUDO} chmod 600 /var/lib/pgsql/data/pg_hba.conf >>"${RUN_LOG}" 2>&1
    fi
  fi
  if [[ $DISTRO_GROUP == "Arch" ]]; then
    if [[ ! -d /var/lib/postgres/data ]]; then
      log_debug "Adding ${pgsql_config_folder}"
      run_ok "${SUDO} mkdir ${pgsql_config_folder}"
    fi
    if [[ -d ${pgsql_config_folder} ]]; then
      log_debug "Adding ${pgsql_config_folder}"
      su - postgres -c "initdb --locale en_US.UTF-8 -D '/var/lib/postgres/data'" >>"${RUN_LOG}" 2>&1
    fi
  fi

  if [[ -d ${pgsql_config_folder}/main ]]; then
    log_debug "Editing pg_hba.conf to allow login"
    ${SUDO} -u postgres sed -i "s/local   all             all                                     peer/local   all             all                                     md5/g" ${pgsql_config_folder}/main/pg_hba.conf >>"${RUN_LOG}" 2>&1
  fi
  log_debug "Enabling ${PGSQL_SERVICE}"
  run_ok "${SUDO} $SYSTEM_CMD enable ${PGSQL_SERVICE}" "Enabling ${PGSQL_SERVICE}"
  read_sleep 1
  log_debug "Restarting ${PGSQL_SERVICE}"
  run_ok "${SUDO} $SYSTEM_CMD restart ${PGSQL_SERVICE}" "Restarting ${PGSQL_SERVICE}"
  read_sleep 1
  # Create users and set privileges
  log_debug "Creating user kemal with password $PSQLPASS"
  ${SUDO} -u postgres psql -c "CREATE USER kemal WITH PASSWORD '$PSQLPASS';" >>"${RUN_LOG}" 2>&1
  log_debug "Creating database $PSQLDB with owner kemal"
  ${SUDO} -u postgres psql -c "CREATE DATABASE $PSQLDB WITH OWNER kemal;" >>"${RUN_LOG}" 2>&1
  log_debug "Grant all on database $PSQLDB to user kemal"
  ${SUDO} -u postgres psql -c "GRANT ALL ON DATABASE $PSQLDB TO kemal;" >>"${RUN_LOG}" 2>&1
  # Import db files
  if [[ -d ${REPO_DIR}/config/sql ]]; then
    for file in "${REPO_DIR}"/config/sql/*; do
      log_debug "Running $file"
      ${SUDO} -i -u postgres PGPASSWORD="$PSQLPASS" psql -U kemal -d "$PSQLDB" -f "$file" >>"${RUN_LOG}" 2>&1
    done
  fi
  log_success "Database Setup Success"

  log_debug "Phase 4 of 4: Invidious Configuration"
  printf "${GREEN}▣▣▣${YELLOW}▣${NORMAL} Phase ${YELLOW}4${NORMAL} of ${GREEN}4${NORMAL}: Setup Invidious\\n"
  if [[ $DISTRO_GROUP == "Arch" ]]; then
    git config --global --add safe.directory ${REPO_DIR} >>"${RUN_LOG}" 2>&1
  fi
  run_ok "update_config" "Updating config"
  # Crystal complaining about permissions on CentOS and somewhat Debian
  # So before we build, make sure permissions are set.
  run_ok "set_permissions" "Setting folder permissions"
  cd ${REPO_DIR} >/dev/null 2>&1 || exit 1
  run_ok "shards install --production" "Running shards install"
  run_ok "crystal build src/invidious.cr --release" "Running crystal build"
  #check_exit_status
  if [[ $DISTRO_GROUP == "RHEL" ]]; then
    # Set SELinux to permissive on RHEL
    ${SUDO} setenforce 0 >>"${RUN_LOG}" 2>&1
  fi
  run_ok "systemd_install" "Installing Invidious Service"
  # Not figured out why yet, so let's set permissions after as well...
  run_ok "set_permissions" "Setting folder permissions again to be sure"
  run_ok "logrotate_install" "Adding logrotate configuration"
  log_success "${GREEN}▣▣▣▣${NORMAL} All phases finished successfully"
  # Make sure the cursor is back (if spinners misbehaved)
  tput cnorm
  read_sleep 5
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