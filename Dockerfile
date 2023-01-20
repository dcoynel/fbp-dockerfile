FROM nvidia/cuda:9.0-devel-centos7 as base

ENV CUDA_PKG_VERSION 9-0-9.0.176-1
ENV CUDA_VERSION 9.0.176
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility
ENV NVIDIA_REQUIRE_CUDA cuda>=9.0
ENV NVIDIA_VISIBLE_DEVICES all
ENV PATH /usr/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ARG TAR_OPTIONS=--no-same-owner

COPY install.r DATA_private*.tar.gz /tmp/

# OS / build dependencies
RUN yum groupinstall -y "development tools"                                              && \
    yum-builddep     -y python python3                                                   && \
    yum install      -y epel-release                                                     && \
    yum install      -y sshpass openssh-clients git nano                                    \
                        wget curl unzip qt4-devel qt5-qtbase-devel qt5-qtx11extras-devel    \
                        glib2-devel tcsh gcc gcc-c++ libgfortran-static make vim-common     \
                        lapack-devel lapack-static blas-devel blas-static zlib-devel        \
                        python-devel python3-devel                                          \
                        libX11-devel libXmu-devel mesa-libGL-devel                          \
                        R libpng-devel libjpeg-turbo-devel                                  \
                        libxml2-devel libcurl-devel openssl-devel                           \
                        libssh2-devel                                                       \
                        perl perl-Env

# Download the version of FSL specific for the pipeline and also the public DATA.
RUN pushd tmp  && \
    wget https://www.fmrib.ox.ac.uk/ukbiobank/fbp/templates/dckr_build/bb_FSL.tar.gz      && \
    wget https://www.fmrib.ox.ac.uk/ukbiobank/fbp/templates/dckr_build/DATA_public.tar.gz && \
    popd

# need newer cmake to compile freesurfer7
# (/usr/local/bin/ added to PATH above)
RUN wget --no-check-certificate https://cmake.org/files/v3.12/cmake-3.12.0.tar.gz && \
    tar -xzvf cmake-3.12.0.tar.gz                                                 && \
    cd cmake-3.12.0                                                               && \
    ./bootstrap                                                                   && \
    make                                                                          && \
    make install                                                                  && \
    cd ..                                                                         && \
    rm -rf cmake-3.12.0 cmake-3.12.0.tar.gz

# git annex for freesurfer datasets
RUN curl https://downloads.kitenet.net/git-annex/linux/current/rpms/git-annex.repo > /etc/yum.repos.d/git-annex.repo && \
    yum install -y git-annex-standalone

# parallel for parallelising bedpostx
RUN wget https://linuxsoft.cern.ch/cern/centos/7/cern/x86_64/Packages/parallel-20150522-1.el7.cern.noarch.rpm && \
    yum localinstall -y parallel-20150522-1.el7.cern.noarch.rpm                                               && \
    rm -f parallel-20150522-1.el7.cern.noarch.rpm

