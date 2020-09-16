#!/bin/bash -e
sudo -s

# setup environment
hostname=$(hostname)
realm=$(echo $hostname | awk -F'.' '{print $2"."$3}')   #st1gven.com
REALM=$(echo $realm | awk '{ print toupper($0) }')     #ST1GVEN.COM
echo "realm: $realm"
echo "REALM:$REALM"

domain=$(echo $hostname | awk -F'.' '{print $2}')       #st1gven
DOMAIN=$(echo $domain | awk '{ print toupper($0) }')    #ST1GVEN
echo "domain:$domain"
echo "DOMAIN:$DOMAIN"

node_name=$(echo $hostname | awk -F'.' '{print $1}')    #dc1
NODE_NAME=$(echo $node_name | awk '{ print toupper($0) }') #DC1
echo "node_name:$node_name"
echo "NODE_NAME:$NODE_NAME"

password="ZA1BASs"

# disable selinux
sed 's/SELINUX=.*/SELINUX=disabled/g' -i /etc/sysconfig/selinux
sed 's/SELINUX=.*/SELINUX=disabled/g' -i /etc/selinux/config
setenforce 0

# disable firewall
systemctl disable firewalld
systemctl stop firewalld

# install required packages
dnf -y install epel-release
dnf config-manager --set-enabled PowerTools
dnf -y install docbook-style-xsl gcc gdb gnutls-devel gpgme-devel jansson-devel \
      keyutils-libs-devel krb5-workstation libacl-devel libaio-devel \
      libarchive-devel libattr-devel libblkid-devel libtasn1 libtasn1-tools libtirpc-devel \
      libxml2-devel libxslt lmdb-devel openldap-devel pam-devel perl \
      perl-ExtUtils-MakeMaker perl-Parse-Yapp popt-devel python3-cryptography \
      python3-dns python3-gpg python36-devel readline-devel rpcgen systemd-devel \
      tar zlib-devel wget bind-utils samba-client authconfig dhcp-server

# compile samba cuz there`s no AD for CentOS
cd /tmp/
wget https://ftp.samba.org/pub/samba/samba-4.12.6.tar.gz -o /dev/null >/dev/null
tar -xzvf samba-4.12.6.tar.gz
cd ./samba-4.12.6
./configure #--enable-debug --enable-selftest --with-ads --with-systemd --with-winbind >/dev/null
make
make install
#//todo(deps)  sudo dnf -y remove 


rm -f /etc/krb5.conf
/usr/local/samba/bin/samba-tool domain provision --use-rfc2307 --realm="$REALM" \
        --domain="$DOMAIN" --server-role="dc" --dns-backend="SAMBA_INTERNAL" \
        --adminpass="$password"

# DNS
sed 's/\[main\]/\[main\]\ndns=none/g' -i /etc/NetworkManager/NetworkManager.conf
cat <<EOF > /etc/resolv.conf
search $realm
nameserver 127.0.0.1
domain $realm
EOF

# setup smb domain, dns, netlogon and sysvol shares
cat <<EOF > /usr/local/samba/etc/smb.conf
[global]
    workgroup = $DOMAIN
    realm = $REALM
    netbios name = $NODE_NAME
    server role = active directory domain controller
    dns forwarder = 8.8.8.8 #todo
    allow dns updates = nonsecure
    nsupdate command = /usr/bin/nsupdate -g
    template shell = /bin/bash
    template homedir = /home/%U
    
    bind interfaces only = yes
    interfaces = lo eth1
[netlogon]
    path = /usr/local/samba/var/locks/sysvol/$realm/scripts
    read only = No
    write ok = Yes

[sysvol]
    path = /usr/local/samba/var/locks/sysvol
    read only = No
    write ok = Yes
EOF

# configure Kerberos
cat <<EOF > /etc/krb5.conf
[libdefaults]
    default_realm = $REALM
    dns_lookup_realm = false
    dns_lookup_kdc = true
[realms]
$REALM = {
    default_domain = $realm
}

[domain_realm]
    dc1 = $REALM
EOF


# add samba unit
cat <<EOF > /etc/systemd/system/samba4.service
[Unit]
Description=Samba Active Directory Domain Controller
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
ExecStart=/usr/local/samba/sbin/samba -D
PIDFile=/usr/local/samba/var/run/samba.pid
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
EOF

systemctl enable --now samba4

# setup reverse DNS zone
until /usr/local/samba/bin/samba-tool dns zonelist 127.0.0.1 --username=administrator --password=$password
do
  echo "Waiting DNS server to start..."
  sleep 5
done
/usr/local/samba/bin/samba-tool dns zonecreate 127.0.0.1 25.172.in-addr.arpa --username=administrator --password=$password
/usr/local/samba/bin/samba-tool dns add 127.0.0.1 25.172.in-addr.arpa 1.0 PTR $hostname --username=administrator --password $password
# setup AD login

##link winbind
ln -s /usr/local/samba/lib/security/pam_winbind.so /lib64/security/
##link libnss
ln -s /usr/local/samba/lib/libnss_winbind.so.2 /lib64/
ln -s /lib64/libnss_winbind.so.2 /lib64/libnss_winbind.so
ldconfig

cat <<EOF >> /etc/nsswitch.conf
passwd: files winbind
group:  files winbind
EOF

authselect select winbind --force
authselect enable-feature with-mkhomedir
systemctl enable --now oddjobd

# test

## DNS
host -t SRV "_ldap._tcp.$realm."
host -t SRV "_kerberos._udp.$realm."
host -t A $hostname.

## Kerberos
echo $password | kinit "administrator@$REALM"
/usr/local/samba/bin/samba-tool domain passwordsettings set --complexity=off --min-pwd-length=0 --max-pwd-age=0
klist

#test netlogon file server
smbclient -L localhost -N
echo $password | smbclient //localhost/netlogon -UAdministrator -c 'ls'

#test winbind
/usr/local/samba/bin/wbinfo --ping-dc


#setup dhcp
/usr/local/samba/bin/samba-tool user create dhcpduser --description="Unprivileged user for TSIG-GSSAPI DNS updates via ISC DHCP server" --random-password
/usr/local/samba/bin/samba-tool user setexpiry dhcpduser --noexpiry
/usr/local/samba/bin/samba-tool group addmembers DnsAdmins dhcpduser
/usr/local/samba/bin/samba-tool domain exportkeytab --principal=dhcpduser@ST1GVEN.COM /etc/dhcpduser.keytab
chmod 400  /etc/dhcpduser.keytab

cp -f /vagrant/dhcp-dyndns.sh /usr/local/bin/dhcp-dyndns.sh
chmod 755 /usr/local/bin/dhcp-dyndns.sh

cp -f /vagrant/dhcp.conf /etc/dhcp/dhcpd.conf 
sudo systemctl enable --now dhcpd