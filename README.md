# Nginx-Docker-Setup-Script
One-click bash (debian) setup script for nginx with docker.

# Usage
1. clone repo `git clone https://github.com/Mekacher-Anis/Nginx-Docker-Setup-Script.git nginx-setup`
2. run setup script as root with username `cd nginx-setup && sudo ./setup.sh $USER`
3. create a new server
```
SERVER_NAME=<your desired server name>
cp /home/$USER/nginx-data/config/conf.d/default.conf /home/$USER/nginx-data/config/conf.d/$SERVER_NAME.conf \
mkdir /home/$USER/nginx-data/srv/$SERVER_NAME
mkdir /home/$USER/nginx-data/logs/$SERVER_NAME
touch /home/$USER/nginx-data/logs/$SERVER_NAME/access.log /home/$USER/nginx-data/logs/$SERVER_NAME/error.log
mkdir /home/$USER/nginx-data/tls/$SERVER_NAME
```
4. add your server files to `/home/$USER/nginx-data/srv/$SERVER_NAME`
