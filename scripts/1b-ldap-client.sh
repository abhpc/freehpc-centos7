#! /bin/bash
#=======================================================================#
#                   FreeHPC Basic Setup for CentOS 7.9                  #
#=======================================================================#

# Load environment variables
. $HOME/env.conf

# check environment variable
if [ -z "$LDAP_SERV" ]; then
    echo "Error: The environmenal variable LDAP_SERV is empty."
    exit 1
fi
if [ -z "$LDAP_BASE" ]; then
    echo "Error: The environmenal variable LDAP_BASE is empty."
    exit 1
fi
if [ -z "$LDAP_PASS" ]; then
    echo "Error: The environmenal variable LDAP_PASS is empty."
    exit 1
fi

# Install LDAP clients
yum -y install openldap-clients nss-pam-ldapd

# Enable ldap auth
authconfig --enableldap \
--enableldapauth \
--ldapserver="$LDAP_SERV" \
--ldapbasedn="$LDAP_BASE" \
--enablemkhomedir \
--update

cat << EOF > /etc/nslcd.conf
uid nslcd
gid ldap
uri ldap://$LDAP_SERV/
base $LDAP_BASE
ssl no
tls_cacertdir /etc/openldap/cacerts
binddn cn=admin,$LDAP_BASE
bindpw $LDAP_PASS
validnames /^[a-z0-9._@\$-][a-z0-9._@$ \\\~-]*[a-z0-9._@$~-]$/i
EOF

cat << EOF > /etc/nsswitch.conf
passwd: files nis sss ldap
shadow: files nis sss ldap
group:  files nis sss ldap

hosts:  files nis dns myhostname

bootparams: nisplus [NOTFOUND=return] files

ethers:     files
netmasks:   files
networks:   files
protocols:  files
rpc:        files
services:   files sss

netgroup:   files sss ldap

publickey:  nisplus

automount:  files ldap
aliases:    files nisplus
EOF

cat << EOF > /etc/pam.d/system-auth-ac 
#%PAM-1.0
# This file is auto-generated.
# User changes will be destroyed the next time authconfig is run.
auth        required      pam_env.so
auth        required      pam_faildelay.so delay=2000000
auth        sufficient    pam_unix.so nullok try_first_pass
auth        requisite     pam_succeed_if.so uid >= 1000 quiet_success
auth        sufficient    pam_ldap.so use_first_pass
auth        required      pam_deny.so

account     required      pam_unix.so broken_shadow
account     sufficient    pam_localuser.so
account     sufficient    pam_succeed_if.so uid < 1000 quiet
account     [default=bad success=ok user_unknown=ignore] pam_ldap.so
account     required      pam_permit.so

password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=
password    sufficient    pam_unix.so sha512 shadow nullok try_first_pass use_authtok
password    sufficient    pam_ldap.so use_authtok
password    required      pam_deny.so

session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
-session     optional      pam_systemd.so
session     optional      pam_oddjob_mkhomedir.so umask=0077
session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session     required      pam_unix.so
session     optional      pam_ldap.so
EOF

mkdir $APP_DIR/bin/ -p
cat << EOF > $APP_DIR/bin/list-users
#! /bin/bash
(echo -e "ID\tUSER\tNAME\tHOMEDIR\n------ ---------- ---------- --------------" && getent passwd | awk -F ":" '\$3>1000 && \$3<65500 {print \$3"\t"\$1,\$5"\t\t"\$6}'|sort -n)| column -t
EOF
chmod +x $APP_DIR/bin/list-users

systemctl disable --now sssd.service
systemctl enable --now nslcd.service
systemctl restart nslcd.service