#!/usr/bin/env bash

clear

echo -e "\e[36m
   ▄▄▄▄       ██                         ▄▄▄▄                                   
  ██▀▀██      ▀▀                         ▀▀██                                   
 ██    ██   ████     ██▄████▄   ▄███▄██    ██       ▄████▄   ██▄████▄   ▄███▄██ 
 ██    ██     ██     ██▀   ██  ██▀  ▀██    ██      ██▀  ▀██  ██▀   ██  ██▀  ▀██ 
 ██    ██     ██     ██    ██  ██    ██    ██      ██    ██  ██    ██  ██    ██ 
  ██▄▄██▀  ▄▄▄██▄▄▄  ██    ██  ▀██▄▄███    ██▄▄▄   ▀██▄▄██▀  ██    ██  ▀██▄▄███ 
   ▀▀▀██   ▀▀▀▀▀▀▀▀  ▀▀    ▀▀   ▄▀▀▀ ██     ▀▀▀▀     ▀▀▀▀    ▀▀    ▀▀   ▄▀▀▀ ██ 
       ▀                        ▀████▀▀                                 ▀████▀▀
\e[0m\n"

DOCKER_IMG_NAME="ghcr.io/whyour/qinglong:2.17.9"
QL_PATH=""
SHELL_FOLDER="/opt"
CONTAINER_NAME=""
TAG="2.17.9"
NETWORK="host"
QL_PORT=5700

HAS_IMAGE=false
PULL_IMAGE=true
HAS_CONTAINER=false
DEL_CONTAINER=true
OLD_IMAGE_ID=""

# 定义子目录路径变量（修复未定义变量错误）
CONFIG_PATH=""
DB_PATH=""
REPO_PATH=""
RAW_PATH=""
SCRIPT_PATH=""
LOG_PATH=""
JBOT_PATH=""

log() {
    echo -e "\e[32m\n$1 \e[0m\n"
}

inp() {
    echo -e "\e[33m\n$1 \e[0m\n"
}

opt() {
    echo -n -e "\e[36m输入您的选择->\e[0m"
}

warn() {
    echo -e "\e[31m$1 \e[0m\n"
}

cancelrun() {
    if [ $# -gt 0 ]; then
        echo -e "\e[31m $1 \e[0m"
    fi
    exit 1
}

docker_install() {
    echo "检测 Docker......"
    if [ -x "$(command -v docker)" ]; then
        echo "检测到 Docker 已安装!"
    else
        if [ -r /etc/os-release ]; then
            lsb_dist="$(. /etc/os-release && echo "$ID")"
        fi
        if [ "$lsb_dist" == "openwrt" ]; then
            echo "安装 docker 环境..."
            opkg update -V0
            opkg install -V0 --force-checksum --force-depends luci-app-dockerman
            echo "安装 docker 环境...安装完成!"
        else
            echo "安装 docker 环境..."
            curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
            echo "安装 docker 环境...安装完成!"
            systemctl enable docker
            systemctl start docker
        fi
    fi
}

# 关键修复函数：安全创建目录
safe_mkdir() {
    local dir_path="$1"
    # 处理以破折号开头的路径
    if [[ "${dir_path}" == -* ]]; then
        mkdir -p -- "./${dir_path}" || cancelrun "目录创建失败: ./${dir_path}"
    else
        mkdir -p -- "${dir_path}" || cancelrun "目录创建失败: ${dir_path}"
    fi
}

docker_install
warn "降低学习成本，小白回车到底，一路默认选择"

# ====================== 修复点1：安全创建目录 ======================
echo -n -e "\e[33m一、请输入配置文件保存的绝对路径（示例：/root/ql1)，回车默认为 /opt/ql:\e[0m"
read ql_path
if [ -z "$ql_path" ]; then
    QL_PATH="$SHELL_FOLDER/ql"
    safe_mkdir "$QL_PATH"
elif [ -d "$ql_path" ]; then
    QL_PATH="$ql_path"
else
    QL_PATH="$ql_path"
    safe_mkdir "$QL_PATH"
fi

# ====================== 修复点2：定义子目录路径 ======================
CONFIG_PATH="$QL_PATH/config"
DB_PATH="$QL_PATH/db"
REPO_PATH="$QL_PATH/repo"
RAW_PATH="$QL_PATH/raw"
SCRIPT_PATH="$QL_PATH/scripts"
LOG_PATH="$QL_PATH/log"
JBOT_PATH="$QL_PATH/jbot"

# 检测镜像是否存在
if [ ! -z "$(docker images -q $DOCKER_IMG_NAME:$TAG 2> /dev/null)" ]; then
    HAS_IMAGE=true
    OLD_IMAGE_ID=$(docker images -q --filter reference=$DOCKER_IMG_NAME:$TAG)
    inp "检测到先前已经存在的镜像，是否拉取最新的镜像：\n1) 拉取[默认]\n2) 不拉取"
    opt
    read update
    if [ "$update" = "2" ]; then
        PULL_IMAGE=false
    fi
fi

# 检测容器是否存在
check_container_name() {
    if [ ! -z "$(docker ps -a | grep $CONTAINER_NAME 2> /dev/null)" ]; then
        HAS_CONTAINER=true
        inp "检测到先前已经存在的容器，是否删除先前的容器：\n1) 删除[默认]\n2) 不删除"
        opt
        read update
        if [ "$update" = "2" ]; then
            PULL_IMAGE=false
            inp "您选择了不删除之前的容器，需要重新输入容器名称"
            input_container_name
        fi
    fi
}

# 容器名称
input_container_name() {
    echo -n -e "\e[33m\n二、请输入要创建的 Docker 容器名称[默认为：qinglong]->\e[0m"
    read container_name
    if [ -z "$container_name" ]; then
        CONTAINER_NAME="qinglong"
    else
        CONTAINER_NAME="$container_name"
    fi
    check_container_name
}
input_container_name

inp "请选择容器的网络类型：\n1) host[默认]\n2) bridge"
opt
read net
if [ "$net" = "1" ]; then
    NETWORK="host"
    MAPPING_QL_PORT=""
    MAPPING_NINJA_PORT=""
fi

# 端口问题
modify_ql_port() {
    inp "是否修改青龙端口[默认 5700]：\n1) 修改\n2) 不修改[默认]"
    opt
    read change_ql_port
    if [ "$change_ql_port" = "1" ]; then
        echo -n -e "\e[36m输入您想修改的端口->\e[0m"
        read QL_PORT
    fi
}

if [ "$NETWORK" = "bridge" ]; then
    inp "是否映射端口：\n1) 映射[默认]\n2) 不映射"
    opt
    read port
    if [ "$port" = "2" ]; then
        MAPPING_QL_PORT=""
    fi
fi


# 配置已经创建完成，开始执行
log "1.开始创建配置文件目录"
# ====================== 修复点3：安全创建子目录 ======================
PATH_LIST=("$CONFIG_PATH" "$DB_PATH" "$REPO_PATH" "$RAW_PATH" "$SCRIPT_PATH" "$LOG_PATH" "$JBOT_PATH")
for i in "${PATH_LIST[@]}"; do
    safe_mkdir "$i"
done
 
if [ "$HAS_CONTAINER" = true ] && [ "$DEL_CONTAINER" = true ]; then
    log "2.1.删除先前的容器"
    docker stop $CONTAINER_NAME >/dev/null
    docker rm $CONTAINER_NAME >/dev/null
fi

if [ "$HAS_IMAGE" = true ] && [ "$PULL_IMAGE" = true ]; then
    if [ ! -z "$OLD_IMAGE_ID" ] && [ "$HAS_CONTAINER" = true ] && [ "$DEL_CONTAINER" = true ]; then
        log "2.2.删除旧的镜像"
        docker image rm $OLD_IMAGE_ID 
    fi
    log "2.3.开始拉取最新的镜像"
    docker pull $DOCKER_IMG_NAME:$TAG
    if [ $? -ne 0 ] ; then
        cancelrun "** 错误：拉取不到镜像！"
    fi
fi

# 端口存在检测
check_port() {
    echo "正在检测端口:$1"
    netstat -tlpn | grep "[[:graph:]]*:${1}\b"
}
if [ "$port" != "2" ]; then
    while check_port $QL_PORT; do    
        echo -n -e "\e[31m端口:$QL_PORT 被占用，请重新输入青龙面板端口：\e[0m"
        read QL_PORT
    done
    echo -e "\e[34m恭喜，端口:$QL_PORT 可用\e[0m"
    MAPPING_QL_PORT="-p $QL_PORT:5700"
fi


log "3.开始创建容器并执行"
docker run -dit \
    -t \
    -v "$QL_PATH":/ql/data \
    $MAPPING_QL_PORT \
    --name $CONTAINER_NAME \
    --hostname qinglong \
    --restart always \
    --network $NETWORK \
    $DOCKER_IMG_NAME:$TAG

if [ $? -ne 0 ] ; then
    cancelrun "** 错误：容器创建失败，请翻译以上英文报错，Google/百度尝试解决问题！"
fi

# ====================== 修复点4：安全复制配置文件 ======================
log "3.1 复制配置文件"
docker cp $CONTAINER_NAME:/ql/sample/config.sample.sh "$CONFIG_PATH/config.sh"
if [ $? -ne 0 ] ; then
    warn "** 警告：配置文件复制失败，但容器已启动"
fi

log "4.下面列出所有容器"
docker ps

# Nginx 静态解析检测
log "5.开始检测 Nginx 静态解析"
echo "开始扫描静态解析是否在线！"
ps -fe|grep nginx|grep -v grep
if [ $? -ne 0 ]; then
    echo "$(date +%Y-%m-%d" "%H:%M:%S) 扫描结束！Nginx 静态解析停止！准备重启！"
    docker exec -it $CONTAINER_NAME nginx -c /etc/nginx/nginx.conf
    echo "$(date +%Y-%m-%d" "%H:%M:%S) Nginx 静态解析重启完成！"
else
    echo "$(date +%Y-%m-%d" "%H:%M:%S) 扫描结束！Nginx 静态解析正常！"
fi

if [ "$port" = "2" ]; then
    log "6.用户名和密码已显示，请登录 ql/ (或 路由ip:$QL_PORT)"
    cat "$CONFIG_PATH/auth.json" 2>/dev/null || warn "未找到认证文件"
fi


log "请登录 ip:$QL_PORT enjoy~"
