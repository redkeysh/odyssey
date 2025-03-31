#!/bin/bash

# This is used as a central file server repository containing the configuration files used.
res="http://files.webserver.com/unix/stig/resources"

#if [ -f /etc/issue ] ; then
   cd /etc && curl -O $res/issue
#fi

#if [ -f /etc/ssh/sshd_config ] ; then
   cd /etc/ssh/ && curl -O $res/sshd_config
#fi

cd /etc/modprobe.d/ && curl -O $res/blacklist.conf


#if [ -f /etc/crypto-policies/back-ends/openssh.config ] ; then
   cd /etc/crypto-policies/back-ends/ && curl -O $res/openssh.config
#fi

#if [ -f /etc/pam.d/system-auth ] ; then
   cd /etc/pam.d/ && curl -O $res/system-auth
#fi

#if [ -f /etc/pam.d/password-auth ] ; then
   cd /etc/pam.d/ && curl -O $res/password-auth
#fi

#if [ -f /etc/rsyslog.conf ] ; then
   cd /etc/ && curl -O $res/rsyslog.conf
#fi

#if [ -f /etc/audit/rules.d/audit.rules ] ; then
   cd /etc/audit/rules.d/ && curl -O $res/audit.rules
#fi

#if [ -f /etc/sysctl.d/99-sysctl.conf ] ; then
   cd /etc/sysctl.d/ && curl -O $res/99-sysctl.conf
#fi

#if [ -f /etc/security/faillock.conf ] ; then
   cd /etc/security/ && curl -O $res/faillock.conf
#fi

cd /etc/ && curl -O $res/login.defs

cd /etc/pam.d/ && curl -O $res/postlogin

#sed -i '/GSSAPIAuthentication/s/^#//g' /etc/ssh/sshd_config.d/50-redhat.conf # Commenting out, this is covered in ../sshd_config
rm -f /etc/ssh/sshd_config.d/50-redhat.conf # Removing the Default RedHat sshd configuration file which conflicts with DISA RHEL9 v1 STIG
sed -i '/X11forwarding/s/^#//g' /etc/ssh/sshd_config.d/50-redhat.conf # Commenting out, this is covered in ../sshd_config

systemctl restart sshd

sed -i '/CtrlAltDelBurstAction/s/^#//g' /etc/systemd/system.conf # Uncommenting out
sed -r -i '/CtrlAltDelBurstAction/ s/(^.*)(=.*)/\1=none/g' /etc/systemd/system.conf

sed -i '/ProcessSizeMax/s/^#//g' /etc/systemd/coredump.conf # Commenting out
sed -r -i '/ProcessSizeMax/ s/(^.*)(=.*)/\1=0/g' /etc/systemd/coredump.conf

sed -i '/Storage/s/^#//g' /etc/systemd/coredump.conf # Uncommenting out
sed -r -i '/Storage/ s/(^.*)(=.*)/\1=none/g' /etc/systemd/coredump.conf

sudo systemctl daemon-reload

sudo systemctl disable --now ctrl-alt-del.target
sudo systemctl disable --now debug-shell.service

sudo systemctl mask --now ctrl-alt-del.target
sudo systemctl mask --now debug-shell.service

grubby --update-kernel=ALL --args="vsyscall=none"
grubby --update-kernel=ALL --args="page_poison=1"
grubby --update-kernel=ALL --args="page_poison=1"
grubby --update-kernel=ALL --args="pti=on"
grubby --update-kernel=ALL --args="audit=1"
# Vul ID: V-258173         Rule ID: SV-258173r926506_rule         STIG ID: RHEL-09-653120
grubby --update-kernel=ALL --args=audit_backlog_limit=8192
# Vul ID: V-257794         Rule ID: SV-257794r925369_rule         STIG ID: RHEL-09-212045
grubby --update-kernel=ALL --args="slub_debug=P"

sysctl --system

# Vul ID: V-257814         Rule ID: SV-257814r925429_rule         STIG ID: RHEL-09-213095
if  ! grep -q "* hard core 0" /etc/security/limits.conf ; then
   echo "* hard core 0" >> /etc/security/limits.conf
