# OpenCode Server Deployment & Operations Guide (For Reference Only)

<p align="right">
  <b>English</b> | <a href="./server.md">简体中文</a>
</p>

## 1. Installation & Environment Configuration

1. **Install OpenCode**
   ```bash
   curl -fsSL https://opencode.ai/install | bash
   ```

2. **Reload Environment Variables**
   ```bash
   source ~/.bashrc
   ```

3. **Get Absolute Path**
   ```bash
   which opencode
   ```
   > **Note**: Fill the returned path (e.g., `/home/ubuntu/.opencode/bin/opencode`) into the `ExecStart` field of the systemd service configuration below.

---

## 2. Configure Systemd Background Service

1. **Create/Edit Service Configuration File**
   ```bash
   sudo nano /etc/systemd/system/opencode.service
   ```

2. **Service Configuration File Content**
   ```ini
   [Unit]
   Description=OpenCode Web Server
   After=network.target

   [Service]
   Type=simple
   User=ubuntu
   # Securely define environment variable for server password
   Environment="OPENCODE_SERVER_PASSWORD=YOUR_PASSWORD"
   # Start command (binds to 0.0.0.0 and listens on port 4097)
   ExecStart=/home/ubuntu/.opencode/bin/opencode serve --hostname 0.0.0.0 --port 4097
   Restart=always
   RestartSec=5

   [Install]
   WantedBy=multi-user.target
   ```
   > *(Save and exit nano prompt: Press `Ctrl + O` -> `Enter` -> `Ctrl + X`)*

3. **Reload and Start Service**
   ```bash
   # 1. Reload systemd daemon configuration
   sudo systemctl daemon-reload

   # 2. Enable service auto-start on boot
   sudo systemctl enable opencode

   # 3. Start OpenCode background service immediately
   sudo systemctl start opencode
   ```

---

## 3. Project Management & Notes

1. **Create New Project Directory**
   ```bash
   mkdir new_project
   ```

2. **Path Requirement**
   When adding a project, you MUST use an absolute path (e.g., `/home/username/new_project`); otherwise, conversation sessions cannot be created.

---

## 4. Firewall & Port Opening

### 1. Layer 1: Cloud Provider Console (Security Groups / Security Lists)
*Example using Oracle Cloud:*
1. Navigate to Console -> **Networking** -> **Virtual Cloud Networks (VCN)** -> **Subnets**.
2. Click on the **Security Lists** associated with your server.
3. Click **Add Ingress Rules**:
   - **Source CIDR**: `0.0.0.0/0` *(For higher security, restrict to your public IP/32)*
   - **IP Protocol**: `TCP`
   - **Destination Port Range**: `4097` *(Must match the `--port` in systemd configuration)*
4. Click Save.

### 2. Layer 2: Ubuntu Internal Firewall (iptables)
*Oracle Cloud official Ubuntu images enforce strict default iptables rules, requiring manual configuration:*

```bash
# 1. Insert TCP port 4097 allow rule at the top of INPUT chain
sudo iptables -I INPUT -p tcp --dport 4097 -j ACCEPT

# 2. Save rules persistently to prevent loss after server reboot
sudo netfilter-persistent save
```

---

## 5. Common Operations & Troubleshooting Commands

| Task | Command |
| :--- | :--- |
| **View real-time logs** *(most useful for troubleshooting)* | `sudo journalctl -u opencode -f` |
| **Restart service** *(applies changes after editing config)* | `sudo systemctl restart opencode` |
| **Stop service** | `sudo systemctl stop opencode` |
| **Reload service daemon** *(after editing .service file)* | `sudo systemctl daemon-reload` |
| **Check port 4097 listening status** | `sudo ss -tuln \| grep 4097` |
