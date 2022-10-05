##########################################
#         构建基础镜像                    #
##########################################
#
# 构建镜像版本
ARG BUILD_NGINX_IMAGE=danxiaonuo/nginx:latest
ARG BUILD_SINGBOX_IMAGE=danxiaonuo/sing-box:latest

# 指定创建的基础镜像
FROM ${BUILD_NGINX_IMAGE} as nginx
FROM ${BUILD_SINGBOX_IMAGE} as singbox

# 指定创建的基础镜像
FROM alpine:latest

# 作者描述信息
MAINTAINER danxiaonuo
# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ
# 语言设置
ARG LANG=C.UTF-8
ENV LANG=$LANG

# NGINX工作目录
ARG NGINX_DIR=/data/nginx
ENV NGINX_DIR=$NGINX_DIR
# NGINX环境变量
ARG PATH=/data/nginx/sbin:$PATH
ENV PATH=$PATH

# luajit2
# https://github.com/openresty/luajit2
ARG LUAJIT_VERSION=2.1-20220411
ENV LUAJIT_VERSION=$LUAJIT_VERSION
ARG LUAJIT_LIB=/usr/local/lib
ENV LUAJIT_LIB=$LUAJIT_LIB
ARG LUAJIT_INC=/usr/local/include/luajit-2.1
ENV LUAJIT_INC=$LUAJIT_INC
ARG LD_LIBRARY_PATH=/usr/local/lib/:$LD_LIBRARY_PATH
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH

# lua-resty-core
# https://github.com/openresty/lua-resty-core
ARG LUA_RESTY_CORE_VERSION=0.1.23
ENV LUA_RESTY_CORE_VERSION=$LUA_RESTY_CORE_VERSION
ARG LUA_LIB_DIR=/usr/local/share/lua/5.1
ENV LUA_LIB_DIR=$LUA_LIB_DIR

ARG NGINX_BUILD_DEPS="\
    # NGINX
    alpine-sdk \
    bash \
    findutils \
    gcc \
    gd-dev \
    geoip-dev \
    libc-dev \
    libedit-dev \
    libxslt-dev \
    linux-headers \
    make \
    mercurial \
    openssl-dev \
    pcre-dev \
    perl-dev \
    zlib-dev"
ENV NGINX_BUILD_DEPS=$NGINX_BUILD_DEPS

ARG SINGBOX_BUILD_DEPS="\
      # SINGBOX
      zsh \
      bash \
      linux-headers \
      build-base \
      zlib-dev \
      openssl \
      openssl-dev \
      tor \
      libevent-dev \
      bind-tools \
      iproute2 \
      ipset \
      git \
      vim \
      tzdata \
      curl \
      wget \
      lsof \
      zip \
      unzip \
      supervisor \
      ca-certificates"
ENV SINGBOX_BUILD_DEPS=$SINGBOX_BUILD_DEPS
