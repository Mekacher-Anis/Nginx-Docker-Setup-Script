#!/usr/bin/bash

NGINX_IMG_NAME='anismk/nginx-server'

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
    if [ ! -f /usr/local/bin/docker-compose ]; then
        echo "[LOG] installing docker-compose..."
        curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
}

# create necessary directories
check_dirs() {
    echo "[LOG] checking/creating necessary directories..."
    if [ ! -d $NGINX_ROOT_FOLDER/logs/$SERVER_NAME ]; then mkdir -p $NGINX_ROOT_FOLDER/logs/$SERVER_NAME; fi
    if [ ! -d $NGINX_ROOT_FOLDER/config/nginx/conf.d ]; then mkdir -p $NGINX_ROOT_FOLDER/config/nginx/conf.d; fi
    if [ ! -d $NGINX_ROOT_FOLDER/config/php/confg.d ]; then mkdir -p $NGINX_ROOT_FOLDER/config/php/conf.d; fi
    if [ ! -d $NGINX_ROOT_FOLDER/srv/$SERVER_NAME ]; then mkdir -p $NGINX_ROOT_FOLDER/srv/$SERVER_NAME; fi
    if [ ! -d $NGINX_ROOT_FOLDER/tls/log ]; then mkdir -p $NGINX_ROOT_FOLDER/tls/log; fi
    if [ ! -d $NGINX_ROOT_FOLDER/tls/work_dir ]; then mkdir -p $NGINX_ROOT_FOLDER/tls/work_dir; fi
    if [ ! -d $NGINX_ROOT_FOLDER/tls/config ]; then mkdir -p $NGINX_ROOT_FOLDER/tls/config; fi
    chown -R $USERNAME:$USERNAME $NGINX_ROOT_FOLDER

    # move default configuration files
    if [ ! -f $NGINX_ROOT_FOLDER/config/nginx/nginx.conf ]; then
        cp nginx.conf $NGINX_ROOT_FOLDER/config/nginx/nginx.conf
        cp mime.types $NGINX_ROOT_FOLDER/config/nginx/mime.types
        cp fastcgi_params $NGINX_ROOT_FOLDER/config/nginx/fastcgi_params
        cp php.ini $NGINX_ROOT_FOLDER/config/php/php.ini
        chown -R $USERNAME:$USERNAME $NGINX_ROOT_FOLDER/config
        # php-fpm default configuration file is already available on the image
    fi
}

# delete files for a defined server
delete_dirs() {
    if [ -d $NGINX_ROOT_FOLDER/logs/$SERVER_NAME ]; then rm -r $NGINX_ROOT_FOLDER/logs/$SERVER_NAME; fi
    if [ -d $NGINX_ROOT_FOLDER/srv/$SERVER_NAME ]; then rm -r $NGINX_ROOT_FOLDER/srv/$SERVER_NAME; fi
    if [ -f $NGINX_ROOT_FOLDER/config/nginx/conf.d/$SERVER_NAME.conf ]; then 
        rm $NGINX_ROOT_FOLDER/config/nginx/conf.d/$SERVER_NAME.conf;
    fi
    if [ -f $NGINX_ROOT_FOLDER/config/nginx/conf.d/$SERVER_NAME.conf.disabled ]; then 
        rm $NGINX_ROOT_FOLDER/config/nginx/conf.d/$SERVER_NAME.conf.disabled;
    fi
    if [ -f $NGINX_ROOT_FOLDER/config/php/conf.d/$SERVER_NAME.ini ]; then 
        rm $NGINX_ROOT_FOLDER/config/php/conf.d/$SERVER_NAME.ini;
    fi
}

