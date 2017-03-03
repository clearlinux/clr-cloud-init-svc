Ister Cloud Initalization Service
=================================

This web application is a helper for standing up up n-node clusters of
Clear Linux.  It works with Ister, the Clear Linux Installer, and enables
landing role-based cloud-init userdata files.  Hosts can be stood up that
are ready to be managed with Ansible.

An install script is included which sets up an iPXE server and gets this
web application running.  It assumes that the PXE setup is using NAT, since
it is a common deployment scenario meant to isolate clients from an external
network.

For additional details, please see the following documentation on clearlinux.org:
Bulk provisioning: https://clearlinux.org/documentation/bulk_provisioning.html
Network booting: https://clearlinux.org/documentation/network_boot.html
