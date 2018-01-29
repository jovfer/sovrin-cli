FROM ubuntu:16.04

ARG uid=1000

RUN apt-get update && \
    apt-get install -y \
      apt-transport-https \
      debhelper \
      devscripts \
      python3.5 \
      python3-pip \
      ruby-dev \
      ssh \
      unzip \
      wget \
      zip

RUN pip3 install -U pip plumbum deb-pkg-tools

# install fpm
RUN gem install --no-ri --no-rdoc fpm

# FIXME change SDK and sovrin-genesis type to stable
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 68DB5E88
RUN echo "deb https://repo.sovrin.org/test/deb xenial master" >> /etc/apt/sources.list
RUN echo "deb https://repo.sovrin.org/sdk/deb xenial master" >> /etc/apt/sources.list

ARG genesis_version=0.0.4
ARG indy_cli_version=1.3.0~337

RUN apt-get update && \
    apt-get install -y \
      sovrin-genesis=${genesis_version} \
      indy-cli=${indy_cli_version}

RUN useradd -ms /bin/bash -u $uid indy
USER indy
