#!/usr/bin/env sh

# Linux Server Installer Pro
# Created by @Linuztx
# Copyright (C) 2024 Linuztx

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 重置颜色

# 常量设置
TIMEOUT=2
MAX_RETRIES=5
ARCH_DEFAULT=$(uname -m)
ARCH_ALT=$([ "$ARCH_DEFAULT" = "x86_64" ] && echo "amd64" || echo "arm64")
PROOT_VERSION="5.3.0"

# 预检测必要工具
check_dependencies() {
    for cmd in curl tar gzip xz; do
        if ! command -v $cmd >/dev/null 2>&1; then
            echo -e "${RED}错误：必需的工具 $cmd 未安装，请先安装后再运行本脚本${NC}"
            exit 1
        fi
    已完成
}

# 打印带颜色的消息
print_msg() {
    color=$1
    message=$2
    printf "${color}%s${NC}\n" "$message"
}

# 显示主菜单
show_menu() {
    print_msg $BLUE "================================================"
    print_msg $BLUE "|      Linux 服务器安装专家版 - 由 @Linuztx 开发   |"
    print_msg $BLUE "================================================"
    print_msg $YELLOW "| 1.) Ubuntu 20.04 Focal Fossa                |"
    print_msg $YELLOW "| 2.) Alpine 3.19                            |"
    print_msg $YELLOW "| 3.) Debian 12 Bookworm                     |"
    print_msg $YELLOW "| 4.) Fedora 40                              |"
    print_msg $YELLOW "| 5.) 使用已安装的发行版                      |"
    print_msg $BLUE "================================================"
}

# 安装基础系统
install_system() {
    distro_name=$1
    distro_dir=$2
    rootfs_url=$3
    strip_level=$4

    print_msg $GREEN "开始安装 $distro_name ..."
    
    if ! curl -L --retry $MAX_RETRIES --retry-delay $TIMEOUT -o /tmp/rootfs.tar.gz "$rootfs_url"; then
        print_msg $RED "下载 $distro_name 根文件系统失败！"
        exit 1
    fi

    mkdir -p "$(pwd)/$distro_dir" || {
        print_msg $RED "创建目录失败：$(pwd)/$distro_dir"
        exit 1
    }

    if [ -n "$strip_level" ]; then
        tar_flags="-xf /tmp/rootfs.tar.gz -C $(pwd)/$distro_dir --strip-components=$strip_level"
    else
        tar_flags="-xf /tmp/rootfs.tar.gz -C $(pwd)/$distro_dir"
    fi

    if ! tar $tar_flags; then
        print_msg $RED "解压根文件系统失败！"
        rm -f /tmp/rootfs.tar.gz
        exit 1
    fi
    rm -f /tmp/rootfs.tar.gz

    print_msg $GREEN "$distro_name 基础系统安装完成"
}

# 安装必要工具
install_tools() {
    distro_name=$1
    distro_dir=$2

    print_msg $BLUE "正在安装基础工具 (curl/ca-certificates/iptables)..."

    case $distro_name in
        "Ubuntu"*|"Debian"*)
            proot_exec -S $distro_dir apt update -y
            proot_exec -S $distro_dir apt install -y curl ca-certificates iptables
            ;;
        "Alpine"*)
            proot_exec -S $distro_dir apk add --no-cache curl ca-certificates iptables
            ;;
        "Fedora"*)
            proot_exec -S $distro_dir dnf install -y curl ca-certificates iptables
            ;;
    esac
}

# Proot 执行封装
proot_exec() {
    "$(pwd)/${distro_dir}/usr/local/bin/proot" \
        -0 \
        -w /root \
        -b /dev \
        -b /sys \
        -b /proc \
        -b /etc/resolv.conf \
        -b /dev/urandom:/dev/random \
        -b /proc/net \
        -r "$(pwd)/${distro_dir}" "$@"
}

# 配置DNS
setup_dns() {
    distro_dir=$1
    resolv_conf="$(pwd)/$distro_dir/etc/resolv.conf"
    
    print_msg $BLUE "配置DNS服务器..."
    printf "nameserver 8.8.8.8\nnameserver 2001:4860:4860::8888\n" | tee $resolv_conf >/dev/null
    chmod 644 $resolv_conf
}