# MCRs
RUN mkdir -p /mcr/v81/bld /mcr/v83/bld /mcr/v84/bld  /mcr/v901/bld /mcr/v92/bld && \
    pushd /mcr/v81/bld  && \
    wget https://ssd.mathworks.com/supportfiles/MCR_Runtime/R2013a/MCR_R2013a_glnxa64_installer.zip  && \
    unzip MCR_R2013a_glnxa64_installer.zip  && \
    ./install -destinationFolder /mcr/v81 -mode silent -agreeToLicense yes  && \
    popd  && \
    pushd /mcr/v83/bld && \
    wget https://uk.mathworks.com/supportfiles/downloads/R2014a/deployment_files/R2014a/installers/glnxa64/MCR_R2014a_glnxa64_installer.zip && \
    unzip MCR_R2014a_glnxa64_installer.zip && \
    ./install -destinationFolder /mcr/v83 -mode silent -agreeToLicense yes && \
    popd && \
    pushd /mcr/v84/bld && \
    wget https://ssd.mathworks.com/supportfiles/downloads/R2014b/deployment_files/R2014b/installers/glnxa64/MCR_R2014b_glnxa64_installer.zip && \
    unzip MCR_R2014b_glnxa64_installer.zip && \
    ./install -destinationFolder /mcr/v84 -mode silent -agreeToLicense yes && \
    popd && \
    pushd /mcr/v901/bld && \
    wget https://ssd.mathworks.com/supportfiles/downloads/R2016a/deployment_files/R2016a/installers/glnxa64/MCR_R2016a_glnxa64_installer.zip && \
    unzip MCR_R2016a_glnxa64_installer.zip && \
    ./install -destinationFolder /mcr/v901 -mode silent -agreeToLicense yes && \
    wget https://ssd.mathworks.com/supportfiles/downloads/R2016a/deployment_files/R2016a/installers/glnxa64/MCR_R2016a_Update_7_glnxa64.sh && \
    sh ./MCR_R2016a_Update_7_glnxa64.sh -d=/mcr/v901 -s && \
    popd && \
    pushd /mcr/v92/bld  && \
    wget https://ssd.mathworks.com/supportfiles/downloads/R2017a/deployment_files/R2017a/installers/glnxa64/MCR_R2017a_glnxa64_installer.zip && \
    unzip MCR_R2017a_glnxa64_installer.zip && \
    ./install -destinationFolder /mcr/v92 -mode silent -agreeToLicense yes && \
    wget https://ssd.mathworks.com/supportfiles/downloads/R2017a/deployment_files/R2017a/installers/glnxa64/MCR_R2017a_Update_3_glnxa64.sh && \
    sh ./MCR_R2017a_Update_3_glnxa64.sh -d=/mcr/v92 -s && \
    popd && \
    rm -rf /mcr/v81/bld /mcr/v83/bld /mcr/v84/bld  /mcr/v901/bld /mcr/v92/bld

# CUDA runtimes
RUN mkdir /cuda-bld                                                                                                  && \
    pushd /cuda-bld                                                                                                  && \
    wget http://developer.download.nvidia.com/compute/cuda/5_5/rel/installers/cuda_5.5.22_linux_64.run               && \
    sh ./cuda_5.5.22_linux_64.run -silent -toolkit -override -toolkitpath=/cuda-bld/cuda5.5                          && \
    cp cuda5.5/lib64/libcudart.so.5.5 cuda5.5/lib64/libcurand.so.5.5 /usr/local/cuda-9.0/lib64                       && \
    wget http://developer.download.nvidia.com/compute/cuda/6_5/rel/installers/cuda_6.5.14_linux_64.run               && \
    sh ./cuda_6.5.14_linux_64.run -silent -toolkit -override -no-opengl-libs -toolkitpath=/cuda-bld/cuda6.5          && \
    cp cuda6.5/lib64/libcudart.so.6.5 cuda6.5/lib64/libcurand.so.6.5 /usr/local/cuda-9.0/lib64                       && \
    popd                                                                                                             && \
    rm -f /usr/local/cuda                                                                                            && \
    ln -s /usr/local/cuda-9.0 /usr/local/cuda                                                                        && \
    rm -rf /cuda-bld

# FBP
RUN mkdir /fbp                                                                  && \
    pushd fbp                                                                   && \
    git clone https://git.fmrib.ox.ac.uk/falmagro/uk_biobank_pipeline_v_1.5.git && \
    mv uk_biobank_pipeline_v_1.5 bb_pipeline_v_2.5                              && \
    echo "source /fbp/bb_pipeline_v_2.5/init_vars" >> ~/.bashrc                 && \
    rm -rf uk_biobank_pipeline_v_1.5/.git                                       && \
    mkdir -p /fbp/bb_pipeline_v_2.5/bb_python                                   && \
    mkdir -p /fbp/bb_pipeline_v_2.5/bb_ext_tools                                && \
    popd

# FBP python environments
RUN mkdir -p /fbp/bb_pipeline_v_2.5/bb_python/bld                          && \
    pushd /fbp/bb_pipeline_v_2.5/bb_python/bld                             && \
    wget https://www.python.org/ftp/python/2.7.12/Python-2.7.12.tgz        && \
    wget https://www.python.org/ftp/python/3.7.11/Python-3.7.11.tgz        && \
    tar xf Python-3.7.11.tgz                                               && \
    tar xf Python-2.7.12.tgz                                               && \
    pushd Python-2.7.12                                                    && \
    ./configure --prefix=/fbp/bb_pipeline_v_2.5/bb_python/bb_python-2.7.12 && \
    make && make install                                                   && \
    popd                                                                   && \
    pushd Python-3.7.11                                                    && \
    ./configure --prefix=/fbp/bb_pipeline_v_2.5/bb_python/bb_python        && \
    make && make install                                                   && \
    popd                                                                   && \
    popd                                                                   && \
    rm -rf /fbp/bb_pipeline_v_2.5/bb_python/bld

