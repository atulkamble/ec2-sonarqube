#!/bin/bash

# ==========================================================
# SonarQube Automated Installation Script
# OS: Amazon Linux 2023
# SonarQube: 9.9 LTS
# PostgreSQL: 17
# Java: Corretto 21
# Author: Atul Kamble
# ==========================================================

set -e

echo "================================================="
echo "Updating Server"
echo "================================================="

sudo dnf update -y
sudo dnf install wget unzip git -y

echo "================================================="
echo "Checking Existing Java"
echo "================================================="

rpm -qa | grep -i java || true

echo "================================================="
echo "Installing Java 21 Amazon Corretto"
echo "================================================="

sudo dnf install java-21-amazon-corretto.x86_64 -y

java -version

echo "================================================="
echo "Java Path"
echo "================================================="

readlink -f $(which java)

echo "================================================="
echo "Installing PostgreSQL 17"
echo "================================================="

sudo dnf install postgresql17.x86_64 postgresql17-server.x86_64 -y

echo "================================================="
echo "Initializing PostgreSQL"
echo "================================================="

sudo /usr/bin/postgresql-setup --initdb

sudo systemctl enable postgresql
sudo systemctl start postgresql

sudo systemctl status postgresql --no-pager

echo "================================================="
echo "Configuring PostgreSQL Authentication"
echo "================================================="

sudo rm -f /var/lib/pgsql/data/pg_hba.conf

sudo bash -c 'cat <<EOF > /var/lib/pgsql/data/pg_hba.conf

# TYPE  DATABASE        USER            ADDRESS                 METHOD

local   all             postgres                                peer
local   all             all                                     peer
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5

EOF'

sudo systemctl restart postgresql

echo "================================================="
echo "Creating SonarQube Database"
echo "================================================="

sudo -i -u postgres psql <<EOF

CREATE DATABASE sonarqube;

CREATE USER sonar WITH PASSWORD 'StrongPassword';

ALTER USER sonar WITH ENCRYPTED PASSWORD 'StrongPassword';

ALTER DATABASE sonarqube OWNER TO sonar;

GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;

EOF

echo "================================================="
echo "Testing Database Connection"
echo "================================================="

PGPASSWORD='StrongPassword' psql -U sonar -d sonarqube -h localhost -c '\l'

echo "================================================="
echo "Downloading SonarQube"
echo "================================================="

cd /opt

sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.4.87374.zip

sudo unzip sonarqube-9.9.4.87374.zip

sudo mv sonarqube-9.9.4.87374 sonarqube

echo "================================================="
echo "Creating SonarQube User"
echo "================================================="

id sonar &>/dev/null || sudo useradd sonar

sudo chown -R sonar:sonar /opt/sonarqube

echo "================================================="
echo "Configuring SonarQube Database"
echo "================================================="

sudo cp /opt/sonarqube/conf/sonar.properties /opt/sonarqube/conf/sonar.properties.bak

sudo bash -c 'cat <<EOF >> /opt/sonarqube/conf/sonar.properties

sonar.jdbc.username=sonar
sonar.jdbc.password=StrongPassword
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube

EOF'

echo "================================================="
echo "Configuring Kernel Parameters"
echo "================================================="

sudo bash -c 'cat <<EOF >> /etc/sysctl.conf

vm.max_map_count=524288
fs.file-max=131072

EOF'

sudo sysctl -p

echo "================================================="
echo "Configuring System Limits"
echo "================================================="

sudo bash -c 'cat <<EOF >> /etc/security/limits.conf

sonar   -   nofile   131072
sonar   -   nproc    8192

EOF'

echo "================================================="
echo "Creating SonarQube Service"
echo "================================================="

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

Environment="JAVA_HOME=/usr/lib/jvm/java-21-amazon-corretto.x86_64"
Environment="PATH=/usr/lib/jvm/java-21-amazon-corretto.x86_64/bin:/usr/local/bin:/usr/bin:/bin"

ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target

EOF'

echo "================================================="
echo "Reloading Systemd"
echo "================================================="

sudo systemctl daemon-reload

echo "================================================="
echo "Enabling SonarQube Service"
echo "================================================="

sudo systemctl enable sonarqube

echo "================================================="
echo "Starting SonarQube Service"
echo "================================================="

sudo systemctl start sonarqube

sleep 20

echo "================================================="
echo "SonarQube Service Status"
echo "================================================="

sudo systemctl status sonarqube --no-pager

echo "================================================="
echo "Checking Port 9000"
echo "================================================="

sudo ss -tulpn | grep 9000 || true

echo "================================================="
echo "Checking SonarQube Logs"
echo "================================================="

tail -20 /opt/sonarqube/logs/sonar.log || true

echo "================================================="
echo "Installing Sonar Scanner"
echo "================================================="

cd /opt

sudo wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-8.1.0.6389.zip

sudo unzip sonar-scanner-cli-8.1.0.6389.zip

sudo mv sonar-scanner-8.1.0.6389 sonar-scanner

echo '#!/bin/bash' | sudo tee /etc/profile.d/sonar-scanner.sh
echo 'export PATH=$PATH:/opt/sonar-scanner/bin' | sudo tee -a /etc/profile.d/sonar-scanner.sh

sudo chmod +x /etc/profile.d/sonar-scanner.sh

source /etc/profile.d/sonar-scanner.sh

echo "================================================="
echo "Verifying Sonar Scanner"
echo "================================================="

/opt/sonar-scanner/bin/sonar-scanner -v

echo "================================================="
echo "Installation Completed"
echo "================================================="

PUBLIC_IP=$(curl -s ifconfig.me)

echo ""
echo "Access SonarQube:"
echo "http://$PUBLIC_IP:9000"
echo ""

echo "Default Login"
echo "Username: admin"
echo "Password: admin"

echo ""
echo "After first login change password:"
echo "Admin@123456"

echo "================================================="
