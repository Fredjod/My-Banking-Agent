FROM perl:latest

# RUN cpanm DateTime 
RUN cpanm Archive::Zip
RUN cpanm LWP::UserAgent
RUN cpanm LWP::Protocol::https
RUN cpanm HTTP::CookieJar::LWP
RUN cpanm Path::Tiny
RUN cpanm Spreadsheet::ParseExcel
RUN cpanm Spreadsheet::XLSX
RUN cpanm Spreadsheet::WriteExcel
RUN cpanm MIME::Lite
RUN cpanm HTTP::Server::Simple
RUN cpanm Proc::Daemon
RUN cpanm JSON
RUN cpanm --force Module::Pluggable
RUN cpanm Params::ValidationCompiler
RUN cpanm DateTime::TimeZone
RUN cpanm DateTime
RUN cpanm URI::Encode

VOLUME /usr/mba/src
WORKDIR /usr/mba/src
ENTRYPOINT [ "perl", "-w" ]