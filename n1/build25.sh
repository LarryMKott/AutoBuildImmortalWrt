#!/bin/bash
# 斐讯 N1 (Amlogic S905D) ImmortalWrt 25.12.x 构建脚本 (apk 软件包体系)
# 说明: 25.12 使用 apk 包管理, 因此 source shell/apk-custom-packages.sh,
#       第三方软件从 wukongdaily/apk 仓库 (run/apk) 同步, 不再使用 opkg 的 repositories.conf
source shell/apk-custom-packages.sh
echo "第三方APK软件包: $CUSTOM_PACKAGES"
LOGFILE="/tmp/uci-defaults-log.txt"
echo "Starting 25.12 N1 build at $(date)" >> $LOGFILE
# yml 传入的路由器型号 PROFILE
echo "Building for profile: $PROFILE"
# yml 传入的固件大小 ROOTFS_PARTSIZE
echo "Building for ROOTFS_PARTSIZE: $ROOTFS_PARTSIZE"
echo "$(date '+%Y-%m-%d %H:%M:%S') - 开始构建arm64的rootfs.tar.gz"

# 定义所需安装的包列表 下列插件你都可以自行删减
PACKAGES=""
PACKAGES="$PACKAGES curl fdisk"
PACKAGES="$PACKAGES luci-i18n-diskman-zh-cn"
PACKAGES="$PACKAGES luci-i18n-package-manager-zh-cn"
PACKAGES="$PACKAGES luci-i18n-firewall-zh-cn"
# 服务——FileBrowser 用户名admin 密码admin
PACKAGES="$PACKAGES luci-i18n-filebrowser-go-zh-cn"
PACKAGES="$PACKAGES luci-theme-argon"
PACKAGES="$PACKAGES luci-app-argon-config"
PACKAGES="$PACKAGES luci-i18n-argon-config-zh-cn"
PACKAGES="$PACKAGES luci-i18n-ttyd-zh-cn"
PACKAGES="$PACKAGES openssh-sftp-server"
# 文件管理器
PACKAGES="$PACKAGES luci-i18n-filemanager-zh-cn"
# 判断是否需要编译 Docker 插件
if [ "$INCLUDE_DOCKER" = "yes" ]; then
    PACKAGES="$PACKAGES luci-i18n-dockerman-zh-cn"
    echo "✅ 已选择docker : luci-i18n-dockerman-zh-cn"
fi
# 斐讯N1 无线
PACKAGES="$PACKAGES kmod-brcmfmac wpad-basic-mbedtls iw iwinfo"
# 晶晨宝盒: N1 刷写 eMMC / 在线升级固件与内核 / 备份恢复的唯一 GUI 入口。
# ophub/luci-app-amlogic 自 26.10.2002 起正式发布 apk 版本:
#   r2 = JS LuCI (main 分支, 对应 25.12), r1 = Lua LuCI (lua 分支, 对应 24.10)
# 运行依赖(见上游 Makefile): luci-base rpcd rpcd-mod-ucode bash blkid block-mount curl
#   dosfstools e2fsprogs fdisk jq losetup lsblk parted perl pv uuidgen
# 其中 perlbase-* 与几个小工具在 ImageBuilder 默认裁剪里常缺失, 这里显式带上,
# 否则 apk 依赖解析会在 make image 阶段失败。
PACKAGES="$PACKAGES perlbase-base perlbase-file perlbase-time perlbase-utf8 perlbase-xsloader"
PACKAGES="$PACKAGES bash jq pv uuidgen rpcd-mod-ucode dosfstools fdisk lsblk parted"
CUSTOM_PACKAGES="$CUSTOM_PACKAGES luci-app-amlogic luci-i18n-amlogic-zh-cn"

# ============= 同步第三方插件库==============
if [ -z "$CUSTOM_PACKAGES" ]; then
    echo "⚪️ 未选择 任何第三方软件包"
