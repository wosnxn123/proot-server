#!/usr/bin/env sh

# Linux Server Installer Pro
# Created by @Linuztx
# Copyright (C) 2024 Linuztx

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Constants
TIMEOUT=1
MAX_RETRIES=10
ARCH_DEFAULT=$(uname -m)
ARCH_ALT=$([ "$ARCH_DEFAULT" = "x86_64" ] && echo "amd64" || echo "arm64")

# 支持的发行版配置 (名称|目录|下载URL|解压参数)
DISTROS=(
  # Ubuntu
  "Ubuntu 24.04 Noble Numbat|ubuntu-24.04|https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-${ARCH_ALT}-root.tar.xz|1"
  "Ubuntu 22.04 Jammy Jellyfish|ubuntu-22.04|https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-${ARCH_ALT}-root.tar.xz|1"
  
  # Debian
  "Debian 13 Trixie|debian-13|https://github.com/termux/proot-distro/releases/download/v5.0.0/debian-trixie-${ARCH_DEFAULT}-pd-v5.0.0.tar.xz|1"
  "Debian 12 Bookworm|debian-12|https://github.com/termux/proot-distro/releases/download/v4.7.0/debian-bullseye-${ARCH_DEFAULT}-pd-v4.7.0.tar.xz|1"
  
  # RHEL 系
  "Rocky Linux 9|rocky-9|https://dl.rockylinux.org/pub/rocky/9/images/${ARCH_DEFAULT}/Rocky-9-Container-Base.latest.${ARCH_DEFAULT}.tar.xz|1"
  "AlmaLinux 9|alma-9|https://repo.almalinux.org/almalinux/9/cloud/${ARCH_DEFAULT}/images/AlmaLinux-9-Container-Base.latest.${ARCH_DEFAULT}.tar.xz|1"
  "CentOS Stream 9|centos-stream-9|https://cloud.centos.org/centos/9-stream/${ARCH_DEFAULT}/images/CentOS-Stream-Container-Base-9-latest.${ARCH_DEFAULT}.tar.xz|1"
  "Oracle Linux 9|oracle-9|https://yum.oracle.com/templates/OracleLinux/OL9/container/oraclelinux9-${ARCH_DEFAULT}.tar.xz|1"
  
  # Fedora
  "Fedora 40|fedora-40|https://github.com/termux/proot-distro/releases/download/v4.15.0/fedora-${ARCH_DEFAULT}-pd-v4.15.0.tar.xz|1"
  "Fedora 39|fedora-39|https://github.com/termux/proot-distro/releases/download/v4.12.0/fedora-${ARCH_DEFAULT}-pd-v4.12.0.tar.xz|1"
  
  # 安全发行版
  "Kali Linux 2024.2|kali-2024.2|https://kali.download/nethunter-images/current/rootfs/kalifs-${ARCH_DEFAULT}-minimal.tar.xz|1"
  
  # 轻量级发行版
  "Alpine 3.20|alpine-3.20|https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/${ARCH_DEFAULT}/alpine-minirootfs-3.20.0-${ARCH_DEFAULT}.tar.gz"
  "Devuan 5|devuan-5|https://github.com/termux/proot-distro/releases/download/v5.0.0/devuan-daedalus-${ARCH_DEFAULT}-pd-v5.0.0.tar.xz|1"
  
  # 滚动发行版
  "Arch Linux|arch|https://mirror.rackspace.com/archlinux/iso/latest/archlinux-bootstrap-${ARCH_DEFAULT}.tar.gz|1"
  "Void Linux|void|https://repo-default.voidlinux.org/live/current/void-${ARCH_DEFAULT}-ROOTFS-20240314.tar.xz"
  
  # 特殊发行版
  "Gentoo Linux|gentoo|https://distfiles.gentoo.org/releases/${ARCH_DEFAULT}/autobuilds/latest-stage3-${ARCH_DEFAULT}-systemd.txt|1"
  "openSUSE Tumbleweed|opensuse-tumbleweed|https://download.opensuse.org/tumbleweed/appliances/openSUSE-Tumbleweed-Container-${ARCH_DEFAULT}.tar.xz|1"
  "Slackware 15.0|slackware-15|https://slackware.uk/slackware/slackware64-15.0/slackware64-15.0-install-dvd.iso"
  "Chimera Linux|chimera|https://repo.chimera-linux.org/live/20240111/chimera-${ARCH_DEFAULT}-ROOTFS-20240111.tar.gz"
  "Amazon Linux 2023|amazon-2023|https://cdn.amazonlinux.com/al2023/core/guids/$(curl -s https://cdn.amazonlinux.com/al2023/core/latest/${ARCH_DEFAULT}/).rootfs.squashfs"
  "Linux Mint 21.3|mint-21.3|https://mirrors.ustc.edu.cn/linuxmint-images/stable/21.3/linuxmint-21.3-cinnamon-64bit.iso"
  "Alt Linux 10|alt-10|https://ftp.altlinux.org/pub/distributions/ALTLinux/images/cloud/alt-${ARCH_DEFAULT}-c10.tar.xz|1"
  "Plamo Linux 7.3|plamo-7.3|https://ftp.plamolinux.org/pub/Plamo/Plamo-7.3/x86_64/plamo-7.3_${ARCH_DEFAULT}.iso"
)

# Function to print colored messages
print_message() {
    color=$1
    message=$2
    printf "${color}%s${NC}\n" "$message"
}

