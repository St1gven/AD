
# setup environment
SAMBA_VERSION=4.12.8
hostname=$(hostname)
export realm=$(echo $hostname | awk -F'.' '{print $2"."$3}')   #st1gven.com
export REALM=$(echo $realm | awk '{ print toupper($0) }')     #ST1GVEN.COM
echo "realm: $realm"
echo "REALM:$REALM"

export domain=$(echo $hostname | awk -F'.' '{print $2}')       #st1gven
export DOMAIN=$(echo $domain | awk '{ print toupper($0) }')    #ST1GVEN
echo "domain:$domain"
echo "DOMAIN:$DOMAIN"

export node_name=$(echo $hostname | awk -F'.' '{print $1}')    #dc1
export NODE_NAME=$(echo $node_name | awk '{ print toupper($0) }') #DC1
echo "node_name:$node_name"
echo "NODE_NAME:$NODE_NAME"

# disable selinux
sed 's/SELINUX=.*/SELINUX=disabled/g' -i /etc/sysconfig/selinux
sed 's/SELINUX=.*/SELINUX=disabled/g' -i /etc/selinux/config
setenforce 0

# disable firewall
systemctl disable firewalld
systemctl stop firewalld