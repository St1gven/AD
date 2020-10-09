#!/bin/bash -e
sudo -s
. /vagrant/env.sh
. /vagrant/dc/samba.sh
# DNS
sed 's/\[main\]/\[main\]\ndns=none/g' -i /etc/NetworkManager/NetworkManager.conf
cat <<EOF > /etc/resolv.conf
search $realm
nameserver 172.25.0.1
domain $realm
EOF

cat <<EOF > /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
$(ip addr show eth1 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1) $(hostname) ${node_name}
EOF



envsubst < /vagrant/dc/krb5.conf > /etc/krb5.conf

until echo $PASSWORD | kinit "administrator@$REALM"
do
  echo "Waiting DC1 server to start..."
  sleep 60
done


#todo ntpd 
if [[ -n $SITE ]]; then SITE_CMD="--site=$SITE"; fi
samba-tool domain join $realm DC -k yes --option='idmap_ldb:use rfc2307 = yes' --dns-backend="SAMBA_INTERNAL"  --option="interfaces=lo eth1" --option="bind interfaces only=yes" --option="template shell = /bin/bash" --option="template homedir = /home/%U" $SITE_CMD

# add samba unit
cp -f /vagrant/dc/samba4.service /etc/systemd/system/samba4.service
systemctl enable --now samba4

##link winbind
ln -s /usr/local/samba/lib/security/pam_winbind.so /lib64/security/
##link libnss
ln -s /usr/local/samba/lib/libnss_winbind.so.2 /lib64/
ln -s /lib64/libnss_winbind.so.2 /lib64/libnss_winbind.so
ldconfig

authselect select winbind --force
authselect enable-feature with-mkhomedir
systemctl enable --now oddjobd