#!/usr/bin/env bash

set -euo pipefail

source /usr/local/sbin/library.bash
# Not using get-flag here, because this might run multiple times and the calling script still has to continue (instead of exit 1)
if [ -n "$(peek-flag pool-setup-finished)" ]; then
  exit
fi

# Create user and set up SSH access
/sbin/useradd -d "${EXPERIMENTS_DIR}" -M pool
ssh-keygen -f /root/pool.key -N '' -o -q -t ed25519
cat /root/pool.key | tr '\n' '$' > /var/log/nightking/cache/pool.key
chmod 400 /var/log/nightking/cache/pool.key
rm /root/pool.key

mv /root/pool.key.pub "${EXPERIMENTS_DIR}"/.pool
chmod 400 "${EXPERIMENTS_DIR}"/.pool
chown pool "${EXPERIMENTS_DIR}"/.pool

#Create a SFTP daemon on port 2222
cp /usr/lib/systemd/system/sshd.service /etc/systemd/system/sftpd.service
sed -i 's,^EnvironmentFile=.*$,EnvironmentFile=/etc/sysconfig/sftpd,' /etc/systemd/system/sftpd.service
cp /etc/sysconfig/sshd /etc/sysconfig/sftpd
echo 'OPTIONS="-f /etc/ssh/sftpd_config"' >> /etc/sysconfig/sftpd
cat << EOF > /etc/ssh/sftpd_config
Port 2222
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
SyslogFacility AUTHPRIV
AuthorizedKeysFile .pool
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
GSSAPIAuthentication no
GSSAPICleanupCredentials no
UsePAM yes
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
PrintMotd no
PrintLastLog no
PidFile /var/run/sftpd.pid
Subsystem sftp internal-sftp
AllowUsers pool
ChrootDirectory ${EXPERIMENTS_DIR}
EOF
chmod 400 /etc/ssh/sftpd_config

set-flag pool-setup-finished
