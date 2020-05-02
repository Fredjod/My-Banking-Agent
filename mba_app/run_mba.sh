#!/bin/bash

docker run --rm -v /home/pi/mba_app/prod/app:/usr/mba/app -v /mnt/mba/logs:/usr/mba/logs -v /mnt/mba/files:/usr/mba/files mba:prod
docker exec owncloud-server_owncloud_1 occ files:scan "--path=/jaudin/files/MBA"