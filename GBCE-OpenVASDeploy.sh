#!/bin/bash

# Based off of https://greenbone.github.io/docs/latest/22.4/container/index.html
# Intended for a fresh deployed Debian 12 Proxmox container without any modifications & Post updated
# Modified in indicated areas

## MOD
# Install dependencies
apt install ca-certificates curl gnupg sudo -y
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt remove $pkg -y; done
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
## /MOD

# MOD
# Aquired from: https://greenbone.github.io/docs/latest/_static/setup-and-start-greenbone-community-edition.sh
set -e

DOWNLOAD_DIR=$HOME/greenbone-community-container

installed() {
    # $1 should be the command to look for. If $2 is set, we have arguments
    local failed=0
    if [ -z "$2" ]; then
        if ! [ -x "$(command -v $1)" ]; then
            failed=1
        fi
    else
        local ret=0
        $@ &> /dev/null || ret=$?
        if [ "$ret" -ne 0 ]; then
            failed=1
        fi
    fi

    if [ $failed -ne 0 ]; then
        echo "$@ is not available. See https://greenbone.github.io/docs/latest/$RELEASE/container/#prerequisites."
        exit 1
    fi

}

RELEASE="22.4"

installed curl
installed docker
installed docker compose

echo "Using Greenbone Community Containers $RELEASE"

mkdir -p $DOWNLOAD_DIR && cd $DOWNLOAD_DIR

echo "Downloading docker-compose file..."
curl -f -O https://greenbone.github.io/docs/latest/_static/docker-compose-$RELEASE.yml
## MOD
# Make WebUI accessable by any local device on the same network
sed -i 's/127.0.0.1:9392:80/0.0.0.0:9392:80/g' $DOWNLOAD_DIR/docker-compose-$RELEASE.yml
## /MOD

echo "Pulling Greenbone Community Containers $RELEASE"
docker compose -f $DOWNLOAD_DIR/docker-compose-$RELEASE.yml -p greenbone-community-edition pull
echo

echo "Starting Greenbone Community Containers $RELEASE"
docker compose -f $DOWNLOAD_DIR/docker-compose-$RELEASE.yml -p greenbone-community-edition up -d
echo

read -s -p "Password for admin user: " password
docker compose -f $DOWNLOAD_DIR/docker-compose-$RELEASE.yml -p greenbone-community-edition \
    exec -u gvmd gvmd gvmd --user=admin --new-password=$password
## MOD
sleep 2
echo "Access via: $(echo "http://$(hostname -I |awk '{print $1}'):9392/)"
## MOD
echo
echo "The feed data will be loaded now. This process may take several minutes up to hours."
echo "Before the data is not loaded completely, scans will show insufficient or erroneous results."
echo "See https://greenbone.github.io/docs/latest/$RELEASE/container/workflows.html#loading-the-feed-changes for more details."
echo
## MOD
## This is a headless system - Dont 
# echo "Press Enter to open the Greenbone Security Assistant web interface in the web browser."
# read
# xdg-open "http://127.0.0.1:9392" 2>/dev/null >/dev/null &
## /MOD
