#!/bin/bash -e
sudo -s

. /vagrant/env.sh
. /vagrant/dc/samba.sh

rm -f /etc/krb5.conf
samba-tool domain provision --use-rfc2307 --realm="$REALM" \
        --domain="$DOMAIN" --server-role="dc" --dns-backend="SAMBA_INTERNAL" \
        --adminpass="$PASSWORD"

# DNS
sed 's/\[main\]/\[main\]\ndns=none/g' -i /etc/NetworkManager/NetworkManager.conf
cat <<EOF > /etc/resolv.conf
search $realm
nameserver 127.0.0.1
domain $realm
EOF

cat <<EOF > /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
$(ip addr show eth1 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1) dc1.st1gven.com dc1
EOF

mkdir -p /share/dfs
# setup smb domain, dns, netlogon and sysvol shares
envsubst < /vagrant/dc/smb.conf > /usr/local/samba/etc/smb.conf

# configure Kerberos
envsubst < /vagrant/dc/krb5.conf > /etc/krb5.conf

# add samba unit
cp -f /vagrant/dc/samba4.service /etc/systemd/system/samba4.service
systemctl enable --now samba4

# setup reverse DNS zone
until samba-tool dns zonelist 127.0.0.1 --username=administrator --password=$PASSWORD
do
  echo "Waiting DNS server to start..."
  sleep 5
done
samba-tool dns zonecreate 127.0.0.1 25.172.in-addr.arpa --username=administrator --password=$PASSWORD
samba-tool dns add 127.0.0.1 25.172.in-addr.arpa 2.0 PTR $hostname --username=administrator --password $PASSWORD

# setup AD login

##link winbind
ln -s /usr/local/samba/lib/security/pam_winbind.so /lib64/security/
##link libnss
ln -s /usr/local/samba/lib/libnss_winbind.so.2 /lib64/
ln -s /lib64/libnss_winbind.so.2 /lib64/libnss_winbind.so
ldconfig

authselect select winbind --force
authselect enable-feature with-mkhomedir
systemctl enable --now oddjobd


#setup dhcp
samba-tool user create dhcpduser --description="Unprivileged user for TSIG-GSSAPI DNS updates via ISC DHCP server" --random-password
samba-tool user setexpiry dhcpduser --noexpiry
samba-tool group addmembers DnsAdmins dhcpduser
samba-tool domain exportkeytab --principal=dhcpduser@$REALM /etc/dhcp/dhcpduser.keytab
chown -R dhcpd:dhcpd /etc/dhcp
chmod 400 /etc/dhcp/dhcpduser.keytab
cp -f /vagrant/dc/dhcp-dyndns.sh /usr/local/bin/dhcp-dyndns.sh
chmod 755 /usr/local/bin/dhcp-dyndns.sh
cp -f /vagrant/dc/dhcp.conf /etc/dhcp/dhcpd.conf 
cp -f /vagrant/dc/dhcpd_root.service /etc/systemd/system/dhcpd_root.service
sudo systemctl enable --now dhcpd_root

samba-tool sites create testSite

/usr/local/samba/bin/ldbsearch -H "/usr/local/samba/private/sam.ldb.d/CN=CONFIGURATION,DC=$DOMAIN,DC=COM.ldb" "(distinguishedName=CN=DEFAULTIPSITELINK,CN=IP,CN=Inter-Site Transports,CN=Sites,CN=Configuration,DC=$domain,DC=com)" > siteLink.ldif
sed -i 's/DEFAULTIPSITELINK/testSiteLink/' siteLink.ldif
cat siteLink.ldif | perl -ne "s/objectGUID:.*\$/objectGUID:$(uuidgen)/g; print;" > siteLink.ldif
/usr/local/samba/bin/ldbadd -H "/usr/local/samba/private/sam.ldb.d/CN=CONFIGURATION,DC=$DOMAIN,DC=COM.ldb" siteLink.ldif

guid=$(/usr/local/samba/bin/ldbsearch -H "/usr/local/samba/private/sam.ldb.d/CN=CONFIGURATION,DC=$DOMAIN,DC=COM.ldb" "(distinguishedName=CN=testSite,CN=Sites,CN=Configuration,DC=$domain,DC=com)" | grep objectGUID | awk '{print $2}')

siteList=$(/usr/local/samba/bin/ldbsearch -H "/usr/local/samba/private/sam.ldb.d/CN=CONFIGURATION,DC=$DOMAIN,DC=COM.ldb" "(distinguishedName=CN=DEFAULTIPSITELINK,CN=IP,CN=Inter-Site Transports,CN=Sites,CN=Configuration,DC=$domain,DC=com)" | perl -ne 's/^ /\\/g; print;' | perl -ne 's/\n/\\/g; print;' | perl -ne 's/\\{1}(?!\\)/\n/g; print;' | perl -ne 's/\\\n//g; print;' | grep siteList | perl -ne "s/GUID=.*?>/GUID=${guid}>/g; print;" | perl -ne "s/Default-First-Site-Name/testSite/g; print;")
cat <<EOF > mSiteLink.ldif
dn: CN=testSiteLink,CN=IP,CN=Inter-Site Transports,CN=Sites,CN=Configuration,DC=$domain,DC=com
changetype: modify
add: siteList
$siteList
-
delete: replInterval
-
add: replInterval
replInterval: 15
EOF
/usr/local/samba/bin/ldbmodify -H "/usr/local/samba/private/sam.ldb.d/CN=CONFIGURATION,DC=$DOMAIN,DC=COM.ldb" mSiteLink.ldif

samba-tool sites subnet create 172.25.0.0/24 Default-First-Site-Name
samba-tool sites subnet create 172.25.1.0/24 testSite

# test

## DNS
host -t SRV "_ldap._tcp.$realm."
host -t SRV "_kerberos._udp.$realm."
host -t A $hostname.

## Kerberos
echo $PASSWORD | kinit "administrator@$REALM"
samba-tool domain passwordsettings set --complexity=off --min-pwd-length=0 --max-pwd-age=0
klist

#test netlogon file server
smbclient -L localhost -N
echo $PASSWORD | smbclient //localhost/netlogon -UAdministrator -c 'ls'

#test winbind
/usr/local/samba/bin/wbinfo --ping-dc