# 安装最新版Proot
install_proot() {
    distro_dir=$1
    
    print_msg $GREEN "正在安装 Proot v${PROOT_VERSION}..."
    mkdir -p "$(pwd)/$distro_dir/usr/local/bin"
    
    proot_url="https://github.com/proot-me/proot/releases/download/v${PROOT_VERSION}/proot-v${PROOT_VERSION}-${ARCH_ALT}-static"
    
    if ! curl -L --retry $MAX_RETRIES --retry-delay $TIMEOUT -o "$(pwd)/$distro_dir/usr/local/bin/proot" "$proot_url"; then
        print_msg $RED "Proot 下载失败！"
        exit 1
    fi
    
    chmod 755 "$(pwd)/$distro_dir/usr/local/bin/proot"
}

# 主程序
check_dependencies
clear
show_menu
read -p "请选择要安装的发行版 (1-5): " choice

case $choice in
    1)
        distro_name="Ubuntu 20.04"
        distro_dir="ubuntu"
        install_system "$distro_name" "$distro_dir" \
            "http://cdimage.ubuntu.com/ubuntu-base/releases/20.04/release/ubuntu-base-20.04.4-base-${ARCH_ALT}.tar.gz"
        ;;
    2)
        distro_name="Alpine 3.19"
        distro_dir="alpine" 
        install_system "$distro_name" "$distro_dir" \
            "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/${ARCH_DEFAULT}/alpine-minirootfs-3.19.1-${ARCH_DEFAULT}.tar.gz"
        ;;
    3)
        distro_name="Debian 12"
        distro_dir="debian"
        install_system "$distro_name" "$distro_dir" \
            "https://github.com/termux/proot-distro/releases/download/v4.7.0/debian-bullseye-${ARCH_DEFAULT}-pd-v4.7.0.tar.xz" 1
        ;;
    4)
        distro_name="Fedora 40"
        distro_dir="fedora"
        install_system "$distro_name" "$distro_dir" \
            "https://github.com/termux/proot-distro/releases/download/v4.15.0/fedora-${ARCH_DEFAULT}-pd-v4.15.0.tar.xz" 1
        ;;
    5)
        [ ! -d "ubuntu" ] && [ ! -d "alpine" ] && [ ! -d "debian" ] && [ ! -d "fedora" ] && \
            { print_msg $RED "没有找到已安装的发行版！"; exit 1; }
        
        print_msg $BLUE "已安装的发行版:"
        [ -d "ubuntu" ] && print_msg $YELLOW "1) Ubuntu"
        [ -d "alpine" ] && print_msg $YELLOW "2) Alpine"
        [ -d "debian" ] && print_msg $YELLOW "3) Debian"
        [ -d "fedora" ] && print_msg $YELLOW "4) Fedora"
        
        read -p "请选择要使用的发行版 (1-4): " sub_choice
        case $sub_choice in
            1) distro_dir="ubuntu" ;;
            2) distro_dir="alpine" ;;
            3) distro_dir="debian" ;;
            4) distro_dir="fedora" ;;
            *) print_msg $RED "无效选择！"; exit 1 ;;
        esac
        ;;
    *)
        print_msg $RED "无效选择！"
        exit 1
        ;;
esac

# 公共配置部分
install_proot $distro_dir
setup_dns $distro_dir
install_tools "$distro_name" $distro_dir

# 启动信息
clear
print_msg $BLUE "================================================"
print_msg $GREEN "|           环境准备就绪，即将进入系统          |"
print_msg $BLUE "================================================"
print_msg $YELLOW "使用说明："
print_msg $YELLOW "1. 输入 'su' 切换为 root 用户"
print_msg $YELLOW "2. 输入 'exit' 两次可退出容器环境"
print_msg $YELLOW "3. 已预装网络工具：curl/iptables"
print_msg $BLUE "================================================"

# 启动Proot环境
proot_exec /bin/sh -l
