FROM mba:build

# ARG mba_version
RUN mkdir -p /usr/mba/app
VOLUME /usr/mba/files
VOLUME /usr/mba/logs
VOLUME /usr/mba/app
WORKDIR /usr/mba/app
ENTRYPOINT [ "bash" ]
CMD [ "/usr/mba/app/mba.sh" ]