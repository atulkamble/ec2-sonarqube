# 🚀 SonarQube Installation Guide
## Amazon Linux 2023 (Kernel 6.1) on AWS EC2

**Author:** Atul Kamble
**Role:** Cloud Solutions Architect | DevOps Trainer


```
// Configuration of sonarqube on EC2 

1. Launch ec2 connect via ssh 
amazon linux | t3.large | SSD - 60GB 
NSG - Inbound - 9000 
2. ssh to server 
3. installation and configuration 
https://github.com/atulkamble/ec2-sonarqube
4. public-ip:9000 
5. username/password 
admin/admin 
>> Admin@123
```


---

# 🖥️ Server Configuration

| Component         | Value             |
| ----------------- | ----------------- |
| Cloud Provider    | AWS               |
| Instance Type     | t3.large          |
| OS                | Amazon Linux 2023 |
| Kernel            | 6.1               |
| Storage           | 50 GB SSD         |
| SonarQube Version | 9.9 LTS           |
| Java              | OpenJDK 17        |
| Database          | PostgreSQL 15     |
| SonarQube Port    | 9000              |

---

# 🔐 Security Group (NSG)

Allow inbound traffic:

| Port | Protocol | Purpose      |
| ---- | -------- | ------------ |
| 22   | TCP      | SSH          |
| 9000 | TCP      | SonarQube UI |

---

# 1️⃣ Connect to EC2 Instance

From local machine:

```bash
cd Downloads
chmod 400 sonar.pem

ssh -i "sonar.pem" ec2-user@ec2-54-152-122-131.compute-1.amazonaws.com
```

---

# 2️⃣ Update Server

Amazon Linux 2023 uses **dnf package manager**.

```bash
sudo dnf update -y
```

Install utilities:

```bash
sudo dnf install wget unzip git -y
```

---

# 3️⃣ Install Java 17 (Required by SonarQube)

```bash
sudo dnf install java-17-amazon-corretto -y
```

Verify Java:

```bash
java -version
```

Check Java path:

```bash
readlink -f $(which java)
```

Example output:

```
/usr/lib/jvm/java-17-amazon-corretto.x86_64/bin/java
```

---

# 4️⃣ Install PostgreSQL

Install PostgreSQL server:

```bash
sudo dnf install postgresql15 postgresql15-server -y
```

Initialize database:

```bash
sudo /usr/bin/postgresql-setup --initdb
```

Start PostgreSQL:

```bash
sudo systemctl enable postgresql
sudo systemctl start postgresql
```

Verify:

```bash
sudo systemctl status postgresql
```

---

# 5️⃣ Create SonarQube Database

Switch to postgres user:

```bash
sudo -i -u postgres
psql
```

Create database and user:

```sql
CREATE DATABASE sonarqube;

CREATE USER sonar WITH PASSWORD 'StrongPassword';

ALTER USER sonar WITH ENCRYPTED PASSWORD 'StrongPassword';

GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;
```

Exit:

```sql
\q
```

Exit postgres shell:

```bash
exit
```

---

# 6️⃣ Install SonarQube

Move to installation directory:

```bash
cd /opt
```

Download SonarQube LTS:

```bash
sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.4.87374.zip
```

Extract package:

```bash
sudo unzip sonarqube-9.9.4.87374.zip
```

Rename directory:

```bash
sudo mv sonarqube-9.9.4.87374 sonarqube
```

---

# 7️⃣ Create SonarQube System User

```bash
sudo useradd sonar
```

Set permissions:

```bash
sudo chown -R sonar:sonar /opt/sonarqube
```

---

# 8️⃣ Configure SonarQube Database Connection

Edit configuration file:

```bash
sudo nano /opt/sonarqube/conf/sonar.properties
```

Add:

```properties
sonar.jdbc.username=sonar
sonar.jdbc.password=StrongPassword
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube
```

---

# 9️⃣ Configure Kernel Parameters

Edit sysctl configuration:

```bash
sudo nano /etc/sysctl.conf
```

Add:

```
vm.max_map_count=524288
fs.file-max=131072
```

Apply changes:

```bash
sudo sysctl -p
```

---

# 🔟 Configure System Limits

Edit limits file:

```bash
sudo nano /etc/security/limits.conf
```

Add:

```
sonar   -   nofile   131072
sonar   -   nproc    8192
```

---

# 1️⃣1️⃣ Create SonarQube Service

Create systemd service:

```bash
sudo nano /etc/systemd/system/sonarqube.service
```

Paste:

```ini
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
```

Reload systemd:

```bash
sudo systemctl daemon-reload
```

Enable SonarQube:

```bash
sudo systemctl enable sonarqube
```

Start SonarQube:

```bash
sudo systemctl start sonarqube
```

Check service:

```bash
sudo systemctl status sonarqube
```

---

# 1️⃣2️⃣ Fix PostgreSQL Authentication (Important)

SonarQube requires **password authentication (md5)**.

Edit PostgreSQL config:

```bash
sudo nano /var/lib/pgsql/data/pg_hba.conf
```

Change authentication method to:

```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             postgres                                peer
local   all             all                                     peer
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
```

Restart PostgreSQL:

```bash
sudo systemctl restart postgresql
```

---

# 1️⃣3️⃣ Verify Database Access

Test login:

```bash
psql -U sonar -d sonarqube -h localhost
```

Enter password:

```
StrongPassword
```

