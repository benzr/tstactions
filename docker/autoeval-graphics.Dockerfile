FROM ubuntu:24.04

# improve OpenGL
# libgl1-mesa-glx si  deprecated in ubuntu 24.04 , replaced by packages "libgl1 libglx-mesa0 mesa-vulkan-drivers"
RUN apt-get update && apt-get install -y \
    mesa-utils \
    libgl1 libglx-mesa0 mesa-vulkan-drivers \
    libgles2-mesa-dev \
    mesa-utils-extra \
    libglfw3

# libjasper-dev 
RUN apt-get update && apt-get install -y \
    wget \
    libglib2.0-0  \
    #libgl1-mesa-glx \
    xcb \
    "^libxcb.*" \
    libx11-xcb-dev \
    libxkbcommon-x11-dev \
    libglu1-mesa-dev \
    libxrender-dev \
    libxi6 \
    libdbus-1-3 \
    libfontconfig1 \
    xvfb \
    xz-utils  

# install python3
RUN mkdir -p /opt
RUN apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv python3-apt python3-setuptools
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip3 install pyzmq cbor2 numpy scipy pyzmq cbor2 coppeliasim-zmqremoteapi-client


# add some tools and missing packages and clean apt cache
RUN apt-get install -y --no-install-recommends \
    wget \
    vim \
    libsodium-dev libjpeg-dev libtiff-dev \
    libzmq5 \
    && \
    apt-get autoclean -y && apt-get autoremove -y && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY ./tmp/CoppeliaSim_Edu_V4_10_0_rev0_Ubuntu24_04.tar.xz /opt/
#RUN wget -P /opt/ https://downloads.coppeliarobotics.com/V4_10_0_rev0/CoppeliaSim_Edu_V4_10_0_rev0_Ubuntu24_04.tar.xz
RUN tar -xf /opt/CoppeliaSim_Edu_V4_10_0_rev0_Ubuntu24_04.tar.xz -C /opt && \
    rm /opt/CoppeliaSim_Edu_V4_10_0_rev0_Ubuntu24_04.tar.xz

ENV COPPELIASIM_ROOT_DIR=/opt/CoppeliaSim_Edu_V4_10_0_rev0_Ubuntu24_04
#ENV LD_LIBRARY_PATH=$COPPELIASIM_ROOT_DIR:$LD_LIBRARY_PATH
ENV LD_LIBRARY_PATH=$COPPELIASIM_ROOT_DIR
ENV PATH=$COPPELIASIM_ROOT_DIR:$PATH

RUN mkdir -p /shared

# RUN echo '#!/bin/bash\ncd $COPPELIASIM_ROOT_DIR\n/usr/bin/xvfb-run --server-args "-ac -screen 0, 1024x1024x24" coppeliaSim "$@"' > /entrypoint && chmod a+x /entrypoint
# Run CoppeliaSim with the -h option (you can also specify a license key with -Glicense=licenseKey or use of Python with -GpreferredSandboxLang=python):
# CMD ["./coppeliaSim.sh", "-h"]

# Use following instead to open an application window via an X server:
# RUN echo '#!/bin/bash\ncd $COPPELIASIM_ROOT_DIR\n./coppeliaSim "$@"' > /entrypoint && chmod a+x /entrypoint
# CMD ["./coppeliaSim.sh"]


EXPOSE 23000-23500
# ENTRYPOINT ["/entrypoint"]

CMD ["/bin/bash"]