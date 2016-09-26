Ister Cloud Init Service
========================

This little web application is intended to be a helper for standing up
up n-node clusters of Clear Linux. It complements the Clear Linux
Installer (Ister) and enables landing role-based cloud-init userdata files.
Our proof-of-concept enabled standing up hosts ready to be managed
through ansible.

Generally this would run on the iPXE server that hosts are booting from
to install Clear Linux. See docs on https://clearlinux.org for more details.

Standing up the web app (high level)
# Configure nginx
    # In /etc/nginx/nginx.conf....
    # Note only server directives here.
# Land ister-cloud-init-svc on pxe server
# Copy it to /var/www/ister-cloud-init-svc and set perms appropriately
    mkdir /var/www
    copy ister-cloud-init-svc to /var/www
    chown -R httpd:httpd /var/www
# User virtualenv and requirements.txt file to generate virtualenv for web app
# Make uwsgi logging directory
    mkdir -p /var/log/uwsgi
    chown httpd:httpd /var/log/uwsgi
# Copy uwsgiemp service file into /etc/systemd/service/uwsgiemp.service
    <insert sytemd unit file here>
# Create uwsgi vassals directory
    mkdir -p /etc/uwsgi/vassals
    ln -s /var/www/ister-cloud-init-svc/icis_uwsgi.ini  /etc/uwsgi/vassals
# Start uwsgi emperor
    systemctl enable uwsgiemp
    systemctl start uwsgiemp
# Test web-app
    curl localhost/icis/get_role/compute


.. code-block:: console

  mkdir -pv /var/www
  mkdir -pv /var/log/uwsgi
  chown httpd:httpd /var/log/uwsgi
  cd /var/www/
  git clone https://github.com/clearlinux/ister-cloud-init-svc
  chown -R httpd:httpd /var/www
  cd ister-cloud-init-svc
  # Install python if you are on clear and don't have it already this bundle
  # has it
  swupd bundle-add os-core-dev
  virtualenv .venv
  . .venv/bin/activate
  pip install -r requirements.txt
  ln -s /var/www/ister-cloud-init-svc/icis_uwsgi.service \
    /etc/systemd/system/icis_uwsgi.service
  # If you are using nginx then obviously don't trash your current config, use
  # this as a guide instead
  cp /var/www/ister-cloud-init-svc/nginx.conf /etc/nginx/nginx.conf
  systemctl daemon-reload
  systemctl restart nginx icis_uwsgi
  # Verify it reponds
  curl http://localhost/icis/get_role/compute
