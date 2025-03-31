#!/bin/bash
sed -i '/PubkeyAuthentication/s/^#//g' /etc/ssh/sshd_config # Uncommenting out
sed -i '/PermitEmptyPassword/s/^#//g' /etc/ssh/sshd_config # Uncommenting out
sed -r -i '/PermitRootLogin/s/^#//g ; /PermitRootLogin/ s/(^.*)(\s.*)/\1 no/g' /etc/ssh/sshd_config
sed -r -i '/HostbasedAuthentication no/s/^#//g' /etc/ssh/sshd_config
sed -r -i '/PermitUserEnvironment/s/^#//g' /etc/ssh/sshd_config
sed -r -i '/RekeyLimit/s/^#//g ; /RekeyLimit/s/(^.*)(\s.*)/\1 1G 1h/g ; /RekeyLimit/s/default //g' /etc/ssh/sshd_config
sed -r -i '/ClientAliveCountMax/s/^#//g ; /ClientAliveCountMax/s/(^.*)(\s.*)/\1 1/g' /etc/ssh/sshd_config
sed -r -i '/ClientAliveInterval/s/^#//g ; /ClientAliveInterval/s/(^.*)(\s.*)/\1 600/g' /etc/ssh/sshd_config
sed -r -i '/Compression/s/^#//g ; /Compression/s/(^.*)(\s.*)/\1 no/g' /etc/ssh/sshd_config
sed -r -i '/GSSAPIAuth/s/^#//g ; /GSSAPIAuth/s/(^.*)(\s.*)/\1 no/g' /etc/ssh/sshd_config
sed -r -i '/KerberosAuthentication/s/^#//g' /etc/ssh/sshd_config
sed -r -i '/IgnoreUserKnownHosts/s/^#//g ; /IgnoreUserKnownHosts/s/(^.*)(\s.*)/\1 yes/g' /etc/ssh/sshd_config
sed -r -i '/X11Forwarding/s///g' /etc/ssh/sshd_config
sed -r -i '/StrictModes/s/^#//g' /etc/ssh/sshd_config
sed -r -i '/PrintLastLog/s/^#//g' /etc/ssh/sshd_config
sed -r -i '/X11UseLocalhost/s/^#//g' /etc/ssh/sshd_config

sed -r -i '/GSSAPIAuth/s/^/#/g ; /GSSAPIAuth/s/(^.*)(\s.*)/\1 no/g' /etc/ssh/sshd_config.d/50-redhat.conf 
sed -r -i '/X11Forwarding/s/^/#/g' /etc/ssh/sshd_config.d/50-redhat.conf

echo "X11Forwarding no" >> /etc/ssh/sshd_config
echo "UsePrivilegeSeparation sandbox" >> /etc/ssh/sshd_config
echo "Banner /etc/issue/" >> /etc/ssh/sshd_config
echo "LogLevel VERBOSE" >> /etc/ssh/sshd_config