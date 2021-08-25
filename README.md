# Nginx-Docker-Setup-Script
One-click bash (debian) setup script for nginx with docker.

# Usage
1. clone repo `git clone https://github.com/Mekacher-Anis/Nginx-Docker-Setup-Script.git nginx-setup`
2. run setup script as root with username `cd nginx-setup && sudo ./setup.sh $USER`
3. set your server name `SERVER_NAME=TestServer`
4. create the necessary server subfolders
```
cp /home/$USER/nginx-data/config/conf.d/default.conf /home/$USER/nginx-data/config/conf.d/$SERVER_NAME.conf \
&& mkdir /home/$USER/nginx-data/srv/$SERVER_NAME \
&& mkdir /home/$USER/nginx-data/logs/$SERVER_NAME \
&& touch /home/$USER/nginx-data/logs/$SERVER_NAME/access.log /home/$USER/nginx-data/logs/$SERVER_NAME/error.log \
&& mkdir /home/$USER/nginx-data/tls/$SERVER_NAME
```
5. add your server files to `/home/$USER/nginx-data/srv/$SERVER_NAME`
6. signal nginx to reload the configuration files.

# What this script does
1. checks if all required dependencies are met and installs them accordingly, the dependencies are:
    - curl
    - docker-ce
    - docker-compose
2. creates the "nginx-data" directory structure in "/home/\<given username\>/nginx-data, which has the following structure:
    - "srv" mapped to "/srv" in the nginx-server docker image which is the default location it serves website data from. This where the new virtual servers should place their data.
    - "logs" mapped to "/logs" which is where nginx writes its logs. Users are encouraged to create subfolders of this folder for the virtual servers. 
    - "config" mapped to "/etc/nginx" which contains nginx's main cofiguration file. This file should not be modified.
        - "conf.d" mappted to "/etc/nginx/conf.d" and this is where the virtual servers should add their configuration files.
    - "tls" mapped to "/tls" and this should contain subfolders for every virtual server and the corresponding TLS certificates should be added there.
3. creates the default webserver by creating the necessary subfolders in the structure above and copying all necessary configuration files.
4. builds the required nginx server image based on the "nginx:alpine" docker image.
5. generates the required "docker-compose.yml" and starts up nginx.
5. copies the "docker-compose.yml" file to the "nginx-data" directory for use later.

# Commands
- to reload the nginx configuration manually run the following comamnd `docker exec anismk-nginx-server nginx -s reload`

# Todo
- [x] make it easier to add new server quickly
- [x] add a way to specify the host IP as proxied ip address 
- [x] add the functionality to signal nginx to reload the data.
- [ ] add the functionality to start certbot and automatically request a let's encrypt certificate.
- [ ] add script (perhaps saved in /usr/bin) to easily add virual server or proxy servers.
- [ ] add the functionality to easily update nginx to latest version.
- [ ] add the functionality to disable/remove a server.
- [ ] add basic support for php-fpm and/or apache for serving php files.
