#!/bin/sh
# ============================================================
# N1 旁路由卡顿 只读诊断脚本
# 不会修改任何配置，只采集现场。输出可直接贴回 issue。
#
# 用法（在 N1 上执行）：
#   sh diag-bypass.sh [客户端IP]
#   例：sh diag-bypass.sh 192.168.1.23   # 卡顿的手机IP
#
# 建议连续跑两次：卡顿时跑一次，正常时跑一次，对比差异。
# ============================================================

CLIENT="$1"

say() { echo ""; echo "----- $* -----"; }
kv()  { printf '  %-34s %s\n' "$1" "$2"; }

SEND_REDIRECTS_ALL=$(cat /proc/sys/net/ipv4/conf/all/send_redirects 2>/dev/null)
ACCEPT_REDIRECTS_ALL=$(cat /proc/sys/net/ipv4/conf/all/accept_redirects 2>/dev/null)

say "0. 固件与内核"
grep -E "DISTRIB_(ID|RELEASE|DESCRIPTION)" /etc/openwrt_release 2>/dev/null | sed 's/^/  /'
kv "kernel" "$(uname -r)"
kv "model"  "$(cat /tmp/sysinfo/model 2>/dev/null)"
kv "board"  "$(cat /tmp/sysinfo/board_name 2>/dev/null)"

say "1. 网卡 / 桥 / MTU"
for d in /sys/class/net/*; do
  n=$(basename "$d")
  printf '  %-12s mtu=%-6s state=%s\n' "$n" "$(cat "$d/mtu" 2>/dev/null)" "$(cat "$d/operstate" 2>/dev/null)"
done
echo "  --- bridge members ---"
for b in /sys/class/net/*/brif; do
  [ -d "$b" ] || continue
  printf '  %-12s <- %s\n' "$(basename "$(dirname "$b")")" "$(ls "$b" | tr '\n' ' ')"
done

say "2. IPv4 地址与路由"
ip -4 addr show 2>/dev/null | grep -E "^[0-9]+:|inet " | sed 's/^/  /'
echo "  --- route ---"
ip -4 route 2>/dev/null | sed 's/^/  /'

say "3. IPv6 地址与路由（安卓强偏好 IPv6，重点看）"
ip -6 addr show scope global 2>/dev/null | grep -E "^[0-9]+:|inet6 " | sed 's/^/  /'
echo "  --- route ---"
ip -6 route 2>/dev/null | sed 's/^/  /'
echo "  --- RA / DHCPv6 配置 ---"
uci show dhcp 2>/dev/null | grep -iE "ra=|dhcpv6=|ndp=|ra_default|ra_flags|prefix" | sed 's/^/  /'

say "4. 防火墙 zone 与 masquerade（关键）"
uci show firewall 2>/dev/null | grep -E "zone|forwarding|masquerade|network=" | sed 's/^/  /'
echo "  --- nft fw4 中与 NAT/offload 相关的规则 ---"
nft list table inet fw4 2>/dev/null | grep -nE "masquerade|redirect|flow|oifname" | head -40 | sed 's/^/  /'
echo "  --- iptables nat 表（如存在）---"
iptables -t nat -S 2>/dev/null | head -30 | sed 's/^/  /'

say "5. 硬件/软件流量分载（offload）"
kv "flow_offloading"    "$(uci -q get firewall.@defaults[0].flow_offloading 2>/dev/null)"
kv "flow_offloading_hw" "$(uci -q get firewall.@defaults[0].flow_offloading_hw 2>/dev/null)"
nft list ruleset 2>/dev/null | grep -iE "flowtable|flags offload" | head -10 | sed 's/^/  /'

say "6. ICMP 重定向开关（安卓会听，Windows 默认不听 = 卡顿不对称的关键嫌疑）"
for f in /proc/sys/net/ipv4/conf/*/send_redirects; do
  printf '  %-46s %s\n' "$f" "$(cat "$f" 2>/dev/null)"
done
for f in /proc/sys/net/ipv4/conf/*/accept_redirects; do
  printf '  %-46s %s\n' "$f" "$(cat "$f" 2>/dev/null)"
