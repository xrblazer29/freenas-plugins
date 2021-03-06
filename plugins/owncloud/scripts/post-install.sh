#!/bin/sh
#########################################

owncloud_pbi_path=/usr/pbi/owncloud-$(uname -m)

/bin/cp ${owncloud_pbi_path}/etc/rc.d/apache22 /usr/local/etc/rc.d/

${owncloud_pbi_path}/bin/python ${owncloud_pbi_path}/owncloudUI/manage.py syncdb --migrate --noinput

if [ ! -f "${owncloud_pbi_path}/www/owncloud/config/config.php" ]; then
	cat << __EOF__ > ${owncloud_pbi_path}/www/owncloud/config/config.php
	<?php
	\$CONFIG = array (
	  'datadirectory' => '/media',
	);
	?>
__EOF__
fi

cat << __EOF__ > ${owncloud_pbi_path}/etc/apache22/Includes/owncloud.conf
AddType application/x-httpd-php .php

Alias / ${owncloud_pbi_path}/www/owncloud/
AcceptPathInfo On
<Directory ${owncloud_pbi_path}/www/owncloud>
    AllowOverride All
    Order Allow,Deny
    Allow from all
</Directory>
__EOF__

chown www:www ${owncloud_pbi_path}/www/owncloud \
	${owncloud_pbi_path}/www/owncloud/apps \
	${owncloud_pbi_path}/www/owncloud/config \
	${owncloud_pbi_path}/www/owncloud/config/config.php \
	/media


# Generate SSL certificate
if [ ! -f "${owncloud_pbi_path}/etc/apache22/server.crt" ]; then

	if ! fgrep "commonName_default" /etc/ssl/openssl.cnf; then
		/usr/bin/sed -i '' -E 's/(^commonName_max.*)/\1\
commonName_default = ownCloud/' /etc/ssl/openssl.cnf
	fi
	tmp=$(mktemp /tmp/tmp.XXXXXX)
	dd if=/dev/urandom count=16 bs=1 2> /dev/null | uuencode -|head -2 |tail -1 > "${tmp}"
	/usr/bin/openssl req -batch -passout file:"${tmp}" -new -x509 -keyout ${owncloud_pbi_path}/etc/apache22/server.key.out -out ${owncloud_pbi_path}/etc/apache22/server.crt
	/usr/bin/openssl rsa -passin file:"${tmp}" -in ${owncloud_pbi_path}/etc/apache22/server.key.out -out ${owncloud_pbi_path}/etc/apache22/server.key

fi

#Enable SSL
/usr/bin/sed -i '' -E -e 's/^#(.*httpd-ssl.conf)/\1/' ${owncloud_pbi_path}/etc/apache22/httpd.conf
