#!/bin/bash

#Debug
debug_(){
    LOG_FILE=/opt/run.log
    exec 5> ${LOG_FILE}
    BASH_XTRACEFD="5"
    PS4='$LINENO: '
    set -x
}

debug_

############################################
# Auto Install & Optimize LEMP Stack on CentOS 7
# Version: 1.0
# Author: Sanvv - HOSTVN Technical
#
############################################

# Set variables
OS_VER=$(rpm -E %centos)
OS_ARCH=$(uname -m)
IPADDRESS=$(ip route get 1 | awk '{print $NF;exit}')
DIR=$(pwd)
BASH_DIR="/var/hostvn/script"
GITHUB_RAW_LINK="https://raw.githubusercontent.com"
GITHUB_URL="https://github.com"
PECL_PHP_LINK="https://pecl.php.net/get"

# Copyright
AUTHOR="HOSTVN Technical Team!"
AUTHOR_CONTACT="kythuat@hostvn.net"

# Set Lang
ROOT_ERR="Bạn cần chạy script với user root. Chạy lệnh \"sudo su\" để có quyền root!\n"
CANCEL_INSTALL="Huỷ cài đặt..."
OS_WROG="Script chỉ hoạt động trên \"CentOS 7\"!\n"
RAM_NOT_ENOUGH="Cảnh báo: Dung lượng RAM quá thấp để cài Script. (Ít nhất 512MB)\n"
OTHER_CP_EXISTS="Máy chủ của bạn đã cài đặt Control Panel khác. Vui lòng rebuild để cài đặt Script"
ENTER_OPTION="Nhập vào lựa chọn của bạn [1-6]: "
SELECT_PHP="Hãy lựa chọn phiên bản PHP muốn cài đặt:\n"
INST_PHP_NOTIFY1="\nHệ thống sẽ cài đặt PHP 7.4\n"
INST_PHP_NOTIFY2="Bạn nhập sai, hệ thống sẽ cài đặt PHP 7.4\n"
INST_MARIADB_ERR="Cài đặt MariaDB thất bại, vui lòng liên hệ ${AUTHOR_CONTACT} để được hỗ trợ."
INST_NGINX_ERR="Cài đặt Nginx thất bại, vui lòng liên hệ ${AUTHOR_CONTACT} để được hỗ trợ."
INST_PHP_ERR="Cài đặt PHP thất bại, vui lòng liên hệ ${AUTHOR_CONTACT} để được hỗ trợ."
INST_IGBINARY_ERR="Cài đặt Igbinary không thành công. Vui lòng cài đặt lại: Igbinary, Php memcached ext, Phpredis."
INST_MEMEXT_ERR="Cài đặt Php memcached extension không thành công. Vui lòng cài đặt lại."
INST_PHPREDIS_ERR="Cài đặt Phpredis không thành công. Vui lòng cài đặt lại."
NGINX_NOT_WORKING="Nginx không hoạt động."
MARIADB_NOT_WORKING="MariaDB không hoạt động."
PUREFTP_NOT_WORKING="Pure-ftp không hoạt động."
PHP_NOT_WORKING="PHP-FPM không hoạt động."
LFD_NOT_WORKING="LFD không hoạt động."

# Service Version
IGBINARY_VERSION="3.1.2"
PHP_MEMCACHED_VERSION="3.1.5"
PHPMYADMIN_FOUR="4.9.5"
PHPMYADMIN_FIVE="5.0.2"
PHP_REDIS_VERSION="5.2.2"
PHP_SYS_INFO_VERSION="3.3.2"

# Select Service Version
MARIADB_VERSION="10.5"
PHP_VERSION="74"

# Random Admin Port
RANDOM_ADMIN_PORT=$(( ( RANDOM % 9999 )  + 2000 ))

# Dir
DEFAULT_DIR_WEB="/usr/share/nginx/html"
USR_DIR="/usr/share"

# Control Panel path
CPANEL="/usr/local/cpanel/cpanel"
DIRECTADMIN="/usr/local/directadmin/custombuild/build"
PLESK="/usr/local/psa/version"
WEBMIN="/etc/init.d/webmin"
SENTORA="/root/passwords.txt"
HOCVPS="/etc/hocvps/scripts.conf"
VPSSIM="/home/vpssim.conf"
EEV3="/usr/local/bin/ee"
WORDOPS="/usr/local/bin/wo"
KUSANAGI="/home/kusanagi"
CWP="/usr/local/cwpsrv"
VESTA="/usr/local/vesta/"
EEV4="/opt/easyengine"

#Install requirements
yum -y install epel-release
yum install http://rpms.remirepo.net/enterprise/remi-release-7.rpm -y
yum -y update
yum -y install gawk git bc wget lsof htop curl zip unzip nano gcc gcc-c++ yum-utils

# Get info VPS
CPU_CORES=$(grep -c "processor" /proc/cpuinfo)
RAM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
SWAP_TOTAL=$(awk '/SwapFree/ {print $2}' /proc/meminfo)
PHP_MEM=${RAM_TOTAL}+${SWAP_TOTAL}
RAM_MB=$(echo "scale=0;${RAM_TOTAL}/1024" | bc)
LOW_RAM='524288'
NGINX_PROCESSES=$(grep -c ^processor /proc/cpuinfo)
MAX_CLIENT=$((1024 * "${NGINX_PROCESSES}"))
#MAX_CLIENT=$(expr 1024 \* "${NGINX_PROCESSES}" )

rm -rf "${DIR}"/install

############################################
# Function
############################################
cd_dir(){
    cd "$1" || return
}

############################################
# Prepare install
############################################

# Disable Selinux
disable_selinux(){
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
    sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
    systemctl stop firewalld
    systemctl disable firewalld
}

#Set timezone
set_timezone(){
    if [[ -f "/etc/localtime" && -f "/usr/share/zoneinfo/Asia/Ho_Chi_Minh" ]]; then
        rm -f /etc/localtime
        ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
    else
        timedatectl set-timezone Asia/Ho_Chi_Minh
    fi
}

#Set OS Archive
set_os_arch(){
    if [[ "${OS_ARCH}" == "x86_64" ]]; then
        OS_ARCH1="amd64"
    elif [[ "${OS_ARCH}" == "i686" ]]; then
        OS_ARCH1="x86"
    fi
}

# Set DNS
set_dns(){
    sed -i 's/nameserver/#nameserver/g' /etc/resolv.conf
    {
        echo "nameserver 8.8.8.8"
        echo "nameserver 8.8.4.4"
        echo "nameserver 4.2.2.2"
        echo "options rotate"
        echo "options timeout:1"
        echo "options attempts:1"
    } >> /etc/resolv.conf
}

# Remove unnecessary services
remove_service(){
    yum -y remove mysql* php* httpd* sendmail* postfix* rsyslog* nginx*
    yum clean all
}

# Install requirement service
instell_service(){
    yum -y install syslog-ng syslog-ng-libdbi cronie ntpdate
}

# Create log file
create_log(){
    LOG="/var/log/install.log"
    touch "${LOG}"
}

prepare_install(){
    echo ""
    disable_selinux
    set_timezone
    set_os_arch
    set_dns
    remove_service
    instell_service
    create_log
}

############################################
# Check conditions
############################################

# Check if user not root
check_root(){
    if [[ $(id -u) != "0" ]]; then
        echo "${ROOT_ERR}"
        echo "${CANCEL_INSTALL}"
        exit
    fi
}

# Check OS
check_os(){
    if [[ "${OS_VER}" != "7" ]]; then
        echo "${OS_WROG}"
        echo "${CANCEL_INSTALL}"
        exit
    fi
}

# Check if not enough ram
check_low_ram(){
    if [ "${RAM_TOTAL}" -lt ${LOW_RAM} ]; then
        echo -e "${RAM_NOT_ENOUGH}"
        echo "${CANCEL_INSTALL}"
        exit
    fi
}

# Check if other Control Panel has installed before
check_control_panel(){
    if [[ -f ${CPANEL} ]] || [[ -f ${DIRECTADMIN} ]] || [[ -f ${PLESK} || -f ${WEBMIN} || -f ${SENTORA} || -f ${HOCVPS} ]]; then
        echo -e "${OTHER_CP_EXISTS}"
        echo "${CANCEL_INSTALL}"
        exit
    fi

    if [[ -f ${VPSSIM} || -f ${WORDOPS} || -f ${EEV3} || -d ${EEV4} || -d ${VESTA} || -d ${CWP} || -d ${KUSANAGI}  ]]; then
        echo -e "${OTHER_CP_EXISTS}"
        echo "${CANCEL_INSTALL}"
        exit
    fi
}

check_before_install(){
    echo ""
    check_root
    check_os
    check_low_ram
    check_control_panel
}

############################################
# Install LEMP Stack
############################################

#Install Nginx
install_nginx(){
    cat >> "/etc/yum.repos.d/nginx.repo" << EONGINXREPO
[nginx-stable]
name=nginx stable repo
baseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://nginx.org/keys/nginx_signing.key
module_hotfixes=true
EONGINXREPO

    yum -y install nginx
}

#Install Mariadb
install_mariadb(){
    cat >> "/etc/yum.repos.d/mariadb.repo" << EOMARIADBREPO
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/${MARIADB_VERSION}/centos${OS_VER}-${OS_ARCH1}
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOMARIADBREPO

    yum -y install MariaDB-server MariaDB-client
}

