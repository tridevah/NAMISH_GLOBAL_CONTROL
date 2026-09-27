#!/bin/bash
ssh -i ~/.ssh/namish_erp_vps tridevah@97.74.92.189 << 'EOF'
sudo cp /etc/nginx/sites-available/erp.tridevah.com /etc/nginx/sites-available/erp.tridevah.com.bak

sudo bash -c 'cat << "NGINX_CONF" > /etc/nginx/sites-available/erp.tridevah.com
server {
    listen 443 ssl;
    listen [::]:443 ssl;

    server_name erp.tridevah.com;

    ssl_certificate /etc/letsencrypt/live/erp.tridevah.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/erp.tridevah.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location = /api/cron/sync-integration-catalogs {
        client_max_body_size 10m;
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 30s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
    }

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_connect_timeout 30s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
    }
}

server {
    listen 80;
    listen [::]:80;

    server_name erp.tridevah.com;

    return 301 https://$host$request_uri;
}
NGINX_CONF'

echo "Testing NGINX configuration..."
if sudo nginx -t; then
    echo "Reloading NGINX..."
    sudo systemctl reload nginx
    echo "NGINX updated successfully."
else
    echo "Validation failed! Restoring backup..."
    sudo cp /etc/nginx/sites-available/erp.tridevah.com.bak /etc/nginx/sites-available/erp.tridevah.com
    sudo nginx -t
    exit 1
fi
EOF
