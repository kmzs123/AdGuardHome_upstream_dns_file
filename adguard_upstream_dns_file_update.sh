#!/bin/bash

LANGUAGE=zh_CN:zh
LANG=zh_CN.UTF-8
repo_dir=$(dirname "$(readlink -f "$0")")
https_proxy="http://127.0.0.1:10808"
geosite_dir="$repo_dir"/geosite
target_file=/root/Docker-compose/AdGuardHome/conf

# 优化后的文件转换函数
convert_files() {
    local geosite_file="$1"
    local adguard_home_file="$2"
    shift 2
    local custom_dns="$*"
    
    # 初始化计数器
    local skipped_regexp_lines=0 skipped_regex_lines=0
    local processed_full_lines=0 processed_domain_lines=0
    local removed_suffix_lines=0 skipped_illegal_lines=0 processed_lines=0
    
    # 使用单一awk处理流程提高效率
    awk '
    BEGIN {
        # 预先编译常用正则表达式
        regexp_prefix = "^regexp:"
        regex_prefix = "^regex:"
        full_prefix = "^full:"
        domain_prefix = "^domain:"
        suffix_pattern = "[[:space:]]+@[^[:space:]]+$"
    }
    
    $0 ~ regexp_prefix { skipped_regexp++; next }
    $0 ~ regex_prefix { skipped_regex++; next }
    
    {
        # 处理前缀
        if ($0 ~ full_prefix) {
            processed_full++
            sub(full_prefix, "")
        } else if ($0 ~ domain_prefix) {
            processed_domain++
            sub(domain_prefix, "")
        }
        
        # 处理后缀
        if ($0 ~ suffix_pattern) {
            removed_suffix++
            sub(suffix_pattern, "")
        }
        
        # 跳过空行
        if ($0 == "") next
        
        # 转换为小写并去除空白
        gsub(/^[[:space:]]+|[[:space:]]+$/, "")
        $0 = tolower($0)
        
        # 验证域名
        if (is_valid_domain($0)) {
            printf "[/%s/]%s\n", $0, custom_dns
            processed++
        } else {
            skipped_illegal++
        }
    }
    
    function is_valid_domain(domain) {
        if (length(domain) > 253) return 0
        if (domain ~ /[^a-z0-9.-]/) return 0
        
        split(domain, labels, ".")
        for (i in labels) {
            label = labels[i]
            if (length(label) > 63) return 0
            if (label ~ /^-|-$/) return 0  # 不能以连字符开头或结尾
            if (label !~ /^[a-z0-9]([a-z0-9-]*[a-z0-9])?$/) return 0
        }
        
        return 1
    }
    
    END {
        print "处理完成统计:" > "/dev/stderr"
        print "- 跳过了 " skipped_regexp " 行 '\''regexp:'\'' 开头的行" > "/dev/stderr"
        print "- 跳过了 " skipped_regex " 行 '\''regex:'\'' 开头的行" > "/dev/stderr"
        print "- 处理了 " processed_full " 行 '\''full:'\'' 开头的行" > "/dev/stderr"
        print "- 处理了 " processed_domain " 行 '\''domain:'\'' 开头的行" > "/dev/stderr"
        print "- 处理了 " removed_suffix " 行 '\''空格@字符串'\'' 结尾的行" > "/dev/stderr"
        print "- 跳过了 " skipped_illegal " 行非法的行" > "/dev/stderr"
        print "- 最终生成了 " processed " 行有效规则" > "/dev/stderr"
        print "- DNS服务器列表：" custom_dns > "/dev/stderr"
    }
    ' custom_dns="$custom_dns" \
      skipped_regexp=0 skipped_regex=0 \
      processed_full=0 processed_domain=0 \
      removed_suffix=0 skipped_illegal=0 processed=0 \
      "$geosite_file" > "$adguard_home_file"
}

cd "$repo_dir" || exit 1

# https://ghfast.top/
# wget -N 参数表示文件未更新时跳过下载
if ! wget -N -e https_proxy="$https_proxy" https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat ; then
    echo "错误：下载规则文件失败！"
    rm -f "$repo_dir"/geosite.dat
    exit 1
fi

# 对于不同平台，需要修改对应下载路径
#https://github.com/MetaCubeX/geo/releases/download/v1.1/geo-linux-amd64
#https://github.com/MetaCubeX/geo/releases/download/v1.1/geo-linux-arm64
#https://github.com/MetaCubeX/geo/releases/download/v1.1/geo-linux-armv7
#https://github.com/MetaCubeX/geo/releases/download/v1.1/geo-macos-amd64
#https://github.com/MetaCubeX/geo/releases/download/v1.1/geo-macos-arm64
#https://github.com/MetaCubeX/geo/releases/download/v1.1/geo-windows-amd64.exe
#https://github.com/MetaCubeX/geo/releases/download/v1.1/geo-windows-arm64.exe
# wget -N 参数表示文件未更新时跳过下载
if ! wget -N -e https_proxy="$https_proxy" https://github.com/MetaCubeX/geo/releases/latest/download/geo-linux-amd64 ; then
    echo "错误：下载geo解包工具失败！"
    rm -f "$repo_dir"/geo-linux-amd64
    exit 1
