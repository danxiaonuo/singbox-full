#!/bin/bash

ulimit -SHc unlimited
ulimit -SHu unlimited
ulimit -SHs unlimited
ulimit -SHl unlimited
ulimit -SHi unlimited
ulimit -SHq unlimited
ulimit -SHn 655360

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
            "listen_port":${PORT},
            "tcp_fast_open":true,
            "udp_fragment":true,
            "sniff":true,
            "sniff_override_destination":true,
            "proxy_protocol":false,
            "proxy_protocol_accept_no_header":false,
            "users":[
                {
                    "name":"${NAME}",
                    "uuid":"${UUID}",
                    "alterId":${ALTER_ID}
                }
            ],
            "transport":{
                "type":"ws",
                "path":"${WSPATH}",
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
            "listen_port":${PORT},
            "tcp_fast_open":true,
            "udp_fragment":true,
            "sniff":true,
            "sniff_override_destination":true,
            "udp_timeout":300,
            "proxy_protocol":false,
            "proxy_protocol_accept_no_header":false,
            "users":[
                {
                    "name":"${NAME}",
                    "password":"${pwd}"
                }
            ],
            "transport":{
                "type":"ws",
                "path":"${WSPATH}",
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

# 运行supervisord
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
