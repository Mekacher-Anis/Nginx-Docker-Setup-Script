#!/usr/bin/bash

# check required packages
check_packages()
{
    echo "[LOG] checking necessary packages..."
    if ! command -v curl &> /dev/null;
    then
        apt-get install curl -y
    fi
    if [[ $(dpkg -l | grep 'docker-ce') ]]
    then
        echo "[INFO] docker already installed."
    else
        echo "[LOG] installing docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
    fi
    if ! command -v docker-compose &> /dev/null
    then
        echo "installing docker-compose..."
        curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
}


# create necessary directories
check_dirs()
{
    echo "[LOG] creating necessary directories..."
    if [ ! -d $NGINX_ROOT_FOLDER/logs/default ]; then mkdir -p $NGINX_ROOT_FOLDER/logs/default;fi
    if [ ! -d $NGINX_ROOT_FOLDER/config/conf.d ]; then mkdir -p $NGINX_ROOT_FOLDER/config/conf.d;fi
    if [ ! -d $NGINX_ROOT_FOLDER/srv/default ]; then mkdir -p $NGINX_ROOT_FOLDER/srv/default;fi
    if [ ! -d $NGINX_ROOT_FOLDER/tls ]; then mkdir -p $NGINX_ROOT_FOLDER/tls;fi
    chown -R $1:$1 $NGINX_ROOT_FOLDER

    # move default configuration files
    if [ ! -f $NGINX_ROOT_FOLDER/config/nginx.conf ];
    then
        cp nginx.conf $NGINX_ROOT_FOLDER/config/nginx.conf
        cp mime.types $NGINX_ROOT_FOLDER/config/mime.types
        chown -R $1:$1 $NGINX_ROOT_FOLDER/config
    fi
}

create_default_server() {
    if [ ! -f $NGINX_ROOT_FOLDER/config/conf.d/default.conf ];
    then
        cp default-server.conf $NGINX_ROOT_FOLDER/config/conf.d/default.conf
        chown $1:$1 $NGINX_ROOT_FOLDER/config/conf.d/default.conf
        cp index.html $NGINX_ROOT_FOLDER/srv/default/index.html
        chown $1:$1 $NGINX_ROOT_FOLDER/srv/default/index.html
        touch $NGINX_ROOT_FOLDER/logs/default/access.log $NGINX_ROOT_FOLDER/logs/default/error.log
        chown -R $1:$1 $NGINX_ROOT_FOLDER/logs/default
    fi
}

# create the required nginx image
create_nginx_image() {
    echo "[LOG] building nginx image..."
    IMG_NAME='anismk/nginx-server'
    docker build -f nginx-dockerfile -t $IMG_NAME . 1> /dev/null
}

# generate docker compose configuration and start server
start_docker_compose() {
    if nc -z 127.0.0.1 80,nc -z 127.0.0.1 443; then
        echo "[ERROR] Ports 80,443 are already in use, please stop the services that are using the ports before running the script again."
        #return 1
    fi
    echo "[LOG] starting nginx server..."
    rm -f docker-compose.yml
    envsubst < compose-template.yml > docker-compose.yml
    docker-compose up -d 1> /dev/null
    res=$?
    mv docker-compose.yml $NGINX_ROOT_FOLDER/docker-compose.yml
    return $res
}

# log infos
log_infos() {
    echo "[INFO] server started successfully !"
    echo "[INFO] nginx data folder is located at $NGINX_ROOT_FOLDER please add new websites there."
    echo "[INFO] the created image is named $IMG_NAME"
    echo "[INFO] the generated docker-compose file is located at $NGINX_ROOT_FOLDER/docker-compose.yml"
}





####################################################
################### main script ####################
####################################################

if [ "$EUID" -ne 0 ]
then
  echo "[ERROR] Please run as root"
  exit
fi

if [ $# -lt 1 ]
then
    echo "USAGE: ./setup.sh username"
    exit
fi

NGINX_ROOT_FOLDER=/home/$1/nginx-data
export NGINX_ROOT_FOLDER

check_packages
check_dirs
create_default_server
create_nginx_image
if start_docker_compose;
then
    log_infos
else
    echo "[ERROR] sorry, something went wrong, couldn't start nginx-server."
fi
