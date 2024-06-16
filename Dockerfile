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
FROM ubuntu:jammy

# 作者描述信息
MAINTAINER danxiaonuo
# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ
# 语言设置
ARG LANG=zh_CN.UTF-8
ENV LANG=$LANG

# 环境设置
ARG DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND=$DEBIAN_FRONTEND

# NGINX工作目录
ARG NGINX_DIR=/data/nginx
ENV NGINX_DIR=$NGINX_DIR
# NGINX环境变量
ARG PATH=/data/nginx/sbin:$PATH
ENV PATH=$PATH

# luajit2
# https://github.com/openresty/luajit2
ARG LUAJIT_VERSION=2.1-20240314
ENV LUAJIT_VERSION=$LUAJIT_VERSION
ARG LUAJIT_LIB=/usr/local/lib
ENV LUAJIT_LIB=$LUAJIT_LIB
ARG LUAJIT_INC=/usr/local/include/luajit-2.1
ENV LUAJIT_INC=$LUAJIT_INC
ARG LD_LIBRARY_PATH=/usr/local/lib/:$LD_LIBRARY_PATH
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH

# lua-resty-core
# https://github.com/openresty/lua-resty-core
ARG LUA_RESTY_CORE_VERSION=0.1.28
ENV LUA_RESTY_CORE_VERSION=$LUA_RESTY_CORE_VERSION
ARG LUA_LIB_DIR=/usr/local/share/lua/5.1
ENV LUA_LIB_DIR=$LUA_LIB_DIR

ARG NGINX_BUILD_DEPS="\
    libssl-dev \
    zlib1g-dev \
    libpcre3-dev \
    libxml2-dev \
    libxslt1-dev \
    libgd-dev \
    libgeoip-dev"
ENV NGINX_BUILD_DEPS=$NGINX_BUILD_DEPS

# 安装依赖包
ARG PKG_DEPS="\
    zsh \
    bash \
    bash-doc \
    bash-completion \
    dnsutils \
    iproute2 \
    net-tools \
    sysstat \
    ncat \
    git \
    vim \
    jq \
    lrzsz \
    tzdata \
    curl \
    wget \
    axel \
    lsof \
    zip \
    unzip \
    tar \
    rsync \
    iputils-ping \
    telnet \
    procps \
    libaio1 \
    numactl \
    xz-utils \
    gnupg2 \
    psmisc \
    libmecab2 \
    debsums \
    locales \
    iptables \
    python3 \
    python3-dev \
    python3-pip \
    language-pack-zh-hans \
    fonts-droid-fallback \
    fonts-wqy-zenhei \
    fonts-wqy-microhei \
    fonts-arphic-ukai \
    fonts-arphic-uming \
    ca-certificates"
ENV PKG_DEPS=$PKG_DEPS

# ***** 安装依赖 *****
RUN --mount=type=cache,target=/var/lib/apt/,sharing=locked \
   set -eux && \
   # 更新源地址
   sed -i s@http://*.*ubuntu.com@https://mirrors.aliyun.com@g /etc/apt/sources.list && \
   sed -i 's?# deb-src?deb-src?g' /etc/apt/sources.list && \
   # 解决证书认证失败问题
   touch /etc/apt/apt.conf.d/99verify-peer.conf && echo >>/etc/apt/apt.conf.d/99verify-peer.conf "Acquire { https::Verify-Peer false }" && \
   # 更新系统软件
   DEBIAN_FRONTEND=noninteractive apt-get update -qqy && apt-get upgrade -qqy && \
   # 安装依赖包
   DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends $PKG_DEPS $NGINX_BUILD_DEPS --option=Dpkg::Options::=--force-confdef && \
   DEBIAN_FRONTEND=noninteractive apt-get -qqy --no-install-recommends autoremove --purge && \
   DEBIAN_FRONTEND=noninteractive apt-get -qqy --no-install-recommends autoclean && \
   rm -rf /var/lib/apt/lists/* && \
   # 更新时区
   ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
   # 更新时间
   echo ${TZ} > /etc/timezone && \
   # 更改为zsh
   sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true && \
   sed -i -e "s/bin\/ash/bin\/zsh/" /etc/passwd && \
   sed -i -e 's/mouse=/mouse-=/g' /usr/share/vim/vim*/defaults.vim && \
   locale-gen zh_CN.UTF-8 && localedef -f UTF-8 -i zh_CN zh_CN.UTF-8 && locale-gen && \
   mkdir -p /etc/sing-box /ssl /www && \
   /bin/zsh

   
# 拷贝二进制文件
COPY --from=nginx /usr/local/lib /usr/local/lib
COPY --from=nginx /usr/local/share/lua /usr/local/share/lua
COPY --from=nginx /data/nginx /data/nginx
COPY --from=singbox /usr/bin/sing-box /usr/bin/sing-box

# 拷贝文件
COPY ["./docker-entrypoint.sh", "/usr/bin/"]
COPY ["./conf/nginx/ssl", "/ssl"]
COPY ["./conf/nginx/www", "/www"]
COPY ["./conf/nginx/vhost/default.conf", "/data/nginx/conf/vhost/default.conf"]
COPY ["./conf/sing-box", "/etc/sing-box"]
COPY ["./conf/supervisor", "/etc/supervisor"]

    
# 将请求和错误日志转发到docker日志收集器
RUN set -eux && \
    ln -sf /dev/stdout /data/nginx/logs/access.log && \
    ln -sf /dev/stderr /data/nginx/logs/error.log && \
# 创建用户和用户组
addgroup --system --quiet nginx && \
adduser --quiet --system --disabled-login --ingroup nginx --home /data/nginx --no-create-home nginx && \
# smoke test
# ##############################################################################
    ln -sf ${NGINX_DIR}/sbin/* /usr/sbin/ && \
    nginx -V && \
    nginx -t

# ***** 入口 *****
ENTRYPOINT ["docker-entrypoint.sh"]

# 自动检测服务是否可用
HEALTHCHECK --interval=30s --timeout=3s CMD curl --fail http://localhost/ || exit 1