create_server_files() {
    if [ ! -f $NGINX_ROOT_FOLDER/config/nginx/conf.d/$SERVER_NAME.conf ]; then
        # escape $document_root and $fastcgi_script_name
        document_root='$document_root'
        fastcgi_script_name='$fastcgi_script_name'
        export document_root fastcgi_script_name 
        # generate and copy server config file
        envsubst < $TYPE-template.conf >$SERVER_NAME.conf
        mv $SERVER_NAME.conf $NGINX_ROOT_FOLDER/config/nginx/conf.d/$SERVER_NAME.conf
        chown $USERNAME:$USERNAME $NGINX_ROOT_FOLDER/config/nginx/conf.d/$SERVER_NAME.conf
        # generate and copy index file if required
        if [ ! $TYPE == 'proxy' ]; then
            envsubst < index-template.html > index.html
            mv index.html $NGINX_ROOT_FOLDER/srv/$SERVER_NAME/index.html
            chown $USERNAME:$USERNAME $NGINX_ROOT_FOLDER/srv/$SERVER_NAME/index.html
        fi
        # copy php info file if this is php server
        if [ $TYPE == 'php' ]; then
            echo "<?php echo phpinfo();?>" > $NGINX_ROOT_FOLDER/srv/$SERVER_NAME/info.php
            chown $USERNAME:$USERNAME $NGINX_ROOT_FOLDER/srv/$SERVER_NAME/info.php
        fi
        # create access.log and error.log and php-fpm.ini
        touch $NGINX_ROOT_FOLDER/logs/$SERVER_NAME/access.log \
            $NGINX_ROOT_FOLDER/logs/$SERVER_NAME/error.log \
            $NGINX_ROOT_FOLDER/config/php/conf.d/$SERVER_NAME.ini
        chown -R $USERNAME:$USERNAME $NGINX_ROOT_FOLDER/logs/$SERVER_NAME
    fi
}

# create the required nginx image
create_images() {
    if [[ "$(docker images -q $NGINX_IMG_NAME 2> /dev/null)" == "" ]]; then
        echo "[LOG] building nginx image..."
        docker build -f nginx-dockerfile -t $NGINX_IMG_NAME . 1>/dev/null
    fi
    if [[ "$(docker images -q anismk/php-fpm 2> /dev/null)" == "" ]]; then
        echo "[LOG] building php image..."
        docker build -f php-dockerfile -t anismk/php-fpm . 1>/dev/null
    fi
}

# generate docker compose configuration and start server
start_docker_compose() {
    # if nginx image doesn't exist then build it
    create_images

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
    echo "[INFO] the created image is named $NGINX_IMG_NAME"
    echo "[INFO] the generated docker-compose file is located at $NGINX_ROOT_FOLDER/docker-compose.yml"
}

# request letsencrypt certificate
request_certificate() {
    # this should request the certificate, configure it and reload nginx automatically
    docker exec $NGINX_IMG_NAME /usr/bin/certbot \
                --nginx \
                -m "$EMAIL" \
                -d "$SERVER_NAME" \
                --agree-tos \
                -n \
                --quiet
                --dry-run
}

parse_cmd_args() {
    # parse command line arguments
    OPTIONS=u:p:d:t:s:m:
    LONGOPTS=user:,path:,domain:,type:,proxiedServer:,delete,enable,disable,ssl,email:

    ! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        exit 2
    fi
    # read getopt’s output this way to handle the quoting right:
    eval set -- "$PARSED"

    USERNAME=''
    NGINX_ROOT_FOLDER=''
    SERVER_NAME=''
    ACTION='create'
    TYPE='server'
    PROXIED_SERVER=''
    SSL=false
    EMAIL=''
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
        -t | --type)
            case "$2" in
                php | proxy | server)
                    TYPE="$2"
                    ;;
                *)
                    echo "[LOG] Undefined type value, defaulting to type 'server'"
                    TYPE='server'
                    ;;
            esac
            shift 2
            ;;
        -s | --proxiedServer)
            PROXIED_SERVER=$2
            shift 2
            ;;
        --delete)
            ACTION='delete'
            shift
            ;;
        --enable)
            ACTION='enable'
            shift
            ;;
        --disable)
            ACTION='disable'
            shift
            ;;
        --ssl)
            SSL=true
            shift
            ;;
        -m | --email)
            EMAIL="$2"
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

    if [[ $TYPE == 'proxy' && -z $PROXIED_SERVER ]]; then
        echo "Type is proxy server but no proxied server is defined, please it using '-s | --proxiedServer' option"
        exit 1
    fi

    if [[ $ACTION == 'create' && $SSL == true && -z $EMAIL ]]; then
        echo "Please provide an email for let's encrypt certificate notifications usind '-m | --email' option"
        exit 1
    fi

    # if no path has been, set the default path to the use home directory
    if [ -z $NGINX_ROOT_FOLDER ]; then
        NGINX_ROOT_FOLDER=/home/$USERNAME/nginx-data
    fi

    export NGINX_ROOT_FOLDER
    export SERVER_NAME
    export USERNAME
    export TYPE
    export PROXIED_SERVER
    export ACTION
    export SSL
    export EMAIL

    # echo -e "[CONFIG]\nselected user\t: ${USERNAME}\nroot folder\t: ${NGINX_ROOT_FOLDER}\nnew server name\t: ${SERVER_NAME}\n"
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
# check_packages
check_dirs