fi
chmod +x "$repo_dir"/geo-linux-amd64

# 对于不同平台，需要修改对应文件名
rm -rf "$geosite_dir"
"$repo_dir"/geo-linux-amd64 unpack site "$repo_dir"/geosite.dat -d "$geosite_dir"

# 建议与 openwrt网页-->网络-->DHCP/DNS-->常规-->本地域名 相同
# 一行一个，不能带端口
cat > "$repo_dir"/private << 'EOF'
mir3g70
rm2100dd
EOF
# 内网自定义域，可选取消注释下一行启用geosite:private
#awk 1 "$geosite_dir"/private | awk '!seen[$0]++' >> "$repo_dir"/private

# 与proxy可能会冲突并希望由国内dns解析的域名，一行一个，不能带端口
cat > "$repo_dir"/direct1 << 'EOF'
360.cn
alidns.com
doh.pub
dot.pub
onedns.net
EOF
# geosite_dir里的文件没有结尾空行，需要使用awk 1来合并，不能使用cat
# 注意行尾的斜杠和竖线 \		| \
# 参考 v2ray/xray/singbox的路由配置，将geosite是修改配置改一下之后写到对应位置
awk 1 "$geosite_dir"/apple-cn \
      "$geosite_dir"/google-cn | \
awk '!seen[$0]++' >> "$repo_dir"/direct1 #去除重复

# 国外dns黑名单
# 一行一个，不能带端口
cat > "$repo_dir"/proxy << 'EOF'
1.ip.skk.moe
EOF
# geosite_dir里的文件没有结尾空行，需要使用awk 1来合并，不能使用cat
# 注意行尾的斜杠和竖线 \		| \
# 参考 v2ray/xray/singbox的路由配置，将geosite是修改配置改一下之后写到对应位置
awk 1 "$geosite_dir"/gfw \
      "$geosite_dir"/google \
      "$geosite_dir"/greatfire | \
awk '!seen[$0]++' >> "$repo_dir"/proxy #去除重复

