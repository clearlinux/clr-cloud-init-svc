#!/bin/bash
source $(dirname $0)/parameters.conf

main() {
	install_dependencies
	stop_web_services
	$(dirname $0)/configure-ipxe.sh
	if [ $? -eq 0 ]; then
		populate_icis_content
		generate_web_configuration
		start_web_services
		return 0
	else
		echo 'ICIS not installed!!'
		return 1
	fi
}

install_dependencies() {
	swupd bundle-add pxe-server python-basic-dev
	pip install uwsgi
}

stop_web_services() {
	systemctl stop nginx
	systemctl stop uwsgi@$icis_app_name.socket
	systemctl disable uwsgi@$icis_app_name.service
}

populate_icis_content() {
	# Reference: http://uwsgi-docs.readthedocs.io/en/latest/Systemd.html#one-service-per-app-in-systemd
	# Reference: https://www.dabapps.com/blog/introduction-to-pip-and-virtualenv-python/
	rm -rf $icis_root
	mkdir -p $icis_root
	cp -rf $(dirname ${0})/app/* $icis_root
	local icis_venv_dir=$icis_root/env
	virtualenv $icis_venv_dir
	$icis_venv_dir/bin/pip install -r $(dirname ${0})/requirements.txt

	mkdir -p $uwsgi_app_dir
	cat > $uwsgi_app_dir/$icis_app_name.ini << EOF
[uwsgi]
# App configurations
module = app
callable = app
chdir = $icis_root
home = $icis_venv_dir

# Init system configurations
master = true
cheap = true
idle = 600
die-on-idle = true
manage-script-name = true
EOF
}

generate_web_configuration() {
	local nginx_dir=/etc/nginx
	mkdir -p $nginx_dir/conf.d
	cp -f /usr/share/nginx/conf/nginx.conf.example $nginx_dir/nginx.conf
	cat > /etc/nginx/conf.d/pxe.conf << EOF
server {
	listen 80;
	server_name localhost;
	location / {
		root $ipxe_root;
		autoindex on;
	}
	location /$icis_app_name/static/ {
		root $icis_root/static;
		rewrite ^/$icis_app_name/static(/.*)$ \$1 break;
	}
	location /$icis_app_name/ {
		uwsgi_pass unix://$uwsgi_socket_dir/$icis_app_name.sock;
		include uwsgi_params;
	}
}
EOF
}

start_web_services() {
	systemctl enable uwsgi@$icis_app_name.service
	systemctl enable uwsgi@$icis_app_name.socket
	systemctl restart uwsgi@$icis_app_name.socket
	systemctl enable nginx
	systemctl restart nginx
}

main
