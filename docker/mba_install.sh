#!/bin/bash

docker build -t mba:build ./build
docker build -t mba:prod ./prod

tar xzvf ./prod/mba_$1.tar.gz -C ./server/app
cp ./prod/app.txt ./server/app/properties
cp ./prod/mba.sh ./server/app

(crontab -l 2>/dev/null; echo "30 20 * * * sudo -u www-data docker run -it --rm -v /home/debian/mba-server/docker/server/app:/usr/mba/app -v /home/debian/mba-server/docker/server/logs:/usr/mba/logs -v /home/debian/mba-server/docker/server/files:/usr/mba/files mba:prod >> /var/log/cron.log 2>&1") | crontab -

cd ./server
docker-compose stop
docker-compose up -d
