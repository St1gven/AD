#!/bin/bash -e
sudo -s

# setup environment
realm=$(echo $(hostname) | awk -F'.' '{print $2"."$3}')   #st1gven.com
REALM=$(echo $realm | awk '{ print toupper($0) }')     #ST1GVEN.COM
echo "realm: $realm"
echo "REALM:$REALM"

domain=$(echo $(hostname) | awk -F'.' '{print $2}')       #st1gven
DOMAIN=$(echo $domain | awk '{ print toupper($0) }')    #ST1GVEN
echo "domain:$domain"
echo "DOMAIN:$DOMAIN"

node_name=$(echo $(hostname) | awk -F'.' '{print $1}')    #dc1
NODE_NAME=$(echo $node_name | awk '{ print toupper($0) }') #DC1
echo "node_name:$node_name"
echo "NODE_NAME:$NODE_NAME"

password="ZA1BASs"
# disable selinux
sed 's/SELINUX=.*/SELINUX=disabled/g' -i /etc/sysconfig/selinux
sed 's/SELINUX=.*/SELINUX=disabled/g' -i /etc/selinux/config
setenforce 0 | :

# disable firewall
systemctl disable firewalld
systemctl stop firewalld

dnf install -y samba samba-common samba-client samba-winbind samba-winbind-clients krb5-workstation oddjob oddjob-mkhomedir compat-openssl10

# DNS
sed 's/\[main\]/\[main\]\ndns=none/g' -i /etc/NetworkManager/NetworkManager.conf
cat <<EOF > /etc/resolv.conf
search $realm
nameserver 172.25.0.1
domain $realm
EOF

cat <<EOF > /etc/samba/smb.conf
[global]
    workgroup = $DOMAIN
    security = ADS
    realm = $REALM
    netbios name = $NODE_NAME
    
    auth methods = winbind
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

echo $password | net ads join -U administrator

sudo systemctl enable --now smb
sudo systemctl enable --now nmb
sudo systemctl enable --now winbind

authselect select winbind --force
authselect enable-feature with-mkhomedir
systemctl enable --now oddjobd

mkdir -p /share/dfs
mount -t cifs //dc1/dfs /share/dfs -o username=Administrator,pass=$password