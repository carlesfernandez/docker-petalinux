FROM ubuntu:16.04

# The Xilinx toolchain version
ARG XILVER=2018.3
ARG XXXX_XXXX=1207_2324

# The PetaLinux base. We expect ${PETALINUX_BASE}-installer.run to be the patched installer.
# PetaLinux will be installed in /opt/${PETALINX_BASE}
# File is expected in the "./resources" subdirectory
ARG PETALINUX_BASE=petalinux-v${XILVER}-final

# The PetaLinux runnable installer
ARG PETALINUX_INSTALLER=${PETALINUX_BASE}-installer.run

RUN dpkg --add-architecture i386 && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3.4 \
    tofrodos \
    iproute2 \
    gawk \
    xvfb \
    gcc-4.8 \
    git \
    make \
    net-tools \
    libncurses5-dev \
    zlib1g-dev:i386 \
    libssl-dev \
    flex \
    bison \
    libselinux1 \
    gnupg \
    wget \
    diffstat \
    chrpath \
    socat \
    xterm \
    autoconf \
    libtool \
    libtool-bin \
    tar \
    unzip \
    texinfo \
    zlib1g-dev \
    gcc-multilib \
    build-essential \
    libsdl1.2-dev \
    libglib2.0-dev \
    screen \
    expect \
    locales \
    cpio \
    sudo \
    software-properties-common \
    pax \
    gzip \
    vim \
    libgtk2.0-0 \
    libgtk2.0-dev \
    nano \
    tftpd-hpa \
    update-inetd \
    python3-gi \
    less \
    lsb-release \
    fakeroot \
    rsync \
    xorg \
    dos2unix \
    && update-alternatives --install /usr/bin/python python /usr/bin/python2.7 2 \
    && add-apt-repository ppa:deadsnakes/ppa && apt update \
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

# Install PetaLinux
RUN echo "" | sudo -S chown -R petalinux:petalinux . \
    && wget -q ${HTTP_SERV}/${PETALINUX_INSTALLER} \
    && chmod a+x ${PETALINUX_INSTALLER} \
    && SKIP_LICENSE=y ./${PETALINUX_FILE}${PETALINUX_INSTALLER} /opt/${PETALINUX_BASE} \
    && rm -f ./${PETALINUX_INSTALLER} \
    && rm -f petalinux_installation_log

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
