#!/bin/bash
source $(dirname $0)/parameters.conf

main() {
	if [ -d /sys/class/net/$external_iface ] && [ -d /sys/class/net/$internal_iface ] && [[ $(grep '^up$' /sys/class/net/$external_iface/operstate) ]] && [[ $(grep '^up$' /sys/class/net/$internal_iface/operstate) ]]; then
		populate_ipxe_content
		configure_tftp_server
		configure_dns_server
		configure_network
		configure_dhcp_server
		configure_nat
		return 0
	else
		echo 'ERROR: External interface or internal interface does not exist!!  Alternatively, external interface or internal interface is not up!!'
		echo 'PXE not configured!!'
		return 1
	fi
}

populate_ipxe_content() {
	rm -rf $ipxe_root
	mkdir -p $ipxe_root
	curl -o /tmp/clear-pxe.tar.xz https://download.clearlinux.org/current/clear-$(curl https://download.clearlinux.org/latest)-pxe.tar.xz
	tar -xJf /tmp/clear-pxe.tar.xz -C $ipxe_root
	ln -sf $(ls $ipxe_root | grep 'org.clearlinux.*') $ipxe_root/linux
	cat > $ipxe_root/ipxe_boot_script.txt << EOF
#!ipxe
kernel linux quiet init=/usr/lib/systemd/systemd-bootchart initcall_debug tsc=reliable no_timer_check noreplace-smp rw initrd=initrd clri.descriptor=http://$pxe_internal_ip/$icis_app_name/static/clr-installer/cloud.yaml
initrd initrd
boot
EOF
}

configure_tftp_server() {
	rm -rf $tftp_root
	mkdir -p $tftp_root
	ln -sf /usr/share/ipxe/ipxe-x86_64.efi $tftp_root/ipxe-x86_64.efi
	ln -sf /usr/share/ipxe/undionly.kpxe $tftp_root/undionly.kpxe
	cat > /etc/dnsmasq.conf << EOF
enable-tftp
tftp-root=$tftp_root
EOF
	
	systemctl enable dnsmasq
	
}

configure_dns_server() {
	mkdir -p /etc/systemd
	cat > /etc/systemd/resolved.conf << EOF
[Resolve]
DNSStubListener=no
EOF
	cat >> /etc/dnsmasq.conf << EOF
listen-address=$pxe_internal_ip
EOF
	
	systemctl stop systemd-resolved
	systemctl restart dnsmasq
	systemctl start systemd-resolved
}

configure_network() {
	mkdir -p /etc/systemd/network
	ln -sf /dev/null /etc/systemd/network/80-dhcp.network
	cat > /etc/systemd/network/80-external-dynamic.network << EOF
[Match]
Name=$external_iface
[Network]
DHCP=yes
EOF
	local pxe_subnet_bitmask
	convert_ip_address_to_bitmask $pxe_subnet_mask_ip pxe_subnet_bitmask
	cat > /etc/systemd/network/80-internal-static.network << EOF
[Match]
Name=$internal_iface
[Network]
DHCP=no
Address=$pxe_internal_ip/$pxe_subnet_bitmask
EOF
	
	systemctl restart systemd-networkd
}

convert_ip_address_to_bitmask() {
	local binary=''
	local D2B=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1})
	local decimals=($(tr '.' ' ' <<< $1))
	local decimal
	for decimal in "${decimals[@]}"; do
		binary=$binary${D2B[$decimal]}
	done
	eval "$2=$(grep -o 1 <<< $binary | wc -l)"
}

