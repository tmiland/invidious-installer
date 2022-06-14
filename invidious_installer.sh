#!/usr/bin/env bash
# shellcheck disable=SC2059,SC1091,SC2166,SC2015,SC2129,SC2221,SC2222

## Author: Tommy Miland (@tmiland) - Copyright (c) 2022


######################################################################
####                   Invidious Installer.sh                     ####
####            Automatic install script for Invidious            ####
####                 Script to install Invidious                  ####
####                   Maintained by @tmiland                     ####
######################################################################

VERSION='2.0.1' # Must stay on line 14 for updater to fetch the numbers

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
#SCRIPT_FILENAME=$(basename "$0")
cd - > /dev/null || exit
sfp=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || greadlink -f "${BASH_SOURCE[0]}" 2>/dev/null)
if [ -z "$sfp" ]; then sfp=${BASH_SOURCE[0]}; fi
#SCRIPT_DIR=$(dirname "${sfp}")
# Icons used for printing
ARROW='➜'
#WARNING='⚠'
# Repo name
REPO_NAME="tmiland/invidious-installer"
# Invidious repo name
IN_REPO=${IN_REPO:-iv-org/invidious}
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
LOGFILE=$CURRDIR/invidious_installer.log
# Console output level; ignore debug level messages.
VERBOSE=0
#
BANNERS=1

usage() {
  # shellcheck disable=SC2046
  printf "Usage: %s %s [options]\\n" "${CYAN}" $(basename "$0")
  echo
  echo "  If called without arguments, installs Invidious."
  echo
  printf "  ${YELLOW}--help|-h${NORMAL}               display this help and exit\\n"
  printf "  ${YELLOW}--verbose|-v${NORMAL}            increase verbosity\\n"
  printf "  ${YELLOW}--banners|-b${NORMAL}            disable banners\\n"
  printf "  ${YELLOW}--repo|-r${NORMAL}               select custom repo. E.G: user/invidious\\n"
  echo
}

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
  --help | -h)
    usage
    exit 0
    ;;
  --verbose | -v)
    shift
    VERBOSE=1
    ;;
  --banners | -b)
    shift
    BANNERS=0
    ;;
  --repo | -r) # Bash Space-Separated (e.g., --option argument)
    IN_REPO="$2" # Source: https://stackoverflow.com/a/14203146
    shift # past argument
    shift # past value
    ;;
  --uninstall | -u)
    shift
    mode="uninstall"
    ;;
  -*|--*)
    printf "Unrecognized option: $1\\n\\n"
    usage
    exit 1
    ;;
  *)
    POSITIONAL_ARGS+=("$1") # save positional arg
    shift # past argument
    ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

# Include functions
if [[ -f ./src/slib.sh ]]; then
  . ./src/slib.sh
else
  SLIB_URL=https://raw.githubusercontent.com/tmiland/invidious-installer/main/src/slib.sh
  if [[ $(command -v 'curl') ]]; then
    # shellcheck source=$SLIB_URL
    source <(curl -sSLf $SLIB_URL)
  elif [[ $(command -v 'wget') ]]; then
    # shellcheck source=$SLIB_URL
    . <(wget -qO - $SLIB_URL)
  else
    echo -e "${RED}${BALLOT_X} This script requires curl or wget.\nProcess aborted${NORMAL}"
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

read_sleep() {
  read -rt "$1" <> <(:) || :
}

# Start with a clean log
if [[ -f $LOGFILE ]]; then
  rm $LOGFILE
fi

# Distro support
ARCH_CHK=$(uname -m)
if [ ! "${ARCH_CHK}" == 'x86_64' ]; then
  echo -e "${RED}${BALLOT_X} Error: Sorry, your OS ($ARCH_CHK) is not supported.${NORMAL}"
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
  *) echo -e "${RED}${BALLOT_X} unknown distro: '$DISTRO'${NORMAL}" ; exit 1 ;;
