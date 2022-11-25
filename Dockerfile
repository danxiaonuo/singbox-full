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
FROM golang:alpine

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
      bash-doc \
      bash-completion \
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

# ***** 安装依赖 *****
RUN set -eux && \
   # 修改源地址
   sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && \
   # 更新源地址并更新系统软件
   apk update && apk upgrade && \
   # 安装依赖包
   apk add --no-cache --clean-protected $SINGBOX_BUILD_DEPS && \
   rm -rf /var/cache/apk/* && \
   # 更新时区
   ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
   # 更新时间
   echo ${TZ} > /etc/timezone && \
   # 更改为zsh
   sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true && \
   sed -i -e "s/bin\/ash/bin\/zsh/" /etc/passwd && \
   sed -i -e 's/mouse=/mouse-=/g' /usr/share/vim/vim*/defaults.vim && \
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

# 安装相关依赖
RUN set -eux && \
    apk add --no-cache --virtual .gettext gettext && \
    mv /usr/bin/envsubst /tmp/ && \
    runDeps="$( \
        scanelf --needed --nobanner ${NGINX_DIR}/sbin/nginx ${NGINX_DIR}/modules/*.so ${LUAJIT_LIB}/*.so /tmp/envsubst \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" && \
    apk add --no-cache --virtual .$NGINX_BUILD_DEPS $runDeps && \
    apk del .gettext && \
    mv /tmp/envsubst /usr/local/bin/
    
# ***** 检查依赖并授权 *****
RUN set -eux && \
    # 创建用户和用户组
    addgroup -g 32548 -S nginx && \
    adduser -S -D -H -u 32548 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx && \
    chmod a+x /usr/bin/docker-entrypoint.sh /usr/bin/sing-box && \
    chown --quiet -R nginx:nginx /www && chmod -R 775 /www && \
    ln -sf /dev/stdout /data/nginx/logs/access.log && \
    ln -sf /dev/stderr /data/nginx/logs/error.log && \
    # smoke test
    # ##############################################################################
    ln -sf ${NGINX_DIR}/sbin/* /usr/sbin/ && \
    nginx -V && \
    nginx -t && \
    rm -rf /var/cache/apk/*

# ***** 入口 *****
ENTRYPOINT ["docker-entrypoint.sh"]

# 自动检测服务是否可用
HEALTHCHECK --interval=30s --timeout=3s CMD curl --fail http://localhost/ || exit 1
