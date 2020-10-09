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
wget https://ftp.samba.org/pub/samba/samba-$SAMBA_VERSION.tar.gz -o /dev/null >/dev/null
tar -xzvf samba-$SAMBA_VERSION.tar.gz
cd ./samba-$SAMBA_VERSION
./configure #--enable-debug --enable-selftest --with-ads --with-systemd --with-winbind >/dev/null
make
make install
cd -
rm -rf /tmp/samba-$SAMBA_VERSION*

ln -s /usr/local/samba/bin/wbinfo /usr/bin/wbinfo
ln -s /usr/local/samba/bin/samba-tool /usr/bin/samba-tool
ln -s /usr/local/samba/sbin/samba /usr/bin/samba