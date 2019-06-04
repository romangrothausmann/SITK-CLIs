################################################################################
# base system
################################################################################
FROM ubuntu:18.04 as system

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 r-base

################################################################################
# builder
################################################################################
FROM system as builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates `# essential for git over https` \
    cmake \
    build-essential \
    python3-dev

### SITK
RUN git clone -b v1.2.0 --depth 1 https://github.com/InsightSoftwareConsortium/SimpleITK

RUN mkdir -p SITK_build && \
    cd SITK_build && \
    cmake \
    	  -DCMAKE_INSTALL_PREFIX=/opt/sitk/ \
	  -DCMAKE_BUILD_TYPE=Release \
	  -DBUILD_TESTING=OFF \
	  -DBUILD_SHARED_LIBS=OFF \
	  -DITK_USE_SYSTEM_LIBRARIES=OFF \
    	  -DWRAP_CSHARP=OFF \
	  -DWRAP_LUA=OFF \
	  -DWRAP_PYTHON=ON \
	  -DWRAP_JAVA=OFF \
	  -DWRAP_TCL=OFF \
	  -DWRAP_R=ON \
	  -DWRAP_RUBY=OFF \
	  ../SimpleITK/SuperBuild && \
    make -j"$(nproc)"

RUN cd SITK_build/SimpleITK-build/Wrapping/Python `# essential for py install ` && \
    python3 Packaging/setup.py install --home /opt/sitk/

RUN cd SITK_build/SimpleITK-build/Wrapping/R/Packaging && \
    R CMD INSTALL -l /opt/sitk/ SimpleITK



################################################################################
# install
################################################################################
FROM system as install

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-numpy python3-h5py

COPY --from=builder /opt/sitk/ /opt/sitk/
ENV PYTHONPATH "${PYTHONPATH}:/opt/sitk/lib/python/"
ENV R_LIBS "${R_LIBS}:/opt/sitk/"

COPY . /opt/SITK-CLIs/
ENV PATH "/opt/SITK-CLIs/:${PATH}"

WORKDIR /images

ENV USERNAME diUser
RUN useradd -m $USERNAME && \
    echo "$USERNAME:$USERNAME" | chpasswd && \
    usermod --shell /bin/bash $USERNAME

USER $USERNAME
