#!/bin/bash
echo "Starting build"
STARTTIME=$(date +%s)
echo "Time: $(date)"

apt update && apt upgrade -y
apt install -y freerdp2-dev libavcodec-dev libavformat-dev libavutil-dev libswscale-dev libcairo2-dev libjpeg62-turbo-dev libjpeg-dev libpng-dev libtool-bin libpango1.0-dev libpango1.0-0 libssh2-1 libwebsocketpp-dev libossp-uuid-dev libssl-dev libwebp-dev libvorbis-dev libpulse-dev libwebsockets-dev libvncserver-dev libssh2-1-dev openssl libtelnet-dev tomcat9 tomcat9-admin tomcat9-common tomcat9-user nano wget curl zip make gcc git mariadb-server mariadb-client openssh-server openssh-client supervisor

cd

VER=1.4.0
wget https://downloads.apache.org/guacamole/$VER/source/guacamole-server-$VER.tar.gz
tar xzf guacamole-server-$VER.tar.gz
cd guacamole-server-$VER
CFLAGS=-Wno-error ./configure
make
make install
ldconfig


cd


mkdir /etc/guacamole
mkdir /etc/guacamole/{extensions,lib}
mkdir /usr/share/tomcat9/{logs,webapps}
cp -r /usr/share/tomcat9/etc /usr/share/tomcat9/conf



VER=1.4.0
wget https://downloads.apache.org/guacamole/$VER/binary/guacamole-$VER.war -O /etc/guacamole/ROOT.war

ln -s /etc/guacamole/ROOT.war /usr/share/tomcat9/webapps/

echo "GUACAMOLE_HOME=/etc/guacamole" >> /etc/default/tomcat9

cd

/usr/share/tomcat9/bin/catalina.sh start
service mariadb start




mysql -e "CREATE DATABASE guacamole_db;"
mysql -e "CREATE USER 'guacamole_user'@'localhost' IDENTIFIED BY 'johndoe,1';"
mysql -e "GRANT SELECT,INSERT,UPDATE,DELETE ON guacamole_db.* TO 'guacamole_user'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"



wget https://downloads.apache.org/guacamole/1.3.0/binary/guacamole-auth-jdbc-1.3.0.tar.gz
tar vfx guacamole-auth-jdbc-1.3.0.tar.gz
cat guacamole-auth-jdbc-1.3.0/mysql/schema/*.sql | mysql -u root guacamole_db
cp guacamole-auth-jdbc-1.3.0/mysql/guacamole-auth-jdbc-mysql-1.3.0.jar /etc/guacamole/extensions/



wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-8.0.28.tar.gz
tar xvzf mysql-connector-java-8.0.28.tar.gz
cp mysql-connector-java-8.0.28/mysql-connector-java-8.0.28.jar /etc/guacamole/lib/



cat > /etc/guacamole/guacamole.properties << EOL
guacd-hostname: localhost
guacd-port: 4822
#user-mapping:   /etc/guacamole/user-mapping.xml
#auth-provider:  net.sourceforge.guacamole.net.basic.BasicFileAuthenticationProvider
mysql-hostname: localhost
mysql-port: 3306
mysql-database: guacamole_db
mysql-username: guacamole_user
mysql-password: johndoe,1
EOL

cat > /etc/guacamole/guacd.conf << EOL
[server]
bind_host = 0.0.0.0
bind_port = 4822
EOL

ln -s /etc/guacamole /usr/share/tomcat9/.ROOT





mkdir -p /var/log/supervisor

cat > /etc/supervisor/conf.d/supervisord.conf << EOL
[supervisord]
nodaemon=true

[program:start]
user=root
command=/guacamole/start_db.sh
EOL

cd

rm -rf guacamole-server-$VER guacamole-server-$VER.tar.gz guacamole-auth-jdbc-1.3.0 guacamole-auth-jdbc-1.3.0.tar.gz mysql-connector-java-8.0.28.tar.gz mysql-connector-java-8.0.28




mkdir -p /guacamole/branding
sed -i "s/Guacamole/Apache Guacamole/g" /usr/share/tomcat9/webapps/ROOT/translations/en.json
sed -i "s/Apache Apache Guacamole/Apache Guacamole/g" /usr/share/tomcat9/webapps/ROOT/translations/en.json

cp /usr/share/tomcat9/webapps/ROOT/translations/en.json /guacamole/branding/en.original.json

cat > /guacamole/branding/brand.config << EOL
brandname=Apache Guacamole
EOL

cat > /guacamole/branding.sh << EOL
#!/bin/bash

FILENAME=/usr/share/tomcat9/webapps/ROOT/translations/en.json
read -p "Enter new brand name: " brandname
echo "Selected brand name is: \$brandname"
if [ -z "\$brandname" ]; then
    echo "Brand name can't be empty"
    exit 1
fi
if [[ ! \$brandname =~ ^[a-zA-Z0-9\ ]+\$ ]]; then
    echo "Brand name can only contain alphanumeric characters and may contain spaces"
    exit 1
fi
rm \$FILENAME
cp /guacamole/branding/en.original.json \$FILENAME
brand=\$brandname
old_brand=\$(grep "brandname" /guacamole/branding/brand.config | cut -d "=" -f2)
echo "Old brand name was: \$old_brand"
sed -i "s/Apache Guacamole/\$brand/g" \$FILENAME
sed -i "s/\$old_brand/\$brand/g" /guacamole/branding/brand.config
echo "Brand name successfully changed"

read -p "Do you want to restart services now? (y/n): " restart
if [ "\$restart" == "y" ]; then
    pkill guacd && pkill java && pkill mariadb && sleep 1
    /guacamole/start.sh
fi
exit 0
EOL

chmod +x /guacamole/branding.sh


echo "Build complete"
echo "Time: $(date)"
echo "Total time: $(($(date +%s) - $STARTTIME)) seconds"
