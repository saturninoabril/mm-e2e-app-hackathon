#! /bin/bash

sudo apt-get update
sudo apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  software-properties-common \
  unzip

# Install docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# Install docker-compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version

export HOME=/home/ubuntu
cd $HOME

# Clone mm-e2e-app-hackathon repo
mkdir $HOME/mm-e2e-app-hackathon
cd $HOME/mm-e2e-app-hackathon
git init
git remote add origin https://github.com/saturninoabril/mm-e2e-app-hackathon.git
git fetch --depth 1 origin main
git reset --hard FETCH_HEAD

# Run dependencies
cd $HOME/mm-e2e-app-hackathon/docker
docker-compose --ansi never run --rm start_dependencies
cat config/openldap/test-data.ldif | docker-compose --ansi never exec -T openldap bash -c 'ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest';
docker-compose --ansi never exec -T minio sh -c 'mkdir -p /data/mattermost-test';
docker-compose --ansi never ps

# Wait for dependencies
sleep 5
until curl --max-time 5 --output - http://localhost:9200; do echo "waiting for Elasticsearch"; sleep 5; done;

mkdir $HOME/mattermost_config

# Setup config
curl https://raw.githubusercontent.com/saturninoabril/mm-e2e-app-hackathon/main/docker/config/mattermost/config.json --output $HOME/mattermost_config/config.json

# Setup user
touch $HOME/mattermost_config/mattermost.mattermost-license
echo ${license} > $HOME/mattermost_config/mattermost.mattermost-license

sudo chown -R 2000:2000 $HOME/mattermost_config/

ulimit -n 8096

# Set DB config
export MM_SQLSETTINGS_DRIVERNAME="postgres"
export MM_SQLSETTINGS_DATASOURCE="postgres://mmuser:mostest@mattermost-postgres:5432/mattermost_test?sslmode=disable&connect_timeout=10"

sudo docker run -d --net docker_mm-test \
  --name mattermost-server \
  -p 8065:8065 \
  -e MM_CLUSTERSETTINGS_READONLYCONFIG=false \
  -e MM_PLUGINSETTINGS_ENABLEUPLOADS=true \
  -e MM_SQLSETTINGS_DRIVERNAME=$MM_SQLSETTINGS_DRIVERNAME \
  -e MM_SQLSETTINGS_DATASOURCE=$MM_SQLSETTINGS_DATASOURCE \
  -v $HOME/mattermost_config:/mattermost/config \
  mattermost/${mattermost_docker_image}:${mattermost_docker_tag}

sleep 5
until curl --max-time 5 --output - http://localhost:8065; do echo "waiting for Mattermost server"; sleep 5; done;

# Install Cypress system requirements
# From https://github.com/cypress-io/cypress-docker-images/blob/master/base/14.16.0/Dockerfile#L10-L37
sudo apt-get install --no-install-recommends -y \
  libgtk2.0-0 \
  libgtk-3-0 \
  libnotify-dev \
  libgconf-2-4 \
  libgbm-dev \
  libnss3 \
  libxss1 \
  libasound2 \
  libxtst6 \
  xauth \
  xvfb \
  fonts-noto-color-emoji \
  fonts-arphic-bkai00mp \
  fonts-arphic-bsmi00lp \
  fonts-arphic-gbsn00lp \
  fonts-arphic-gkai00mp \
  fonts-arphic-ukai \
  fonts-arphic-uming \
  ttf-wqy-zenhei \
  ttf-wqy-microhei \
  xfonts-wqy

# Install chrome browser
# From https://github.com/cypress-io/cypress-docker-images/blob/master/browsers/node14.16.0-chrome89-ff86/Dockerfile#L9-L17
sudo apt-get install -y \
  fonts-liberation \
  libappindicator3-1 \
  xdg-utils

export CHROME_VERSION="89.0.4389.72"

sudo wget -O /usr/src/google-chrome-stable_current_amd64.deb "http://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_$CHROME_VERSION-1_amd64.deb"
sudo dpkg -i /usr/src/google-chrome-stable_current_amd64.deb
sudo apt-get install -f -y
sudo rm -f /usr/src/google-chrome-stable_current_amd64.deb
google-chrome --version

# Install node
cd $HOME
curl -sL https://deb.nodesource.com/setup_14.x -o nodesource_setup.sh
sudo bash nodesource_setup.sh
sudo apt-get install -y nodejs
node -v
npm -v

# Clone mattermost-webapp repo
mkdir $HOME/mattermost-webapp
cd $HOME/mattermost-webapp
git init
git remote add origin https://github.com/mattermost/mattermost-webapp.git
# TODO: user input for commit hash or branch name
git fetch --depth 1 origin ${e2e_branch_or_commit}
git reset --hard FETCH_HEAD

cd $HOME/mattermost-webapp/e2e
npm ci
# TODO: use "run_test_cycle.js" one generating cycle is done
node run_tests.js

echo DONE
