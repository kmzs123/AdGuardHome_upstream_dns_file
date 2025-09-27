#!/bin/bash

target_file=/root/Docker-compose/AdGuardHome/conf

cat > "$repo_dir"/private << 'EOF'
domain:mir3g70
domain:rm2100dd
EOF
awk 1 "$geosite_dir"/private | awk '!seen[$0]++' >> "$repo_dir"/private

cat > "$repo_dir"/direct1 << 'EOF'
domain:360.cn
domain:alidns.com
domain:doh.pub
domain:dot.pub
domain:onedns.net
EOF
awk 1 "$geosite_dir"/apple-cn \
      "$geosite_dir"/google-cn | \
awk '!seen[$0]++' >> "$repo_dir"/direct1

cat > "$repo_dir"/proxy << 'EOF'
domain:1.ip.skk.moe
EOF
awk 1 "$geosite_dir"/gfw \
      "$geosite_dir"/google \
      "$geosite_dir"/greatfire | \
awk '!seen[$0]++' >> "$repo_dir"/proxy

cat > "$repo_dir"/direct2 << 'EOF'
domain:2.ip.skk.moe
domain:cytus.tk
domain:deepseek.com
domain:kmzs123.cf
domain:kmzs123.cn
domain:kmzs123.tk
domain:kmzs123.top
domain:ping0.cc
domain:vmshell.com
EOF
grep -i -h "@cn" "$geosite_dir"/category-games > "$geosite_dir"/category-games@cn
grep -i -h "@cn" "$geosite_dir"/* > "$geosite_dir"/@cn
awk 1 "$geosite_dir"/category-games@cn \
      "$geosite_dir"/china-list \
      "$geosite_dir"/cn \
      "$geosite_dir"/tld-cn \
      "$geosite_dir"/win-update \
      "$geosite_dir"/@cn \
      "$geosite_dir"/*-cn | \
awk '!seen[$0]++' >> "$repo_dir"/direct2

convert_files "$repo_dir"/private "$repo_dir"/private.txt 192.168.15.1 fd21:bda8:56ba::1
convert_files "$repo_dir"/direct1 "$repo_dir"/direct1.txt https://dns.alidns.com/dns-query https://doh.pub/dns-query https://doh.360.cn https://doh-pure.onedns.net/dns-query
convert_files "$repo_dir"/proxy "$repo_dir"/proxy.txt tcp://192.168.15.20:11114 tcp://192.168.15.20:10014 'tcp://[fd21:bda8:56ba:0:222:4dff:fea7:674d]:11116' 'tcp://[fd21:bda8:56ba:0:222:4dff:fea7:674d]:10016'
convert_files "$repo_dir"/direct2 "$repo_dir"/direct2.txt https://dns.alidns.com/dns-query https://doh.pub/dns-query https://doh.360.cn https://doh-pure.onedns.net/dns-query

# "合并"
awk 1 "$repo_dir"/private.txt "$repo_dir"/direct1.txt "$repo_dir"/proxy.txt "$repo_dir"/direct2.txt > "$repo_dir"/ADG.txt

# 添加上游DNS服务器配置
cat >> "$repo_dir"/ADG.txt << 'EOF'
tcp://192.168.15.20:11114
tcp://192.168.15.20:10014
tcp://[fd21:bda8:56ba:0:222:4dff:fea7:674d]:11116
tcp://[fd21:bda8:56ba:0:222:4dff:fea7:674d]:10016
EOF