# Dependencies for python environemnts
RUN ln -s /fbp/bb_pipeline_v_2.5/bb_python/bb_python/bin/python3.7 /fbp/bb_pipeline_v_2.5/bb_python/bb_python/bin/python                           && \
    /fbp/bb_pipeline_v_2.5/bb_python/bb_python/bin/pip3 install --upgrade pip setuptools wheel                                                     && \
    /fbp/bb_pipeline_v_2.5/bb_python/bb_python/bin/python3 -m venv /fbp/bb_pipeline_v_2.5/bb_python/bb_python_gradunwarp                           && \
    /fbp/bb_pipeline_v_2.5/bb_python/bb_python/bin/python3 -m venv /fbp/bb_pipeline_v_2.5/bb_python/bb_python_asl_ukbb                             && \
    /fbp/bb_pipeline_v_2.5/bb_python/bb_python/bin/python3 -m venv /fbp/bb_pipeline_v_2.5/bb_python/bb_python_plots                                && \
    /fbp/bb_pipeline_v_2.5/bb_python/bb_python/bin/pip3           install -r /fbp/bb_pipeline_v_2.5/bb_python/python_installation/req.txt          && \
    /fbp/bb_pipeline_v_2.5/bb_python/bb_python_gradunwarp/bin/pip install -r /fbp/bb_pipeline_v_2.5/bb_python/python_installation/req_grad.txt     && \
    /fbp/bb_pipeline_v_2.5/bb_python/bb_python_asl_ukbb/bin/pip   install -r /fbp/bb_pipeline_v_2.5/bb_python/python_installation/req_asl_ukbb.txt && \
    /fbp/bb_pipeline_v_2.5/bb_python/bb_python_plots/bin/pip      install -r /fbp/bb_pipeline_v_2.5/bb_python/python_installation/req_plots.txt


# dcm2niix
RUN pushd /fbp/bb_pipeline_v_2.5/bb_ext_tools                                                   && \
    wget https://github.com/rordenlab/dcm2niix/releases/download/v1.0.20210317/dcm2niix_lnx.zip && \
    unzip dcm2niix_lnx.zip                                                                      && \
    rm dcm2niix_lnx.zip                                                                         && \
    popd

# ROBEX
RUN pushd /fbp/bb_pipeline_v_2.5/bb_ext_tools                                                                                                                 && \
    wget --no-check-certificate -O ROBEXv12.linux64.tar.gz https://www.nitrc.org/frs/download.php/5994/ROBEXv12.linux64.tar.gz//\?i_agree\=1\&download_now\=1 && \
    tar xf ROBEXv12.linux64.tar.gz                                                                                                                            && \
    rm ROBEXv12.linux64.tar.gz                                                                                                                                && \
    popd

# BrainSuite15c
RUN pushd /fbp/bb_pipeline_v_2.5/bb_ext_tools                  && \
    wget -q http://brainsuite.org/data/BIDS/bse15c.biobank.tgz && \
    tar -xf bse15c.biobank.tgz                                 && \
    chmod -R ugo+rx BrainSuite15c                              && \
    rm bse15c.biobank.tgz                                      && \
    popd