fi
if  ! grep -q "* hard maxlogins 10" /etc/security/limits.conf ; then
   echo "* hard maxlogins 10" >> /etc/security/limits.conf
fi

# Vul ID: V-257821         Rule ID: SV-257821r925450_rule         STIG ID: RHEL-09-214020
if  ! grep -q "localpkg_gpgcheck=1" /etc/dnf/dnf.conf ; then
   echo "localpkg_gpgcheck=1" >> /etc/dnf/dnf.conf
fi

if ! grep -q "DefaultNetstreamDriver gtls" /etc/rsyslog.conf ; then 
   echo "$DefaultNetstreamDriver gtls" >> /etc/rsyslog.conf
fi

# Vul ID: V-257815         Rule ID: SV-257815r925432_rule         STIG ID: RHEL-09-213100
sudo systemctl mask --now systemd-coredump.socket
systemctl daemon-reload

# Vul ID: V-257838         Rule ID: SV-257838r925501_rule         STIG ID: RHEL-09-215075    openssl-pkcs11
# Vul ID: V-257839         Rule ID: SV-257839r925504_rule         STIG ID: RHEL-09-215080    gnutls-utils
# Vul ID: V-257840         Rule ID: SV-257840r925507_rule         STIG ID: RHEL-09-215085    nss-tools
# Vul ID: V-257841         Rule ID: SV-257841r925510_rule         STIG ID: RHEL-09-215090    rng-tools
# Vul ID: V-257842         Rule ID: SV-257842r942959_rule         STIG ID: RHEL-09-215095    s-nail
# Vul ID: V-257954         Rule ID: SV-257954r925849_rule         STIG ID: RHEL-09-252065    libreswan
# Vul ID: V-258035         Rule ID: SV-258035r926092_rule         STIG ID: RHEL-09-291015    usbguard
# Vul ID: V-258063         Rule ID: SV-258063r926176_rule         STIG ID: RHEL-09-412010    tmux
# Vul ID: V-258089         Rule ID: SV-258089r926254_rule         STIG ID: RHEL-09-433010    fapolicyd
# Vul ID: V-258124         Rule ID: SV-258124r926359_rule         STIG ID: RHEL-09-611175    pcsc-lite
# Vul ID: V-258126         Rule ID: SV-258126r926365_rule         STIG ID: RHEL-09-611185    open-sc
# Vul ID: V-258175         Rule ID: SV-258175r926512_rule         STIG ID: RHEL-09-653130    audispd-plugins
dnf install openssl-pkcs11 gnutls-utils nss-tools rng-tools s-nail \
       libreswan usbguard tmux fapolicyd pcsc-lite opensc audispd-plugins aide -y

# Vul ID: V-258036         Rule ID: SV-258036r926095_rule         STIG ID: RHEL-09-291020    usbguard
if rpm -q --quiet usbguard ; then
   systemctl enable --now usbguard
else
#   dnf install usbguard -y
   systemctl enable --now usbguard
fi

# Vul ID: V-258090         Rule ID: SV-258090r926257_rule         STIG ID: RHEL-09-433015    fapolicyd
if rpm -q --quiet fapolicyd ; then
   systemctl enable --now fapolicyd
else
#   dnf install fapolicyd -y
   systemctl enable --now fapolicyd
fi

# Vul ID: V-258134         Rule ID: SV-258134r926389_rule         STIG ID: RHEL-09-651010
if rpm -q --quiet aide ; then
   sudo /usr/sbin/aide --init
else
#   dnf install aide -y
   sudo /usr/sbin/aide --init
fi

# Vul ID: V-258125         Rule ID: SV-258125r926362_rule         STIG ID: RHEL-09-611180    pcsc-lite
if rpm -q --quiet pcscd ; then
   systemctl enable --now pcscd
else
#   dnf install fapolicyd -y
   systemctl enable --now pcscd
fi

# Vul ID: V-257888         Rule ID: SV-257888r925651_rule         STIG ID: RHEL-09-232040
chmod 0700 /etc/cron.*

# Vul ID: V-257933         Rule ID: SV-257933r925786_rule         STIG ID: RHEL-09-232265
chmod 0600 /etc/crontab

