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
# ??????????????????
upstream vmess-splitflow {
         server 127.0.0.1:${VMESS_PORT} max_fails=0 fail_timeout=0;
}
upstream trojan-splitflow {
         server 127.0.0.1:${TROJAN_PORT} max_fails=0 fail_timeout=0;
}

# ??????
map \$request_uri \$backend_name {
    ${VMESS_WSPATH} vmess-splitflow;
    ${TROJAN_WSPATH} trojan-splitflow;

}

# ??????
server {

    # ??????????????????
    listen 80;
    listen [::]:80;
    # ??????
    server_name _;
    # ????????????
    charset utf-8;
    # SSL?????? 
    #if (\$ssl_protocol = "") {
    #    return 301 https://\$host\$request_uri;
    #}
    # ??????SSL
    include /ssl/xiaonuo.live/xiaonuo.live.conf;
    # ?????????
    root /www;
    # ??????????????????
    index index.html index.htm default.htm default.html forum.php default.php index.php;
    # ??????????????????
    # ?????????????????????????????????
    # limit_conn perserver 200;
    # ????????????IP?????????????????????
    # limit_conn perip 20;
    # ?????????????????????????????????????????????KB???
    # limit_rate 512k;
    # ??????????????????
    # include cache.conf;
    # ??????php??????
    # include php.conf;
    # ??????rewrite
    # include /rewrite/default.conf;
    # ??????
    access_log logs/default.log combined;
    error_log logs/default.log error;
    # ??????
    location ^~ ${VMESS_WSPATH} {
             # ??????websocket
             include websocket.conf;
             # ????????????
             proxy_pass http://\$backend_name;
             # ??????
             access_log logs/xiaonuo.log combined;
             error_log logs/xiaonuo.log error;
    }
    location ^~ ${TROJAN_WSPATH} {
             # ??????websocket
             include websocket.conf;
             # ????????????
             proxy_pass http://\$backend_name;
             # ??????
             access_log logs/xiaonuo.log combined;
             error_log logs/xiaonuo.log error;
    }
    # ?????????????????????nginx?????????
    location ~ .*.(htm|html|gif|jpg|jpeg|png|bmp|swf|ioc|rar|zip|txt|flv|mid|doc|ppt|pdf|xls|mp3|wma|gz|svg|mp4|ogg|ogv|webm|htc|xml|woff)\$
    # ????????????????????????
    {
       expires 1m;
    }
    # JS???CSS??????????????????
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

# ??????supervisord
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