# Workbench
RUN pushd /fbp/bb_pipeline_v_2.5/bb_ext_tools                                               && \
    mkdir wb-bld                                                                            && \
    pushd wb-bld                                                                            && \
    wget https://github.com/Washington-University/workbench/archive/refs/tags/v1.2.3.tar.gz && \
    tar xf v1.2.3.tar.gz                                                                    && \
    mkdir  workbench-1.2.3/build                                                            && \
    pushd workbench-1.2.3/build                                                             && \
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=./bld  ../src                   && \
    make                                                                                    && \
    make install                                                                            && \
    mkdir -p /fbp/bb_pipeline_v_2.5/bb_ext_tools/workbench/bin_linux64/                     && \
    cp bld/bin/* /fbp/bb_pipeline_v_2.5/bb_ext_tools/workbench/bin_linux64/                 && \
    popd                                                                                    && \
    popd                                                                                    && \
    rm -rf wb-bld

# freesurfer6
RUN pushd /fbp/bb_pipeline_v_2.5/bb_ext_tools                                                                                                         && \
    wget --no-check-certificate https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/6.0.0/freesurfer-Linux-centos6_x86_64-stable-pub-v6.0.0.tar.gz && \
    tar xf freesurfer-Linux-centos6_x86_64-stable-pub-v6.0.0.tar.gz                                                                                   && \
    mv freesurfer freesurfer4                                                                                                                         && \
    chown -R root:root freesurfer4                                                                                                                    && \
    rm freesurfer-Linux-centos6_x86_64-stable-pub-v6.0.0.tar.gz                                                                                       && \
    popd

# freesurfer7 - dev version
# https://github.com/freesurfer/freesurfer/tree/4a77265f77909e6b0c8e48e5548742c19bb579cc
# https://surfer.nmr.mgh.harvard.edu/fswiki/BuildGuide
# https://surfer.nmr.mgh.harvard.edu/fswiki/BuildRequirements
RUN pushd /fbp/bb_pipeline_v_2.5/bb_ext_tools                                                                             && \
    mkdir -p freesurfer3/bld                                                                                              && \
    pushd freesurfer3/bld                                                                                                 && \
    wget --no-check-certificate https://surfer.nmr.mgh.harvard.edu/pub/data/fspackages/prebuilt/centos7-packages.tar.gz   && \
    tar -xzvf centos7-packages.tar.gz                                                                                     && \
    rm -f centos7-packages.tar.gz                                                                                         && \
    git clone https://github.com/freesurfer/freesurfer.git                                                                && \
    pushd freesurfer                                                                                                      && \
    git checkout 4a77265f77909e6b0c8e48e5548742c19bb579cc                                                                 && \
    git config user.name fbp                                                                                              && \
    git config user.email fbp@fmrib.ox.ac.uk                                                                              && \
    git remote add datasrc https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/repo/annex.git                          && \
    git fetch datasrc                                                                                                     && \
    echo "git-annex POINT"                                                                                                && \
    git-annex get .                                                                                                       && \
    cmake . -DFS_PACKAGES_DIR="$(pwd)/../packages" -DCMAKE_INSTALL_PREFIX=/fbp/bb_pipeline_v_2.5/bb_ext_tools/freesurfer3 && \
    make                                                                                                                  && \
    make install                                                                                                          && \
    popd                                                                                                                  && \
    popd                                                                                                                  && \
    rm -rf /fbp/bb_pipeline_v_2.5/bb_ext_tools/freesurfer3/bld                                                            && \
    pushd /fbp/bb_pipeline_v_2.5/bb_ext_tools/freesurfer3/                                                                && \
    chown -R root:root .                                                                                                  && \
    ln -s /mcr/v84 MCRv84                                                                                                 && \
    popd


# R dependencies
RUN Rscript /tmp/install.r


# gradunwarp
RUN pushd /fbp/bb_pipeline_v_2.5/bb_python/python_installation                         && \
    tar -zxvf gradunwarp_FMRIB.tar.gz                                                  && \
    pushd gradunwarp_FMRIB                                                             && \
    /fbp/bb_pipeline_v_2.5/bb_python/bb_python/bin/python3 setup.py install            && \
    /fbp/bb_pipeline_v_2.5/bb_python/bb_python_asl_ukbb/bin/python3 setup.py install   && \
    /fbp/bb_pipeline_v_2.5/bb_python/bb_python_gradunwarp/bin/python3 setup.py install && \
    popd                                                                               && \
    rm -rf gradunwarp_FMRIB                                                            && \
    popd

# FSL
RUN pushd /fbp                && \
    tar xf /tmp/bb_FSL.tar.gz && \
    popd

# Other FBP bits
RUN pushd /fbp && \
    tar xf /tmp/DATA_public.tar.gz  && \
    tar xf /tmp/DATA_private.tar.gz && \
    popd

# Clean up
RUN rm -rf /tmp/*           && \
    rm -rf $HOME/.cache/pip && \
    yum clean all           && \
    rm -rf /var/cache/yum/*