# Vul ID: V-257999              Rule ID: SV-257999r925984_rule          STIG ID: RHEL-09-255115
chmod 0600 /etc/ssh/sshd_config


# Vul ID: V-257945         Rule ID: SV-257945r925822_rule         STIG ID: RHEL-09-252020
if ! grep -q "#pool 2." /etc/chrony.conf ; then
        sed -i '/pool 2\./s/^/#/g' /etc/chrony.conf
fi

if  ! grep -q "server your.ntp.server.com iburst maxpoll 16" /etc/chrony.conf ; then
   echo "server your.ntp.server.com iburst maxpoll 16" >> /etc/chrony.conf
fi

# Vul ID: V-257946         Rule ID: SV-257946r925825_rule         STIG ID: RHEL-09-252025
if  ! grep -q "port 0" /etc/chrony.conf ; then
   echo "port 0" >> /etc/chrony.conf
fi

# Vul ID: V-257947         Rule ID: SV-257947r925828_rule         STIG ID: RHEL-09-252030
if  ! grep -q "cmdport 0" /etc/chrony.conf ; then
   echo "cmdport 0" >> /etc/chrony.conf
fi

# Vul ID: V-257949         Rule ID: SV-257949r925834_rule         STIG ID: RHEL-09-252040
if ! grep -q "dns = none" /etc/NetworkManager/NetworkManager.conf ; then
        sed -i -e '/\[main\]/a\' -e 'dns = none' /etc/NetworkManager/NetworkManager.conf
        systemctl reload NetworkManager
fi

sudo authselect enable-feature with-faillock

# Vul ID: V-258073              Rule ID: SV-258073r926206_rule          STIG ID: RHEL-09-412060
sed -r -i '/umask 022/ s/022/077/g' /etc/csh.cshrc

if ! grep -q "umask 077" /etc/profile ; then
   echo "umask 077" >> /etc/profile
fi

# Vul ID: V-258077              Rule ID: SV-258077r926218_rule          STIG ID: RHEL-09-412080
if ! grep -q "StopIdleSessionSec=900" /etc/systemd/logind.conf ; then
   echo "StopIdleSessionSec=900" >> /etc/systemd/logind.conf
   systemctl restart systemd-logind
fi

# Vul ID: V-258084              Rule ID: SV-258084r943061_rule          STIG ID: RHEL-09-432015
if ! grep -q "Defaults timestamp_timeout=0" /etc/sudoers ; then
   echo "Defaults timestamp_timeout=0" >> /etc/sudoers
fi

# Vul ID: V-258085              Rule ID: SV-258085r943063_rule          STIG ID: RHEL-09-43202
if ! grep -q "Defaults !targetpw" /etc/sudoers ; then
   echo "Defaults !targetpw" >> /etc/sudoers
fi

if ! grep -q "Defaults !rootpw" /etc/sudoers ; then
   echo "Defaults !rootpw" >> /etc/sudoers
fi
if ! grep -q "Defaults !runaspw" /etc/sudoers ; then
   echo "Defaults !runaspw" >> /etc/sudoers
fi



# Vul ID: V-258091              Rule ID: SV-258091r926260_rule          STIG ID: RHEL-09-611010
sed -r -i '/pam_pwquality.so/ s/$/ retry=3/g' /etc/pam.d/system-auth

# Vul ID: V-258094              Rule ID: SV-258094r926269_rule          STIG ID: RHEL-09-611025
sed -i -r '/nullok/ s/nullok//g' /etc/pam.d/system-auth /etc/pam.d/password-auth

# Vul ID: V-258101              Rule ID: SV-258101r926290_rule          STIG ID: RHEL-09-611060
sed -r -i '/enforce_for_root/ s/^#//g' /etc/security/pwquality.conf

# Vul ID: V-258102              Rule ID: SV-258102r926293_rule          STIG ID: RHEL-09-611065
sed -r -i '/lcredit/s/^#//g ; /lcredit/ s/(^.*)(\s.*)/\1 -1/g' /etc/security/pwquality.conf

