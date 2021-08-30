sudo docker run --rm --name certbot \
                -v "$NGINX_ROOT_FOLDER/tls/config:/etc/letsencrypt" \
                -v "$NGINX_ROOT_FOLDER/tls/work_dir:/var/lib/letsencrypt" \
                -v "$NGINX_ROOT_FOLDER/tls/log:/var/log/letsencrypt" \
                -p "80:80" -p "443:443" \
                certbot/certbot certonly --standalone --dry-run \
                -n -m "anismekacher@outlook.com" \
                -d dev.anismk.de \
                --cert-name $SERVER_NAME \
                --agree-tos \
                --quiet