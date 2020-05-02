FROM perl:latest

RUN cpanm DateTime 
RUN cpanm Archive::Zip
RUN cpanm LWP::UserAgent
RUN cpanm LWP::Protocol::https
RUN cpanm HTTP::CookieJar::LWP
RUN cpanm Path::Tiny
RUN cpanm Spreadsheet::ParseExcel
RUN cpanm Spreadsheet::XLSX
RUN cpanm Spreadsheet::WriteExcel
RUN cpanm MIME::Lite

VOLUME /usr/mba/src
WORKDIR /usr/mba/src
ENTRYPOINT [ "perl", "-w" ]