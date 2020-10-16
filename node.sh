#!/bin/bash -e
sudo -s

. /vagrant/env.sh

dnf install -y samba samba-common samba-client samba-winbind samba-winbind-clients krb5-workstation oddjob oddjob-mkhomedir compat-openssl10

/usr/sbin/dhclient
sed 's/\[main\]/\[main\]\ndns=none/g' -i /etc/NetworkManager/NetworkManager.conf

cat <<EOF > /etc/samba/smb.conf
[global]
    workgroup = $DOMAIN
    security = ADS
    realm = $REALM
    netbios name = $NODE_NAME
    
    winbind refresh tickets = Yes
    vfs objects = acl_xattr
    map acl inherit = Yes
    store dos attributes = Yes

    dedicated keytab file = /etc/krb5.keytab
    kerberos method = secrets and keytab
        
    winbind use default domain = yes
    idmap config * : rangesize = 1000000
    idmap config * : range = 1000000-19999999
    idmap config * : backend = autorid
    template shell = /bin/bash
    template homedir = /home/%U

    bind interfaces only = yes
    interfaces = lo eth1
EOF

cat <<EOF > /etc/krb5.conf
[libdefaults]
    default_realm = $REALM
    dns_lookup_realm = false
    dns_lookup_kdc = true
EOF

until echo $PASSWORD | net ads join -U administrator
do
  echo "Waiting DC to start..."
  sleep 60
done


sudo systemctl enable --now smb
sudo systemctl enable --now nmb
sudo systemctl enable --now winbind

authselect select winbind --force
authselect enable-feature with-mkhomedir
systemctl enable --now oddjobd

mkdir -p /share/dfs
mount -t cifs //dc1/dfs /share/dfs -o username=Administrator,pass=$PASSWORD