# Function to display the menu
display_menu() {
    print_message $BLUE "=================================================="
    print_message $BLUE "|      Linux Server Installer Pro by @Linuztx    |"
    print_message $BLUE "=================================================="
    print_message $BLUE "|                Copyright (C) 2024              |"
    print_message $BLUE "=================================================="
    
    local count=1
    for distro in "${DISTROS[@]}"; do
        IFS='|' read -r name _ _ <<< "$distro"
        print_message $YELLOW "|        $count.) $name"
        ((count++))
    done
    
    print_message $YELLOW "|        $count.) Use existing installation"
    print_message $BLUE "=================================================="
}

# Function to install a distribution
install_distro() {
    local distro_info=$1
    IFS='|' read -r name dir url strip <<< "$distro_info"
    
    print_message $GREEN "Starting installation of $name..."
    if curl -L --retry $MAX_RETRIES --retry-delay $TIMEOUT --output /tmp/rootfs.tar.gz "$url"; then
        mkdir -p "$(pwd)/$dir"
        
        # 处理不同压缩格式
        case $url in
            *.tar.xz)   tar_cmd="tar -Jxf";;
            *.tar.gz)   tar_cmd="tar -zxf";;
            *.tar)      tar_cmd="tar -xf";;
            *.squashfs) 
                print_message $YELLOW "Detected squashfs image, using unsquashfs..."
                unsquashfs -f -d "$(pwd)/$dir" /tmp/rootfs.tar.gz
                rm -f /tmp/rootfs.tar.gz
                print_message $GREEN "$name installed successfully."
                return
                ;;
            *.iso)
                print_message $YELLOW "ISO detected, mounting..."
                mkdir -p /mnt/iso
                mount -o loop /tmp/rootfs.tar.gz /mnt/iso
                cp -a /mnt/iso/* "$(pwd)/$dir"
                umount /mnt/iso
                rm -f /tmp/rootfs.tar.gz
                print_message $GREEN "$name installed successfully."
                return
                ;;
        esac

        $tar_cmd /tmp/rootfs.tar.gz -C "$(pwd)/$dir" ${strip:+--strip-components=$strip}
        rm -f /tmp/rootfs.tar.gz
        print_message $GREEN "$name installed successfully."
    else
        print_message $RED "Failed to download $name"
        exit 1
    fi
}

# Main script
display_menu
total_items=$((${#DISTROS[@]} + 1))
read -p "Choose a distro (1-$total_items): " choice

if (( choice > 0 && choice <= ${#DISTROS[@]} )); then
    install_distro "${DISTROS[$((choice-1))]}"
    distro_dir=$(cut -d'|' -f2 <<< "${DISTROS[$((choice-1))]}")
elif (( choice == total_items )); then
    installed_dirs=()
    for distro in "${DISTROS[@]}"; do
        IFS='|' read -r _ dir _ <<< "$distro"
        [ -d "$(pwd)/$dir" ] && installed_dirs+=("$dir")
    done
    
    if [ ${#installed_dirs[@]} -eq 0 ]; then
        print_message $RED "No distro installed. Please install first."
        exit 1
    fi

    print_message $BLUE "Available installations:"
    local count=1
    for dir in "${installed_dirs[@]}"; do
        print_message $YELLOW "$count.) $dir"
        ((count++))
    done
    
    read -p "Select installation (1-${#installed_dirs[@]}): " selected
    if (( selected > 0 && selected <= ${#installed_dirs[@]} )); then
        distro_dir="${installed_dirs[$((selected-1))]}"
    else
        print_message $RED "Invalid selection"
        exit 1
    fi
else
    print_message $RED "Invalid choice"
    exit 1
fi

# 公共设置部分
[ ! -d "$(pwd)/$distro_dir" ] && { print_message $RED "Install directory missing"; exit 1; }

# 安装/更新proot
proot_path="$(pwd)/$distro_dir/usr/local/bin/proot"
mkdir -p "$(dirname "$proot_path")"
if [ ! -x "$proot_path" ] || [ "$(( $(date +%s) - $(stat -c %Y "$proot_path") ))" -gt 604800 ]; then
    print_message $GREEN "Downloading/Updating proot..."
    curl -L --retry 3 --output "$proot_path" "https://proot.gitlab.io/proot/bin/proot"
    chmod 755 "$proot_path"
fi

# 网络配置
resolv_conf="$(pwd)/$distro_dir/etc/resolv.conf"
[ ! -f "$resolv_conf" ] && {
    mkdir -p "$(dirname "$resolv_conf")"
    printf "nameserver 1.1.1.1\nnameserver 8.8.8.8\n" > "$resolv_conf"
}

# 启动环境
print_message $BLUE "=================================================="
print_message $GREEN "|        Starting $distro_dir environment        |"
print_message $BLUE "=================================================="

extra_args=""
case $distro_dir in
    *alpine*)   extra_args="-b /lib/modules";;
    *gentoo*)   extra_args="-b /usr/portage";;
    *slackware*) extra_args="-b /var/log/packages";;
esac

"$proot_path" --rootfs="$(pwd)/$distro_dir" \
    -0 -w "/root" \
    -b /dev -b /sys -b /proc \
    -b /etc/resolv.conf \
    $extra_args \
    /bin/sh -c "
    echo 'System information:';
    echo -n 'Distro: '; grep PRETTY_NAME /etc/os-release 2>/dev/null || cat /etc/*release;
    echo -n 'Kernel: '; uname -sr;
    echo 'Use \"exit\" to logout';
    exec /bin/sh"
