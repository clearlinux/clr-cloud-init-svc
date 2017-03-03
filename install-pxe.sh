#!/bin/bash
external_iface=eno1
internal_iface=eno2
pxe_subnet=192.168.1
pxe_internal_ip=$pxe_subnet.1
pxe_subnet_mask_ip=255.255.255.0
tftp_root=/srv/tftp

main() {
	install_dependencies
	configure_network
	configure_nat
	configure_tftp_server
	configure_dhcp_server
}

install_dependencies() {
	swupd bundle-add pxe-server
}

configure_network() {
	rm -rf /etc/systemd/network
	mkdir -p /etc/systemd/network
	
	ln -sf /dev/null /etc/systemd/network/80-dhcp.network
	
	cat > /etc/systemd/network/80-external-dynamic.network << EOF
[Match]
Name=$external_iface
[Network]
DHCP=yes
EOF
	
	local bitmask
	convert_ip_address_to_bitmask $pxe_subnet_mask_ip bitmask
	cat > /etc/systemd/network/80-internal-static.network << EOF
[Match]
Name=$internal_iface
[Network]
Address=$pxe_internal_ip/$bitmask
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

configure_nat() {
	iptables -t nat -F POSTROUTING
	iptables -t nat -A POSTROUTING -o $external_iface -j MASQUERADE
	iptables -t filter -F FORWARD
	iptables -t filter -A FORWARD -i $external_iface -o $internal_iface -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -t filter -A FORWARD -i $internal_iface -o $external_iface -j ACCEPT
	iptables_save_units=($(ls /usr/lib/systemd/system | egrep 'ip6?tables-save'))
	systemctl enable ${iptables_save_units[@]}
	systemctl restart ${iptables_save_units[@]}
	iptables_restore_units=($(ls /usr/lib/systemd/system | egrep 'ip6?tables-restore'))
	systemctl enable ${iptables_restore_units[@]}
	systemctl restart ${iptables_restore_units[@]}
	
	rm -rf /etc/sysctl.d
	mkdir -p /etc/sysctl.d
	echo net.ipv4.ip_forward=1 > /etc/sysctl.d/80-nat-forwarding.conf
	echo 1 > /proc/sys/net/ipv4/ip_forward
}

configure_tftp_server() {
	rm -rf $tftp_root
	mkdir -p $tftp_root
	ln -sf /usr/share/ipxe/ipxe-x86_64.efi $tftp_root/ipxe-x86_64.efi
	ln -sf /usr/share/ipxe/undionly.kpxe $tftp_root/undionly.kpxe
	
	cat > /etc/systemd/resolved.conf << EOF
[Resolve]
DNSStubListener=no
EOF
	systemctl restart systemd-resolved
	
	cat > /etc/dnsmasq.conf << EOF
interface=$internal_iface
enable-tftp
tftp-root=$tftp_root
EOF
	systemctl enable dnsmasq
	systemctl restart dnsmasq
}

configure_dhcp_server() {
	local host_dns_servers=($(grep -Po '(?<=nameserver )(\d+\.?){4}' /etc/resolv.conf))
	local dns_server_list=$(echo ${host_dns_servers[@]} | sed 's/ /, /g')
	
	cat > /etc/dhcpd.conf << EOF
DHCPDARGS="$internal_iface";
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

subnet $pxe_subnet.0 netmask $pxe_subnet_mask_ip {
	option broadcast-address $pxe_subnet.255;
	option routers $pxe_internal_ip;
	option domain-name-servers $dns_server_list, $pxe_internal_ip;
	
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
	
	rm -rf /var/db
	mkdir -p /var/db
	touch /var/db/dhcpd.leases
	
	systemctl enable dhcp4
	systemctl restart dhcp4
}

main

