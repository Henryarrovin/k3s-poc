FROM jrei/systemd-ubuntu:24.04

COPY setup.sh /usr/local/bin/setup.sh
COPY setup.service /etc/systemd/system/setup.service

RUN chmod +x /usr/local/bin/setup.sh && \
    systemctl enable setup.service