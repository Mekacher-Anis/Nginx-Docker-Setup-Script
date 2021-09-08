# Nginx-Docker-Setup-Script
Bash (debian) script for setting up nginx with docker.

# basic commands
The script must be ran with root previliges.\
The script needs a username and a domain name specified using `-u` and `-d` options
### Add static file server
`sudo ./setup.sh -u user -d example.com`
### Add proxy server
`sudo ./setup.sh -u user -t proxy -d example.com -s http://docker.host.ip:8080`
### Add php enabled server
`sudo ./setup.sh -u user -t php -d example.com`
### Enable SSL encryption
Just append `--ssl` to any of the previous commands to automatically request an SSL certificate \
`sudo ./setup.sh -u user -d example.com --ssl -m email@example.com`
### Disable/enable a server
`sudo ./setup.sh -u user -d example.com --enable/disable`
### Delete server and all files
`sudo ./setup.sh -u user -d example.com --delete`
### reload the nginx configuration manually
`sudo docker exec anismk-nginx-server nginx -s reload`
### list all configured servers
`sudo ./setup.sh -u user -l`
### install the script for easier access
To be able to run this script more easily without having to cd to this folder, run the following command. \
`sudo ./setup.sh -u user -i` \
This script will then be avaible by calling `ndss` from the command line

# command line arguments
|argument|default|description|
|:---: | :--: | :---------: |
|-u --user| - | the username of the owner of the nginx server|
|-p --path | /home/$USERNAME/nginx-data | the path to the folder where all nginx files should be stored |
|-d --domain | - | the domain of the server to be created/modified |
|-t --type | 'server' | 'server': static files server / 'php': server for serving php files / 'proxy': nginx reverse proxy server |
| -s --proxiedServer| - | the server to be proxied, used in combination with type 'proxy'. To access a server running on host use the IP "docker.host.ip" |
| --ssl | - | automatically acquire an SSL certificate for the specified domain |
| -m --email | - | the email to be used for SSL certificate renewal notifications |
| --disable | - | disable the server for the specified domain |
| --enable | - | enable an already disabled server for a domain |
| --delete | - | delete the server for the specified domain and all its files |
| -l --list | - | list all the configured servers. |
| -i --install | - | install this script to make it more accessible using `ndss` command |

# Todo
- [x] update readme file (because it's way too fucking old)
- [x] make it easier to add new server quickly
- [x] add a way to specify the host IP as proxied ip address 
- [x] add the functionality to signal nginx to reload the data.
- [x] add the functionality to start certbot and automatically request a let's encrypt certificate.
- [x] add the functionality to disable/remove a server.
- [x] add basic support for php-fpm and/or apache for serving php files.
- [x] add a simple way to list all available servers and if they're active or not
- [x] improve logging (because this [log] and [info] shit doesn't make sense)
- [x] add systemd timer for checking certifcate renewals.
- [ ] make the script installable
- [ ] add option to easily make compressed and encrypted backups
- [ ] add option to automatically create periodic backups and upload them to a remote server.
- [ ] add the functionality to easily update nginx to latest version.
- [ ] add a check to stop the script if one of the actions requires the container to be already running but it's not