esac
if ! lsb_release -si 1>/dev/null 2>&1; then
  echo ""
  echo -e "${RED}${BALLOT_X} Looks like ${LSB} is not installed!${NORMAL}"
  echo ""
  read -r -p "Do you want to download ${LSB}? [y/n]? " ANSWER
  echo ""
  case $ANSWER in
    [Yy]* )
      echo -e "${GREEN}${ARROW} Installing ${LSB} on ${DISTRO}...${NORMAL}"
      su -s "$(which bash)" -c "${PKGCMD} ${LSB}" || echo -e "${RED}${BALLOT_X} Error: could not install ${LSB}!${NORMAL}"
      echo -e "${GREEN}${CHECK} Done${NORMAL}"
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
#UPGRADE=""
INSTALL=""
UNINSTALL=""
PURGE=""
CLEAN=""
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
  # UPGRADE="apt-get -o Dpkg::Progress-Fancy="1" upgrade -qq"
  # shellcheck disable=SC2140
  INSTALL="apt-get -o Dpkg::Progress-Fancy="1" install -qq"
  # shellcheck disable=SC2140
  UNINSTALL="apt-get -o Dpkg::Progress-Fancy="1" remove -qq"
  # shellcheck disable=SC2140
  PURGE="apt-get purge -o Dpkg::Progress-Fancy="1" -qq"
  CLEAN="apt-get clean && apt-get autoremove -qq"
  PKGCHK="dpkg -s"
  # Pre-install packages
  PRE_INSTALL_PKGS="apt-transport-https git curl sudo gnupg"
  # Install packages
  INSTALL_PKGS="crystal libssl-dev libxml2-dev libyaml-dev libgmp-dev libreadline-dev librsvg2-bin postgresql libsqlite3-dev zlib1g-dev libpcre3-dev libevent-dev"
  #Uninstall packages
  UNINSTALL_PKGS="crystal libssl-dev libxml2-dev libyaml-dev libgmp-dev libreadline-dev librsvg2-bin libsqlite3-dev zlib1g-dev libpcre3-dev libevent-dev"
  # PostgreSQL Service
  PGSQL_SERVICE="postgresql"
  # System cmd
  SYSTEM_CMD="systemctl"
  # Postgresql config folder
  pgsql_config_folder=$(find "/etc/postgresql/" -maxdepth 1 -type d -name "*" | sort -V | tail -1)
elif [[ $(lsb_release -si) == "CentOS" ]]; then
  SUDO="sudo"
  UPDATE="yum update -q"
  # UPGRADE="yum upgrade -q"
  INSTALL="yum install -y -q"
  UNINSTALL="yum remove -y -q"
  PURGE="yum purge -y -q"
  CLEAN="yum clean all -y -q"
  PKGCHK="rpm --quiet --query"
  # Pre-install packages
  PRE_INSTALL_PKGS="epel-release git curl sudo dnf-plugins-core"
  # Install packages
  INSTALL_PKGS="crystal openssl-devel libxml2-devel libyaml-devel gmp-devel readline-devel librsvg2-tools sqlite-devel postgresql postgresql-server zlib-devel gcc libevent-devel"
  #Uninstall packages
  UNINSTALL_PKGS="crystal openssl-devel libxml2-devel libyaml-devel gmp-devel readline-devel librsvg2-tools sqlite-devel zlib-devel gcc libevent-devel"
  # PostgreSQL Service
  PGSQL_SERVICE="postgresql"
  # System cmd
  SYSTEM_CMD="systemctl"
  # Postgresql config folder
  pgsql_config_folder=$(find "/etc/postgresql/" -maxdepth 1 -type d -name "*" | sort -V | tail -1)
elif [[ $(lsb_release -si) == "Fedora" ]]; then
  SUDO="sudo"
  UPDATE="dnf update -q"
  # UPGRADE="dnf upgrade -q"
  INSTALL="dnf install -y -q"
  UNINSTALL="dnf remove -y -q"
  PURGE="dnf purge -y -q"
  CLEAN="dnf clean all -y -q"
  PKGCHK="rpm --quiet --query"
  # Pre-install packages
  PRE_INSTALL_PKGS="git curl sudo"
  # Install packages
  INSTALL_PKGS="crystal openssl-devel libxml2-devel libyaml-devel gmp-devel readline-devel librsvg2-tools sqlite-devel postgresql postgresql-server zlib-devel gcc libevent-devel"
  #Uninstall packages
  UNINSTALL_PKGS="crystal openssl-devel libxml2-devel libyaml-devel gmp-devel readline-devel librsvg2-tools sqlite-devel zlib-devel gcc libevent-devel"
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
  UNINSTALL="pacman -R"
  PURGE="pacman -Rs"
  CLEAN="pacman -Sc"
  PKGCHK="pacman -Qs"
  # Pre-install packages
  PRE_INSTALL_PKGS="git curl sudo"
  # Install packages
  INSTALL_PKGS="base-devel shards crystal librsvg postgresql"
  #Uninstall packages
  UNINSTALL_PKGS="base-devel shards crystal librsvg"
  # PostgreSQL Service
  PGSQL_SERVICE="postgresql"
  # System cmd
  SYSTEM_CMD="systemctl"
  # Postgresql config folder
  pgsql_config_folder="/var/lib/postgres/data"
