CCIS: Clear Cloud Initialization Service
#######################################

CCIS is a service that `clr-installer`_ uses to automatically install an instance of
Clear Linux.  It applies role-based cloud-init configurations during the
installation.  It can be used to stand up a cluster of Clear Linux instances
that are ready to be managed with Ansible.

Getting Started
===============

To get started, simply ``git clone https://github.com/clearlinux/clr-cloud-init-svc.git``,
configure parameters.conf to suit your system, and run ``install.sh``. 
This will provision a PXE server, install CCIS with default configurations,
and disable NetworkManager for the internal/external interfaces set in
parameters.conf which allows the systemd-networkd settings to take effect.

The default configuration for provisioning a PXE server creates a router that
performs network address translation for PXE clients.  Additional requirements
that must be met to use the default configuration out of the box are outlined in
the preparations section of the `network booting`_ documentation for Clear
Linux.

CCIS relies on cloud-init configurations to perform an automated installation of
Clear Linux. These need to be changed to apply user-specific configurations.
Instructions on how to change these are outlined in the `bulk provisioning`_
documentation for Clear Linux.


.. _clr-installer: https://github.com/clearlinux/clr-installer
.. _network booting: https://clearlinux.org/documentation/clear-linux/guides/network/ipxe-install
.. _bulk provisioning: https://clearlinux.org/documentation/clear-linux/guides/maintenance/bulk-provision
