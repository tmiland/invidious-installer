# invidious-installer
Automatic install script for Invidious

```
                  ╔═══════════════════════════════════════════════════════════════════╗
                  ║                      Invidious Installer.sh                       ║
                  ║              Automatic install script for Invidious               ║
                  ║                      Maintained by @tmiland                       ║
                  ╚═══════════════════════════════════════════════════════════════════╝
```
[![GitHub release](https://img.shields.io/github/release/tmiland/Invidious-Updater.svg?style=for-the-badge)](https://github.com/tmiland/Invidious-Updater/releases)
[![licence](https://img.shields.io/github/license/tmiland/Invidious-Updater.svg?style=for-the-badge)](https://github.com/tmiland/Invidious-Updater/blob/master/LICENSE)
![Bash](https://img.shields.io/badge/Language-SH-4EAA25.svg?style=for-the-badge)

## Script to install [Invidious](https://github.com/iv-org/invidious)

This script is just the install option in [Invidious-Updater](https://github.com/tmiland/Invidious-Updater)

## Download the script:

Quick install with default options for localhost:
With Curl:
```bash
curl -sSL https://github.com/tmiland/invidious-installer/raw/main/invidious_installer.sh | bash
```
With Wget:
```bash
wget -qO - https://github.com/tmiland/invidious-installer/raw/main/invidious_installer.sh | bash
```

With custom options:
```bash
curl -sSL https://github.com/tmiland/invidious-installer/raw/main/invidious_installer.sh
```
Set execute permission:
```bash
chmod +x invidious_installer.sh
```

## Installation


### Install with default options to run on localhost:

```bash
DOMAIN= \
IP=localhost \
PORT=3000 \
PSQLDB=invidious \
HTTPS_ONLY=n \
EXTERNAL_PORT= \
ADMINS= \
SWAP_OPTIONS=n \
./invidious_installer.sh
```

### Install with options to run on HTTPS site:

```bash
DOMAIN=domain.com \
IP=123.45.67.89 \
PORT=3000 \
PSQLDB=invidious \
HTTPS_ONLY=y \
EXTERNAL_PORT=443 \
ADMINS=admin \
SWAP_OPTIONS=n \
./invidious_installer.sh
```

For Captcha key, add `CAPTCHA_KEY=YOUR_CAPTCHA_KEY \` to options.

#### Check for script update (Default "no")

```bash

$ ./invidious_installer.sh -u

```

***Note: you will be prompted to enter root password***

If root password is not set, type:

```bash
sudo passwd root
```

### To keep Invidious up-to-date: [Invidious-Updater](https://github.com/tmiland/Invidious-Updater)

## Testing

Tested and working on:

| Debian | Ubuntu | CentOS | Fedora | Arch | PureOS |
| ------ | ------ | ------ | ------ | ------ | ------ |
| [<img src="https://raw.githubusercontent.com/tmiland/Invidious-Updater/master/img/os_icons/debian.svg?sanitize=true" height="128" width="128">](https://raw.githubusercontent.com/tmiland/Invidious-Updater/master/img/os_icons/debian.svg?sanitize=true) | [<img src="https://raw.githubusercontent.com/tmiland/Invidious-Updater/master/img/os_icons/ubuntu.svg?sanitize=true" height="128" width="128">](https://raw.githubusercontent.com/tmiland/Invidious-Updater/master/img/os_icons/ubuntu.svg?sanitize=true) | [<img src="https://raw.githubusercontent.com/tmiland/Invidious-Updater/master/img/os_icons/cent-os.svg?sanitize=true" height="128" width="128">](https://raw.githubusercontent.com/tmiland/Invidious-Updater/master/img/os_icons/cent-os.svg?sanitize=true) | [<img src="https://raw.githubusercontent.com/tmiland/Invidious-Updater/master/img/os_icons/fedora.svg?sanitize=true" height="128" width="128">](https://raw.githubusercontent.com/tmiland/Invidious-Updater/master/img/os_icons/fedora.svg?sanitize=true) | [<img src="https://raw.githubusercontent.com/tmiland/Invidious-Updater/master/img/os_icons/arch.svg?sanitize=true" height="128" width="128">](https://raw.githubusercontent.com/tmiland/Invidious-Updater/master/img/os_icons/arch.svg?sanitize=true) | [<img src="https://raw.githubusercontent.com/tmiland/Invidious-Updater/master/img/os_icons/pureos.svg?sanitize=true" height="128" width="128">](https://raw.githubusercontent.com/tmiland/Invidious-Updater/master/img/os_icons/pureos.svg?sanitize=true)

## Compatibility and Requirements

* Debian 8 and later
* Ubuntu 16.04 and later
* PureOS (Not tested)
* CentOS 8
* Fedora 33
  * Docker support
    - [OS requirements](https://docs.docker.com/install/linux/docker-ce/fedora/)
* Arch Linux

## Feature request and bug reports
- [Bug report](https://github.com/tmiland/Invidious-Updater/issues/new?assignees=tmiland&labels=bug&template=bug_report.md&title=Bug-report:)
- [Feature request](https://github.com/tmiland/Invidious-Updater/issues/new?assignees=tmiland&labels=enhancement&template=feature_request.md&title=Feature-request:)

## Donations 
- [PayPal me](https://paypal.me/milanddata)
- [BTC] : 33mjmoPxqfXnWNsvy8gvMZrrcG3gEa3YDM

## Web Hosting

Sign up for web hosting using this link, and receive $100 in credit over 60 days.

[DigitalOcean](https://m.do.co/c/f1f2b475fca0)

#### Disclaimer 

*** ***Use at own risk*** ***

### License

[![MIT License Image](https://upload.wikimedia.org/wikipedia/commons/thumb/0/0c/MIT_logo.svg/220px-MIT_logo.svg.png)](https://github.com/tmiland/invidious-installer/blob/master/LICENSE)

[MIT License](https://github.com/tmiland/invidious-installer/blob/master/LICENSE)