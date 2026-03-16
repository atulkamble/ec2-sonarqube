#!/bin/bash

# ==========================================================
# SonarQube Automated Installation Script
# OS: Amazon Linux 2023
# Author: Atul Kamble
# ==========================================================

echo "=========================================="
echo "Updating system"
echo "=========================================="

sudo dnf update -y
sudo dnf install wget unzip git -y

echo "=========================================="
echo "Installing Java 17"
echo "=========================================="

sudo dnf install java-17-amazon-corretto -y

java -version

echo "=========================================="
echo "Installing PostgreSQL 15"
echo "=========================================="

sudo dnf install postgresql15 postgresql15-server -y

sudo /usr/bin/postgresql-setup --initdb

sudo systemctl enable postgresql
sudo systemctl start postgresql

echo "=========================================="
echo "Configuring PostgreSQL Database"
echo "=========================================="

sudo -i -u postgres psql <<EOF

CREATE DATABASE sonarqube;
CREATE USER sonar WITH PASSWORD 'StrongPassword';
ALTER USER sonar WITH ENCRYPTED PASSWORD 'StrongPassword';
ALTER DATABASE sonarqube OWNER TO sonar;
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;

EOF

echo "=========================================="
echo "Updating PostgreSQL Authentication"
echo "=========================================="

sudo sed -i 's/ident/md5/g' /var/lib/pgsql/data/pg_hba.conf

sudo systemctl restart postgresql

echo "=========================================="
echo "Downloading SonarQube"
echo "=========================================="

cd /opt

sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.4.87374.zip

sudo unzip sonarqube-9.9.4.87374.zip

sudo mv sonarqube-9.9.4.87374 sonarqube

echo "=========================================="
echo "Creating SonarQube User"
echo "=========================================="

sudo useradd sonar

sudo chown -R sonar:sonar /opt/sonarqube

echo "=========================================="
echo "Configuring SonarQube Database"
echo "=========================================="

sudo bash -c 'cat <<EOF >> /opt/sonarqube/conf/sonar.properties

sonar.jdbc.username=sonar
sonar.jdbc.password=StrongPassword
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube

EOF'

echo "=========================================="
echo "Configuring Kernel Parameters"
echo "=========================================="

sudo bash -c 'cat <<EOF >> /etc/sysctl.conf

vm.max_map_count=524288
fs.file-max=131072

EOF'

sudo sysctl -p

echo "=========================================="
echo "Configuring System Limits"
echo "=========================================="

sudo bash -c 'cat <<EOF >> /etc/security/limits.conf

sonar   -   nofile   131072
sonar   -   nproc    8192

EOF'

echo "=========================================="
echo "Creating SonarQube Service"
echo "=========================================="

sudo bash -c 'cat <<EOF > /etc/systemd/system/sonarqube.service

[Unit]
Description=SonarQube Service
After=network.target

[Service]
Type=forking
User=sonar
Group=sonar

LimitNOFILE=65536
LimitNPROC=4096

Environment="JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto.x86_64"
Environment="PATH=/usr/lib/jvm/java-17-amazon-corretto.x86_64/bin:/usr/local/bin:/usr/bin:/bin"

ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop

Restart=always

[Install]
WantedBy=multi-user.target

EOF'

echo "=========================================="
echo "Starting SonarQube Service"
echo "=========================================="

sudo systemctl daemon-reload

sudo systemctl enable sonarqube

sudo systemctl start sonarqube

echo "=========================================="
echo "Installation Completed"
echo "=========================================="

echo "Access SonarQube at:"
curl ifconfig.me

echo ":9000"

echo "Default Login:"
echo "Username: admin"
echo "Password: admin"

echo "=========================================="
