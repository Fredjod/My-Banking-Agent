FROM perl:5.22

RUN cpanm DateTime 
RUN cpanm Archive::Zip
RUN cpanm LWP::UserAgent
RUN cpanm LWP::Protocol::https
RUN cpanm Spreadsheet::ParseExcel
RUN cpanm Spreadsheet::XLSX
RUN cpanm Spreadsheet::WriteExcel
RUN cpanm MIME::Lite

VOLUME /usr/src/mba
WORKDIR /usr/src/mba
CMD [ "perl" ]