configure_dhcp_server() {
	cat > /etc/dhcpd.conf << EOF
# iPXE-specific options
# Source: http://www.ipxe.org/howto/dhcpd
option space ipxe;
option ipxe-encap-opts code 175 = encapsulate ipxe;
option ipxe.priority code 1 = signed integer 8;
option ipxe.keep-san code 8 = unsigned integer 8;
option ipxe.skip-san-boot code 9 = unsigned integer 8;
option ipxe.syslogs code 85 = string;
option ipxe.cert code 91 = string;
option ipxe.privkey code 92 = string;
option ipxe.crosscert code 93 = string;
option ipxe.no-pxedhcp code 176 = unsigned integer 8;
option ipxe.bus-id code 177 = string;
option ipxe.bios-drive code 189 = unsigned integer 8;
option ipxe.username code 190 = string;
option ipxe.password code 191 = string;
option ipxe.reverse-username code 192 = string;
option ipxe.reverse-password code 193 = string;
option ipxe.version code 235 = string;
option iscsi-initiator-iqn code 203 = string;
option ipxe.pxeext code 16 = unsigned integer 8;
option ipxe.iscsi code 17 = unsigned integer 8;
option ipxe.aoe code 18 = unsigned integer 8;
option ipxe.http code 19 = unsigned integer 8;
option ipxe.https code 20 = unsigned integer 8;
option ipxe.tftp code 21 = unsigned integer 8;
option ipxe.ftp code 22 = unsigned integer 8;
option ipxe.dns code 23 = unsigned integer 8;
option ipxe.bzimage code 24 = unsigned integer 8;
option ipxe.multiboot code 25 = unsigned integer 8;
option ipxe.slam code 26 = unsigned integer 8;
option ipxe.srp code 27 = unsigned integer 8;
option ipxe.nbi code 32 = unsigned integer 8;
option ipxe.pxe code 33 = unsigned integer 8;
option ipxe.elf code 34 = unsigned integer 8;
option ipxe.comboot code 35 = unsigned integer 8;
option ipxe.efi code 36 = unsigned integer 8;
option ipxe.fcoe code 37 = unsigned integer 8;
option ipxe.vlan code 38 = unsigned integer 8;
option ipxe.menu code 39 = unsigned integer 8;
option ipxe.sdi code 40 = unsigned integer 8;
option ipxe.nfs code 41 = unsigned integer 8;

class "PXE-Chainload" {
	match if substring(option vendor-class-identifier, 0, 9) = "PXEClient";
	
	next-server $pxe_internal_ip;
	if exists user-class and option user-class = "iPXE" {
		filename "http://$pxe_internal_ip/ipxe_boot_script.txt";
	}
	elsif substring(option vendor-class-identifier, 0, 20) = "PXEClient:Arch:00007" or substring(option vendor-class-identifier, 0, 20) = "PXEClient:Arch:00008" or substring(option vendor-class-identifier, 0, 20) = "PXEClient:Arch:00009" {
		filename "ipxe-x86_64.efi";
	}
	elsif substring(option vendor-class-identifier, 0, 20) = "PXEClient:Arch:00000" {
		filename "undionly.kpxe";
	}
}

subnet $pxe_subnet.0 netmask $pxe_subnet_mask_ip {
	authoritative;
	option routers $pxe_internal_ip;
	option domain-name-servers $pxe_internal_ip;
	
	pool {
		allow members of "PXE-Chainload";
		range $pxe_subnet.128 $pxe_subnet.253;
		default-lease-time 600;
		max-lease-time 3600;
	}
	
	pool {
		deny members of "PXE-Chainload";
		range $pxe_subnet.2 $pxe_subnet.127;
		default-lease-time 3600;
		max-lease-time 21600;
	}
}
EOF
	
	mkdir -p /var/db
	touch /var/db/dhcpd.leases
	
	systemctl enable dhcp4
	systemctl restart dhcp4
}

configure_nat() {
	iptables -t nat -F POSTROUTING
	iptables -t nat -A POSTROUTING -o $external_iface -j MASQUERADE
	systemctl enable iptables-save.service
	systemctl restart iptables-save.service
	systemctl enable iptables-restore.service
	systemctl restart iptables-restore.service
	
	mkdir -p /etc/sysctl.d
	echo net.ipv4.ip_forward=1 > /etc/sysctl.d/80-nat-forwarding.conf
	echo 1 > /proc/sys/net/ipv4/ip_forward
}

main

