#!/bin/bash
sudo -s
sed 's/SELINUX=.*/SELINUX=disabled/g' -i /etc/sysconfig/selinux
sed 's/SELINUX=.*/SELINUX=disabled/g' -i /etc/selinux/config
setenforce 0

systemctl disable firewalld
systemctl stop firewalld

dnf -y install epel-release
dnf config-manager --set-enabled PowerTools

dnf -y install docbook-style-xsl gcc gdb gnutls-devel gpgme-devel jansson-devel \
      keyutils-libs-devel krb5-workstation libacl-devel libaio-devel \
      libarchive-devel libattr-devel libblkid-devel libtasn1 libtasn1-tools libtirpc-devel \
      libxml2-devel libxslt lmdb-devel openldap-devel pam-devel perl \
      perl-ExtUtils-MakeMaker perl-Parse-Yapp popt-devel python3-cryptography \
      python3-dns python3-gpg python36-devel readline-devel rpcgen systemd-devel \
      tar zlib-devel wget bind-utils 
      
cd /tmp/
wget https://ftp.samba.org/pub/samba/samba-4.12.6.tar.gz
tar -xzvf samba-4.12.6.tar.gz
cd ./samba-4.12.6
./configure --enable-debug --enable-selftest --with-ads --with-systemd --with-winbind

make
make install

#//todo(deps)  sudo dnf -y remove 

mv /etc/krb5.conf /etc/krb5.conf_alt
cp /usr/local/samba/share/setup/krb5.conf /etc/krb5.conf

/usr/local/samba/bin/samba-tool domain provision --use-rfc2307 --realm="ST1GVEN.COM" \
        --domain="ST1GVEN" --server-role="dc" --dns-backend="SAMBA_INTERNAL" \
        --adminpass="ZA1BASs"

sudo chmod 777 /usr/local/samba/sbin/samba

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

systemctl enable samba4
systemctl restart samba4

cat <<EOF > /usr/local/samba/etc/smb.conf
# Global parameters
[global]
    workgroup = ST1GVEN
    realm = ST1GVEN.COM
    netbios name = DC
    server role = active directory domain controller
    dns forwarder = 8.8.8.8 #todo
    allow dns updates = nonsecure
    nsupdate command = /usr/bin/nsupdate -g

[netlogon]
    path = /usr/local/samba/var/locks/sysvol/domain.local/scripts
    read only = No
    write ok = Yes

[sysvol]
    path = /usr/local/samba/var/locks/sysvol
    read only = No
    write ok = Yes
EOF

cat <<EOF > /etc/krb5.conf
[libdefaults]
    default_realm = DOMAIN.LOCAL
    dns_lookup_realm = false
    dns_lookup_kdc = true
[realms]
ST1GVEN.COM = {
    default_domain = st1gven.com
}

[domain_realm]
    dc1 = ST1GVEN.COM
EOF

echo ZA1BASs | kinit administrator@ST1GVEN.COM 
/usr/local/samba/bin/samba-tool domain passwordsettings set --complexity=off --min-pwd-length=6 --max-pwd-age=0
klist

sed 's/\[main\]/\[main\]\ndns=none/g' -i /etc/NetworkManager/NetworkManager.conf
cat <<EOF > /etc/resolv.conf
    search st1gven.com
    nameserver 127.0.0.1
    domain st1gven.com
EOF
#sed 's/nameserver/#nameserver/g' -i /etc/resolv.conf
#echo 'nameserver 127.0.0.1' >> /etc/resolv.conf

host -t SRV _ldap._tcp.st1gven.com.
host -t SRV _kerberos._udp.st1gven.com.
host -t A $(hostname).

/usr/local/samba/bin/samba-tool dns zonecreate $(hostname) 0.25.172.in-addr.arpa --username=administrator --password=ZA1BASs