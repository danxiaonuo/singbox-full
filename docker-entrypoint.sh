#!/bin/bash

# ulimit -SHc unlimited
# ulimit -SHu unlimited
# ulimit -SHs unlimited
# ulimit -SHl unlimited
# ulimit -SHi unlimited
# ulimit -SHq unlimited
# ulimit -SHn 655360

cat <<-EOF > /etc/sing-box/vmess.json
{
    "log":{
        "level":"info"
    },
    "inbounds":[
        {
            "type":"vmess",
            "tag":"vmess-in",
            "listen":"::",
            "listen_port":${VMESS_PORT},
            "tcp_fast_open":true,
            "udp_fragment":true,
            "sniff":true,
            "sniff_override_destination":true,
            "proxy_protocol":false,
            "proxy_protocol_accept_no_header":false,
            "users":[
                {
                    "name":"${VMESS_NAME}",
                    "uuid":"${VMESS_UUID}",
                    "alterId":${VMESS_ALTER_ID}
                }
            ],
            "transport":{
                "type":"ws",
                "path":"${VMESS_WSPATH}",
                "max_early_data":0,
                "early_data_header_name":"Sec-WebSocket-Protocol"
            }
        }
    ],
    "outbounds":[
        {
            "type":"direct",
            "tag":"direct"
        }
    ]
}
EOF

cat <<-EOF > /etc/sing-box/trojan.json
{
    "log":{
        "level":"info"
    },
    "inbounds":[
        {
            "type":"trojan",
            "tag":"trojan-in",
            "listen":"::",
            "listen_port":${TROJAN_PORT},
            "tcp_fast_open":true,
            "udp_fragment":true,
            "sniff":true,
            "sniff_override_destination":true,
            "udp_timeout":300,
            "proxy_protocol":false,
            "proxy_protocol_accept_no_header":false,
            "users":[
                {
                    "name":"${TROJAN_NAME}",
                    "password":"${TROJAN_PWD}"
                }
            ],
            "transport":{
                "type":"ws",
                "path":"${TROJAN_WSPATH}",
                "max_early_data":0,
                "early_data_header_name":"Sec-WebSocket-Protocol"
            }
        }
    ],
    "outbounds":[
        {
            "type":"direct",
            "tag":"direct"
        }
    ]
}
EOF

cat <<-EOF > /data/nginx/conf/vhost/default.conf
# 上游后端服务
upstream vmess-splitflow {
         server 127.0.0.1:${VMESS_PORT} max_fails=0 fail_timeout=0;
}
upstream trojan-splitflow {
         server 127.0.0.1:${TROJAN_PORT} max_fails=0 fail_timeout=0;
}

# 分流
map \$request_uri \$backend_name {
    ${VMESS_WSPATH} vmess-splitflow;
    ${TROJAN_WSPATH} trojan-splitflow;

}

# 服务
server {

    # 指定监听端口
    listen 80;
    listen [::]:80;
    # 域名
    server_name _;
    # 指定编码
    charset utf-8;
    # SSL跳转 
    #if (\$ssl_protocol = "") {
    #    return 301 https://\$host\$request_uri;
    #}
    # 开启SSL
    # include /ssl/xiaonuo.live/xiaonuo.live.conf;
    # 启用流量控制
    # 限制当前站点最大并发数
    # limit_conn perserver 200;
    # 限制单个IP访问最大并发数
    # limit_conn perip 20;
    # 限制每个请求的流量上限（单位：KB）
    # limit_rate 512k;
    # 关联缓存配置
    # include cache.conf;
    # 关联php配置
    # include php.conf;
    # 开启rewrite
    # include /rewrite/default.conf;
    # 根目录
    root /www;
    # 站点索引设置
    index forum.php index.html index.htm default.php default.htm default.html index.php;
    # 日志
    access_log logs/default.log combined;
    error_log logs/default.log error;
    # 路由
    location ^~ ${VMESS_WSPATH} {
             # 开启websocket
             include websocket.conf;
             # 反向代理
             proxy_pass http://\$backend_name;
             # 日志
             access_log logs/xiaonuo.log combined;
             error_log logs/xiaonuo.log error;
    }
    location ^~ ${TROJAN_WSPATH} {
             # 开启websocket
             include websocket.conf;
             # 反向代理
             proxy_pass http://\$backend_name;
             # 日志
             access_log logs/xiaonuo.log combined;
             error_log logs/xiaonuo.log error;
    }
    # 所有静态文件由nginx直接读
    location ~ .*.(htm|html|gif|jpg|jpeg|png|bmp|swf|ioc|rar|zip|txt|flv|mid|doc|ppt|pdf|xls|mp3|wma|gz|svg|mp4|ogg|ogv|webm|htc|xml|woff)\$
    # 图片缓存时间设置
    {
       expires 1m;
    }
    # JS和CSS缓存时间设置
    location ~ .*.(js|css)?\$
    {
       expires 1m;
    }
		
    location ~ /\.
    {
       deny all;
    }
}
EOF

# 运行supervisord
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