else
    echo "🔄 正在同步第三方软件仓库 Cloning apk file repo..."
    git clone --depth=1 https://github.com/wukongdaily/apk.git /tmp/store-apk-repo

    # 拷贝 run/arm64 下所有 run 文件和 apk 文件 到 extra-packages 目录
    mkdir -p /home/build/immortalwrt/extra-packages
    cp -r /tmp/store-apk-repo/run/arm64/* /home/build/immortalwrt/extra-packages/

    # ============= 晶晨宝盒 apk (N1 eMMC 安装 / 固件与内核升级) =============
    # 固定拉取 ophub 官方 apk, 不依赖上面 clone 的仓库是否已收录; 已存在则跳过。
    AMLOGIC_TAG="26.10.2002-js"
    AMLOGIC_URL="https://github.com/ophub/luci-app-amlogic/releases/download/${AMLOGIC_TAG}"
    AMLOGIC_DIR="/home/build/immortalwrt/extra-packages/amlogic"
    mkdir -p "$AMLOGIC_DIR"
    for apk in luci-app-amlogic-26.10.2002-r2.apk luci-i18n-amlogic-zh-cn-0.apk luci-i18n-amlogic-ru-0.apk; do
        if [ -f "$AMLOGIC_DIR/$apk" ]; then
            echo "✅ 已存在 $apk"
            continue
        fi
        wget -q "$AMLOGIC_URL/$apk" -P "$AMLOGIC_DIR/" || echo "❌ 下载 $apk 失败"
    done
    ls -lh "$AMLOGIC_DIR"

    echo "✅ Run files copied to extra-packages:"
    # 解压并拷贝apk到packages目录
    sh shell/apk-prepare-packages.sh
    ls -lah /home/build/immortalwrt/packages/
fi

# ======== shell/apk-custom-packages.sh =======
# 合并imm仓库以外的第三方插件
PACKAGES="$PACKAGES $CUSTOM_PACKAGES"

# 若构建openclash 则添加内核
if echo "$PACKAGES" | grep -q "luci-app-openclash"; then
    echo "✅ 已选择 luci-app-openclash，添加 openclash core"
    mkdir -p files/etc/openclash/core
    # Download clash_meta
    META_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz"
    wget -qO- $META_URL | tar xOvz > files/etc/openclash/core/clash_meta
    chmod +x files/etc/openclash/core/clash_meta
    # Download GeoIP and GeoSite
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat -O files/etc/openclash/GeoIP.dat
    wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat -O files/etc/openclash/GeoSite.dat
    # Download latest openclash Client
    URL=$(curl -s https://api.github.com/repos/vernesong/OpenClash/releases/latest \
      | grep "browser_download_url.*apk" \
      | head -n1 \
      | cut -d '"' -f 4)
    echo "OpenClash latest apk: $URL"
    wget "$URL" -P /home/build/immortalwrt/packages/
else
    echo "⚪️ 未选择 luci-app-openclash"
fi

if echo "$PACKAGES" | grep -q "luci-app-ssr-plus"; then
    echo "✅ 已选择 luci-app-ssr-plus，添加 mihomo core"
    mkdir -p files/usr/bin
    # Download mihomo
    MIHOMO_URL="https://github.com/MetaCubeX/mihomo/releases/download/v1.19.24/mihomo-linux-arm64-v1.19.24.gz"
    wget -qO- "$MIHOMO_URL" | gzip -dc > files/usr/bin/mihomo
    chmod +x files/usr/bin/mihomo
    echo "✅ 已下载 mihomo core"
    ls -lah files/usr/bin
else
    echo "⚪️ 未选择 luci-app-ssr-plus"
fi

# 输出软件源调试信息 (25.12 为 apk, 软件源文件名为 repositories)
echo "查看repositories信息——————"
[ -f repositories ] && cat repositories

# 构建镜像
echo "$(date '+%Y-%m-%d %H:%M:%S') - Building image with the following packages:"
echo "$PACKAGES"

make image PROFILE=$PROFILE PACKAGES="$PACKAGES" FILES="/home/build/immortalwrt/files" ROOTFS_PARTSIZE=$ROOTFS_PARTSIZE

if [ $? -ne 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Build failed!"
    exit 1
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') - Build completed successfully."
