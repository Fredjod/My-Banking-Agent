#!/bin/bash

# docker run --rm -v /home/pi/mba_app/prod/app:/usr/mba/app -v /mnt/logs:/usr/mba/logs -v /mnt/mba:/usr/mba/files mba:prod
# docker exec owncloud_server occ files:scan "--path=/jaudin/files/MBA"

docker-compose -p mba-web-server up -d