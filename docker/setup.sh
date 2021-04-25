#!/bin/bash

set -ex  # Exit on error; debugging enabled.
set -o pipefail  # Fail a pipe if any sub-command fails.

# not makes sure the command passed to it does not exit with a return code of 0.
not() {
  ! "$@"
}

die() {
  echo "$@" >&2
  exit 1
}

fail_on_output() {
  tee /dev/stderr | not read
}

# Undo any edits made by this script.
cleanup() {
  # todo
  echo DO CLEAN UP
}
trap cleanup EXIT

# Run dependencies
docker-compose --no-ansi run --rm start_dependencies
cat config/openldap/test-data.ldif | docker-compose --no-ansi exec -T openldap bash -c 'ldapadd -x -D "cn=admin,dc=mm,dc=test,dc=com" -w mostest';
docker-compose --no-ansi exec -T minio sh -c 'mkdir -p /data/mattermost-test';
docker-compose --no-ansi ps

# Wait for dependencies
sleep 5
until curl --max-time 5 --output - http://localhost:9200; do echo "waiting for Elasticsearch"; sleep 5; done;

ulimit -n 8096
mkdir ~/mattermost
# setup and  modify config
# touch ~/mattermost/config/config.json
# setup license

sudo chown -R 2000:2000 mattermost/

MM_SQLSETTINGS_DRIVERNAME=postgres
MM_SQLSETTINGS_DATASOURCE="postgres://mmuser:mostest@mattermost-postgres:5432/mattermost_test?sslmode=disable&connect_timeout=10"

MATTERMOST_DOCKER_IMAGE=mattermost-enterprise-edition
MATTERMOST_DOCKER_TAG=master

PWD=$(pwd)

docker run -it --net docker_mm-test \
  --name mattermost-server \
  -p 8065:8065 \
  -e MM_CLUSTERSETTINGS_READONLYCONFIG=false \
  -e MM_EMAILSETTINGS_SMTPSERVER=mattermost-inbucket \
  -e MM_LDAPSETTINGS_LDAPSERVER=mattermost-openldap \
  -e MM_ELASTICSEARCHSETTINGS_CONNECTIONURL=http://mattermost-elasticsearch:9200 \
  -e MM_PLUGINSETTINGS_ENABLEUPLOADS=true \
  -e MM_SQLSETTINGS_DRIVERNAME=$MM_SQLSETTINGS_DRIVERNAME \
  -e MM_SQLSETTINGS_DATASOURCE=$MM_SQLSETTINGS_DATASOURCE \
  -v ~/mattermost:/mattermost \
  mattermost/$MATTERMOST_DOCKER_IMAGE:$MATTERMOST_DOCKER_TAG

until curl --max-time 5 --output - http://localhost:8065; do echo "waiting for Mattermost server"; sleep 5; done;

echo SUCCESS
