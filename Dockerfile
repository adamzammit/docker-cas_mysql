FROM ubuntu:14.04

MAINTAINER Wei-Ming Wu <wnameless@gmail.com>

RUN apt-get update

# Install sshd
RUN apt-get install -y openssh-server
RUN mkdir /var/run/sshd

# Set password to 'admin'
RUN printf admin\\nadmin\\n | passwd

# Install MySQL
RUN apt-get install -y mysql-server mysql-client libmysqlclient-dev
# Install Apache
RUN apt-get install -y apache2
# Install php
RUN apt-get install -y php5 libapache2-mod-php5 php5-mcrypt

# Install phpMyAdmin
RUN mysqld & \
	service apache2 start; \
	sleep 5; \
	printf y\\n\\n\\n1\\n | apt-get install -y phpmyadmin; \
	sleep 15; \
	mysqladmin -u root shutdown

RUN sed -i "s#// \$cfg\['Servers'\]\[\$i\]\['AllowNoPassword'\] = TRUE;#\$cfg\['Servers'\]\[\$i\]\['AllowNoPassword'\] = TRUE;#g" /etc/phpmyadmin/config.inc.php 

# Install libfuse2
RUN apt-get install -y libfuse2; \
	cd /tmp; \
	apt-get download fuse; \
	dpkg-deb -x fuse_* .; \
	dpkg-deb -e fuse_*; \
	rm fuse_*.deb; \
	echo -en '#!/bin/bash\nexit 0\n' > DEBIAN/postinst; \
	dpkg-deb -b . /fuse.deb; \
	dpkg -i /fuse.deb

# Install Java 7
RUN apt-get install -y openjdk-7-jdk unzip

# Install Tomcat 7
RUN apt-get install -y tomcat7 tomcat7-admin
RUN sed -i "s#</tomcat-users>##g" /etc/tomcat7/tomcat-users.xml; \
	echo '  <role rolename="manager-gui"/>' >>  /etc/tomcat7/tomcat-users.xml; \
	echo '  <role rolename="manager-script"/>' >>  /etc/tomcat7/tomcat-users.xml; \
	echo '  <role rolename="manager-jmx"/>' >>  /etc/tomcat7/tomcat-users.xml; \
	echo '  <role rolename="manager-status"/>' >>  /etc/tomcat7/tomcat-users.xml; \
	echo '  <role rolename="admin-gui"/>' >>  /etc/tomcat7/tomcat-users.xml; \
	echo '  <role rolename="admin-script"/>' >>  /etc/tomcat7/tomcat-users.xml; \
	echo '  <user username="admin" password="admin" roles="manager-gui, manager-script, manager-jmx, manager-status, admin-gui, admin-script"/>' >>  /etc/tomcat7/tomcat-users.xml; \
	echo '</tomcat-users>' >> /etc/tomcat7/tomcat-users.xml

# Install CAS server
RUN cd /tmp; \
	wget https://github.com/Jasig/cas/releases/download/v3.5.2/cas-server-3.5.2-release.zip; \
	unzip cas-server-3.5.2-release.zip; \
    cp cas-server-3.5.2/modules/cas-server-webapp-3.5.2.war /var/lib/tomcat7/webapps/cas.war; \
    service tomcat7 start; \
    sleep 10; \
    service tomcat7 stop; \
    cp cas-server-3.5.2/modules/cas-server-support-jdbc-3.5.2.jar /var/lib/tomcat7/webapps/cas/WEB-INF/lib

# Configure https
RUN sed -i "s#</Server>##g" /etc/tomcat7/server.xml; \
	sed -i "s#  </Service>##g" /etc/tomcat7/server.xml; \
	echo '    <Connector port="8443" protocol="HTTP/1.1" SSLEnabled="true" maxThreads="150" scheme="https" secure="true" clientAuth="false"  sslProtocols="TLSv1, TLSv1.1, TLSv1.2" sslEnabledProtocols="TLSv1, TLSv1.1, TLSv1.2" keystoreFile="/usr/share/tomcat7/.keystore" keystorePass="tomcat_admin" />' >> /etc/tomcat7/server.xml; \
	echo '  </Service>' >> /etc/tomcat7/server.xml; \
	echo '</Server>' >> /etc/tomcat7/server.xml

# Create CAS authentication DB
RUN chmod 1777 /tmp; \
	mysqld & \
	sleep 5; \
	echo "CREATE DATABASE cas" | mysql -u root; \
	echo "CREATE TABLE cas_users (id INT AUTO_INCREMENT NOT NULL, username VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL, password VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL, PRIMARY KEY (id), UNIQUE KEY (username))"| mysql -u root -D cas; \
	echo "INSERT INTO cas_users (username, password) VALUES ('admin', '21232f297a57a5a743894a0e4a801fc3')" | mysql -u root -D cas; \
	sleep 10

# Replace CAS deployerConfigContext.xml & install MySQL driver
ADD deployerConfigContext.xml /
ADD mysql-connector-java-5.1.28-bin.jar /
RUN mv deployerConfigContext.xml /var/lib/tomcat7/webapps/cas/WEB-INF/deployerConfigContext.xml; \
	mv mysql-connector-java-5.1.28-bin.jar /var/lib/tomcat7/webapps/cas/WEB-INF/lib

EXPOSE 22
EXPOSE 80
EXPOSE 3306
EXPOSE 8080
EXPOSE 8443

CMD chmod 1777 /tmp; \
	mysqld_safe & \
	service apache2 start; \
	[ ! -f /usr/share/tomcat7/.keystore ] && printf tomcat_admin\\ntomcat_admin\\n\\n\\n\\n\\n\\n\\ny\\ntomcat_admin\\ntomcat_admin\\n | keytool -genkey -alias tomcat -keyalg RSA -keystore /usr/share/tomcat7/.keystore; \
	service tomcat7 start; \
	/usr/sbin/sshd -D
