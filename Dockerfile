from ubuntu:18.04

COPY sources.list /etc/apt/sources.list
RUN apt-get update -y 
RUN env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
                        sudo \
                        wget \
                        curl \
                        iputils-ping \
                        netcat \
                        vim \
                        libnss-sss \
                        libnss3 \
                        iptables \
                        net-tools \
                        ssh \
                        rsync \
                        && rm -rf /var/lib/apt/lists/*

RUN useradd -u 1000 -s /bin/bash -m satanson
RUN usermod -a -G sudo satanson
RUN echo "satanson ALL=(ALL) NOPASSWD : ALL" > /etc/sudoers.d/satanson