Exit:

```sql
\q
```

---

# 1️⃣4️⃣ Ensure Database Ownership

Run:

```bash
sudo -i -u postgres
psql
```

```sql
ALTER DATABASE sonarqube OWNER TO sonar;
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;
\q
```

Restart SonarQube:

```bash
sudo systemctl restart sonarqube
```

---

# 🌐 Access SonarQube

Open browser:

```
http://54.152.122.131:9000/
```

---

# 🔑 Default Login

| Field    | Value |
| -------- | ----- |
| Username | admin |
| Password | admin |

You will be prompted to **change password after first login**.

---

# 📊 Verify SonarQube Service

Check running processes:

```bash
ps -ef | grep sonar
```

Check listening port:

```bash
sudo ss -tulpn | grep 9000
```

Check logs:

```bash
tail -f /opt/sonarqube/logs/sonar.log
```

---

# 🏗️ Architecture

```
AWS EC2 (t3.large)
│
├── Amazon Linux 2023
│
├── Java 17 (Amazon Corretto)
│
├── PostgreSQL 15
│      └── sonarqube database
│
└── SonarQube 9.9 LTS
       └── Web UI Port 9000
```

---

# ⚡ Common Issues

### SonarQube restarting

Cause:

```
PostgreSQL authentication method = ident
```

Solution:

```
Change to md5 in pg_hba.conf
```

---

### Port 9000 not accessible

Check:

```
Security Group inbound rules
```

---

### Database connection error

Verify:

```
systemctl status postgresql
```

---

Here is a **clean, professional documentation section** you can add to your **SonarQube EC2 Installation Guide**.

---

# 🔎 Install Sonar Scanner CLI (Linux)

**SonarScanner** is the official tool used to **analyze source code and send results to the SonarQube server**.

It is typically used in:

* CI/CD pipelines (Jenkins, GitHub Actions, Azure DevOps)
* Local developer machines
* Automated build servers

---

# 📦 Step 1 — Download SonarScanner

Navigate to the `/opt` directory (recommended for tools installation).

```bash
cd /opt
```

Download the SonarScanner CLI package.

```bash
sudo wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-5.0.1.3006-linux.zip
```

⚠️ Always verify the **latest version** from:

[https://docs.sonarsource.com/sonarqube/latest/analyzing-source-code/scanners/sonarscanner/](https://docs.sonarsource.com/sonarqube/latest/analyzing-source-code/scanners/sonarscanner/)

---

# 📦 Step 2 — Extract Package

```bash
sudo unzip sonar-scanner-cli-5.0.1.3006-linux.zip
```

After extraction you will see:

```
sonar-scanner-5.0.1.3006-linux
```

Rename it for simplicity.

```bash
sudo mv sonar-scanner-5.0.1.3006-linux sonar-scanner
```

Final installation path:

```
/opt/sonar-scanner
```

---

# ⚙️ Step 3 — Configure Sonar Scanner

Open configuration file.

```bash
sudo nano /opt/sonar-scanner/conf/sonar-scanner.properties
```

Add or update the following values:

```properties
sonar.host.url=http://localhost:9000
sonar.sourceEncoding=UTF-8
```

### Explanation

| Property             | Description                   |
| -------------------- | ----------------------------- |
| sonar.host.url       | URL of SonarQube server       |
| sonar.sourceEncoding | Encoding used for source code |

If SonarQube is hosted on another server, replace `localhost`.

Example:

```
sonar.host.url=http://54.152.122.131:9000
```

---

# ⚙️ Step 4 — Configure Global PATH

Create environment file.

```bash
sudo nano /etc/profile.d/sonar-scanner.sh
```

Add the following:

```bash
#!/bin/bash
export PATH="$PATH:/opt/sonar-scanner/bin"
```

Save and exit.

---

# 🔐 Step 5 — Set Execution Permission

Ensure SonarScanner binary is executable.

```bash
sudo chmod +x /opt/sonar-scanner/bin/sonar-scanner
```

---

# 🔄 Step 6 — Reload Environment Variables

Load the new PATH configuration.

```bash
source /etc/profile.d/sonar-scanner.sh
```

---

# ✅ Step 7 — Verify Installation

Run:

```bash
sonar-scanner -h
```

check version 
```
sonar-scanner -v
```

Expected output:

```
INFO: usage: sonar-scanner [options]
```

This confirms **SonarScanner is successfully installed**.

---

# 📂 Directory Structure

```
/opt
 ├── sonarqube
 └── sonar-scanner
      ├── bin
      ├── conf
      ├── jre
      └── lib
```

---

# 🚀 Example: Run Sonar Scanner

Inside a project directory:

```bash
sonar-scanner \
-Dsonar.projectKey=myproject \
-Dsonar.sources=. \
-Dsonar.host.url=http://localhost:9000 \
-Dsonar.login=YOUR_TOKEN
```

---

# 🧠 Points to Remember

✔ SonarScanner **does not require root user**
✔ Used in **CI/CD pipelines**
✔ Requires **Java (already included in scanner)**
✔ Requires **SonarQube server running**

---

# 🧩 DevOps Pipeline Integration

Common integrations:

| Tool           | Usage              |
| -------------- | ------------------ |
| Jenkins        | Code quality stage |
| GitHub Actions | PR scanning        |
| Azure DevOps   | Pipeline task      |
| GitLab CI      | Quality gate check |

---

