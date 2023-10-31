# SPDX-FileCopyrightText: 2020, Carles Fernandez-Prades <carles.fernandez@cttc.es>
# SPDX-License-Identifier: MIT

FROM ubuntu:16.04
LABEL version="1.0" description="PetaLinux and Vivado image" maintainer="carles.fernandez@cttc.es"

RUN dpkg --add-architecture i386 && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
  autoconf \
  bison \
  build-essential \
  chrpath \
  cpio \
  diffstat \
  dos2unix \
  expect \
  fakeroot \
  flex \
  gawk \
  gcc-4.8 \
  gcc-multilib \
  git \
  gnupg \
  gzip \
  iproute2 \
  less \
  libbz2-dev \
  libffi-dev \
  libgdbm-dev \
  libglib2.0-dev \
  libgtk2.0-0 \
  libgtk2.0-dev \
  libncurses5-dev \
  libnss3-dev \
  libreadline-dev \
  libsdl1.2-dev \
  libselinux1 \
  libsqlite3-dev \
  libssl-dev \
  libtool \
  libtool-bin \
  locales \
  lsb-release \
  make \
  nano \
  net-tools \
  pax \
  pkg-config \
  python3-gi \
  python3.4 \
  rsync \
  screen \
  socat \
  software-properties-common \
  sudo \
  tar \
  texinfo \
  tftpd-hpa \
  tofrodos \
  unzip \
  update-inetd \
  vim \
  wget \
  xorg \
  xterm \
  xvfb \
  zlib1g-dev \
  zlib1g-dev:i386 \
  && update-alternatives --install /usr/bin/python python /usr/bin/python2.7 2 \
  && add-apt-repository -y ppa:jblgf0/python && apt update \
  && apt-get install -y python3.6 && update-alternatives --install /usr/bin/python python /usr/bin/python3.6 1 \
  && apt-get autoremove --purge && apt-get autoclean && update-alternatives --auto python

# Install the repo tool to handle git submodules (meta layers) comfortably.
ADD https://storage.googleapis.com/git-repo-downloads/repo /usr/local/bin/
RUN chmod 755 /usr/local/bin/repo

RUN echo "%sudo ALL=(ALL:ALL) ALL" >> /etc/sudoers \
  && echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
  && ln -fs /bin/bash /bin/sh

# Set locale
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Build and install Python 3.11, required by repo
RUN wget https://www.python.org/ftp/python/3.11.4/Python-3.11.4.tgz \
  && tar -xf Python-3.11.*.tgz && cd Python-3.11.*/ \
  && ./configure --enable-optimizations && make && make altinstall \
  && cd .. && rm Python-3.11.*.tgz && rm -rf Python-3.11.*/

# The Xilinx toolchain version
ARG XILVER=2018.3

# The PetaLinux base. We expect ${PETALINUX_BASE}-installer.run to be the patched installer.
# PetaLinux will be installed in /opt/${PETALINX_BASE}
# File is expected in the "./resources" subdirectory
ARG PETALINUX_BASE=petalinux-v${XILVER}-final

# Add user 'petalinux' with password 'petalinux' and give it access to install directory /opt
RUN useradd -m -G dialout,sudo -p '$6$wiu9XEXx$ITRrMySAw1SXesQcP.Bm3Su2CuaByujc6Pb7Ztf4M9ES2ES7laSRwdcbgG96if4slduUxyjqvpEq2I0OhxKCa1' petalinux \
  && chmod +w /opt \
  && chown -R petalinux:petalinux /opt \
  && mkdir /opt/${PETALINUX_BASE} \
  && chmod 755 /opt/${PETALINUX_BASE} \
  && chown petalinux:petalinux /opt/${PETALINUX_BASE}

# Set folder for tftp server
RUN mkdir -p /tftpboot && chmod 666 /tftpboot \
  && sed -i 's/TFTP\_USERNAME\=\"tftp\"/TFTP\_USERNAME\=\"petalinux\"/g' /etc/default/tftpd-hpa \
  && sed -i 's/var\/lib\/tftpboot/tftpboot/g' /etc/default/tftpd-hpa \
  && sed -i 's/secure/secure \-\-create/g' /etc/default/tftpd-hpa

# Install under /opt, with user petalinux
WORKDIR /opt
USER petalinux

# The HTTP server to retrieve the files from.
ARG HTTP_SERV=http://172.17.0.1:8000/resources

# The PetaLinux runnable installer
ARG PETALINUX_INSTALLER=${PETALINUX_BASE}-installer.run

# Install PetaLinux
RUN echo "" | sudo -S chown -R petalinux:petalinux . \
  && wget -q ${HTTP_SERV}/${PETALINUX_INSTALLER} \
  && chmod a+x ${PETALINUX_INSTALLER} \
  && SKIP_LICENSE=y ./${PETALINUX_FILE}${PETALINUX_INSTALLER} /opt/${PETALINUX_BASE} \
  && rm -f ./${PETALINUX_INSTALLER} \
  && rm -f petalinux_installation_log

# The Vivado build number
ARG XXXX_XXXX=1207_2324

# Install Vivado
# Files are expected in the "./resources" subdirectory
ENV XLNX_VIVADO_OFFLINE_INSTALLER=Xilinx_Vivado_SDK_${XILVER}_${XXXX_XXXX}.tar.gz
ENV XLNX_VIVADO_BATCH_CONFIG_FILE=install_config.txt
RUN mkdir -p /opt/Xilinx/tmp \
  && cd /opt/Xilinx/tmp \
  && wget -q ${HTTP_SERV}/$XLNX_VIVADO_BATCH_CONFIG_FILE \
  && wget -q ${HTTP_SERV}/$XLNX_VIVADO_OFFLINE_INSTALLER \
  && cat $XLNX_VIVADO_BATCH_CONFIG_FILE \
  && tar -zxf $XLNX_VIVADO_OFFLINE_INSTALLER && ls -al \
  && mv $XLNX_VIVADO_BATCH_CONFIG_FILE Xilinx_Vivado_SDK_${XILVER}_${XXXX_XXXX}/ \
  && cd Xilinx_Vivado_SDK_${XILVER}_${XXXX_XXXX} \
  && chmod a+x xsetup \
  && ./xsetup \
  --agree XilinxEULA,3rdPartyEULA,WebTalkTerms \
  --config $XLNX_VIVADO_BATCH_CONFIG_FILE \
  --batch INSTALL \
  && cd $HOME_DIR \
  && rm -rf /opt/Xilinx/tmp

# Source settings at login
USER root
RUN echo "/usr/sbin/in.tftpd --foreground --listen --address [::]:69 --secure /tftpboot" >> /etc/profile \
  && echo ". /opt/${PETALINUX_BASE}/settings.sh" >> /etc/profile \
  && echo ". /opt/Xilinx/Vivado/${XILVER}/settings64.sh" >> /etc/profile \
  && echo ". /etc/profile" >> /root/.profile

# If 2018.3, apply perf patch
RUN if [ "$XILVER" = "2018.3" ] ; then \
  sed -i 's/virtual\/kernel\:do\_patch/virtual\/kernel\:do\_shared\_workdir/g' /opt/petalinux-v2018.3-final/components/yocto/source/arm/layers/core/meta/classes/kernelsrc.bbclass ; \
  fi

EXPOSE 69/udp

USER petalinux

RUN export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/Xilinx/Vivado/${XILVER}/lib/lnx64.o/

# incorporate Vivado license file or ENV LM_LICENSE_SERVER=portNum@ipAddrOfLicenseServer

ENTRYPOINT ["/bin/sh", "-l"]