else
  echo -e "${RED}${BALLOT_X} Error: Sorry, your OS is not supported.${NORMAL}"
  exit 1;
fi

# Check if systemd is installed on Devuan
if [[ $(lsb_release -si) == "Devuan" ]]; then
  if ( ! $SYSTEM_CMD 2>/dev/null); then
    echo -e "${RED}${BALLOT_X} Error: Sorry, you need systemd to run this script.${NORMAL}"
    exit 1;
  fi
fi

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
    echo -e "${RED}${BALLOT_X} This script requires curl or wget.\nProcess aborted${NORMAL}"
    exit 0
  fi
  read_sleep 3

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
  echo -e "Documentation for this script is available here: ${YELLOW}\n ${ARROW} https://github.com/${REPO_NAME}${NORMAL}\n"
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
  echo -e "${GREEN}${CHECK} Invidious install done.${NORMAL} Now visit http://${IP}:${PORT}"
  echo ""
  echo ""
  echo ""
  echo ""
  echo -e "Documentation for this script is available here: ${YELLOW}\n ${ARROW} https://github.com/${REPO_NAME}${NORMAL}\n"
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
  echo -e "Documentation for this script is available here: ${YELLOW}\n ${ARROW} https://github.com/${REPO_NAME}${NORMAL}\n"
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

   ${GREEN}${CHECK}${NORMAL} ${BBLUE}Paypal${NORMAL} ${ARROW} ${YELLOW}https://paypal.me/milanddata${NORMAL}
   ${GREEN}${CHECK}${NORMAL} ${BBLUE}BTC${NORMAL}    ${ARROW} ${YELLOW}33mjmoPxqfXnWNsvy8gvMZrrcG3gEa3YDM${NORMAL}
  "
  echo -e "Documentation for this script is available here: ${YELLOW}\n${ARROW} https://github.com/${REPO_NAME}${NORMAL}\n"
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
  ${SUDO} chown -R $USER_NAME:$USER_NAME $USER_DIR 1>/dev/null 2>&1
  ${SUDO} chmod -R 755 $USER_DIR 1>/dev/null 2>&1
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
  do
    if [ -f $f -a -r $f ]; then
      /bin/cp -f $f $BPATH
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
    ${SUDO} $SYSTEM_CMD status ${SERVICE_NAME} --no-pager >>"${RUN_LOG}" 2>&1
    read_sleep 5
  else
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

# Get dbname from config file (used in db maintenance and uninstallation)
get_dbname() {
  echo "$(sed -n 's/.*dbname *: *\([^ ]*.*\)/\1/p' "$1")"
}