# 国内dns白名单
# 一行一个，不能带端口
cat > "$repo_dir"/direct2 << 'EOF'
2.ip.skk.moe
cytus.tk
deepseek.com
kmzs123.cf
kmzs123.cn
kmzs123.tk
kmzs123.top
ping0.cc
vmshell.com
EOF
grep -i -h "@cn" "$geosite_dir"/category-games > "$geosite_dir"/category-games@cn
grep -i -h "@cn" "$geosite_dir"/* > "$geosite_dir"/@cn
# geosite_dir里的文件没有结尾空行，需要使用awk 1来合并，不能使用cat
# 注意行尾的斜杠和竖线 \		| \
# 参考 v2ray/xray/singbox的路由配置，将geosite是修改配置改一下之后写到对应位置
awk 1 "$geosite_dir"/category-games@cn \
      "$geosite_dir"/china-list \
      "$geosite_dir"/cn \
      "$geosite_dir"/tld-cn \
      "$geosite_dir"/win-update \
      "$geosite_dir"/@cn \
      "$geosite_dir"/*-cn | \
awk '!seen[$0]++' >> "$repo_dir"/direct2 #去除重复

# convert_files geosite格式文件 AdGuardHome格式文件 上游dns1 上游dns2 上游dns3 ...
convert_files "$repo_dir"/private "$repo_dir"/private.txt 192.168.15.1 fd21:bda8:56ba::1
convert_files "$repo_dir"/direct1 "$repo_dir"/direct1.txt https://dns.alidns.com/dns-query https://doh.pub/dns-query https://doh.360.cn/dns-query https://doh-pure.onedns.net/dns-query
convert_files "$repo_dir"/proxy "$repo_dir"/proxy.txt tcp://192.168.15.20:11114 tcp://192.168.15.20:10014 'tcp://[fd21:bda8:56ba:0:222:4dff:fea7:674d]:11116' 'tcp://[fd21:bda8:56ba:0:222:4dff:fea7:674d]:10016'
convert_files "$repo_dir"/direct2 "$repo_dir"/direct2.txt https://dns.alidns.com/dns-query https://doh.pub/dns-query https://doh.360.cn/dns-query https://doh-pure.onedns.net/dns-query

# "合并"
awk 1 "$repo_dir"/private.txt "$repo_dir"/direct1.txt "$repo_dir"/proxy.txt "$repo_dir"/direct2.txt > "$repo_dir"/ADG.txt

# 添加默认上游DNS服务器配置，没有在上述规则以外的其他域名，如：微软，OpenWrt官网等
cat >> "$repo_dir"/ADG.txt << 'EOF'
tcp://192.168.15.20:11114
tcp://192.168.15.20:10014
tcp://[fd21:bda8:56ba:0:222:4dff:fea7:674d]:11116
tcp://[fd21:bda8:56ba:0:222:4dff:fea7:674d]:10016
EOF

# "去重"
awk -F'[][]' '/^\[\/.*\/\]/ {if (!seen[$2]++) print; next} 1' "$repo_dir"/ADG.txt > "$repo_dir"/ADG_output.txt

awk 1 "$repo_dir"/ADG_output.txt > "$target_file"/ADG.txt

echo
echo "文件 $geosite_dir/private 有 $(awk 1 "$geosite_dir"/private | wc -l) 行"
echo "文件 $repo_dir/private.txt 有 $(awk 1 "$repo_dir"/private.txt | wc -l) 行"
echo
echo "文件 $geosite_dir/apple-cn 有 $(awk 1 "$geosite_dir"/apple-cn | wc -l) 行"
echo "文件 $geosite_dir/google-cn 有 $(awk 1 "$geosite_dir"/google-cn | wc -l) 行"
echo "文件 $repo_dir/direct1 有 $(awk 1 "$repo_dir"/direct1 | wc -l) 行"
echo "文件 $repo_dir/direct1.txt 有 $(awk 1 "$repo_dir"/direct1.txt | wc -l) 行"
echo
echo "文件 $geosite_dir/gfw 有 $(awk 1 "$geosite_dir"/gfw | wc -l) 行"
echo "文件 $geosite_dir/google 有 $(awk 1 "$geosite_dir"/google | wc -l) 行"
echo "文件 $geosite_dir/greatfire 有 $(awk 1 "$geosite_dir"/greatfire | wc -l) 行"
echo "文件 $repo_dir/proxy 有 $(awk 1 "$repo_dir"/proxy | wc -l) 行"
echo "文件 $repo_dir/proxy.txt 有 $(awk 1 "$repo_dir"/proxy.txt | wc -l) 行"
echo
echo "文件 $geosite_dir/category-games 有 $(awk 1 "$geosite_dir"/category-games | wc -l) 行"
echo "文件 $geosite_dir/category-games@cn 有 $(awk 1 "$geosite_dir"/category-games@cn | wc -l) 行"
echo "文件 $geosite_dir/china-list 有 $(awk 1 "$geosite_dir"/china-list | wc -l) 行"
echo "文件 $geosite_dir/cn 有 $(awk 1 "$geosite_dir"/cn | wc -l) 行"
echo "文件 $geosite_dir/tld-cn 有 $(awk 1 "$geosite_dir"/tld-cn | wc -l) 行"
echo "文件 $geosite_dir/win-update 有 $(awk 1 "$geosite_dir"/win-update | wc -l) 行"
echo "文件 $geosite_dir/@cn 有 $(awk 1 "$geosite_dir"/@cn | wc -l) 行"
echo "文件 $geosite_dir/*-cn 有 $(awk 1 "$geosite_dir"/*-cn | wc -l) 行"
echo "文件 $repo_dir/direct2 有 $(awk 1 "$repo_dir"/direct2 | wc -l) 行"
echo "文件 $repo_dir/direct2.txt 有 $(awk 1 "$repo_dir"/direct2.txt | wc -l) 行"
echo
echo "文件 $repo_dir/ADG.txt 有 $(awk 1 "$repo_dir"/ADG.txt | wc -l) 行"
echo "文件 $target_file/ADG.txt 有 $(awk 1 "$target_file"/ADG.txt | wc -l) 行"
echo

# 提交更改到仓库
#if [ -n "$(git -C $repo_dir status --porcelain)" ]; then
#    echo "检测到变更。正在提交..."
#    git -C "$repo_dir" add .
#    git -C "$repo_dir" commit -S -m "更新 $(date "+%Y-%m-%d %H:%M:%S")"
#    echo "提交完成。"
#    echo "注意输入推送密码..."
#    git -C "$repo_dir" push
#    echo "推送完成。"
#else
#    echo "没有变更。"
#fi

# 目标文件示例

#[/rm2100dd/]192.168.15.1 fd21:bda8:56ba::1
#[/360.cn/]https://dns.alidns.com/dns-query https://doh.pub/dns-query https://doh.360.cn/dns-query https://doh-pure.onedns.net/dns-query
#[/1.ip.skk.moe/]tcp://192.168.15.20:11114 tcp://192.168.15.20:10014 tcp://[fd21:bda8:56ba:0:222:4dff:fea7:674d]:11116 tcp://[fd21:bda8:56ba:0:222:4dff:fea7:674d]:10016
#[/2.ip.skk.moe/]https://dns.alidns.com/dns-query https://doh.pub/dns-query https://doh.360.cn/dns-query https://doh-pure.onedns.net/dns-query

#private.txt 约有150行
#direct1.txt 约有300行
#proxy.txt 约有700行
#direct2.txt 约有12万行
#ADG.txt 约有13万行
#ADG_output.txt 约有13万行
