# Based on r-spatial Dockerfile https://github.com/r-spatial/sf/blob/main/inst/docker/parquet/Dockerfile
# Ensures GDAL is built with parquet support

FROM ubuntu:22.04
# minimal docker file to get sp and sf running on ubunty 16.04 image,
# using gdal/geos/proj from ppa:ubuntugis/ubuntugis-unstable

MAINTAINER "edzerpebesma" edzer.pebesma@uni-muenster.de

RUN apt-get update && apt-get install -y software-properties-common dirmngr
RUN add-apt-repository ppa:ubuntugis/ubuntugis-unstable

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9

# add the R 4.0 repo from CRAN -- adjust 'focal' to 'groovy' or 'bionic' as needed
RUN add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"

RUN apt-key  adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9

RUN apt-get update
RUN apt-get upgrade -y

RUN export DEBIAN_FRONTEND=noninteractive; apt-get -y update \
  && apt-get install -y \
	devscripts \
	gdb \
	git \
	libcairo2-dev \
	libcurl4-openssl-dev \
	libexpat1-dev \
	libpq-dev \
	libsqlite3-dev \
	libudunits2-dev \
	make \
	pandoc \
	qpdf \
	r-base-dev \
  	sqlite3 \
	subversion \
	valgrind \
	vim \
	tk-dev \
	wget

#libv8-3.14-dev \
RUN apt-get update && apt-get install -y --fix-missing \
	libjq-dev \
	libprotobuf-dev \
	libxml2-dev \
	libprotobuf-dev \
	protobuf-compiler \
	unixodbc-dev \
	libssh2-1-dev \
	libgit2-dev \
	libnetcdf-dev \
	locales \
	libssl-dev \
	libtiff-dev \
	cmake \
	libtiff5-dev \
	libopenjp2-7-dev \
	libuv1-dev \
  && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8

#ENV PROJ_VERSION=7.1.0
ENV LD_LIBRARY_PATH=/usr/local/lib

# GEOS:
ENV GEOS_VERSION 3.14.0

RUN wget -q http://download.osgeo.org/geos/geos-${GEOS_VERSION}.tar.bz2 \
  && bzip2 -d geos-*bz2 \
  && tar xf geos*tar \
  && cd geos* \
  && mkdir build \
  && cd build \
  && cmake .. \
  && make \
  && make install \
  && cd ../.. \
  && ldconfig

#RUN git clone --depth 1 https://github.com/OSGeo/PROJ.git
# https://download.osgeo.org/proj/proj-9.0.0RC1.tar.gz
ENV PROJ_VERSION 9.7.1
RUN wget -q http://download.osgeo.org/proj/proj-${PROJ_VERSION}.tar.gz
RUN tar zxvf proj-${PROJ_VERSION}.tar.gz
RUN cd proj* \
  && ls -l \
  && mkdir build \
  && cd build \
  && cmake .. \
  && make \
  && make install \
  && cd ../.. \
  && ldconfig

# install proj-data:
#RUN cd /usr/local/share/proj \
#  && wget http://download.osgeo.org/proj/proj-data-1.1RC1.zip \
#  && unzip -o proj-data*zip \
#  && rm proj-data*zip \
#  && cd -

# FROM https://arrow.apache.org/install/ ; probably only a subset is needed:
RUN apt update
RUN apt install -y -V ca-certificates lsb-release wget
RUN wget https://apache.jfrog.io/artifactory/arrow/$(lsb_release --id --short | tr 'A-Z' 'a-z')/apache-arrow-apt-source-latest-$(lsb_release --codename --short).deb
RUN apt install -y -V ./apache-arrow-apt-source-latest-$(lsb_release --codename --short).deb
RUN apt update
RUN apt install -y -V libarrow-dev # For C++
RUN apt install -y -V libarrow-glib-dev # For GLib (C)
RUN apt install -y -V libarrow-dataset-dev # For Apache Arrow Dataset C++
RUN apt install -y -V libarrow-dataset-glib-dev # For Apache Arrow Dataset GLib (C)
RUN apt install -y -V libparquet-dev # For Apache Parquet C++
RUN apt install -y -V libparquet-glib-dev # For Apache Parquet GLib (C)

# GDAL:
ENV GDAL_VERSION 3.12.2
ENV GDAL_VERSION_NAME 3.12.2

# Change cmake default compiler to C++20 in line 128 for Arrow apt packages
RUN wget -q http://download.osgeo.org/gdal/${GDAL_VERSION}/gdal-${GDAL_VERSION_NAME}.tar.gz \
  && tar -xf gdal-${GDAL_VERSION_NAME}.tar.gz \
  && cd gdal* \
  && mkdir build \
  && cd ./build \
  && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_STANDARD=20 .. \
  && make \
  && make install \
  && ldconfig

RUN gdalinfo --formats

RUN Rscript -e 'install.packages(c("sf"))'
RUN Rscript -e 'sf::st_drivers("vector", "Arrow")'
RUN Rscript -e 'sf::st_drivers("vector", "Parquet")'

# Additions to r-spatial Dockerfile below

# Install tippeecanoe for creating vector tiles
# libglpk40 is a requirement for igraph, targets dependency
RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y --no-install-recommends \
    build-essential \
    libsqlite3-dev \
    zlib1g-dev \
    libglpk40 \
    curl \
    gnupg \
  && git clone https://github.com/felt/tippecanoe.git /tmp/tippecanoe \
  && cd /tmp/tippecanoe \
  && make -j \
  && make install \
  && rm -rf /tmp/tippecanoe \
  && rm -rf /var/lib/apt/lists/*
  
# Install Github CLI for pipeline.yml to fetch Release Data
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update \
  && apt-get install -y gh
  
# Rust is required for freestiler and socratadata
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --default-toolchain stable --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"
  
# Install R packages not included above
# A previous version of this file didn't include the stop(...) logic
# tarchetypes failed to install silently
RUN Rscript -e 'pkgs <- c("targets","tarchetypes","socratadata","terra","httr","dplyr","tibble","units","arrow","freestiler", "qs2", "spatstat"); \
  install.packages(pkgs); \
  missing <- setdiff(pkgs, installed.packages()[,"Package"]); \
  if (length(missing) > 0) stop("Failed to install: ", paste(missing, collapse=", "))'

WORKDIR /d26-gi-web-map