uninstall_invidious() {
# Set default uninstallation parameters
RM_PostgreSQLDB=${RM_PostgreSQLDB:-y}
RM_RE_PGSQLDB=${RM_RE_PGSQLDB:-n}
RM_PACKAGES=${RM_PACKAGES:-n}
RM_PURGE=${RM_PURGE:-n}
RM_FILES=${RM_FILES:-y}
RM_USER=${RM_USER:-n}
# Set db backup path
PGSQLDB_BAK_PATH="/home/backup/$USER_NAME"
# Get dbname from config.yml
RM_PSQLDB=$(get_dbname "${IN_CONFIG}")

read -p "Express uninstall ? [y/n]: " EXPRESS_UNINSTALL

if [[ ! $EXPRESS_UNINSTALL =  "y" ]]; then
  echo ""
  read -e -i "$RM_PostgreSQLDB" -p "       Remove database for Invidious ? [y/n]: " RM_PostgreSQLDB
  if [[ $RM_PostgreSQLDB =  "y" ]]; then
    echo -e "       ${YELLOW}${WARNING} (( A backup will be placed in ${ARROW} $PGSQLDB_BAK_PATH ))${NORMAL}"
    echo -e "       Your Invidious database name: $RM_PSQLDB"
  fi
  if [[ $RM_PostgreSQLDB =  "y" ]]; then
    echo -e "       ${YELLOW}${WARNING} (( If yes, only data will be dropped ))${NORMAL}"
    read -e -i "$RM_RE_PGSQLDB" -p "       Do you intend to reinstall?: " RM_RE_PGSQLDB
  fi
  read -e -i "$RM_PACKAGES" -p "       Remove Packages ? [y/n]: " RM_PACKAGES
  if [[ $RM_PACKAGES = "y" ]]; then
    read -e -i "$RM_PURGE" -p "       Purge Package configuration files ? [y/n]: " RM_PURGE
  fi
  echo -e "       ${YELLOW}${WARNING} (( This option will remove ${ARROW} ${REPO_DIR} ))${NORMAL}"
  read -e -i "$RM_FILES" -p "       Remove files ? [y/n]: " RM_FILES
  if [[ "$RM_FILES" = "y" ]]; then
    echo -e "       ${RED}${WARNING} (( This option will remove ${ARROW} $USER_DIR ))${NORMAL}"
    echo -e "       ${YELLOW}${WARNING} (( Not needed for reinstall ))${NORMAL}"
    read -e -i "$RM_USER" -p "       Remove user ? [y/n]: " RM_USER
  fi
  echo ""
  echo -e "${GREEN}${ARROW} Invidious is ready to be uninstalled${NORMAL}"
  echo ""
  read -n1 -r -p "press any key to continue or Ctrl+C to cancel..."
  echo ""
fi
  # Remove PostgreSQL database if user ANSWER is yes
  if [[ "$RM_PostgreSQLDB" = 'y' ]]; then
    # Stop and disable invidious
    ${SUDO} $SYSTEM_CMD stop ${SERVICE_NAME}
    read_sleep 1
    ${SUDO} $SYSTEM_CMD restart ${PGSQL_SERVICE}
    read_sleep 1
    # If directory is not created
    if [[ ! -d $PGSQLDB_BAK_PATH ]]; then
      echo -e "${YELLOW}${ARROW} Backup Folder Not Found, adding folder${NORMAL}"
      ${SUDO} mkdir -p $PGSQLDB_BAK_PATH
    fi

    echo ""
    echo -e "${GREEN}${ARROW} Running database backup${NORMAL}"
    echo ""

    ${SUDO} -i -u postgres pg_dump ${RM_PSQLDB} > ${PGSQLDB_BAK_PATH}/${RM_PSQLDB}.sql
    read_sleep 2
    ${SUDO} chown -R 1000:1000 "/home/backup"

    if [[ "$RM_RE_PGSQLDB" != 'n' ]]; then
      echo ""
      echo -e "${RED}${ARROW} Dropping Invidious PostgreSQL data${NORMAL}"
      echo ""
      ${SUDO} -i -u postgres psql -c "DROP OWNED BY kemal CASCADE;"
      echo ""
      echo -e "${YELLOW}${CHECK} Data dropped and backed up to ${ARROW} ${PGSQLDB_BAK_PATH}/${RM_PSQLDB}.sql ${NORMAL}"
      echo ""
    fi

    if [[ "$RM_RE_PGSQLDB" != 'y' ]]; then
      echo ""
      echo -e "${RED}${ARROW} Dropping Invidious PostgreSQL database${NORMAL}"
      echo ""
      ${SUDO} -i -u postgres psql -c "DROP DATABASE $RM_PSQLDB"
      echo ""
      echo -e "${YELLOW}${CHECK} Database dropped and backed up to ${ARROW} ${PGSQLDB_BAK_PATH}/${RM_PSQLDB}.sql ${NORMAL}"
      echo ""
      echo -e "${RED}${ARROW} Removing user kemal${NORMAL}"
      ${SUDO} -i -u postgres psql -c "DROP ROLE IF EXISTS kemal;"
    fi
  fi

  # Reload Systemd
  ${SUDO} $SYSTEM_CMD daemon-reload
  # Remove packages installed during installation
  if [[ "$RM_PACKAGES" = 'y' ]]; then
    echo ""
    echo -e "${YELLOW}${ARROW} Removing packages installed during installation."
    echo ""
    echo -e "Note: PostgreSQL will not be removed due to unwanted complications${NORMAL}"
    echo ""

    if ${PKGCHK} $UNINSTALL_PKGS >/dev/null 2>&1; then
      for i in $UNINSTALL_PKGS; do
        echo ""
        echo -e "${YELLOW}${ARROW} removing packages.${NORMAL}"
        echo ""
        ${UNINSTALL} $i 2> /dev/null
      done
    fi
    echo ""
    echo -e "${GREEN}${CHECK} done.${NORMAL}"
    echo ""
  fi

  # Remove conf files
  if [[ "$RM_PURGE" = 'y' ]]; then
    # Removing invidious files and modules files
    echo ""
    echo -e "${YELLOW}${ARROW} Removing invidious files and modules files.${NORMAL}"
    echo ""
    if [[ $DISTRO_GROUP == "Debian" ]]; then
      rm -r \
        /lib/systemd/system/${SERVICE_NAME} \
        /etc/apt/sources.list.d/crystal.list
    elif [[ $DISTRO_GROUP == "RHEL" ]]; then
      rm -r \
        /usr/lib/systemd/system/${SERVICE_NAME} \
        /etc/yum.repos.d/crystal.repo
    fi

    if ${PKGCHK} $UNINSTALL_PKGS >/dev/null 2>&1; then
      for i in $UNINSTALL_PKGS; do
        echo ""
        echo -e "${YELLOW}${ARROW} purging packages.${NORMAL}"
        echo ""
        ${PURGE} $i 2> /dev/null
      done
    fi

    echo ""
    echo -e "${YELLOW}${ARROW} cleaning up.${NORMAL}"
    echo ""
    ${CLEAN}
    echo ""
    echo -e "${GREEN}${CHECK} done.${NORMAL}"
    echo ""
  fi

  if [[ "$RM_FILES" = 'y' ]]; then
    # If directory is present, remove
    if [[ -d ${REPO_DIR} ]]; then
      echo -e "${YELLOW}${ARROW} Folder Found, removing folder${NORMAL}"
      rm -r ${REPO_DIR}
    fi
  fi

  # Remove user and settings
  if [[ "$RM_USER" = 'y' ]]; then
    # Stop and disable invidious
    ${SUDO} $SYSTEM_CMD stop ${SERVICE_NAME}
    read_sleep 1
    ${SUDO} $SYSTEM_CMD restart ${PGSQL_SERVICE}
    read_sleep 1
    ${SUDO} $SYSTEM_CMD daemon-reload
    read_sleep 1
    grep $USER_NAME /etc/passwd >/dev/null 2>&1

    if [ $? -eq 0 ] ; then
      echo ""
      echo -e "${YELLOW}${ARROW} User $USER_NAME Found, removing user and files${NORMAL}"
      echo ""
      shopt -s nocasematch
      if [[ $DISTRO_GROUP == "Debian" ]]; then
        ${SUDO} deluser --remove-home $USER_NAME
      fi
      if [[ $DISTRO_GROUP == "RHEL" ]]; then
        /usr/sbin/userdel -r $USER_NAME
      fi
    fi
  fi
  if [ -d /etc/logrotate.d ]; then
    rm /etc/logrotate.d/invidious.logrotate
  fi
  # We're done !
  echo ""
  echo -e "${GREEN}${CHECK} Un-installation done.${NORMAL}"
  echo ""
  read_sleep 3
  tput cnorm
  exit 0
}

