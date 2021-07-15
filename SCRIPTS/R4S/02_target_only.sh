#!/bin/bash
clear

# 更换为 ImmortalWrt Uboot 以及 Target
rm -rf ./target/linux/rockchip
svn co https://github.com/immortalwrt/immortalwrt/branches/master/target/linux/rockchip target/linux/rockchip
rm -rf ./package/boot/uboot-rockchip
svn co https://github.com/immortalwrt/immortalwrt/branches/master/package/boot/uboot-rockchip package/boot/uboot-rockchip
svn co https://github.com/immortalwrt/immortalwrt/branches/master/package/boot/arm-trusted-firmware-rk3328 package/boot/arm-trusted-firmware-rk3328

# 超频到 2.2/1.8 GHz
rm -rf ./target/linux/rockchip/patches-5.4/992-rockchip-rk3399-overclock-to-2.2-1.8-GHz-for-NanoPi4.patch
cp -f ../PATCH/target_r4s/991-rockchip-rk3399-overclock-to-2.2-1.8-GHz-for-NanoPi4.patch ./target/linux/rockchip/patches-5.4/991-rockchip-rk3399-overclock-to-2.2-1.8-GHz-for-NanoPi4.patch
cp -f ../PATCH/target_r4s/213-RK3399-set-critical-CPU-temperature-for-thermal-throttling.patch ./target/linux/rockchip/patches-5.4/213-RK3399-set-critical-CPU-temperature-for-thermal-throttling.patch

# 使用特定的优化
sed -i 's,-mcpu=generic,-march=armv8-a+crypto+crc -mabi=lp64,g' include/target.mk
cp -f ../PATCH/mbedtls/100-Implements-AES-and-GCM-with-ARMv8-Crypto-Extensions.patch ./package/libs/mbedtls/patches/100-Implements-AES-and-GCM-with-ARMv8-Crypto-Extensions.patch
sed -i 's,kmod-r8169,kmod-r8168,g' target/linux/rockchip/image/armv8.mk

#增加风扇调速（被动散热不香么？
wget -P target/linux/rockchip/armv8/base-files/etc/init.d/ https://github.com/friendlyarm/friendlywrt/raw/master-v19.07.1/target/linux/rockchip-rk3399/base-files/etc/init.d/fa-rk3399-pwmfan
wget -P target/linux/rockchip/armv8/base-files/usr/bin/ https://github.com/friendlyarm/friendlywrt/raw/master-v19.07.1/target/linux/rockchip-rk3399/base-files/usr/bin/start-rk3399-pwm-fan.sh

# 测试性功能
sed -i '/CRYPTO_DEV_ROCKCHIP/d' ./target/linux/rockchip/armv8/config-5.4
sed -i '/HW_RANDOM_ROCKCHIP/d' ./target/linux/rockchip/armv8/config-5.4
echo '
CONFIG_CRYPTO_DEV_ROCKCHIP=y
CONFIG_HW_RANDOM_ROCKCHIP=y
' >> ./target/linux/rockchip/armv8/config-5.4

# IRQ 调优
sed -i '/set_interface_core 20 "eth1"/a\set_interface_core 8 "ff3c0000" "ff3c0000.i2c"' target/linux/rockchip/armv8/base-files/etc/hotplug.d/net/40-net-smp-affinity
sed -i '/set_interface_core 20 "eth1"/a\ethtool -C eth0 rx-usecs 1000 rx-frames 25 tx-usecs 100 tx-frames 25' target/linux/rockchip/armv8/base-files/etc/hotplug.d/net/40-net-smp-affinity

# 添加 R4S GPU 驱动
rm -rf ./package/kernel/linux/modules/video.mk
wget -P package/kernel/linux/modules/ https://github.com/immortalwrt/immortalwrt/raw/master/package/kernel/linux/modules/video.mk

# 内核加解密模块
echo '
' >> ./target/linux/rockchip/armv8/config-5.4

# MPTCP
echo '
CONFIG_MPTCP=y
CONFIG_MPTCP_PM_ADVANCED=y
CONFIG_MPTCP_FULLMESH=y
CONFIG_DEFAULT_FULLMESH=y
CONFIG_DEFAULT_MPTCP_PM="fullmesh"
' >> ./target/linux/rockchip/armv8/config-5.4

#Vermagic
latest_version="$(curl -s https://github.com/openwrt/openwrt/releases |grep -Eo "v[0-9\.]+\-*r*c*[0-9]*.tar.gz" |sed -n '/21/p' |sed -n 1p |sed 's/v//g' |sed 's/.tar.gz//g')"
wget https://downloads.openwrt.org/releases/${latest_version}/targets/rockchip/armv8/packages/Packages.gz
zgrep -m 1 "Depends: kernel (=.*)$" Packages.gz | sed -e 's/.*-\(.*\))/\1/' > .vermagic
sed -i -e 's/^\(.\).*vermagic$/\1cp $(TOPDIR)\/.vermagic $(LINUX_DIR)\/.vermagic/' include/kernel-defaults.mk

# 预配置一些插件
cp -rf ../PATCH/files ./files

chmod -R 755 ./
find ./ -name *.orig | xargs rm -f
find ./ -name *.rej | xargs rm -f

#exit 0