# Install php-fpm
select_php_ver(){
    echo "${SELECT_PHP}"
    prompt=${ENTER_OPTION}
    options=("PHP 7.4" "PHP 7.3" "PHP 7.2" "PHP 7.1" "PHP 7.0" "PHP 5.6")
    PS3="$prompt"
    select opt in "${options[@]}"; do
        case "$opt" in
        1) PHP_VERSION="74"; break;;
        2) PHP_VERSION="73"; break;;
        3) PHP_VERSION="72"; break;;
        4) PHP_VERSION="71"; break;;
        5) PHP_VERSION="70"; break;;
        6) PHP_VERSION="56"; break;;
        $(( ${#options[@]}+1 )) ) echo "${INST_PHP_NOTIFY1}"; break;;
        *) echo "${INST_PHP_NOTIFY2}"; break;;
        esac
    done
}

install_php(){
    select_php_ver
    yum-config-manager --enable remi-php${PHP_VERSION}
    yum -y install php php-fpm php-ldap php-zip php-embedded php-cli php-mysql php-common php-gd php-xml php-mbstring \
        php-mcrypt php-pdo php-soap php-json php-simplexml php-process php-curl php-bcmath php-snmp php-pspell php-gmp \
        php-intl php-imap perl-LWP-Protocol-https php-pear-Net-SMTP php-enchant php-pear php-devel php-zlib php-xmlrpc \
        php-tidy php-opcache php-cli php-pecl-zip php-dom php-ssh2 php-xmlreader php-date php-exif php-filter php-ftp \
        php-hash php-iconv php-libxml php-pecl-imagick php-mysqlnd php-openssl php-pcre php-posix php-sockets php-spl \
        php-tokenizer php-bz2 php-pgsql php-sqlite3 php-fileinfo
}

install_php_ext() {
    if [[ ${PHP_VERSION} != "56" ]]; then
        cd "${DIR}" && wget ${GITHUB_URL}/php/pecl-text-wddx/archive/master.zip -O wddx.zip
        unzip wddx.zip
        cd_dir "${DIR}/pecl-text-wddx-master"
        /usr/bin/phpize && ./configure
        make && make install
        cd "${DIR}" && rm -rf pecl-text-wddx-master wddx.zip
        cat >> "/etc/php.d/40-wddx.ini" << EOwddx_ext
        extension=wddx.so
EOwddx_ext

        git clone --recursive --depth=1 ${GITHUB_URL}/kjdev/php-ext-brotli.git
        cd_dir "${DIR}/php-ext-brotli"
        /usr/bin/phpize && ./configure
        make && make install
        cat >> "/etc/php.d/40-brotli.ini" << EObrotli_ext
        extension=brotli.so
EObrotli_ext
        cd "${DIR}" && rm -rf php-ext-brotli
    fi
}

install_lemp(){
    echo ""
    install_nginx
    if [[ ! -f "/usr/lib/systemd/system/nginx.service" ]]; then
        clear
        echo "${INST_NGINX_ERR}"
        sleep 3
        exit
    fi

    install_mariadb

    if [[ ! -f "/usr/lib/systemd/system/mariadb.service" ]]; then
        clear
        echo "${INST_MARIADB_ERR}"
        sleep 3
        exit
    fi

    install_php

    if [[ -f "/usr/lib/systemd/system/php-fpm.service" ]]; then
        install_php_ext
    else
        clear
        echo "${INST_PHP_ERR}"
        sleep 3
        exit
    fi
}

############################################
# Install Composer
############################################
install_composer(){
    echo ""
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
}

############################################
# Install Cache
############################################

# Install igbinary
install_igbinary(){
    if [[ "${PHP_VERSION}" -eq "56" ]]; then
        cd "${DIR}" && wget ${PECL_PHP_LINK}/igbinary-2.0.8.tgz
        tar -xvf igbinary-2.0.8.tgz
        cd_dir "${DIR}/igbinary-2.0.8"
        /usr/bin/phpize && ./configure --with-php-config=/usr/bin/php-config
        make && make install
        cd "${DIR}" && rm -rf igbinary-2.0.8.tgz igbinary-2.0.8
    else
        cd "${DIR}" && wget ${PECL_PHP_LINK}/igbinary-${IGBINARY_VERSION}.tgz
        tar -xvf igbinary-${IGBINARY_VERSION}.tgz
        cd_dir "${DIR}/igbinary-${IGBINARY_VERSION}"
        /usr/bin/phpize && ./configure --with-php-config=/usr/bin/php-config
        make && make install
        cd "${DIR}" && rm -rf igbinary-${IGBINARY_VERSION} igbinary-${IGBINARY_VERSION}.tgz
    fi

    if [[ -f "/usr/lib64/php/modules/igbinary.so" ]]; then
        cat >> "/etc/php.d/40-igbinary.ini" << EOF
extension=igbinary.so
EOF
    else
        echo "${INST_IGBINARY_ERR}" >> ${LOG}
    fi
}

# Install Php memcached extension
install_php_memcached(){
    if [[ "${PHP_VERSION}" -eq "56" ]]; then
        cd "${DIR}" && wget ${PECL_PHP_LINK}/memcached-2.2.0.tgz
        tar -xvf memcached-2.2.0.tgz
        cd_dir "${DIR}/memcached-2.2.0"
        /usr/bin/phpize && ./configure --enable-memcached-igbinary --with-php-config=/usr/bin/php-config
        make
        make install
        cd_dir "${DIR}"
        #rm -rf memcached-2.2.0.tgz memcached-2.2.0
    else
        cd "${DIR}" && wget ${PECL_PHP_LINK}/memcached-${PHP_MEMCACHED_VERSION}.tgz
        tar -xvf memcached-${PHP_MEMCACHED_VERSION}.tgz
        cd_dir "${DIR}/memcached-${PHP_MEMCACHED_VERSION}"
        /usr/bin/phpize && ./configure --enable-memcached-igbinary --with-php-config=/usr/bin/php-config
        make
        make install
        cd "${DIR}" && rm -rf memcached-${PHP_MEMCACHED_VERSION}.tgz memcached-${PHP_MEMCACHED_VERSION}
    fi

    if [[ -f "/usr/lib64/php/modules/memcached.so" ]]; then
        cat >> "/etc/php.d/50-memcached.ini" << EOF
extension=memcached.so
EOF
    else
        echo "${INST_MEMEXT_ERR}" >> ${LOG}
    fi
}

# Install Memcached
install_memcached(){
    yum -y install memcached libmemcached libmemcached-devel -y
    if [[ -f "/etc/sysconfig/memcached" ]]; then
        mv /etc/sysconfig/memcached /etc/sysconfig/memcached.bak
        cat >> "/etc/sysconfig/memcached" << EOMEMCACHED
PORT="11211"
USER="memcached"
MAXCONN="${MAX_CLIENT}"
CACHESIZE="256mb"
OPTIONS="-l 127.0.0.1 -U 0"
EOMEMCACHED
    fi
}

# Install Phpredis
install_php_redis(){
    if [[ "${PHP_VERSION}" -eq "56" ]]; then
        cd "${DIR}" && wget ${PECL_PHP_LINK}/redis-4.3.0.tgz
        tar -xvf redis-4.3.0.tgz
        cd_dir "${DIR}/redis-4.3.0"
        /usr/bin/phpize && ./configure --enable-redis-igbinary --with-php-config=/usr/bin/php-config
        make
        make install
        cd "${DIR}" && rm -rf redis-4.3.0.tgz redis-4.3.0
    else
        cd "${DIR}" && wget ${PECL_PHP_LINK}/redis-${PHP_REDIS_VERSION}.tgz
        tar -xvf redis-${PHP_REDIS_VERSION}.tgz
        cd_dir "${DIR}/redis-${PHP_REDIS_VERSION}"
        /usr/bin/phpize && ./configure --enable-redis-igbinary --with-php-config=/usr/bin/php-config
        make
        make install
        cd "${DIR}" && rm -rf redis-${PHP_REDIS_VERSION}.tgz redis-${PHP_REDIS_VERSION}
    fi

    if [[ -f "/usr/lib64/php/modules/redis.so" ]]; then
        cat >> "/etc/php.d/50-redis.ini" << EOF
extension=redis.so
EOF
    else
        echo "${INST_PHPREDIS_ERR}" >> ${LOG}
    fi

}

# Install Redis
install_redis(){
    yum --enablerepo=remi install redis -y
    mv /etc/redis.conf /etc/redis.conf.bak
cat >> "/etc/redis.conf" << EOFREDIS
maxmemory 256mb
maxmemory-policy allkeys-lru
save ""
EOFREDIS
}

install_cache(){
    echo ""
    install_igbinary

    if [[ -f "/usr/lib64/php/modules/igbinary.so" ]]; then
        install_php_memcached
        install_php_redis
    fi

    install_memcached
    install_redis
}

############################################
# Config Nginx
############################################
cal_ssl_cache_size(){
    if [[ "${RAM_TOTAL}" -gt '500000' && "${RAM_TOTAL}" -le '800000' ]]; then
        SSL_CACHE_SIZE=20
    elif [[ "${RAM_TOTAL}" -gt '800000' && "${RAM_TOTAL}" -le '1000000' ]]; then
        SSL_CACHE_SIZE=40
    elif [[ "${RAM_TOTAL}" -gt '1000000' && "${RAM_TOTAL}" -le '1880000' ]]; then
        SSL_CACHE_SIZE=60
    elif [[ "${RAM_TOTAL}" -gt '1880000' && "${RAM_TOTAL}" -le '2890000' ]]; then
        SSL_CACHE_SIZE=80
    elif [[ "${RAM_TOTAL}" -gt '2890000' && "${RAM_TOTAL}" -le '3890000' ]]; then
        SSL_CACHE_SIZE=150
    elif [[ "${RAM_TOTAL}" -gt '3890000' && "${RAM_TOTAL}" -le '7800000' ]]; then
        SSL_CACHE_SIZE=300
    elif [[ "${RAM_TOTAL}" -gt '7800000' && "${RAM_TOTAL}" -le '15600000' ]]; then
        SSL_CACHE_SIZE=500
    elif [[ "${RAM_TOTAL}" -gt '15600000' && "${RAM_TOTAL}" -le '23600000' ]]; then
        SSL_CACHE_SIZE=1000
    elif [[ "${RAM_TOTAL}" -gt '23600000' ]]; then
        SSL_CACHE_SIZE=2000
    else
        SSL_CACHE_SIZE=10
    fi
}

create_nginx_conf(){
    mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.orig
    cat >> "/etc/nginx/nginx.conf" << EONGINXCONF
user nginx;
worker_processes ${NGINX_PROCESSES};
worker_rlimit_nofile 260000;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  ${MAX_CLIENT};
    accept_mutex off;
    accept_mutex_delay 200ms;
    use epoll;
    #multi_accept on;
}

http {
    index  index.html index.htm index.php;
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    charset utf-8;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                  '\$status \$body_bytes_sent "\$http_referer" '
                  '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  off;
    server_tokens off;

    sendfile on;

    tcp_nopush on;
    tcp_nodelay off;

    types_hash_max_size 2048;
    server_names_hash_bucket_size 128;
    server_names_hash_max_size 10240;
    client_max_body_size 64m;
    client_body_buffer_size 128k;
    client_body_in_file_only off;
    client_body_timeout 60s;
    client_header_buffer_size 256k;
    client_header_timeout  20s;
    large_client_header_buffers 8 256k;
    keepalive_timeout 15;
    keepalive_disable msie6;
    reset_timedout_connection on;
    send_timeout 60s;

    disable_symlinks if_not_owner from=\$document_root;
    server_name_in_redirect off;

    open_file_cache max=2000 inactive=20s;
    open_file_cache_valid 120s;
    open_file_cache_min_uses 2;
    open_file_cache_errors off;

    # Limit Request
    limit_req_status 403;
    limit_conn_zone \$binary_remote_addr zone=one:10m;
    limit_req_zone \$binary_remote_addr zone=two:10m rate=5r/s;

    # Custom Response Headers
    add_header X-Powered-By ${AUTHOR};
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options nosniff;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload";
    add_header X-Download-Options noopen;

    include /etc/nginx/extra/gzip.conf;
    #include /etc/nginx/extra/brotli.conf
    include /etc/nginx/extra/ssl.conf;
    include /etc/nginx/extra/cloudflare.conf;
    include /etc/nginx/extra/webp.conf;
    include /etc/nginx/conf.d/*.conf;
}
EONGINXCONF
}

# Extra config
create_extra_conf(){
    #Create dhparams
    cal_ssl_cache_size
    mkdir -p /etc/nginx/ssl
    openssl dhparam -out /etc/nginx/ssl/dhparams.pem 2048

    # Include http block
    if [[ ! -d "/etc/nginx/extra" ]]; then
        mkdir -p /etc/nginx/extra
    fi

    cat >> "/etc/nginx/extra/brotli.conf" << EOFBRCONF
##Brotli Compression
brotli on;
brotli_static on;
brotli_buffers 16 8k;
brotli_comp_level 4;
brotli_types
    application/atom+xml
    application/geo+json
    application/javascript
    application/json
    application/ld+json
    application/manifest+json
    application/rdf+xml
    application/rss+xml
    application/vnd.ms-fontobject
    application/wasm
    application/x-font-opentype
    application/x-font-truetype
    application/x-font-ttf
    application/x-javascript
    application/x-web-app-manifest+json
    application/xhtml+xml
    application/xml
    application/xml+rss
    font/eot
    font/opentype
    font/otf
    image/bmp
    image/svg+xml
    image/vnd.microsoft.icon
    image/x-icon
    image/x-win-bitmap
    text/cache-manifest
    text/calendar
    text/css
    text/javascript
    text/markdown
    text/plain
    text/vcard
    text/vnd.rim.location.xloc
    text/vtt
    text/x-component
    text/x-cross-domain-policy
    text/xml;
EOFBRCONF

    cat >> "/etc/nginx/extra/gzip.conf" << EOFGZCONF
##Gzip Compression
gzip on;
gzip_static on;
gzip_disable msie6;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 2;
gzip_buffers 16 8k;
gzip_http_version 1.1;
gzip_min_length 256;
gzip_types
    application/atom+xml
    application/geo+json
    application/javascript
    application/json
    application/ld+json
    application/manifest+json
    application/rdf+xml
    application/rss+xml
    application/vnd.ms-fontobject
    application/wasm
    application/x-font-opentype
    application/x-font-truetype
    application/x-font-ttf
    application/x-javascript
    application/x-web-app-manifest+json
    application/xhtml+xml
    application/xml
    application/xml+rss
    font/eot
    font/opentype
    font/otf
    image/bmp
    image/svg+xml
    image/vnd.microsoft.icon
    image/x-icon
    image/x-win-bitmap
    text/cache-manifest
    text/calendar
    text/css
    text/javascript
    text/markdown
    text/plain
    text/vcard
    text/vnd.rim.location.xloc
    text/vtt
    text/x-component
    text/x-cross-domain-policy
    text/xml;
EOFGZCONF

    cat >> "/etc/nginx/extra/ssl.conf" << EOFSSLCONF
# SSL
ssl_session_timeout  1d;
ssl_session_cache    shared:SSL:${SSL_CACHE_SIZE}m;
ssl_session_tickets  off;

# Diffie-Hellman parameter for DHE ciphersuites
ssl_dhparam /etc/nginx/ssl/dhparams.pem;

# Mozilla Intermediate configuration
ssl_protocols        TLSv1.2 TLSv1.3;
ssl_ciphers          ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;

# OCSP Stapling
#ssl_stapling         on;
#ssl_stapling_verify  on;
resolver             1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4 208.67.222.222 208.67.220.220 valid=10m;
resolver_timeout     10s;
EOFSSLCONF

    cat >> "/etc/nginx/extra/webp.conf" << EOWEBP
map \$http_accept \$webpok {
    default   0;
    "~*webp"  1;
}

map \$http_cf_cache_status \$iscf {
    default   1;
    ""        0;
}

map \$webpok\$iscf \$webp_extension {
    11          "";
    10          ".webp";
    01          "";
    00          "";
}
EOWEBP

    cat >> "/etc/nginx/extra/cloudflare.conf" << EOCF
set_real_ip_from 103.21.244.0/22;
set_real_ip_from 103.22.200.0/22;
set_real_ip_from 103.31.4.0/22;
set_real_ip_from 104.16.0.0/12;
set_real_ip_from 108.162.192.0/18;
set_real_ip_from 131.0.72.0/22;
set_real_ip_from 141.101.64.0/18;
set_real_ip_from 162.158.0.0/15;
set_real_ip_from 172.64.0.0/13;
set_real_ip_from 173.245.48.0/20;
set_real_ip_from 188.114.96.0/20;
set_real_ip_from 190.93.240.0/20;
set_real_ip_from 197.234.240.0/22;
set_real_ip_from 198.41.128.0/17;
set_real_ip_from 199.27.128.0/21;
#set_real_ip_from 2400:cb00::/32;
#set_real_ip_from 2405:8100::/32;
#set_real_ip_from 2405:b500::/32;
#set_real_ip_from 2606:4700::/32;
#set_real_ip_from 2803:f800::/32;
real_ip_header CF-Connecting-IP;
EOCF

    # Include Server block
    cat >> "/etc/nginx/extra/staticfiles.conf" << EOSTATICFILES
location = /favicon.ico {
    log_not_found off;
    access_log off;
}
location = /robots.txt {
    allow all;
    log_not_found off;
    access_log off;
}
location ~* \.(gif|jpg|jpeg|png|ico|webp)\$ {
    gzip_static off;
    add_header Access-Control-Allow-Origin *;
    add_header Cache-Control "public, must-revalidate, proxy-revalidate, immutable, stale-while-revalidate=86400, stale-if-error=604800";
    access_log off;
    expires 30d;
    break;
}
location ~* \.(3gp|wmv|avi|asf|asx|mpg|mpeg|mp4|pls|mp3|mid|wav|swf|flv|exe|zip|tar|rar|gz|tgz|bz2|uha|7z|doc|docx|xls|xlsx|pdf|iso)\$ {
    gzip_static off;
    sendfile off;
    sendfile_max_chunk 1m;
    add_header Access-Control-Allow-Origin *;
    add_header Cache-Control "public, must-revalidate, proxy-revalidate, immutable, stale-while-revalidate=86400, stale-if-error=604800";
    access_log off;
    expires 30d;
    break;
}
location ~* \.(js)\$ {
    add_header Access-Control-Allow-Origin *;
    add_header Cache-Control "public, must-revalidate, proxy-revalidate, immutable, stale-while-revalidate=86400, stale-if-error=604800";
    access_log off;
    expires 30d;
    break;
}
location ~* \.(css)\$ {
    add_header Access-Control-Allow-Origin *;
    add_header Cache-Control "public, must-revalidate, proxy-revalidate, immutable, stale-while-revalidate=86400, stale-if-error=604800";
    access_log off;
    expires 30d;
    break;
}
location ~* \.(eot|svg|ttf|woff|woff2)\$ {
    add_header Access-Control-Allow-Origin *;
    add_header Cache-Control "public, must-revalidate, proxy-revalidate";
    access_log off;
    expires 365d;
    break;
}
EOSTATICFILES

    cat >> "/etc/nginx/extra/security.conf" << EOsecurity
# Return 403 forbidden for readme.(txt|html) or license.(txt|html) or example.(txt|html) or other common git repository files
location ~*  "/(^\$|readme|license|example|README|LEGALNOTICE|INSTALLATION|CHANGELOG)\.(txt|html|md)" {
    deny all;
}
# Deny backup extensions & log files and return 403 forbidden
location ~* "\.(old|orig|original|php#|php~|php_bak|save|swo|aspx?|tpl|sh|bash|bak?|cfg|cgi|dll|exe|git|hg|ini|jsp|log|mdb|out|sql|svn|swp|tar|rdf|gz|zip|bz2|7z|pem|asc|conf|dump)\$" {
    deny all;
}
location ~* "/(=|\/\$&|_mm|(wp-)?config\.|cgi-|etc/passwd|muieblack)" {
    deny all;
}
# block base64_encoded content
location ~* "(base64_encode)(.*)(\()" {
    deny all;
}
# block javascript eval()
location ~* "(eval\()" {
    deny all;
}
# Additional security settings
location ~* "(127\.0\.0\.1)" {
    deny all;
}
location ~* "([a-z0-9]{2000})" {
    deny all;
}
location ~* "(javascript\:)(.*)(\;)" {
    deny all;
}
location ~* "(GLOBALS|REQUEST)(=|\[|%)" {
    deny all;
}
location ~* "(<|%3C).*script.*(>|%3)" {
    deny all;
}
location ~* "(boot\.ini|etc/passwd|self/environ)" {
    deny all;
}
location ~* "(thumbs?(_editor|open)?|tim(thumb)?)\.php" {
    deny all;
}
location ~* "(https?|ftp|php):/" {
    deny all;
}
EOsecurity
}

vhost_custom(){
    REWRITE_CONFIG_PATH="/etc/nginx/rewrite"
    mkdir -p ${REWRITE_CONFIG_PATH}
cat >> "${REWRITE_CONFIG_PATH}/default.conf" << EOrewrite_default
location / {
    try_files \$uri \$uri/ /index.php?\$args;
}
EOrewrite_default

cat >> "${REWRITE_CONFIG_PATH}/codeigniter.conf" << EOrewrite_ci
location / {
    try_files \$uri \$uri/ /index.php?/\$request_uri;
}
EOrewrite_ci

cat >> "${REWRITE_CONFIG_PATH}/nextcloud.conf" << EOnextcloud
location / {
    rewrite ^ /index.php;
}
location ~ ^\/(?:build|tests|config|lib|3rdparty|templates|data)\/ {
    deny all;
}
location ~ ^\/(?:\.|autotest|occ|issue|indie|db_|console) {
    deny all;
}
location ~ ^\/(?:index|remote|public|cron|core\/ajax\/update|status|ocs\/v[12]|updater\/.+|oc[ms]-provider\/.+)\.php(?:\$|\/) {
    fastcgi_split_path_info ^(.+?\.php)(\/.*|)\$;
    try_files \$uri =404;
    include fastcgi_params;
    fastcgi_param PATH_INFO \$fastcgi_path_info;
    # Avoid sending the security headers twice
    fastcgi_param modHeadersAvailable true;
    # Enable pretty urls
    fastcgi_param front_controller_active true;
    fastcgi_pass {{upstream}};
    fastcgi_intercept_errors on;
    fastcgi_request_buffering off;
}
location ~ ^\/(?:updater|oc[ms]-provider)(?:\$|\/) {
    try_files \$uri/ =404;
    index index.php;
}
location ~ \.(?:css|js|woff2?|svg|gif|map)\$ {
    try_files \$uri /index.php\$request_uri;
    add_header Cache-Control "public, max-age=15778463";
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Robots-Tag none;
    add_header X-Download-Options noopen;
    add_header X-Permitted-Cross-Domain-Policies none;
    add_header Referrer-Policy no-referrer;
    access_log off;
}
location ~ \.(?:png|html|ttf|ico|jpg|jpeg|bcmap)\$ {
    try_files \$uri /index.php\$request_uri;
    access_log off;
}
EOnextcloud

cat >> "${REWRITE_CONFIG_PATH}/discuz.conf" << EOrewrite_discuz
location / {
    rewrite ^([^\.]*)/topic-(.+)\.html\$ \$1/portal.php?mod=topic&topic=\$2 last;
    rewrite ^([^\.]*)/article-([0-9]+)-([0-9]+)\.html\$ \$1/portal.php?mod=view&aid=\$2&page=\$3 last;
    rewrite ^([^\.]*)/forum-(\w+)-([0-9]+)\.html\$ \$1/forum.php?mod=forumdisplay&fid=\$2&page=\$3 last;
    rewrite ^([^\.]*)/thread-([0-9]+)-([0-9]+)-([0-9]+)\.html\$ \$1/forum.php?mod=viewthread&tid=\$2&extra=page%3D\$4&page=\$3 last;
    rewrite ^([^\.]*)/group-([0-9]+)-([0-9]+)\.html\$ \$1/forum.php?mod=group&fid=\$2&page=\$3 last;
    rewrite ^([^\.]*)/space-(username|uid)-(.+)\.html\$ \$1/home.php?mod=space&\$2=\$3 last;
    rewrite ^([^\.]*)/blog-([0-9]+)-([0-9]+)\.html\$ \$1/home.php?mod=space&uid=\$2&do=blog&id=\$3 last;
    rewrite ^([^\.]*)/(fid|tid)-([0-9]+)\.html\$ \$1/index.php?action=\$2&value=\$3 last;
    rewrite ^([^\.]*)/([a-z]+[a-z0-9_]*)-([a-z0-9_\-]+)\.html\$ \$1/plugin.php?id=\$2:\$3 last;
}
EOrewrite_discuz

cat >> "${REWRITE_CONFIG_PATH}/drupal.conf" << EOrewrite_drupal
location / {
    try_files \$uri /index.php?\$query_string;
}
location ~ \..*/.*\.php\$ {
    return 403;
}
location ~ ^/sites/.*/private/ {
    return 403;
}
# Block access to scripts in site files directory
location ~ ^/sites/[^/]+/files/.*\.php\$ {
    deny all;
}
location ~ (^|/)\. {
    return 403;
}
location @rewrite {
    rewrite ^/(.*)\$ /index.php?q=\$1;
}
location ~ /vendor/.*\.php\$ {
    deny all;
    return 404;
}
location ~* \.(engine|inc|install|make|module|profile|po|sh|.*sql|theme|twig|tpl(\.php)?|xtmpl|yml)(~|\.sw[op]|\.bak|\.orig|\.save)?\$|composer\.(lock|json)\$|web\.config\$|^(\.(?!well-known).*|Entries.*|Repository|Root|Tag|Template)\$|^#.*#\$|\.php(~|\.sw[op]|\.bak|\.orig|\.save)\$ {
    deny all;
    return 404;
}
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {
    try_files \$uri @rewrite;
    expires max;
    log_not_found off;
}
location ~ ^/sites/.*/files/styles/ { # For Drupal >= 7
    try_files \$uri @rewrite;
}
location ~ ^(/[a-z\-]+)?/system/files/ { # For Drupal >= 7
    try_files \$uri /index.php?\$query_string;
}
if (\$request_uri ~* "^(.*/)index\.php/(.*)") {
    return 307 \$1\$2;
}
EOrewrite_drupal

cat >> "${REWRITE_CONFIG_PATH}/ecshop.conf" << EOrewrite_ecshop
if (!-e \$request_filename) {
    rewrite "^/index\.html" /index.php last;
    rewrite "^/category\$" /index.php last;
    rewrite "^/feed-c([0-9]+)\.xml\$" /feed.php?cat=\$1 last;
    rewrite "^/feed-b([0-9]+)\.xml\$" /feed.php?brand=\$1 last;
    rewrite "^/feed\.xml\$" /feed.php last;
    rewrite "^/category-([0-9]+)-b([0-9]+)-min([0-9]+)-max([0-9]+)-attr([^-]*)-([0-9]+)-(.+)-([a-zA-Z]+)(.*)\.html\$" /category.php?id=\$1&brand=\$2&price_min=\$3&price_max=\$4&filter_attr=\$5&page=\$6&sort=\$7&order=\$8 last;
    rewrite "^/category-([0-9]+)-b([0-9]+)-min([0-9]+)-max([0-9]+)-attr([^-]*)(.*)\.html\$" /category.php?id=\$1&brand=\$2&price_min=\$3&price_max=\$4&filter_attr=\$5 last;
    rewrite "^/category-([0-9]+)-b([0-9]+)-([0-9]+)-(.+)-([a-zA-Z]+)(.*)\.html\$" /category.php?id=\$1&brand=\$2&page=\$3&sort=\$4&order=\$5 last;
    rewrite "^/category-([0-9]+)-b([0-9]+)-([0-9]+)(.*)\.html\$" /category.php?id=\$1&brand=\$2&page=\$3 last;
    rewrite "^/category-([0-9]+)-b([0-9]+)(.*)\.html\$" /category.php?id=\$1&brand=\$2 last;
    rewrite "^/category-([0-9]+)(.*)\.html\$" /category.php?id=\$1 last;
    rewrite "^/goods-([0-9]+)(.*)\.html" /goods.php?id=\$1 last;
    rewrite "^/article_cat-([0-9]+)-([0-9]+)-(.+)-([a-zA-Z]+)(.*)\.html\$" /article_cat.php?id=\$1&page=\$2&sort=\$3&order=\$4 last;
    rewrite "^/article_cat-([0-9]+)-([0-9]+)(.*)\.html\$" /article_cat.php?id=\$1&page=\$2 last;
    rewrite "^/article_cat-([0-9]+)(.*)\.html\$" /article_cat.php?id=\$1 last;
    rewrite "^/article-([0-9]+)(.*)\.html\$" /article.php?id=\$1 last;
    rewrite "^/brand-([0-9]+)-c([0-9]+)-([0-9]+)-(.+)-([a-zA-Z]+)\.html" /brand.php?id=\$1&cat=\$2&page=\$3&sort=\$4&order=\$5 last;
    rewrite "^/brand-([0-9]+)-c([0-9]+)-([0-9]+)(.*)\.html" /brand.php?id=\$1&cat=\$2&page=\$3 last;
    rewrite "^/brand-([0-9]+)-c([0-9]+)(.*)\.html" /brand.php?id=\$1&cat=\$2 last;
    rewrite "^/brand-([0-9]+)(.*)\.html" /brand.php?id=\$1 last;
    rewrite "^/tag-(.*)\.html" /search.php?keywords=\$1 last;
    rewrite "^/snatch-([0-9]+)\.html\$" /snatch.php?id=\$1 last;
    rewrite "^/group_buy-([0-9]+)\.html\$" /group_buy.php?act=view&id=\$1 last;
    rewrite "^/auction-([0-9]+)\.html\$" /auction.php?act=view&id=\$1 last;
    rewrite "^/exchange-id([0-9]+)(.*)\.html\$" /exchange.php?id=\$1&act=view last;
    rewrite "^/exchange-([0-9]+)-min([0-9]+)-max([0-9]+)-([0-9]+)-(.+)-([a-zA-Z]+)(.*)\.html\$" /exchange.php?cat_id=\$1&integral_min=\$2&integral_max=\$3&page=\$4&sort=\$5&order=\$6 last;
    rewrite "^/exchange-([0-9]+)-([0-9]+)-(.+)-([a-zA-Z]+)(.*)\.html\$" /exchange.php?cat_id=\$1&page=\$2&sort=\$3&order=\$4 last;
    rewrite "^/exchange-([0-9]+)-([0-9]+)(.*)\.html\$" /exchange.php?cat_id=\$1&page=\$2 last;
    rewrite "^/exchange-([0-9]+)(.*)\.html\$" /exchange.php?cat_id=\$1 last;
}
EOrewrite_ecshop

cat >> "${REWRITE_CONFIG_PATH}/xenforo.conf" << EOrewrite_xenforo
location / {
    try_files \$uri \$uri/ /index.php?\$uri&\$args;
}
location /install/data/ {
    internal;
}

location /install/templates/ {
    internal;
}

location /internal_data/ {
    internal;
}

location /library/ {
    internal;
}

location /src/ {
    internal;
}
EOrewrite_xenforo

cat >> "${REWRITE_CONFIG_PATH}/joomla.conf" << EOjoomla
location / {
    try_files \$uri \$uri/ /index.php?\$args;
}
EOjoomla

cat >> "${REWRITE_CONFIG_PATH}/laravel.conf" << EOlaravel
location / {
    try_files \$uri \$uri/ /index.php?\$query_string;
}
location ~ /\.(ht|svn|env|git) {
    deny all;
    access_log off;
    log_not_found off;
}
EOlaravel

cat >> "${REWRITE_CONFIG_PATH}/whmcs.conf" << EOwhmcs
location ~ /announcements/?(.*)\$ {
    rewrite ^/(.*)\$ /index.php?rp=/announcements/\$1;
}

location ~ /download/?(.*)\$ {
    rewrite ^/(.*)\$ /index.php?rp=/download\$1;
}

location ~ /knowledgebase/?(.*)\$ {
    rewrite ^/(.*)\$ /index.php?rp=/knowledgebase/\$1;
}

location ~ /store/ssl-certificates/?(.*)\$ {
    rewrite ^/(.*)\$ /index.php?rp=/store/ssl-certificates/\$1;
}

location ~ /store/sitelock/?(.*)\$ {
    rewrite ^/(.*)\$ /index.php?rp=/store/sitelock/\$1;
}

location ~ /store/website-builder/?(.*)\$ {
    rewrite ^/(.*)\$ /index.php?rp=/store/website-builder/\$1;
}

location ~ /store/order/?(.*)\$ {
    rewrite ^/(.*)\$ /index.php?rp=/store/order/\$1;
}

location ~ /cart/domain/renew/?(.*)\$ {
    rewrite ^/(.*)\$ /index.php?rp=/cart/domain/renew\$1;
}

location ~ /account/paymentmethods/?(.*)\$ {
    rewrite ^/(.*)\$ /index.php?rp=/account/paymentmethods\$1;
}

location ~ /admin/(addons|apps|domains|help\/license|services|setup|utilities\/system\/php-compat)(.*) {
    rewrite ^/(.*)\$ /admin/index.php?rp=/admin/\$1\$2 last;
}
EOwhmcs

cat >> "${REWRITE_CONFIG_PATH}/wordpress.conf" << EOwordpress
location / {
    try_files \$uri \$uri/ /index.php?\$args;
}
rewrite /wp-admin\$ \$scheme://\$host\$uri/ permanent;

# Disable XML-RPC
location ~ xmlrpc.php { deny all; access_log off; log_not_found off; }

# Reduce Comment Spam
location = /wp-comments-post.php {
    limit_except POST { deny all; access_log off; }
    if (\$http_user_agent ~ "^\$") { return 403; }
    valid_referers server_names jetpack.wordpress.com/jetpack-comment/;
    if (\$invalid_referer) { return 403; }
}

# Protect System Files
location = /wp-admin/install.php { deny all; access_log off; log_not_found off; }
location ~ ^/wp-admin/includes/ { deny all; access_log off; log_not_found off; }
location ~ ^/wp-includes/[^/]+\.php\$ { deny all; access_log off; log_not_found off; }
location ~ ^/wp-includes/js/tinymce/langs/.+\.php\$ { deny all; access_log off; log_not_found off; }
location ~ ^/wp-includes/theme-compat/ { deny all; access_log off; log_not_found off; }

#Deny access to wp-content folders for suspicious files
location ~* ^/(wp-content)/(.*?)\.(gz|tar|bzip2|7z|php|php5|php7|log|error|py|pl|kid|love)\$ { deny all; access_log off; log_not_found off; }
location ~ ^/wp-content/updraft { deny all; access_log off; log_not_found off; }
location ~* /wp-content/uploads/nginx-helper/ { deny all; access_log off; log_not_found off; }

# Disable PHP in Uploads
location ~ ^/wp\-content/uploads/.*\.(?:php[1-7]?|pht|log|error|py|pl|kid|love|phtml?|phps)\$ { deny all; access_log off; log_not_found off; }

# Disable PHP in Plugins
location ~ ^/wp\-content/plugins/.*\.(?:php[1-7]?|pht|log|error|py|pl|kid|love|phtml?|phps)\$ { deny all; access_log off; log_not_found off; }

# Disable PHP in Themes
location ~ ^/wp\-content/themes/.*\.(?:php[1-7]?|pht|log|error|py|pl|kid|love|phtml?|phps)\$ { deny all; access_log off; log_not_found off; }

# WordPress: deny general stuff
location ~* ^/(?:xmlrpc\.php|wp-links-opml\.php|wp-config\.php|wp-config-sample\.php|wp-comments-post\.php|readme\.html|license\.txt)\$ {
    deny all;
}

#Block API User
location ~* /wp-json/wp/v2/users {
    allow 127.0.0.1;
    deny all;
    access_log off;
    log_not_found off;
}

# webp rewrite rules for EWWW testing image
location /wp-content/plugins/ewww-image-optimizer/images {
    location ~ \.(png|jpe?g)\$ {
        add_header Vary "Accept-Encoding";
        more_set_headers 'Access-Control-Allow-Origin : *';
        more_set_headers  "Cache-Control : public, no-transform";
        access_log off;
        log_not_found off;
        expires max;
        try_files \$uri\$webp_suffix \$uri =404;
    }
    location ~ \.php\$ {
        #Prevent Direct Access Of PHP Files From Web Browsers
        deny all;
    }
}

# enable gzip on static assets - php files are forbidden
location /wp-content/cache {
# Cache css & js files
    location ~* \.(?:css(\.map)?|js(\.map)?|.html)\$ {
        more_set_headers 'Access-Control-Allow-Origin : *';
        access_log off;
        log_not_found off;
        expires 30d;
    }
    location ~ \.php\$ {
        #Prevent Direct Access Of PHP Files From Web Browsers
        deny all;
    }
}

# Protect Easy Digital Download files from being accessed directly.
location ~ ^/wp-content/uploads/edd/(.*?)\.zip\$ {
    rewrite / permanent;
}

#Yoast SEO Sitemaps
location ~* ^/wp-content/plugins/wordpress-seo(?:-premium)?/css/main-sitemap\.xsl\$ {}
location ~ ([^/]*)sitemap(.*).x(m|s)l\$ {
    ## this rewrites sitemap.xml to /sitemap_index.xml
    rewrite ^/sitemap.xml\$ /sitemap_index.xml permanent;
    ## this makes the XML sitemaps work
    rewrite ^/([a-z]+)?-?sitemap.xsl\$ /index.php?yoast-sitemap-xsl=\$1 last;
    rewrite ^/sitemap_index.xml\$ /index.php?sitemap=1 last;
    rewrite ^/([^/]+?)-sitemap([0-9]+)?.xml\$ /index.php?sitemap=\$1&sitemap_n=\$2 last;
    ## The following lines are optional for the premium extensions
    ## News SEO
    rewrite ^/news-sitemap.xml\$ /index.php?sitemap=wpseo_news last;
    ## Local SEO
    rewrite ^/locations.kml\$ /index.php?sitemap=wpseo_local_kml last;
    rewrite ^/geo-sitemap.xml\$ /index.php?sitemap=wpseo_local last;
    ## Video SEO
    rewrite ^/video-sitemap.xsl\$ /index.php?yoast-sitemap-xsl=video last;
}

# RANK MATH SEO plugin
rewrite ^/sitemap_index.xml\$ /index.php?sitemap=1 last;
rewrite ^/([^/]+?)-sitemap([0-9]+)?.xml\$ /index.php?sitemap=\$1&sitemap_n=\$2 last;

# webp extension
location ~ ^/wp-content/uploads/ {
    location ~* ^/wp-content/uploads/(.+/)?(.+)\.(png|jpe?g)\$ {
        expires 30d;
        add_header Vary "Accept";
        add_header Cache-Control "public, no-transform";
        try_files \$uri\$webp_extension \$uri =404;
    }
}
EOwordpress

cat >> "${REWRITE_CONFIG_PATH}/prestashop.conf" << EOprestashop
location / {
    rewrite ^/api/?(.*)\$ /webservice/dispatcher.php?url=\$1 last;
    rewrite ^/([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\.jpg\$ /img/p/\$1/\$1\$2.jpg last;
    rewrite ^/([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\.jpg\$ /img/p/\$1/\$2/\$1\$2\$3.jpg last;
    rewrite ^/([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\.jpg\$ /img/p/\$1/\$2/\$3/\$1\$2\$3\$4.jpg last;
    rewrite ^/([0-9])([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\.jpg\$ /img/p/\$1/\$2/\$3/\$4/\$1\$2\$3\$4\$5.jpg last;
    rewrite ^/([0-9])([0-9])([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\.jpg\$ /img/p/\$1/\$2/\$3/\$4/\$5/\$1\$2\$3\$4\$5\$6.jpg last;
    rewrite ^/([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\.jpg\$ /img/p/\$1/\$2/\$3/\$4/\$5/\$6/\$1\$2\$3\$4\$5\$6\$7.jpg last;
    rewrite ^/([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\.jpg\$ /img/p/\$1/\$2/\$3/\$4/\$5/\$6/\$7/\$1\$2\$3\$4\$5\$6\$7\$8.jpg last;
    rewrite ^/([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])([0-9])(-[_a-zA-Z0-9-]*)?(-[0-9]+)?/.+\.jpg\$ /img/p/\$1/\$2/\$3/\$4/\$5/\$6/\$7/\$8/\$1\$2\$3\$4\$5\$6\$7\$8\$9.jpg last;
    rewrite ^/c/([0-9]+)(-[_a-zA-Z0-9-]*)(-[0-9]+)?/.+\.jpg\$ /img/c/\$1\$2.jpg last;
    rewrite ^/c/([a-zA-Z-]+)(-[0-9]+)?/.+\.jpg\$ /img/c/\$1.jpg last;
    rewrite ^/([0-9]+)(-[_a-zA-Z0-9-]*)(-[0-9]+)?/.+\.jpg\$ /img/c/\$1\$2.jpg last;

    try_files \$uri \$uri/ /index.php?\$args;
}
EOprestashop

cat >> "${REWRITE_CONFIG_PATH}/opencart.conf" << EOopencart
rewrite /admin\$ \$scheme://\$host\$uri/ permanent;
rewrite ^/download/(.*) /index.php?route=error/not_found last;
rewrite ^/image-smp/(.*) /index.php?route=product/smp_image&name=\$1 break;
location = /sitemap.xml {
    rewrite ^(.*)\$ /index.php?route=feed/google_sitemap break;
}
location = /googlebase.xml {
    rewrite ^(.*)\$ /index.php?route=feed/google_base break;
}
location / {
    # This try_files directive is used to enable SEO-friendly URLs for OpenCart
    try_files \$uri \$uri/ @opencart;
}
location @opencart {
    rewrite ^/(.+)\$ /index.php?_route_=\$1 last;
}
location /admin {
    index index.php;
}
EOopencart

cat >> "${REWRITE_CONFIG_PATH}/yii.conf" << EOyii
location / {
    try_files \$uri \$uri/ /index.php\$is_args\$args;
}
location ~ \.(js|css|png|jpg|gif|swf|ico|pdf|mov|fla|zip|rar)$ {
    try_files \$uri =404;
}
location ~ /\.(ht|svn|git) {
    deny all;
    access_log off;
    log_not_found off;
}
EOyii
}

# Config default server block
default_vhost(){
    NGINX_VHOST_PATH="/etc/nginx/conf.d"
    mkdir -p ${USR_DIR}/nginx/auth
    if [[ -f "${NGINX_VHOST_PATH}/default.conf" ]]; then
        mv ${NGINX_VHOST_PATH}/default.conf ${NGINX_VHOST_PATH}/default.conf.orig
    fi
cat >> "${NGINX_VHOST_PATH}/default.conf" << EOdefault_vhost
server {
    listen 80 default_server;
    #listen [::]:80 default_server;
}

server {
    listen ${IPADDRESS}:${RANDOM_ADMIN_PORT};
    listen       127.0.0.1:${RANDOM_ADMIN_PORT};
    #listen [::]:${RANDOM_ADMIN_PORT};

    server_name ${IPADDRESS};

    access_log off;
    log_not_found off;
    error_log /var/log/nginx_error.log;

    root /usr/share/nginx/html/;
    index index.php index.html index.htm;

    location ~ ^/(\.user.ini|\.htaccess|\.htpasswd|\.user\.ini|\.ht|\.env|\.git|\.svn|\.project|LICENSE|README.md) {
        deny all;
        access_log off;
        log_not_found off;
    }
    location ^~ /phpmyadmin {
        root /usr/share/nginx/html/;
        index index.php index.html index.htm;
        location ~ ^/phpmyadmin/(.+\.php)\$ {
            try_files \$uri =404;
            fastcgi_split_path_info ^(.+\.php)(/.+)\$;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_connect_timeout 1000;
            fastcgi_send_timeout 1000;
            fastcgi_read_timeout 1000;
            fastcgi_buffer_size 256k;
            fastcgi_buffers 4 256k;
            fastcgi_busy_buffers_size 256k;
            fastcgi_temp_file_write_size 256k;
            fastcgi_intercept_errors on;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            if (-f \$request_filename)
            {
                fastcgi_pass unix:/var/run/php-fpm.sock;
            }
        }
        location ~* ^/phpmyadmin/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|webp|xml|txt))\$ {
            root /usr/share/nginx/html/;
        }
    }

    location ^~ /opcache {
        root /usr/share/nginx/html/;
        index index.php index.html index.htm;

        auth_basic "Restricted";
        auth_basic_user_file ${USR_DIR}/nginx/auth/.htpasswd;

        location ~ ^/opcache/(.+\.php)\$ {
            try_files \$uri =404;
            fastcgi_split_path_info ^(.+\.php)(/.+)\$;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_connect_timeout 1000;
            fastcgi_send_timeout 1000;
            fastcgi_read_timeout 1000;
            fastcgi_buffer_size 256k;
            fastcgi_buffers 4 256k;
            fastcgi_busy_buffers_size 256k;
            fastcgi_temp_file_write_size 256k;
            fastcgi_intercept_errors on;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            if (-f \$request_filename)
            {
                fastcgi_pass unix:/var/run/php-fpm.sock;
            }
        }
        location ~* ^/opcache/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|webp|xml|txt))\$ {
            root /usr/share/nginx/html/;
        }
    }

    location ^~ /serverinfo {
        root /usr/share/nginx/html/;
        index index.php index.html index.htm;

        auth_basic "Restricted";
        auth_basic_user_file ${USR_DIR}/nginx/auth/.htpasswd;

        location ~ ^/serverinfo/(.+\.php)\$ {
            try_files \$uri =404;
            fastcgi_split_path_info ^(.+\.php)(/.+)\$;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_connect_timeout 1000;
            fastcgi_send_timeout 1000;
            fastcgi_read_timeout 1000;
            fastcgi_buffer_size 256k;
            fastcgi_buffers 4 256k;
            fastcgi_busy_buffers_size 256k;
            fastcgi_temp_file_write_size 256k;
            fastcgi_intercept_errors on;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            if (-f \$request_filename)
            {
                fastcgi_pass unix:/var/run/php-fpm.sock;
            }
        }
        location ~* ^/serverinfo/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|webp|xml|txt))\$ {
            root /usr/share/nginx/html/;
        }
    }

    location ~ ^/pma {
        rewrite ^/* /phpmyadmin last;
    }
    location ^~ /phpmyadmin/locale/ {
        deny all;
        access_log off;
        log_not_found off;
    }
    location ^~ /phpmyadmin/doc/ {
        deny all;
        access_log off;
        log_not_found off;
    }
    location ^~ /phpmyadmin/log/ {
        deny all;
        access_log off;
        log_not_found off;
    }
    location ^~ /phpmyadmin/tmp/ {
        deny all;
        access_log off;
        log_not_found off;
    }
    location ^~ /phpmyadmin/libraries/ {
        deny all;
        access_log off;
        log_not_found off;
    }
    location ^~ /phpmyadmin/templates/ {
        deny all;
        access_log off;
        log_not_found off;
    }
    location ^~ /phpmyadmin/sql/ {
        deny all;
        access_log off;
        log_not_found off;
    }
    location ^~ /phpmyadmin/vendor/ {
        deny all;
    }
    location ^~ /phpmyadmin/examples/ {
        deny all;
        access_log off;
        log_not_found off;
    }

    location /nginx_status {
        stub_status on;
        access_log   off;
        allow 127.0.0.1;
        allow ${IPADDRESS};
        deny all;
    }

    location /php_status {
        fastcgi_pass unix:/var/run/php-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
        include /etc/nginx/fastcgi_params;
        allow 127.0.0.1;
        allow ${IPADDRESS};
        deny all;
    }

    include /etc/nginx/extra/staticfiles.conf;
}
EOdefault_vhost
}

default_index(){
    if [[ -f "${DEFAULT_DIR_WEB}/index.html" ]]; then
        rm -rf ${DEFAULT_DIR_WEB}/index.html
        cat >> "${DEFAULT_DIR_WEB}/index.html" << EOdefault_index
<!DOCTYPE html>
<html lang="en">
    <head>
        <title>Site Maintenance</title>
        <style>
          body{text-align:center;padding:150px}
          h1{font-size:50px}
          body{font:20px Helvetica,sans-serif;color:#333}
          article{display:block;text-align:left;max-width:650px;margin:0 auto}
          a{color:#dc8100;text-decoration:none}
          a:hover{color:#333;text-decoration:none}
        </style>
    </head>
    <body>
        <article>
            <h1>We'll be back soon!</h1>
            <div>
                <p>Sorry for the inconvenience but we're performing some maintenance at the moment. If you need to you can always
                <a href="mailto:${AUTHOR_CONTACT}">contact us</a>, otherwise we'll be back online shortly!</p>
                <p>${AUTHOR}</p>
            </div>
        </article>
    </body>
</html>
EOdefault_index
    fi
}

default_error_page(){
    if [[ -f "${DEFAULT_DIR_WEB}/50x.html" ]]; then
        rm -rf ${DEFAULT_DIR_WEB}/50x.html
        cat >> "${DEFAULT_DIR_WEB}/50x.html" << EOdefault_index
<!DOCTYPE html>
<html lang="en">
    <head>
        <title>Error</title>
        <style>
          body{text-align:center;padding:150px}
          h1{font-size:50px}
          body{font:20px Helvetica,sans-serif;color:#333}
          article{display:block;text-align:left;max-width:650px;margin:0 auto}
          a{color:#dc8100;text-decoration:none}
          a:hover{color:#333;text-decoration:none}
        </style>
    </head>
    <body>
        <article>
            <h1>An error occurred.</h1>
            <div>
                <p>Sorry, the page you are looking for is currently unavailable. Please try again later. If you need to you can always
                <a href="mailto:${AUTHOR_CONTACT}">contact us</a>, otherwise we'll be back online shortly!</p>
                <p>${AUTHOR}</p>
            </div>
        </article>
    </body>
</html>
EOdefault_index
    fi
}

config_nginx(){
    echo ""
    create_nginx_conf
    create_extra_conf
    vhost_custom
    default_vhost
    default_index
    default_error_page
}

############################################
# Config PHP-FPM
############################################
# PHP Parameter
php_parameter(){
    if [[ "${CPU_CORES}" -ge '4' && "${CPU_CORES}" -lt '6' && "${RAM_TOTAL}" -gt '1049576' && "${RAM_TOTAL}" -le '2097152' ]]; then
        PM_MAX_CHILDREN="${CPU_CORES}*6"
        PM_START_SERVERS="${CPU_CORES}*4"
        PM_MIN_SPARE_SERVER="${CPU_CORES}*2"
        PM_MAX_SPARE_SERVER="${CPU_CORES}*6"
    elif [[ "${CPU_CORES}" -ge '4' && "${CPU_CORES}" -lt '6' && "${RAM_TOTAL}" -gt '2097152' && "${RAM_TOTAL}" -le '3145728' ]]; then
        PM_MAX_CHILDREN="${CPU_CORES}*6"
        PM_START_SERVERS="${CPU_CORES}*4"
        PM_MIN_SPARE_SERVER="${CPU_CORES}*2"
        PM_MAX_SPARE_SERVER="${CPU_CORES}*6"
    elif [[ "${CPU_CORES}" -ge '4' && "${CPU_CORES}" -lt '6' && "${RAM_TOTAL}" -gt '3145728' && "${RAM_TOTAL}" -le '4194304' ]]; then
        PM_MAX_CHILDREN="${CPU_CORES}*6"
        PM_START_SERVERS="${CPU_CORES}*4"
        PM_MIN_SPARE_SERVER="${CPU_CORES}*2"
        PM_MAX_SPARE_SERVER="${CPU_CORES}*6"
    elif [[ "${CPU_CORES}" -ge '4' && "${CPU_CORES}" -lt '6' && "${RAM_TOTAL}" -gt '4194304' ]]; then
        PM_MAX_CHILDREN="${CPU_CORES}*6"
        PM_START_SERVERS="${CPU_CORES}*4"
        PM_MIN_SPARE_SERVER="${CPU_CORES}*2"
        PM_MAX_SPARE_SERVER="${CPU_CORES}*6"
    elif [[ "${CPU_CORES}" -ge '6' && "${CPU_CORES}" -lt '8' && "${RAM_TOTAL}" -gt '3145728' && "${RAM_TOTAL}" -le '4194304' ]]; then
        PM_MAX_CHILDREN="${CPU_CORES}*6"
        PM_START_SERVERS="${CPU_CORES}*4"
        PM_MIN_SPARE_SERVER="${CPU_CORES}*2"
        PM_MAX_SPARE_SERVER="${CPU_CORES}*6"
    elif [[ "${CPU_CORES}" -ge '6' && "${CPU_CORES}" -lt '8' && "${RAM_TOTAL}" -gt '4194304' ]]; then
        PM_MAX_CHILDREN="${CPU_CORES}*6"
        PM_START_SERVERS="${CPU_CORES}*4"
        PM_MIN_SPARE_SERVER="${CPU_CORES}*2"
        PM_MAX_SPARE_SERVER="${CPU_CORES}*6"
    elif [[ "${CPU_CORES}" -ge '8' && "${CPU_CORES}" -lt '16' && "${RAM_TOTAL}" -gt '3145728' && "${RAM_TOTAL}" -le '4194304' ]]; then
        PM_MAX_CHILDREN="${CPU_CORES}*6"
        PM_START_SERVERS="${CPU_CORES}*4"
        PM_MIN_SPARE_SERVER="${CPU_CORES}*2"
        PM_MAX_SPARE_SERVER="${CPU_CORES}*6"
    elif [[ "${CPU_CORES}" -ge '8' && "${CPU_CORES}" -lt '12' && "${RAM_TOTAL}" -gt '4194304' ]]; then
        PM_MAX_CHILDREN="${CPU_CORES}*6"
        PM_START_SERVERS="${CPU_CORES}*4"
        PM_MIN_SPARE_SERVER="${CPU_CORES}*2"
        PM_MAX_SPARE_SERVER="${CPU_CORES}*6"
    elif [[ "${CPU_CORES}" -ge '13' && "${CPU_CORES}" -lt '16' && "${RAM_TOTAL}" -gt '4194304' ]]; then
        PM_MAX_CHILDREN="${CPU_CORES}*6"
        PM_START_SERVERS="${CPU_CORES}*4"
        PM_MIN_SPARE_SERVER="${CPU_CORES}*2"
        PM_MAX_SPARE_SERVER="${CPU_CORES}*6"
    elif [[ "${CPU_CORES}" -ge '17' && "${RAM_TOTAL}" -gt '4194304' ]]; then
        PM_MAX_CHILDREN="${CPU_CORES}*5"
        PM_START_SERVERS="${CPU_CORES}*4"
        PM_MIN_SPARE_SERVER="${CPU_CORES}*2"
        PM_MAX_SPARE_SERVER="${CPU_CORES}*5"
    else
        PM_MAX_CHILDREN=$(echo "scale=0;${RAM_MB}*0.4/30" | bc)
        PM_START_SERVERS="${CPU_CORES}*4"
        PM_MIN_SPARE_SERVER="${CPU_CORES}*2"
        PM_MAX_SPARE_SERVER="${CPU_CORES}*4"
    fi
}

php_global_config(){
    php_parameter
    if [[ -f "/etc/php-fpm.conf" ]]; then
        mv /etc/php-fpm.conf /etc/php-fpm.conf.orig
    fi
    if [[ ! -d "/var/run/php-fpm" ]]; then
        mkdir -p /var/run/php-fpm
    fi
    cat >> "/etc/php-fpm.conf" << EOphp_fpm_conf
;;;;;;;;;;;;;;;;;;;;;
; FPM Configuration ;
;;;;;;;;;;;;;;;;;;;;;

include=/etc/php-fpm.d/*.conf

[global]
pid = /var/run/php-fpm/php-fpm.pid
error_log = /var/log/php-fpm/error.log
log_level = warning
emergency_restart_threshold = 10
emergency_restart_interval = 1m
process_control_timeout = 10s
daemonize = yes
EOphp_fpm_conf

    if [[ -f "/etc/php-fpm.d/www.conf" ]]; then
        mv /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.orig
    fi
cat >> "/etc/php-fpm.d/www.conf" << EOwww_conf
[www]
listen = /var/run/php-fpm.sock;
listen.backlog = -1
listen.allowed_clients = 127.0.0.1
listen.owner = nginx
listen.group = nginx
listen.mode = 0660
user = nginx
group = nginx
pm = dynamic
pm.max_children = ${PM_MAX_CHILDREN}
pm.start_servers = ${PM_START_SERVERS}
pm.min_spare_servers =  ${PM_MIN_SPARE_SERVER}
pm.max_spare_servers = ${PM_MAX_SPARE_SERVER}
pm.max_requests = 2000
request_terminate_timeout = 300
rlimit_files = 65536
rlimit_core = 0
;slowlog = /var/log/php-fpm/www-slow.log
chdir = /
php_admin_value[error_log] = /var/log/php-fpm/www-error.log
php_admin_flag[log_errors] = on
php_value[session.save_handler] = files
php_value[session.save_path]    = /var/lib/php/session
php_value[soap.wsdl_cache_dir]  = /var/lib/php/wsdlcache
php_admin_value[disable_functions] = exec,system,passthru,shell_exec,dl,show_source,posix_kill,posix_mkfifo,posix_getpwuid,posix_setpgid,posix_setsid,posix_setuid,posix_setgid,posix_seteuid,posix_setegid,posix_uname
;php_admin_value[disable_functions] = exec,system,passthru,shell_exec,proc_close,proc_open,dl,popen,show_source,posix_kill,posix_mkfifo,posix_getpwuid,posix_setpgid,posix_setsid,posix_setuid,posix_setgid,posix_seteuid,posix_setegid,posix_uname
;php_admin_value[open_basedir] = ${DEFAULT_DIR_WEB}/:/tmp/:/var/tmp/:/dev/urandom:/usr/share/php/:/dev/shm:/var/lib/php/sessions/
security.limit_extensions = .php
EOwww_conf

    if [[ ! -d "/var/lib/php/session" ]]; then
        mkdir -p /var/lib/php/session
    fi
    if [[ ! -d "/var/lib/php/wsdlcache" ]]; then
        mkdir -p /var/lib/php/wsdlcache
    fi
    chown -R nginx:nginx /var/lib/php/session
    chown -R nginx:nginx /var/lib/php/wsdlcache
    chown -R nginx:nginx /var/log/php-fpm
}

# dynamic PHP memory_limit calculation
memory_limit_calculation(){
    if [[ "${PHP_MEM}" -le '262144' ]]; then
        OPCACHE_MEM='32'
        PHP_MEMORYLIMIT='48M'
        PHP_UPLOADLIMIT='48M'
        PHP_REALPATHLIMIT='512k'
        PHP_REALPATHTTL='14400'
        MAX_INPUT_VARS="6000"
    elif [[ "${PHP_MEM}" -gt '262144' && "${PHP_MEM}" -le '393216' ]]; then
        OPCACHE_MEM='80'
        PHP_MEMORYLIMIT='96M'
        PHP_UPLOADLIMIT='96M'
        PHP_REALPATHLIMIT='640k'
        PHP_REALPATHTTL='21600'
        MAX_INPUT_VARS="6000"
    elif [[ "${PHP_MEM}" -gt '393216' && "${PHP_MEM}" -le '524288' ]]; then
        OPCACHE_MEM='112'
        PHP_MEMORYLIMIT='128M'
        PHP_UPLOADLIMIT='128M'
        PHP_REALPATHLIMIT='768k'
        PHP_REALPATHTTL='21600'
        MAX_INPUT_VARS="6000"
    elif [[ "${PHP_MEM}" -gt '524288' && "${PHP_MEM}" -le '1049576' ]]; then
        OPCACHE_MEM='144'
        PHP_MEMORYLIMIT='160M'
        PHP_UPLOADLIMIT='160M'
        PHP_REALPATHLIMIT='768k'
        PHP_REALPATHTTL='28800'
        MAX_INPUT_VARS="6000"
    elif [[ "${PHP_MEM}" -gt '1049576' && "${PHP_MEM}" -le '2097152' ]]; then
        OPCACHE_MEM='160'
        PHP_MEMORYLIMIT='320M'
        PHP_UPLOADLIMIT='320M'
        PHP_REALPATHLIMIT='1536k'
        PHP_REALPATHTTL='28800'
        MAX_INPUT_VARS="6000"
    elif [[ "${PHP_MEM}" -gt '2097152' && "${PHP_MEM}" -le '3145728' ]]; then
        OPCACHE_MEM='192'
        PHP_MEMORYLIMIT='384M'
        PHP_UPLOADLIMIT='384M'
        PHP_REALPATHLIMIT='2048k'
        PHP_REALPATHTTL='43200'
        MAX_INPUT_VARS="6000"
    elif [[ "${PHP_MEM}" -gt '3145728' && "${PHP_MEM}" -le '4194304' ]]; then
        OPCACHE_MEM='224'
        PHP_MEMORYLIMIT='512M'
        PHP_UPLOADLIMIT='512M'
        PHP_REALPATHLIMIT='3072k'
        PHP_REALPATHTTL='43200'
        MAX_INPUT_VARS="6000"
    elif [[ "${PHP_MEM}" -gt '4194304' && "${PHP_MEM}" -le '8180000' ]]; then
        OPCACHE_MEM='288'
        PHP_MEMORYLIMIT='640M'
        PHP_UPLOADLIMIT='640M'
        PHP_REALPATHLIMIT='4096k'
        PHP_REALPATHTTL='43200'
        MAX_INPUT_VARS="10000"
    elif [[ "${PHP_MEM}" -gt '8180000' && "${PHP_MEM}" -le '16360000' ]]; then
        OPCACHE_MEM='320'
        PHP_MEMORYLIMIT='800M'
        PHP_UPLOADLIMIT='800M'
        PHP_REALPATHLIMIT='4096k'
        PHP_REALPATHTTL='43200'
        MAX_INPUT_VARS="10000"
    elif [[ "${PHP_MEM}" -gt '16360000' && "${PHP_MEM}" -le '32400000' ]]; then
        OPCACHE_MEM='480'
        PHP_MEMORYLIMIT='1024M'
        PHP_UPLOADLIMIT='1024M'
        PHP_REALPATHLIMIT='4096k'
        PHP_REALPATHTTL='43200'
        MAX_INPUT_VARS="10000"
    elif [[ "${PHP_MEM}" -gt '32400000' && "${PHP_MEM}" -le '64800000' ]]; then
        OPCACHE_MEM='600'
        PHP_MEMORYLIMIT='1280M'
        PHP_UPLOADLIMIT='1280M'
        PHP_REALPATHLIMIT='4096k'
        PHP_REALPATHTTL='43200'
        MAX_INPUT_VARS="10000"
    elif [[ "${PHP_MEM}" -gt '64800000' ]]; then
        OPCACHE_MEM='800'
        PHP_MEMORYLIMIT='2048M'
        PHP_UPLOADLIMIT='2048M'
        PHP_REALPATHLIMIT='8192k'
        PHP_REALPATHTTL='86400'
        MAX_INPUT_VARS="10000"
    fi
}

# Custom PHP Ini
hostvn_custom_ini(){
    memory_limit_calculation
    cat > "/etc/php.d/00-hostvn-custom.ini" <<EOhostvn_custom_ini
date.timezone = Asia/Ho_Chi_Minh
max_execution_time = 90
max_input_time = 90
short_open_tag = On
realpath_cache_size = ${PHP_REALPATHLIMIT}
realpath_cache_ttl = ${PHP_REALPATHTTL}
memory_limit = ${PHP_MEMORYLIMIT}
upload_max_filesize = ${PHP_UPLOADLIMIT}
post_max_size = ${PHP_UPLOADLIMIT}
expose_php = Off
mail.add_x_header = Off
max_input_nesting_level = 128
max_input_vars = ${MAX_INPUT_VARS}
mysqlnd.net_cmd_buffer_size = 16384
mysqlnd.collect_memory_statistics = Off
mysqlnd.mempool_default_size = 16000
always_populate_raw_post_data=-1
;disable_functions=exec,system,passthru,shell_exec,proc_close,proc_open,dl,popen,show_source,posix_kill,posix_mkfifo,posix_getpwuid,posix_setpgid,posix_setsid,posix_setuid,posix_setgid,posix_seteuid,posix_setegid,posix_uname
EOhostvn_custom_ini
}

# Config PHP Opcache
php_opcache(){
    if [[ -f "/etc/php.d/10-opcache.ini" ]]; then
        mv /etc/php.d/10-opcache.ini /etc/php.d/10-opcache.ini.orig
    fi
    cat > "/etc/php.d/10-opcache.ini" << EOphp_opcache
zend_extension=opcache.so
opcache.enable=1
opcache.memory_consumption=${OPCACHE_MEM}
opcache.interned_strings_buffer=8
opcache.max_wasted_percentage=5
opcache.max_accelerated_files=65407
opcache.revalidate_freq=180
opcache.fast_shutdown=0
opcache.enable_cli=0
opcache.save_comments=1
opcache.enable_file_override=1
opcache.validate_timestamps=1
opcache.blacklist_filename=/etc/php.d/opcache-default.blacklist
EOphp_opcache

    cat > "/etc/php.d/opcache-default.blacklist" << EOopcache_blacklist
/home/*/public_html/wp-content/plugins/backwpup/*
/home/*/public_html/wp-content/plugins/duplicator/*
/home/*/public_html/wp-content/plugins/updraftplus/*
EOopcache_blacklist
}

config_php(){
    echo ""
    php_global_config
    hostvn_custom_ini
    php_opcache
}

############################################
# Config MariaDB
############################################
# MariaDB calculation
mariadb_calculation(){
    if [[ "${RAM_TOTAL}" -gt "524288" && "${RAM_TOTAL}" -le "2099152" ]]; then #1GB Ram
        max_allowed_packet="32M"
        back_log="100"
        max_connections="150"
        key_buffer_size="32M"
        myisam_sort_buffer_size="32M"
        myisam_max_sort_file_size="2048M"
        innodb_log_buffer_size="8M"
        join_buffer_size="64K"
        read_buffer_size="64K"
        sort_buffer_size="128K"
        table_definition_cache="4096"
        table_open_cache="2048"
        thread_cache_size="64"
        tmp_table_size="32M"
        max_heap_table_size="32M"
        query_cache_limit="512K"
        query_cache_size="16M"
        innodb_open_files="2000"
        innodb_buffer_pool_size="48M"
        innodb_io_capacity="100"
        aria_pagecache_buffer_size="8M"
        aria_sort_buffer_size="8M"
        net_buffer_length="8192"
        read_rnd_buffer_size="256K"
        innodb_log_file_size="128M"
        innodb_read_io_threads="2"
        aria_log_file_size="32M"
        key_buffer="32M "
        sort_buffer="16M"
        read_buffer="16M"
        write_buffer="16M"
    fi

    if [[ "${RAM_TOTAL}" -gt "2099152" && "${RAM_TOTAL}" -le "4198304" ]]; then #2GB Ram
        max_allowed_packet="48M"
        back_log="200"
        max_connections="200"
        key_buffer_size="32M"
        myisam_sort_buffer_size="64M"
        myisam_max_sort_file_size="2048M"
        innodb_log_buffer_size="8M"
        join_buffer_size="128K"
        read_buffer_size="128K"
        sort_buffer_size="256K"
        table_definition_cache="8192"
        table_open_cache="4096"
        thread_cache_size="128"
        tmp_table_size="128M"
        max_heap_table_size="128M"
        query_cache_limit="1024K"
        query_cache_size="64M"
        innodb_open_files="4000"
        innodb_buffer_pool_size="192M"
        innodb_io_capacity="200"
        aria_pagecache_buffer_size="32M"
        aria_sort_buffer_size="32M"
        net_buffer_length="8192"
        read_rnd_buffer_size="256K"
        innodb_log_file_size="128M"
        innodb_read_io_threads="2"
        aria_log_file_size="32M"
        key_buffer="32M "
        sort_buffer="16M"
        read_buffer="16M"
        write_buffer="16M"
    fi

    if [[ "${RAM_TOTAL}" -gt "4198304" && "${RAM_TOTAL}" -le "8396608" ]]; then #4GB Ram
        max_allowed_packet="64M"
        back_log="200"
        max_connections="350"
        key_buffer_size="256M"
        myisam_sort_buffer_size="256M"
        myisam_max_sort_file_size="2048M"
        innodb_log_buffer_size="8M"
        join_buffer_size="256K"
        read_buffer_size="256K"
        sort_buffer_size="256K"
        table_definition_cache="8192"
        table_open_cache="4096"
        thread_cache_size="256"
        tmp_table_size="256M"
        max_heap_table_size="256M"
        query_cache_limit="1024K"
        query_cache_size="80M"
        innodb_open_files="4000"
        innodb_buffer_pool_size="512M"
        innodb_io_capacity="300"
        aria_pagecache_buffer_size="64M"
        aria_sort_buffer_size="64M"
        net_buffer_length="16384"
        read_rnd_buffer_size="512K"
        innodb_log_file_size="256M"
        innodb_read_io_threads="4"
        aria_log_file_size="64M"
        key_buffer="256M "
        sort_buffer="32M"
        read_buffer="32M"
        write_buffer="32M"
    fi

    if [[ "${RAM_TOTAL}" -gt "8396608" && "${RAM_TOTAL}" -le "16793216" ]]; then #8GB Ram
        max_allowed_packet="64M"
        back_log="512"
        max_connections="400"
        key_buffer_size="384M"
        myisam_sort_buffer_size="256M"
        myisam_max_sort_file_size="2048M"
        innodb_log_buffer_size="16M"
        join_buffer_size="256K"
        read_buffer_size="256K"
        sort_buffer_size="512K"
        table_definition_cache="8192"
        table_open_cache="8192"
        thread_cache_size="256"
        tmp_table_size="512M"
        max_heap_table_size="512M"
        query_cache_limit="1024K"
        query_cache_size="128M"
        innodb_open_files="8000"
        innodb_buffer_pool_size="1024M"
        innodb_io_capacity="400"
        aria_pagecache_buffer_size="64M"
        aria_sort_buffer_size="64M"
        net_buffer_length="16384"
        read_rnd_buffer_size="512K"
        innodb_log_file_size="384M"
        innodb_read_io_threads="4"
        aria_log_file_size="64M"
        key_buffer="384M "
        sort_buffer="64M"
        read_buffer="64M"
        write_buffer="64M"
    fi

    if [[ "${RAM_TOTAL}" -gt "16793216" && "${RAM_TOTAL}" -le "33586432" ]]; then #16GB Ram
        max_allowed_packet="64M"
        back_log="768"
        max_connections="500"
        key_buffer_size="512M"
        myisam_sort_buffer_size="512M"
        myisam_max_sort_file_size="4096M"
        innodb_log_buffer_size="32M"
        join_buffer_size="1M"
        read_buffer_size="1M"
        sort_buffer_size="2M"
        table_definition_cache="10240"
        table_open_cache="10240"
        thread_cache_size="384"
        tmp_table_size="768M"
        max_heap_table_size="768M"
        query_cache_limit="1024K"
        query_cache_size="160M"
        innodb_open_files="10000"
        innodb_buffer_pool_size="4096M"
        innodb_io_capacity="500"
        aria_pagecache_buffer_size="128M"
        aria_sort_buffer_size="128M"
        net_buffer_length="16384"
        read_rnd_buffer_size="512K"
        innodb_log_file_size="640M"
        innodb_read_io_threads="4"
        aria_log_file_size="64M"
        key_buffer="768M "
        sort_buffer="128M"
        read_buffer="128M"
        write_buffer="128M"
    fi

    if [[ "$(expr "${RAM_TOTAL}" \>= 33586432)" = "1" ]]; then #32GB Ram
        max_allowed_packet="64M"
        back_log="1024"
        max_connections="600"
        key_buffer_size="768M"
        myisam_sort_buffer_size="768M"
        myisam_max_sort_file_size="8192M"
        innodb_log_buffer_size="64M"
        join_buffer_size="2M"
        read_buffer_size="2M"
        sort_buffer_size="2M"
        table_definition_cache="10240"
        table_open_cache="10240"
        thread_cache_size="384"
        tmp_table_size="1024M"
        max_heap_table_size="1024M"
        query_cache_limit="1536K"
        query_cache_size="256M"
        innodb_open_files="10000"
        innodb_buffer_pool_size="8192M"
        innodb_io_capacity="600"
        aria_pagecache_buffer_size="128M"
        aria_sort_buffer_size="128M"
        net_buffer_length="16384"
        read_rnd_buffer_size="512K"
        innodb_log_file_size="768M"
        innodb_read_io_threads="4"
        aria_log_file_size="64M"
        key_buffer="1024M "
        sort_buffer="256M"
        read_buffer="256M"
        write_buffer="256M"
    fi

    if [[ "$(expr "${RAM_TOTAL}" \>= 64000000)" = "1" ]]; then #64GB Ram
        max_allowed_packet="80M"
        back_log="1024"
        max_connections="800"
        key_buffer_size="1024M"
        myisam_sort_buffer_size="1024M"
        myisam_max_sort_file_size="10240M"
        innodb_log_buffer_size="64M"
        join_buffer_size="2M"
        read_buffer_size="2M"
        sort_buffer_size="2M"
        table_definition_cache="10240"
        table_open_cache="10240"
        thread_cache_size="384"
        tmp_table_size="1536M"
        max_heap_table_size="1536M"
        query_cache_limit="1536K"
        query_cache_size="256M"
        innodb_open_files="10000"
        innodb_buffer_pool_size="12288M"
        innodb_io_capacity="800"
        aria_pagecache_buffer_size="256M"
        aria_sort_buffer_size="256M"
        net_buffer_length="16384"
        read_rnd_buffer_size="512K"
        innodb_log_file_size="1024M"
        innodb_read_io_threads="4"
        aria_log_file_size="128M"
        key_buffer="1536M "
        sort_buffer="384M"
        read_buffer="384M"
        write_buffer="384M"
    fi
}

config_my_cnf(){
    mariadb_calculation
    mkdir -p /var/log/mysql
    chown -R mysql:mysql /var/log/mysql
    mv /etc/my.cnf /etc/my.cnf.orig

cat >> "/etc/my.cnf" << EOmy_cnf
[client]
socket=/var/lib/mysql/mysql.sock

[mysql]
max_allowed_packet = ${max_allowed_packet}

[mysqld]
local-infile=0
ignore-db-dir=lost+found
character-set-server=utf8
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock

#bind-address=127.0.0.1

tmpdir=/tmp

innodb=ON
#skip-federated
#skip-pbxt
#skip-pbxt_statistics
#skip-archive
#skip-name-resolve
#old_passwords
back_log = ${back_log}
max_connections = ${max_connections}
key_buffer_size = ${key_buffer_size}
myisam_sort_buffer_size = ${myisam_sort_buffer_size}
myisam_max_sort_file_size = ${myisam_max_sort_file_size}
join_buffer_size = ${join_buffer_size}
read_buffer_size = ${read_buffer_size}
sort_buffer_size = ${sort_buffer_size}
table_definition_cache = ${table_definition_cache}
table_open_cache = ${table_open_cache}
thread_cache_size = ${thread_cache_size}
wait_timeout = 1800
connect_timeout = 10
tmp_table_size = ${tmp_table_size}
max_heap_table_size = ${max_heap_table_size}
max_allowed_packet = ${max_allowed_packet}
#max_seeks_for_key = 4294967295
#group_concat_max_len = 1024
max_length_for_sort_data = 1024
net_buffer_length = ${net_buffer_length}
max_connect_errors = 100000
concurrent_insert = 2
read_rnd_buffer_size = ${read_rnd_buffer_size}
bulk_insert_buffer_size = 8M
# query_cache boost for MariaDB >10.1.2+
query_cache_limit = ${query_cache_limit}
query_cache_size = ${query_cache_size}
query_cache_type = 1
query_cache_min_res_unit = 2K
query_prealloc_size = 262144
query_alloc_block_size = 65536
transaction_alloc_block_size = 8192
transaction_prealloc_size = 4096
default-storage-engine = InnoDB

log_warnings=1
slow_query_log=0
long_query_time=1
slow_query_log_file=/var/lib/mysql/slowq.log
log-error=/var/log/mysql/mysqld.log

# innodb settings
#innodb_large_prefix=1
innodb_purge_threads=1
#innodb_file_format = Barracuda
innodb_file_per_table = 1
innodb_open_files = ${innodb_open_files}
innodb_data_file_path= ibdata1:10M:autoextend
innodb_buffer_pool_size = ${innodb_buffer_pool_size}

## https://mariadb.com/kb/en/mariadb/xtradbinnodb-server-system-variables/#innodb_buffer_pool_instances
#innodb_buffer_pool_instances=2

#innodb_log_files_in_group = 2
innodb_log_file_size = ${innodb_log_file_size}
innodb_log_buffer_size = ${innodb_log_buffer_size}
innodb_flush_log_at_trx_commit = 2
innodb_thread_concurrency = 0
innodb_lock_wait_timeout=50
innodb_flush_method = O_DIRECT
#innodb_support_xa=1

# 200 * # DISKS
innodb_io_capacity = ${innodb_io_capacity}
innodb_io_capacity_max = 2000
innodb_read_io_threads = ${innodb_read_io_threads}
innodb_write_io_threads = 2
innodb_flush_neighbors = 1

# mariadb settings
[mariadb]
#thread-handling = pool-of-threads
#thread-pool-size= 20
#mysql --port=3307 --protocol=tcp
#extra-port=3307
#extra-max-connections=1

userstat = 0
key_cache_segments = 1
aria_group_commit = none
aria_group_commit_interval = 0
aria_log_file_size = ${aria_log_file_size}
aria_log_purge_type = immediate
aria_pagecache_buffer_size = ${aria_pagecache_buffer_size}
aria_sort_buffer_size = ${aria_sort_buffer_size}

[mariadb-5.5]
innodb_file_format = Barracuda
innodb_file_per_table = 1

#ignore_db_dirs=
query_cache_strip_comments=0

innodb_read_ahead = linear
innodb_adaptive_flushing_method = estimate
innodb_flush_neighbor_pages = 1
innodb_stats_update_need_lock = 0
innodb_log_block_size = 512

log_slow_filter =admin,filesort,filesort_on_disk,full_join,full_scan,query_cache,query_cache_miss,tmp_table,tmp_table_on_disk

[mysqld_safe]
socket=/var/lib/mysql/mysql.sock
log-error=/var/log/mysqld/mysqld.log
#nice = -5
open-files-limit = 8192

[mysqldump]
quick
max_allowed_packet = ${max_allowed_packet}

[myisamchk]
tmpdir=/tmp
key_buffer = ${key_buffer}
sort_buffer = ${sort_buffer}
read_buffer = ${read_buffer}
write_buffer = ${write_buffer}

[mysqlhotcopy]
interactive-timeout

[mariadb-10.0]
innodb_file_format = Barracuda
innodb_file_per_table = 1

# 2 variables needed to switch from XtraDB to InnoDB plugins
#plugin-load=ha_innodb
#ignore_builtin_innodb

## MariaDB 10 only save and restore buffer pool pages
## warm up InnoDB buffer pool on server restarts
innodb_buffer_pool_dump_at_shutdown=1
innodb_buffer_pool_load_at_startup=1
innodb_buffer_pool_populate=0
## Disabled settings
performance_schema=OFF
innodb_stats_on_metadata=OFF
innodb_sort_buffer_size=2M
innodb_online_alter_log_max_size=128M
query_cache_strip_comments=0
log_slow_filter =admin,filesort,filesort_on_disk,full_join,full_scan,query_cache,query_cache_miss,tmp_table,tmp_table_on_disk
EOmy_cnf
}

mysql_limit_nofile(){
    if [[ ! -d "/etc/systemd/system/mariadb.service.d/" ]]; then
        mkdir -p /etc/systemd/system/mariadb.service.d/
    fi
    cat > "/etc/systemd/system/mariadb.service.d/limits.conf" << EOmysql_limit_nofile
[Service]
LimitNOFILE=100000
EOmysql_limit_nofile
    systemctl daemon-reload
}

# Set MariaDB Root Password
set_mariadb_root_pwd(){
    systemctl start mariadb
    SQLPASS=$(date +%s | sha256sum | base64 | head -c 12)
    cat > "/root/.my.cnf" <<EOmy_conf
[client]
user=root
password=${SQLPASS}
EOmy_conf
    chmod 600 /root/.my.cnf
    service mariadb start

    /usr/bin/mysql_secure_installation << EOF

n
Y
${SQLPASS}
${SQLPASS}
Y
Y
Y
Y
EOF
}

config_mariadb(){
    echo ""
    config_my_cnf
    mysql_limit_nofile
    set_mariadb_root_pwd
}

############################################
# Other Config
############################################

limits_config(){
    mv /etc/security/limits.conf /etc/security/limits.conf.orig
    cat >> "/etc/security/limits.conf" <<EOlimits_config
* soft nofile 524288
* hard nofile 524288
nginx soft nofile 262144
nginx hard nofile 524288
nobody soft nofile 524288
nobody hard nofile 524288
root soft nofile 524288
root hard nofile 524288
EOlimits_config
    ulimit -n 524288

    if [[ -f "/etc/security/limits.d/20-nproc.conf" ]]; then
        mv /etc/security/limits.d/20-nproc.conf /etc/security/limits.d/20-nproc.conf.orig
        cat > "/etc/security/limits.d/20-nproc.conf" <<EOnproc
# Default limit for number of user's processes to prevent
# accidental fork bombs.
# See rhbz #432903 for reasoning.

*          soft    nproc     8192
*          hard    nproc     8192
nginx      soft    nproc     32278
nginx      hard    nproc     32278
root       soft    nproc     unlimited
EOnproc
    fi
}

sysctl_config(){
    mv /etc/sysctl.conf /etc/sysctl.conf.orig
    cat >> "/etc/sysctl.conf" << EOsysctl_config
# sysctl settings are defined through files in
# /usr/lib/sysctl.d/, /run/sysctl.d/, and /etc/sysctl.d/.
#
# Vendors settings live in /usr/lib/sysctl.d/.
# To override a whole file, create a new file with the same in
# /etc/sysctl.d/ and put new settings there. To override
# only specific settings, add a file with a lexically later
# name in /etc/sysctl.d/ and put new settings there.
#
# For more information, see sysctl.conf(5) and sysctl.d(5).

# Controls the System Request debugging functionality of the kernel
kernel.sysrq = 0

# Controls whether core dumps will append the PID to the core filename.
# Useful for debugging multi-threaded applications.
kernel.core_uses_pid = 1

#Allow for more PIDs
kernel.pid_max = 65535

# Controls the maximum size of a message, in bytes
kernel.msgmnb = 65535

# Controls the default maxmimum size of a mesage queue
kernel.msgmax = 65535

# Restrict core dumps
fs.suid_dumpable = 0

# Hide exposed kernel pointers
kernel.kptr_restrict = 1

# Restrict access to kernel logs
kernel.dmesg_restrict = 1

# Restrict ptrace scope
kernel.yama.ptrace_scope = 1

# Increase size of file handles and inode cache
fs.file-max = 209708

# Do less swapping
vm.swappiness = 10
vm.dirty_ratio = 30
vm.dirty_background_ratio = 5

# specifies the minimum virtual address that a process is allowed to mmap
vm.mmap_min_addr = 4096

# 50% overcommitment of available memory
vm.overcommit_ratio = 50

# allow memory overcommit required for redis
vm.overcommit_memory = 1

# Set maximum amount of memory allocated to shm to 256MB
kernel.shmmax = 268435456
kernel.shmall = 268435456

# Keep at least 64MB of free RAM space available
vm.min_free_kbytes = 65535

# Harden BPF JIT compiler
net.core.bpf_jit_harden = 1

#Prevent SYN attack, enable SYNcookies (they will kick-in when the max_syn_backlog reached)
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_syn_backlog = 4096

# Disables IP source routing
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Enable IP spoofing protection, turn on source route verification
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Disable ICMP Redirect Acceptance
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Enable Log Spoofed Packets, Source Routed Packets, Redirect Packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Decrease the time default value for tcp_fin_timeout connection
net.ipv4.tcp_fin_timeout = 7

# Decrease the time default value for connections to keep alive
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# Don't relay bootp
net.ipv4.conf.all.bootp_relay = 0

# Don't proxy arp for anyone
net.ipv4.conf.all.proxy_arp = 0

# Turn on the tcp_timestamps, accurate timestamp make TCP congestion control algorithms work better
net.ipv4.tcp_timestamps = 1

# Don't ignore directed pings
net.ipv4.icmp_echo_ignore_all = 0

# Enable ignoring broadcasts request
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Enable bad error message Protection
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Allowed local port range
net.ipv4.ip_local_port_range = 16384 65535

# Enable a fix for RFC1337 - time-wait assassination hazards in TCP
net.ipv4.tcp_rfc1337 = 1

# Do not auto-configure IPv6
net.ipv6.conf.all.autoconf=0
net.ipv6.conf.all.accept_ra=0
net.ipv6.conf.default.autoconf=0
net.ipv6.conf.default.accept_ra=0
net.ipv6.conf.all.accept_ra_defrtr = 0
net.ipv6.conf.default.accept_ra_defrtr = 0
net.ipv6.conf.all.accept_ra_pinfo = 0
net.ipv6.conf.default.accept_ra_pinfo = 0

# For servers with tcp-heavy workloads, enable 'fq' queue management scheduler (kernel > 3.12)
net.core.default_qdisc = fq

# Turn on the tcp_window_scaling
net.ipv4.tcp_window_scaling = 1

# Increase the read-buffer space allocatable
net.ipv4.tcp_rmem = 8192 87380 16777216
net.ipv4.udp_rmem_min = 16384
net.core.rmem_default = 262144
net.core.rmem_max = 16777216

# Increase the write-buffer-space allocatable
net.ipv4.tcp_wmem = 8192 65536 16777216
net.ipv4.udp_wmem_min = 16384
net.core.wmem_default = 262144
net.core.wmem_max = 16777216

# Increase number of incoming connections
net.core.somaxconn = 32768

# Increase the maximum amount of option memory buffers
net.core.optmem_max = 65535

# Increase the tcp-time-wait buckets pool size to prevent simple DOS attacks
net.ipv4.tcp_max_tw_buckets = 1440000

# try to reuse time-wait connections, but don't recycle them (recycle can break clients behind NAT)
net.ipv4.tcp_tw_reuse = 1

# Limit number of orphans, each orphan can eat up to 16M (max wmem) of unswappable memory
net.ipv4.tcp_max_orphans = 16384
net.ipv4.tcp_orphan_retries = 0

# Limit the maximum memory used to reassemble IP fragments (CVE-2018-5391)
net.ipv4.ipfrag_low_thresh = 196608
net.ipv6.ip6frag_low_thresh = 196608
net.ipv4.ipfrag_high_thresh = 262144
net.ipv6.ip6frag_high_thresh = 262144


# don't cache ssthresh from previous connection
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_moderate_rcvbuf = 1

# Increase size of RPC datagram queue length
net.unix.max_dgram_qlen = 50

# Don't allow the arp table to become bigger than this
net.ipv4.neigh.default.gc_thresh3 = 2048

# Tell the gc when to become aggressive with arp table cleaning.
# Adjust this based on size of the LAN. 1024 is suitable for most /24 networks
net.ipv4.neigh.default.gc_thresh2 = 1024

# Adjust where the gc will leave arp table alone - set to 32.
net.ipv4.neigh.default.gc_thresh1 = 32

# Adjust to arp table gc to clean-up more often
net.ipv4.neigh.default.gc_interval = 30

# Increase TCP queue length
net.ipv4.neigh.default.proxy_qlen = 96
net.ipv4.neigh.default.unres_qlen = 6

# Enable Explicit Congestion Notification (RFC 3168), disable it if it doesn't work for you
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_reordering = 3

# How many times to retry killing an alive TCP connection
net.ipv4.tcp_retries2 = 15
net.ipv4.tcp_retries1 = 3

# Avoid falling back to slow start after a connection goes idle
# keeps our cwnd large with the keep alive connections (kernel > 3.6)
net.ipv4.tcp_slow_start_after_idle = 0

# Allow the TCP fastopen flag to be used, beware some firewalls do not like TFO! (kernel > 3.7)
net.ipv4.tcp_fastopen = 3

# This will enusre that immediatly subsequent connections use the new values
net.ipv4.route.flush = 1
net.ipv6.route.flush = 1
EOsysctl_config
    sysctl -p
    sed -i 's/vm.swappiness/#vm.swappiness/g' /usr/lib/tuned/virtual-guest/tuned.conf
    echo "vm.swappiness = 10" >> /usr/lib/tuned/virtual-guest/tuned.conf
}

other_config(){
    echo ""
    limits_config
    sysctl_config
}

############################################
# Log Rotation
############################################
log_rotation(){
    echo ""
    cat > "/etc/logrotate.d/nginx" << EOnginx_log
/home/*/logs/access.log /home/*/logs/error.log /home/*/logs/nginx_error.log {
    create 640 nginx nginx
        daily
    dateext
        missingok
        rotate 5
        maxage 7
        compress
    size=100M
        notifempty
        sharedscripts
        postrotate
                [ -f /var/run/nginx.pid ] && kill -USR1 \`cat /var/run/nginx.pid\`
        endscript
    su nginx nginx
}
EOnginx_log
cat > "/etc/logrotate.d/php-fpm" << EOphp_fpm_log
/home/*/logs/php-fpm*.log {
        daily
    dateext
        compress
        maxage 7
        missingok
        notifempty
        sharedscripts
        size=100M
        postrotate
            /bin/kill -SIGUSR1 \`cat /var/run/php-fpm/php-fpm.pid 2>/dev/null\` 2>/dev/null || true
        endscript
    su nginx nginx
}
EOphp_fpm_log
cat > "/etc/logrotate.d/mysql" << EOmysql_log
/home/*/logs/mysql*.log {
        create 640 mysql mysql
        notifempty
        daily
        rotate 3
        maxage 7
        missingok
        compress
        postrotate
        # just if mysqld is really running
        if test -x /usr/bin/mysqladmin && \
           /usr/bin/mysqladmin ping &>/dev/null
        then
           /usr/bin/mysqladmin flush-logs
        fi
        endscript
    su mysql mysql
}
EOmysql_log
}

############################################
# Install phpMyAdmin
############################################
unzip_phpmyadmin(){
    cd ${USR_DIR} && unzip phpmyadmin.zip
    rm -rf phpmyadmin.zip
}

#Config phpMyAdmin
config_phpmyadmin(){
    BLOWFISH_SECRET=$(date +%s | sha256sum | base64 | head -c 32)
    mv ${USR_DIR}/phpmyadmin/config.sample.inc.php ${USR_DIR}/phpmyadmin/config.inc.php
    rm -rf ${USR_DIR}/phpmyadmin/setup
    mkdir -p ${USR_DIR}/phpmyadmin/tmp

    cat > "${USR_DIR}/phpmyadmin/config.inc.php" <<EOCONFIGINC
<?php
\$cfg['blowfish_secret'] = '${BLOWFISH_SECRET}';
\$i = 0;
\$i++;
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['host'] = 'localhost';
\$cfg['Servers'][\$i]['connect_type'] = 'tcp';
\$cfg['Servers'][\$i]['compress'] = false;
\$cfg['Servers'][\$i]['AllowNoPassword'] = false;
\$cfg['UploadDir'] = '';
\$cfg['SaveDir'] = '';
\$cfg['PmaNoRelation_DisableWarning'] = true;
\$cfg['VersionCheck'] = false;
\$cfg['TempDir'] = '${USR_DIR}/phpmyadmin/tmp';
\$cfg['CaptchaLoginPublicKey'] = '';
\$cfg['CaptchaLoginPrivateKey'] = '';
EOCONFIGINC

    chown -R nginx:nginx ${USR_DIR}/phpmyadmin
}

create_phpmyadmin_db(){
    cat > "/tmp/phpmyadmin.temp" << EOphpmyadmin_temp
CREATE DATABASE phpmyadmin COLLATE utf8_general_ci;
FLUSH PRIVILEGES;
EOphpmyadmin_temp

    mysql -u root -p"${SQLPASS}" < /tmp/phpmyadmin.temp
    rm -f /tmp/phpmyadmin.temp

    curl -o phpmyadmin.sql ${GITHUB_RAW_LINK}/sanvu88/pma/master/phpmyadmin.sql
    mysql -u root -p"${SQLPASS}" phpmyadmin < phpmyadmin.sql
    rm -rf phpmyadmin.sql
}

install_phpmyadmin(){
    echo ""
    PMA_LINK="https://files.phpmyadmin.net/phpMyAdmin"
    if [[ ${PHP_VERSION} -eq "56" ]]; then
        wget -O ${USR_DIR}/phpmyadmin.zip ${PMA_LINK}/${PHPMYADMIN_FOUR}/phpMyAdmin-${PHPMYADMIN_FOUR}-english.zip
        unzip_phpmyadmin
        mv phpMyAdmin-${PHPMYADMIN_FOUR}-english phpmyadmin
        ln -s ${USR_DIR}/phpmyadmin ${DEFAULT_DIR_WEB}/phpmyadmin
        config_phpmyadmin
        cd_dir "${DIR}"
    else
        wget -O ${USR_DIR}/phpmyadmin.zip  ${PMA_LINK}/${PHPMYADMIN_FIVE}/phpMyAdmin-${PHPMYADMIN_FIVE}-english.zip
        unzip_phpmyadmin
        mv phpMyAdmin-${PHPMYADMIN_FIVE}-english phpmyadmin
        ln -s ${USR_DIR}/phpmyadmin ${DEFAULT_DIR_WEB}/phpmyadmin
        config_phpmyadmin
        cd_dir "${DIR}"
    fi

    chown -R nginx:nginx ${USR_DIR}/nginx/html
    create_phpmyadmin_db
}

############################################
# Install PureFTP
############################################
install_pure_ftpd(){
    echo ""
    yum -y install pure-ftpd
    PURE_CONF_PATH="/etc/pure-ftpd"
    if [[ -f "${PURE_CONF_PATH}/pure-ftpd.conf" ]]; then
        mv ${PURE_CONF_PATH}/pure-ftpd.conf ${PURE_CONF_PATH}/pure-ftpd.conf.orig
    fi

    cat >> "${PURE_CONF_PATH}/pure-ftpd.conf" << EOpure_ftpd_conf
ChrootEveryone               yes
BrokenClientsCompatibility   no
MaxClientsNumber             50
Daemonize                    yes
MaxClientsPerIP              15
VerboseLog                   no
DisplayDotFiles              yes
AnonymousOnly                no
NoAnonymous                  yes
SyslogFacility               ftp
DontResolve                  yes
MaxIdleTime                  15
PureDB                       /etc/pure-ftpd/pureftpd.pdb
LimitRecursion               10000 8
AnonymousCanCreateDirs       no
MaxLoad                      4
PassivePortRange             35000 35999
AntiWarez                    yes
#Bind                         ${IPADDRESS},21
Umask                        133:022
MinUID                       99
UseFtpUsers                  no
AllowUserFXP                 no
AllowAnonymousFXP            no
ProhibitDotFilesWrite        no
ProhibitDotFilesRead         no
AutoRename                   no
AnonymousCantUpload          yes
AltLog                       stats:/var/log/pureftpd.log
PIDFile                      /var/run/pure-ftpd.pid
CallUploadScript             no
MaxDiskUsage                 99
CustomerProof                yes
TLS                          1
TLSCipherSuite               HIGH:MEDIUM:+TLSv1:!SSLv2:+SSLv3
CertFile                     /etc/pure-ftpd/ssl/pure-ftpd.pem
EOpure_ftpd_conf

    mkdir -p ${PURE_CONF_PATH}/ssl
    openssl dhparam -out ${PURE_CONF_PATH}/ssl/pure-ftpd-dhparams.pem 2048
    openssl req -x509 -days 7300 -sha256 -nodes -subj "/C=VN/ST=Ho_Chi_Minh/L=Ho_Chi_Minh/O=Localhost/CN=${IPADDRESS}" -newkey rsa:2048 -keyout ${PURE_CONF_PATH}/ssl/pure-ftpd.pem -out ${PURE_CONF_PATH}/ssl/pure-ftpd.pem
    chmod 600 ${PURE_CONF_PATH}/ssl/pure-ftpd*.pem
}

############################################
# Change SSH Port
############################################
change_ssh_port() {
    echo ""
    sed -i 's/#Port 22/Port 8282/g' /etc/ssh/sshd_config
    systemctl restart sshd
}

############################################
# Opcache Dashboard
############################################
opcache_dashboard(){
    echo ""
    ADMIN_TOOL_PWD=$(date |md5sum |cut -c '14-30')
    mkdir -p ${DEFAULT_DIR_WEB}/opcache
    wget -q ${GITHUB_RAW_LINK}/amnuts/opcache-gui/master/index.php -O  ${DEFAULT_DIR_WEB}/opcache/op.php
    chown -R nginx:nginx ${DEFAULT_DIR_WEB}/opcache
    #printf "admin:$(openssl passwd -1 "${ADMIN_TOOL_PWD}")\n" >> ${USR_DIR}/nginx/auth/.htpasswd
    htpasswd -c ${USR_DIR}/nginx/auth/.htpasswd admin << EOF
    ${ADMIN_TOOL_PWD}
    ${ADMIN_TOOL_PWD}
EOF
    chown -R nginx:nginx ${USR_DIR}/nginx/auth
}

############################################
# phpSysInfo
############################################
php_sys_info(){
    echo ""
    cd_dir "${DEFAULT_DIR_WEB}"
    wget -q ${GITHUB_URL}/phpsysinfo/phpsysinfo/archive/v${PHP_SYS_INFO_VERSION}.zip
    unzip -q v${PHP_SYS_INFO_VERSION}.zip && rm -f v${PHP_SYS_INFO_VERSION}.zip
    mv phpsysinfo-${PHP_SYS_INFO_VERSION} serverinfo
    cd serverinfo && mv phpsysinfo.ini.new phpsysinfo.ini
    cd_dir "${DIR}"
    chown -R nginx:nginx ${DEFAULT_DIR_WEB}
}

############################################
# Install CSF Firewall
############################################
install_csf(){
    echo ""
    yum -y install perl-libwww-perl perl-LWP-Protocol-https perl-GDGraph bind-utils net-tools
    curl -o "${DIR}"/csf.tgz https://download.configserver.com/csf.tgz
    tar -xf csf.tgz
    cd_dir "${DIR}/csf"
    sh install.sh
    cd_dir "${DIR}"
    rm -rf csf*
    sed -i 's/443,465/443,8282,'${RANDOM_ADMIN_PORT}',465/g' /etc/csf/csf.conf
    sed -i 's/TESTING = "1"/TESTING = "0"/; s/443,587/443,465,587,'${RANDOM_ADMIN_PORT}',8282/; s/RESTRICT_SYSLOG = "0"/RESTRICT_SYSLOG = "2"/' /etc/csf/csf.conf
    sed -i 's/CT_LIMIT = "0"/CT_LIMIT = "600"/g' /etc/csf/csf.conf
    sed -i 's/ICMP_IN = "0"/ICMP_IN = "1"/; s/ICMP_IN_RATE = "1/ICMP_IN_RATE = "5/' /etc/csf/csf.conf
    sed -i 's/PORTS_sshd = "22"/PORTS_sshd = "22, 8282"/g' /etc/csf/csf.conf
    sed -i 's/PORTFLOOD = ""/PORTFLOOD = "21;tcp;20;300"/g' /etc/csf/csf.conf
    cat >> "/etc/csf/csf.pignore" << EOCSF
exe:/usr/sbin/nginx
exe:/usr/sbin/php-fpm
exe:/usr/sbin/rpcbind
pexe:/usr/libexec/postfix/.*
EOCSF
    csf -r
}

############################################
# Finished
############################################
start_service() {
    echo ""
    systemctl enable nginx
    systemctl start nginx
    systemctl enable mariadb
    systemctl enable php-fpm
    systemctl start php-fpm
    systemctl start pure-ftpd
    systemctl enable pure-ftpd
    systemctl start lfd
    systemctl enable lfd
    systemctl start csf
    systemctl enable csf
}

check_service_status(){
    echo ""
    NGINX_STATUS=$(pgrep nginx | wc -l)
    if [[ "${NGINX_STATUS}" -eq "0" ]]; then
        echo "${NGINX_NOT_WORKING}" >> ${LOG}
    fi

    MARIADB_STATUS=$(pgrep mariadb | wc -l)
    if [[ "${MARIADB_STATUS}" -eq "0" ]]; then
        echo "${MARIADB_NOT_WORKING}" >> ${LOG}
    fi

    PURE_STATUS=$(pgrep pure-ftpd | wc -l)
    if [[ "${PURE_STATUS}" -eq "0" ]]; then
        echo "${PUREFTP_NOT_WORKING}" >> ${LOG}
    fi

    PHP_STATUS=$(pgrep php-fpm | wc -l)
    if [[ "${PHP_STATUS}" -eq "0" ]]; then
        echo "${PHP_NOT_WORKING}" >> ${LOG}
    fi

    LFD_STATUS=$(pgrep lfd | wc -l)
    if [[ "${LFD_STATUS}" -eq "0" ]]; then
        echo "${LFD_NOT_WORKING}" >> ${LOG}
    fi
}

############################################
# Create menu
############################################
add_menu(){
    echo ""
    mkdir -p "${BASH_DIR}"
    cd_dir "${BASH_DIR}"
}

############################################
# Write Info
############################################
write_info(){
    FILE_INFO="${BASH_DIR}/hostvn.txt"
    touch "${FILE_INFO}"
    chmod 600 "${FILE_INFO}"
    {
        echo "SSH  Port: 8282"
        echo "Link phpMyAdmin: http://${IPADDRESS}:${RANDOM_ADMIN_PORT}/phpmyadmin"
        echo "MariaDB Root Password: ${SQLPASS}"
        echo "Link Opcache Dashboard     : http://${IPADDRESS}:${RANDOM_ADMIN_PORT}/opcache"
        echo "Link Server Info     : http://${IPADDRESS}:${RANDOM_ADMIN_PORT}/serverinfo"
        echo "User Admin Tool    : admin"
        echo "Password Admin Tool : ${ADMIN_TOOL_PWD}"
    } >> "${FILE_INFO}"
}


############################################
# Run Script
############################################
run_(){
    check_before_install
    prepare_install
    install_lemp
    install_composer
    install_cache
    config_nginx
    config_php
    config_mariadb
    other_config
    log_rotation
    install_phpmyadmin
    install_pure_ftpd
    change_ssh_port
    install_csf
    opcache_dashboard
    php_sys_info
    start_service
    add_menu
    check_service_status
    write_info
}

run_

clear
sleep 1

echo "========================================================================="
echo "                        Cài đặt thành công                               "
echo "Bạn có thể xem lại thông tin cần thiết tại file: ${FILE_INFO}            "
echo "          Nếu cần hỗ trợ vui lòng liên hệ ${AUTHOR_CONTACT}              "
echo "========================================================================="
echo "              Lưu lại thông tin dưới đây để truy cập SSH và phpMyAdmin   "
echo "-------------------------------------------------------------------------"
echo "1.  SSH  Port                  : 8282"
echo "2.  phpMyAdmin                 : http://${IPADDRESS}:${RANDOM_ADMIN_PORT}/phpmyadmin"
echo "3.  MariaDB Root Password      : ${SQLPASS}"
echo "-------------------------------------------------------------------------"
echo "========================================================================="
echo "              Lưu lại thông tin dưới đây để truy cập Admin Tool          "
echo "-------------------------------------------------------------------------"
echo "1.  Link Opcache Dashboard     : http://${IPADDRESS}:${RANDOM_ADMIN_PORT}/opcache"
echo "2.  Link Server Info     : http://${IPADDRESS}:${RANDOM_ADMIN_PORT}/serverinfo"
echo "3.  User                       : admin                                   "
echo "4.  Password                   : ${ADMIN_TOOL_PWD}"
echo "-------------------------------------------------------------------------"
echo "========================================================================="
echo "Kiểm tra file ${LOG} để xem có lỗi gì trong quá trình cài đặt hay không."
echo "-------------------------------------------------------------------------"

sleep 3
shutdown -r now