if [ "$mode" = "uninstall" ]; then
  uninstall_invidious
fi

install_invidious() {

  chk_git_repo
if [ "$BANNERS" = "1" ]; then
  show_preinstall_banner
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

  PSQLDB=$(printf '%s\n' "$PSQLDB" | LC_ALL=C tr '[:upper:]' '[:lower:]')
  log_info "Started installation log in $LOGFILE"
  echo
  printf "${YELLOW}▣${CYAN}□□□${NORMAL} Phase ${YELLOW}1${NORMAL} of ${GREEN}4${NORMAL}: Setup packages\\n"
  log_info "Install options: "
  log_info " ${GREEN}${CHECK}${NORMAL} ${YELLOW}branch${NORMAL}        : ${BBLUE}$IN_BRANCH${NORMAL}"
  log_info " ${GREEN}${CHECK}${NORMAL} ${YELLOW}domain${NORMAL}        : ${BBLUE}$DOMAIN${NORMAL}"
  log_info " ${GREEN}${CHECK}${NORMAL} ${YELLOW}ip address${NORMAL}    : ${BBLUE}$IP${NORMAL}"
  log_info " ${GREEN}${CHECK}${NORMAL} ${YELLOW}port${NORMAL}          : ${BBLUE}$PORT${NORMAL}"
  if [ -n "$EXTERNAL_PORT" ]; then
    log_info " ${GREEN}${CHECK}${NORMAL} ${YELLOW}external port${NORMAL} : ${BBLUE}$EXTERNAL_PORT${NORMAL}"
  fi

  log_info " ${GREEN}${CHECK}${NORMAL} ${YELLOW}dbname${NORMAL}        : ${BBLUE}$PSQLDB${NORMAL}"
  log_info " ${GREEN}${CHECK}${NORMAL} ${YELLOW}dbpass${NORMAL}        : ${BBLUE}$PSQLPASS${NORMAL}"
  log_info " ${GREEN}${CHECK}${NORMAL} ${YELLOW}https only${NORMAL}    : ${BBLUE}$HTTPS_ONLY${NORMAL}"

  if [ -n "$ADMINS" ]; then
    log_info " ${GREEN}${CHECK}${NORMAL} ${YELLOW}admins${NORMAL}        : ${BBLUE}$ADMINS${NORMAL}"
  fi

  if [ -n "$CAPTCHA_KEY" ]; then
    log_info " ${GREEN}${CHECK}${NORMAL} ${YELLOW}captcha key${NORMAL}   : ${BBLUE}$CAPTCHA_KEY${NORMAL}"
  fi
  echo
  # echo ""

  # Setup Dependencies
  log_debug "Configuring package manager for ${DISTRO_GROUP} .."
  if ! ${PKGCHK} "$PRE_INSTALL_PKGS" 1>/dev/null 2>&1; then
    log_debug "Updating packages"
    run_ok "${UPDATE}" "Updating package repo"
    for i in $PRE_INSTALL_PKGS; do
      log_debug "Installing pre-install packages $i"
      # shellcheck disable=SC2086
      ${INSTALL} $i >>"${RUN_LOG}" 2>&1
    done
  fi

  log_debug "Installing Crystal packages"
  run_ok "get_crystal" "Installing Crystal"

  if ! ${PKGCHK} "$INSTALL_PKGS" 1>/dev/null 2>&1; then
    log_debug "Updating packages"
    run_ok "${SUDO} ${UPDATE}" "Updating package repo"
    for i in $INSTALL_PKGS; do
      log_debug "Installing required packages $i"
      # shellcheck disable=SC2086
      ${SUDO} ${INSTALL} ${i} >>"${RUN_LOG}" 2>&1
    done
  fi
  log_success "Package Setup Finished"

  # Reap any clingy processes (like spinner forks)
  # get the parent pids (as those are the problem)
  allpids="$(ps -o pid= --ppid $$) $allpids"
  for pid in $allpids; do
    kill "$pid" 1>/dev/null 2>&1
  done

  # Next step is configuration. Wait here for a moment, hopefully letting any
  # apt processes disappear before we start, as they're huge and memory is a
  # problem. XXX This is hacky. I'm not sure what's really causing random fails.
  read_sleep 1
  echo
  # Setup Repository
  log_debug "Phase 2 of 4: Repository Configuration"
  printf "${GREEN}▣${YELLOW}▣${CYAN}□□${NORMAL} Phase ${YELLOW}2${NORMAL} of ${GREEN}4${NORMAL}: Setup Repository\\n"
  # https://stackoverflow.com/a/51894266
  # grep $USER_NAME /etc/passwd 1>/dev/null 2>&1
  # if [ ! $? -eq 0 ] ; then
    #echo -e "${YELLOW}${ARROW} User $USER_NAME Not Found, adding user${NORMAL}"
  if ! id -u "$USER_NAME" 1>/dev/null 2>&1; then
    log_debug "Checking if $USER_NAME exists"
    ${SUDO} useradd -m $USER_NAME >>"${RUN_LOG}" 2>&1
  fi

  # If directory is not created
  if [[ ! -d $USER_DIR ]]; then
    #echo -e "${YELLOW}${ARROW} Folder Not Found, adding folder${NORMAL}"
    log_debug "Checking if $USER_DIR exists"
    mkdir -p $USER_DIR >>"${RUN_LOG}" 2>&1
  fi

  log_debug "Setting folder permissions"
  run_ok "set_permissions" "Setting folder permissions"

  if [ -d $USER_DIR ]; then
    (
      cd $USER_DIR >>"${RUN_LOG}" 2>&1 || exit 1

    log_debug "Download Invidious from github.com/${IN_REPO}"
    run_ok "sudo -i -u invidious \
      git clone https://github.com/${IN_REPO}" "Cloning Invidious from github.com/${IN_REPO}"
      cd - 1>/dev/null 2>&1 || exit 1
    )
  fi

  if [ -d $REPO_DIR ]; then
    (
      cd $REPO_DIR >>"${RUN_LOG}" 2>&1 || exit 1

      # Checkout
      log_debug "Checking out master branch"
      run_ok "GetMaster" "Checking out master branch"
      log_debug "Setting folder permissions again to be sure"
      run_ok "set_permissions" "Setting folder permissions again to be sure"
      log_success "Repository Setup Finished"
      cd - 1>/dev/null 2>&1 || exit 1
    )
  fi

  echo
  # Setup Repository
  log_debug "Phase 3 of 4: Database Configuration"
  printf "${GREEN}▣▣${YELLOW}▣${CYAN}□${NORMAL} Phase ${YELLOW}3${NORMAL} of ${GREEN}4${NORMAL}: Setup Database\\n"

  if [[ $DISTRO_GROUP == "RHEL" ]]; then
    if ! ${PKGCHK} ${PGSQL_SERVICE} 1>/dev/null 2>&1; then
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

  log_success "Database Setup Finished"

  echo
  log_debug "Phase 4 of 4: Invidious Configuration"
  printf "${GREEN}▣▣▣${YELLOW}▣${NORMAL} Phase ${YELLOW}4${NORMAL} of ${GREEN}4${NORMAL}: Setup Invidious\\n"

  # Add invidious folder as safe directory
  git config --global --add safe.directory ${REPO_DIR} >>"${RUN_LOG}" 2>&1

  log_debug "Update config"
  run_ok "update_config" "Updating config"
  # Crystal complaining about permissions on CentOS and somewhat Debian
  # So before we build, make sure permissions are set.
  log_debug "Set folder permissions"
  run_ok "set_permissions" "Setting folder permissions"

  if [[ -d ${REPO_DIR} ]]; then
    (
      cd ${REPO_DIR} >>"${RUN_LOG}" 2>&1 || exit 1
      log_debug "Run shards install"
      run_ok "shards install --production" "Running shards install"
      log_debug "Run crystal build"
      run_ok "crystal build src/invidious.cr --release" "Running crystal build"
      cd - 1>/dev/null 2>&1 || exit 1
    )
  fi

  if [[ $DISTRO_GROUP == "RHEL" ]]; then
    # Set SELinux to permissive on RHEL
    #${SUDO} setenforce 0 >>"${RUN_LOG}" 2>&1
    if [ -x /usr/sbin/setenforce ]; then
      log_debug "Disabling SELinux during installation .."
      if ${SUDO} /usr/sbin/setenforce 0 1>/dev/null 2>&1; then
        log_debug " setenforce 0 succeeded"
      else
        log_debug " setenforce 0 failed: $?"
      fi
    fi
  fi

  run_ok "systemd_install" "Installing Invidious Service"
  # Not figured out why yet, so let's set permissions after as well...
  run_ok "set_permissions" "Setting folder permissions again to be sure"
  run_ok "logrotate_install" "Adding logrotate configuration"
  log_success "Invidious Setup Finished"

  # Make sure the cursor is back (if spinners misbehaved)
  tput cnorm
  printf "${GREEN}▣▣▣▣${NORMAL} All ${GREEN}4${NORMAL} phases finished successfully"
}

# Start Script
  chk_permissions
if [ "$BANNERS" = "1" ]; then
  show_banner
fi
# Install Invidious
  errors=$((0))
  if ! install_invidious; then
    errorlist="${errorlist}  ${YELLOW}◉${NORMAL} Invidious installation returned an error.\\n"
    errors=$((errors + 1))
  fi
  if [ $errors -eq "0" ]; then
    read_sleep 5
    if [ "$BANNERS" = "1" ]; then
      show_install_banner
    fi
    read_sleep 5
    #indexit
  else
    log_warning "The following errors occurred during installation:"
    echo
    printf "${errorlist}"
  fi
  exit_script
  exit