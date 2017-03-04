#!/bin/bash
server_hostname=$(hostname)
server_domain=$(hostname -f | sed -e "s/$server_hostname\.*//")

web_root=/var/www
pxe_root=$web_root/pxe-images
icis_root=$web_root/ister-cloud-init-svc

uwsgi_app_dir=/usr/share/uwsgi
uwsgi_socket_dir=/run/uwsgi
icis_app_name=icis

main() {
	if [ ! -z "$server_hostname" ] && [ ! -z "$server_domain" ]; then
		install_dependencies
		configure_web_server
		$(dirname $0)/configure-pxe.sh
		return $?
	else
		echo 'ERROR: Server hostname or server domain is not defined!!'
		echo 'ICIS not installed!!'
		return 1
	fi
}

install_dependencies() {
	swupd bundle-add pxe-server python-basic-dev dev-utils
	pip install uwsgi
}

configure_web_server() {
	stop_web_services
	populate_web_content
	generate_web_configuration
	start_web_services
}

stop_web_services() {
	systemctl stop nginx
	systemctl stop uwsgi@$icis_app_name.socket
	systemctl stop uwsgi@$icis_app_name.service
}

populate_web_content() {
	rm -rf $web_root
	populate_pxe_content
	populate_icis_content
}

populate_pxe_content() {
	mkdir -p $pxe_root
	curl -o /tmp/clear-pxe.tar.xz https://download.clearlinux.org/current/clear-$(curl https://download.clearlinux.org/latest)-pxe.tar.xz
	tar -xJf /tmp/clear-pxe.tar.xz -C $pxe_root
	ln -sf $(ls $pxe_root | grep 'org.clearlinux.*') $pxe_root/linux
	cat > $pxe_root/ipxe_boot_script.txt << EOF
#!ipxe
kernel linux quiet init=/usr/lib/systemd/systemd-bootchart initcall_debug tsc=reliable no_timer_check noreplace-smp rw initrd=initrd isterconf=http://$server_hostname.$server_domain/icis/static/ister/ister.conf
initrd initrd
boot
EOF
}

populate_icis_content() {
	# Reference: http://uwsgi-docs.readthedocs.io/en/latest/Systemd.html#one-service-per-app-in-systemd
	# Reference: https://www.dabapps.com/blog/introduction-to-pip-and-virtualenv-python/
	mkdir -p $icis_root
	cp -rf $(dirname ${0})/bin/* $icis_root
	
	local icis_venv_dir=$icis_root/env
	virtualenv $icis_venv_dir
	$icis_venv_dir/bin/pip install -r $(dirname ${0})/requirements.txt
	
	rm -rf $uwsgi_app_dir
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
	rm -rf /etc/nginx
	mkdir -p /etc/nginx
	cat > /etc/nginx/nginx.conf << EOF
server {
	listen 80;
	server_name $server_hostname.$server_domain;
	location / {
		root $pxe_root;
		autoindex on;
	}
	location /icis/static/ {
		root $icis_root/static;
		rewrite ^/icis/static(/.*)$ $1 break;
	}
	location /icis/ {
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

