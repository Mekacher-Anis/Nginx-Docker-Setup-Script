#!/usr/bin/bash

IMG_NAME='anismk/nginx-server'

# check required packages
check_packages() {
    echo "[LOG] checking necessary packages..."
    if ! command -v curl &>/dev/null; then
        apt-get install curl -y
    fi
    if [[ $(dpkg -l | grep 'docker-ce') ]]; then
        echo "[INFO] docker already installed."
    else
        echo "[LOG] installing docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
    fi
    if ! command -v docker-compose &>/dev/null; then
        echo "installing docker-compose..."
        curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
}

# create necessary directories
check_dirs() {
    echo "[LOG] checking/creating necessary directories..."
    if [ ! -d $NGINX_ROOT_FOLDER/logs/$SERVER_NAME ]; then mkdir -p $NGINX_ROOT_FOLDER/logs/$SERVER_NAME; fi
    if [ ! -d $NGINX_ROOT_FOLDER/config/conf.d ]; then mkdir -p $NGINX_ROOT_FOLDER/config/conf.d; fi
    if [ ! -d $NGINX_ROOT_FOLDER/srv/$SERVER_NAME ]; then mkdir -p $NGINX_ROOT_FOLDER/srv/$SERVER_NAME; fi
    if [ ! -d $NGINX_ROOT_FOLDER/tls ]; then mkdir -p $NGINX_ROOT_FOLDER/tls; fi
    chown -R $USERNAME:$USERNAME $NGINX_ROOT_FOLDER

    # move default configuration files
    if [ ! -f $NGINX_ROOT_FOLDER/config/nginx.conf ]; then
        cp nginx.conf $NGINX_ROOT_FOLDER/config/nginx.conf
        cp mime.types $NGINX_ROOT_FOLDER/config/mime.types
        chown -R $USERNAME:$USERNAME $NGINX_ROOT_FOLDER/config
    fi
}

create_server_files() {
    if [ ! -f $NGINX_ROOT_FOLDER/config/conf.d/$SERVER_NAME.conf ]; then
        export SERVER_NAME
        envsubst <server-template.conf >$SERVER_NAME.conf
        mv $SERVER_NAME.conf $NGINX_ROOT_FOLDER/config/conf.d/$SERVER_NAME.conf
        chown $USERNAME:$USERNAME $NGINX_ROOT_FOLDER/config/conf.d/$SERVER_NAME.conf
        envsubst < index-template.html > index.html
        mv index.html $NGINX_ROOT_FOLDER/srv/$SERVER_NAME/index.html
        chown $USERNAME:$USERNAME $NGINX_ROOT_FOLDER/srv/$SERVER_NAME/index.html
        touch $NGINX_ROOT_FOLDER/logs/$SERVER_NAME/access.log $NGINX_ROOT_FOLDER/logs/$SERVER_NAME/error.log
        chown -R $USERNAME:$USERNAME $NGINX_ROOT_FOLDER/logs/$SERVER_NAME
    fi
}

# create the required nginx image
create_nginx_image() {
    echo "[LOG] building nginx image..."
    docker build -f nginx-dockerfile -t $IMG_NAME . 1>/dev/null
}

# generate docker compose configuration and start server
start_docker_compose() {
    # if nc -z 127.0.0.1 80 || nc -z 127.0.0.1 443; then
    #     echo "[ERROR] Ports 80,443 are already in use, please stop the services that are using the ports before running the script again."
    #     #return 1
    # fi

    # if nginx image doesn't exist then build it
    if [[ "$(docker images -q $IMG_NAME 2> /dev/null)" == "" ]]; then
        create_nginx_image
    fi

    # if the image is already running, then simply reload the configuration
    if [[ $(docker ps | grep anismk-nginx-server) ]]; then
        echo "[LOG] Nginx Server already running, reloading configuration..."
        $(docker exec anismk-nginx-server nginx -s reload) 2>&1 > /dev/null
        return 0
    fi

    # else build composer file and start services
    rm -f docker-compose.yml
    envsubst <compose-template.yml >docker-compose.yml
    docker-compose up -d 1>/dev/null
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

# generate folders necessary for the new server
add_server() {
    if [ -z $1 ]; then return; fi
    echo "[LOG] Adding new server..."
    create_server_files $1
}

parse_cmd_args() {
    # parse command line arguments
    OPTIONS=u:p:d:
    LONGOPTS=user:,path:,domain:

    ! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit 2
    fi
    # read getopt’s output this way to handle the quoting right:
    eval set -- "$PARSED"

    USERNAME=''
    NGINX_ROOT_FOLDER=''
    SERVER_NAME=''
    while true; do
        case "$1" in
        -u | --user)
            USERNAME=$2
            shift 2
            ;;
        -p | --path)
            NGINX_ROOT_FOLDER=$2
            shift 2
            ;;
        -d | --domain)
            SERVER_NAME=$2
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error"
            exit 3
            ;;
        esac
    done

    # the username must be given
    if [ -z $USERNAME ]; then
        echo "username required, please specify it using the '-u | --user' option"
        exit 1
    fi

    if [ -z $SERVER_NAME ]; then
        echo "Please specify the domain name of the service using the '-d | --domain' option"
        exit 1
    fi

    # if no path has been, set the default path to the use home directory
    if [ -z $NGINX_ROOT_FOLDER ]; then
        NGINX_ROOT_FOLDER=/home/$USERNAME/nginx-data
    fi

    export NGINX_ROOT_FOLDER
    export SERVER_NAME
    export USERNAME

    echo -e "[CONFIG]\nselected user\t: ${USERNAME}\nroot folder\t: ${NGINX_ROOT_FOLDER}\nnew server name\t: ${SERVER_NAME}\n"
}

####################################################
################### main script ####################
####################################################

if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Please run as root"
    exit
fi

parse_cmd_args $@

# always check if all required packages are installed
# and the directory structure exists
check_packages
check_dirs
add_server $SERVER_NAME

if start_docker_compose; then
    log_infos
else
    echo "[ERROR] sorry, something went wrong, couldn't start nginx-server."
fi
