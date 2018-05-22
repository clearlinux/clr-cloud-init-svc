ICIS: Ister Cloud Initalization Service
#######################################

ICIS is a service that `Ister`_ uses to automatically install an instance of
Clear Linux.  It applies role-based coud-init configurations during the
installation.  It can be used to stand up a cluster of Clear Linux instances
that are ready to be managed with Ansible.

Getting Started
===============

To get started, simply ``git clone`` the repository and run ``install.sh``.
This will provision a PXE server and install ICIS with default configurations.

The default configuration for provisioning a PXE server creates a router that
performs network address translation for PXE clients.  Additional requirements
that must be met to use the default configuration out of the box are outlined in
the preparations section of the `network booting`_ documentation for Clear
Linux.

ICIS relies on cloud-init configurations to perform an automated installation of
Clear Linux. These need to be changed to apply user-specific configurations.
Instructions on how to change these are outlined in the `bulk provisioning`_
documentation for Clear Linux.


.. _Ister: https://github.com/bryteise/ister
.. _network booting: https://clearlinux.org/documentation/clear-linux/guides/network/ipxe-install
.. _bulk provisioning: https://clearlinux.org/documentation/clear-linux/guides/maintenance/bulk-provision
