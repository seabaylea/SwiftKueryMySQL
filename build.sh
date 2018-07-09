#!/bin/bash

set -o verbose

if [ -n "${DOCKER_IMAGE}" ]; then
    docker pull ${DOCKER_IMAGE}
    docker run --env SWIFT_SNAPSHOT -v ${TRAVIS_BUILD_DIR}:${TRAVIS_BUILD_DIR} ${DOCKER_IMAGE} /bin/bash -c "apt-get update && apt-get install -y apt-utils debconf-utils dialog git sudo lsb-release wget libxml2 && cd $TRAVIS_BUILD_DIR && ./build.sh"
else
    if [[ $TRAVIS_OS_NAME == "osx" ]]; then
        mysql --version || { brew update && brew install mysql && mysql.server start && mysql --version; }
    else
        export DEBIAN_FRONTEND=noninteractive
        cd /tmp
        wget https://dev.mysql.com/get/mysql-apt-config_0.8.10-1_all.deb
        cd -
        echo mysql-apt-config mysql-apt-config/select-server select mysql-8.0 | debconf-set-selections
        dpkg -i /tmp/mysql-apt-config_0.8.10-1_all.deb
        echo mysql-community-server mysql-community-server/root-pass password | debconf-set-selections
        apt-get update -y
        apt-get install -q -y mysql-server
        apt-get install -y libmysqlclient-dev
        service mysql start
        mysql --version
    fi

    mysql_upgrade -uroot || echo "No need to upgrade"
    mysql -uroot -e "CREATE USER 'swift'@'localhost' IDENTIFIED BY 'kuery';"
    mysql -uroot -e "CREATE DATABASE IF NOT EXISTS test;"
    mysql -uroot -e "GRANT ALL ON test.* TO 'swift'@'localhost';"

    git clone -b install_from_url --single-branch https://github.com/IBM-Swift/Package-Builder.git
    ./Package-Builder/build-package.sh -projectDir $(pwd)
fi