# hmmmm pure functions, aren't my thing, that's why the code is a bit of a mess :D
case $ACTION in 
create)
    case $TYPE in
    server)
        echo "[LOG] Adding new server..."
        create_server_files
        ;;
    proxy)
        echo "[LOG] Adding proxy server..."
        create_server_files
        ;;
    php)
        echo "[LOG] Adding php-fpm server..."
        create_server_files
        ;;
    esac
    if start_docker_compose; then
        if [ $SSL == true ]; then
            echo "Waiting for nginx to start..."
            while ! nc -z 127.0.0.1 80; do 
                sleep 3 
            done
            request_certificate
        fi

        log_infos
    else
        echo "[ERROR] sorry, something went wrong, couldn't start nginx-server."
    fi
    ;;


enable)
    # check if the configuration file exists and change the extension then reload the server
    if [ -f $NGINX_ROOT_FOLDER/config/nginx/conf.d/$SERVER_NAME.conf.disabled ]; then
        echo "[LOG] Enabling block server $SERVER_NAME ..."
        mv $NGINX_ROOT_FOLDER/config/nginx/conf.d/$SERVER_NAME.conf.disabled $NGINX_ROOT_FOLDER/config/nginx/conf.d/$SERVER_NAME.conf
        docker exec anismk-nginx-server nginx -s reload
        if [ $? ]; then
            echo "[LOG] $SERVER_NAME enabled successfully."
        fi
    else
        echo "[ERROR] Can't find the configuration file '$NGINX_ROOT_FOLDER/config/nginx/conf.d/$SERVER_NAME.conf.disabled'"
        exit 1
    fi
    ;;
disable)
    # change the extension of the config file and then reload the nginx server to disable it
    if [ -f $NGINX_ROOT_FOLDER/config/nginx/conf.d/$SERVER_NAME.conf ]; then
        echo "[LOG] Disabling block server $SERVER_NAME ..."
        mv $NGINX_ROOT_FOLDER/config/nginx/conf.d/$SERVER_NAME.conf $NGINX_ROOT_FOLDER/config/nginx/conf.d/$SERVER_NAME.conf.disabled
        docker exec anismk-nginx-server nginx -s reload
        if [ $? ]; then
            echo "[LOG] $SERVER_NAME disabled successfully."
        fi
    else
        echo "[ERROR] Can't find the configuration file '$NGINX_ROOT_FOLDER/config/nginx/conf.d/$SERVER_NAME.conf'"
        exit 1
    fi
    ;;
delete)
    printf "[LOG] You are going to delete %s configuration and all it's files, are you sure [y/n]:" $SERVER_NAME
    read -n 1 ans
    if [ $ans = 'y' ]; then
        printf "\n[LOG] Deleting %s ...\n" $SERVER_NAME
        delete_dirs
        docker exec anismk-nginx-server nginx -s reload
    fi
    ;;
esac