# Vul ID: V-258103         Rule ID: SV-258103r926296_rule         STIG ID: RHEL-09-611070
sed -r -i '/dcredit/s/^#//g ; /dcredit/ s/(^.*)(\s.*)/\1 -1/g' /etc/security/pwquality.conf

# Vul ID: V-258109         Rule ID: SV-258109r926314_rule         STIG ID: RHEL-09-611100
sed -r -i '/ocredit/s/^#//g ; /ocredit/ s/(^.*)(\s.*)/\1 -1/g' /etc/security/pwquality.conf

# Vul ID: V-258111        Rule ID: SV-258111r926320_rule         STIG ID: RHEL-09-611110
sed -r -i '/ucredit/s/^#//g ; /ucredit/ s/(^.*)(\s.*)/\1 -1/g' /etc/security/pwquality.conf

# Vul ID: V-258110        Rule ID: SV-258110r926317_rule         STIG ID: RHEL-09-611105
sed -r -i '/dictcheck/s/^#//g' /etc/security/pwquality.conf

# Vul ID: V-258112         Rule ID: SV-258112r926323_rule         STIG ID: RHEL-09-611115
sed -r -i '/difok/s/^#//g ; /difok/ s/(^.*)(\s.*)/\1 8/g' /etc/security/pwquality.conf

# Vul ID: V-258113         Rule ID: SV-258113r926326_rule         STIG ID: RHEL-09-611120 
sed -r -i '/maxclassrepeat/s/^#//g ; /maxclassrepeat/ s/(^.*)(\s.*)/\1 4/g' /etc/security/pwquality.conf

# Vul ID: V-258114        Rule ID: SV-258114r926329_rule         STIG ID: RHEL-09-611125
sed -r -i '/maxrepeat/s/^#//g ; /maxrepeat/ s/(^.*)(\s.*)/\1 3/g' /etc/security/pwquality.conf

# Vul ID: V-258115         Rule ID: SV-258115r926332_rule         STIG ID: RHEL-09-611130
sed -r -i '/minclass/s/^#//g ; /minclass/ s/(^.*)(\s.*)/\1 4/g' /etc/security/pwquality.conf

# Vul ID: V-258153         Rule ID: SV-258153r926446_rule         STIG ID: RHEL-09-653020
sed -r -i '/disk_error_action/ s/(^.*)(\s.*)/\1 HALT/g' /etc/audit/auditd.conf

# Vul ID: V-258154         Rule ID: SV-258154r926449_rule         STIG ID: RHEL-09-653025
sed -r -i '/disk_full_action/ s/(^.*)(\s.*)/\1 HALT/g' /etc/audit/auditd.conf

# Vul ID: V-258156         Rule ID: SV-258156r926455_rule         STIG ID: RHEL-09-653035
sed -r -i '/space_left/ s/(^.*)(\s.*)/\1 75/g' /etc/audit/auditd.conf

# Vul ID: V-258157         Rule ID: SV-258157r926458_rule         STIG ID: RHEL-09-653040 
sed -r -i '/space_left_action/ s/(^.*)(\s.*)/\1 email/g' /etc/audit/auditd.conf

# Vul ID: V-258158         Rule ID: SV-258158r926461_rule         STIG ID: RHEL-09-653045
sed -r -i '/admin_space_left/ s/(^.*)(\s.*)/\1 95/g' /etc/audit/auditd.conf

# Vul ID: V-258159         Rule ID: SV-258159r926464_rule         STIG ID: RHEL-09-653050
sed -r -i '/admin_space_left_action/ s/(^.*)(\s.*)/\1 single/g' /etc/audit/auditd.conf

# Vul ID: V-258161         Rule ID: SV-258161r926470_rule         STIG ID: RHEL-09-653060
sed -r -i '/name_format/ s/(^.*)(\s.*)/\1 hostname/g' /etc/audit/auditd.conf



# Vul ID: V-258105        Rule ID: SV-258105r926302_rule         STIG ID: RHEL-09-611080
# passwd -n 1 <user>

# Vul ID: V-258049         Rule ID: SV-258049r926134_rule         STIG ID: RHEL-09-411050
useradd -D -f 35

sudo dnf update