done
kv "ip_forward" "$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)"

say "7. fullcone / NAT 模块"
lsmod 2>/dev/null | grep -iE "fullcone|nft_offload|nf_nat|nf_conntrack" | sed 's/^/  /'

say "8. conntrack 压力"
kv "nf_conntrack_count" "$(cat /proc/sys/net/netfilter/nf_conntrack_count 2>/dev/null)"
kv "nf_conntrack_max"   "$(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null)"
kv "nf_conntrack_tcp_timeout_established" "$(cat /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established 2>/dev/null)"

say "9. 邻居表（看 STALE/FAILED、同 IP 多 MAC、同 MAC 多 IP）"
ip -4 neigh show 2>/dev/null | sed 's/^/  /'
echo "  --- 重复 MAC 检测 ---"
ip -4 neigh show 2>/dev/null | awk '/lladdr/ {print $5}' | sort | uniq -d | sed 's/^/  dup-mac /'

say "10. Docker 对 netfilter 的影响"
if command -v docker >/dev/null 2>&1; then
  docker ps --format '  {{.Names}}  {{.Status}}' 2>/dev/null | head -20
  iptables -t nat -S DOCKER 2>/dev/null | head -20 | sed 's/^/  /'
else
  echo "  docker 未安装"
fi
kv "docker0 地址" "$(ip -4 addr show docker0 2>/dev/null | awk '/inet /{print $2}')"

say "11. DNS / 出网基线"
nslookup www.baidu.com 2>/dev/null | tail -6 | sed 's/^/  /'
ping -c 3 -W 2 223.5.5.5 2>/dev/null | tail -3 | sed 's/^/  /'
ping -c 3 -W 2 1.1.1.1   2>/dev/null | tail -3 | sed 's/^/  /'
echo "  --- MTU 探测（能通的最大包）---"
for s in 1472 1452 1400 1372; do
  if ping -c 1 -W 2 -s $s 223.5.5.5 >/dev/null 2>&1; then
    echo "  payload $s (MTU $((s+28))) : OK"; break
  else
    echo "  payload $s (MTU $((s+28))) : FAIL"
  fi
done

if [ -n "$CLIENT" ]; then
  say "12. 指定客户端 $CLIENT 的现场"
  ip -4 neigh show "$CLIENT" 2>/dev/null | sed 's/^/  /'
  ping -c 4 -W 1 "$CLIENT" 2>/dev/null | tail -3 | sed 's/^/  /'
  echo "  --- 该客户端的 conntrack（前20条）---"
  grep -F "$CLIENT" /proc/net/nf_conntrack 2>/dev/null | head -20 | sed 's/^/  /'
  echo "  --- 该客户端的 conntrack 总数 ---"
  kv "conntrack entries" "$(grep -cF "$CLIENT" /proc/net/nf_conntrack 2>/dev/null)"
fi

say "13. 自动判读"
echo "  send_redirects(all)   = $SEND_REDIRECTS_ALL   (应为 0；=1 时旁路由会向安卓发 ICMP 重定向)"
echo "  accept_redirects(all) = $ACCEPT_REDIRECTS_ALL   (N1 自身收到重定向)"
echo ""
echo "  判读顺序："
echo "   A. 若 send_redirects=1 且 br-lan=1 -> 先试关掉重定向，见 issue 里的验证命令"
echo "   B. 若 ip -6 addr 有全局地址且 lan 开了 ra -> 怀疑 IPv6 抢路/黑洞，先在手机上关 IPv6 对比"
echo "   C. 若 flow_offloading=1 -> 旁路由 + 单网口 + 分载是已知卡顿源，关掉对比"
echo "   D. 若 neigh 有 FAILED/STALE 或 dup-mac -> MAC 随机化造成的邻居表不一致"
echo '   E. 若 MTU 探测没到 1472 -> MSS/MTU 问题，卡顿会表现为「网页转圈但 ping 正常」'
echo ""
echo "  done."
