#!/bin/bash
# Docker entrypoint
#
# Author: gw0 [http://gw.tnode.com/] <gw.2021@ena.one>
set -e

# initialize on first run
echo "Initializing..."
mkdir -p /var/log/dovecot /var/log/getmail
touch /var/log/dovecot/dovecot.log
chown root:users /var/log/dovecot/dovecot.log
chmod 664 /var/log/dovecot/dovecot.log
for USER in $(ls -1 /home); do
  echo "User '$USER':"
  if ! id -u "$USER" >/dev/null 2>&1; then
    # respect hosts permissions by cloning uid:gid into container
    host_uid=$(stat -c '%u' /home/$USER)
    host_gid=$(stat -c '%g' /home/$USER)
    # create user with default password
    useradd --uid=$host_uid --gid=$host_gid --groups=users --no-create-home --shell='/bin/true' "$USER"
    echo -e "$DEFAULT_PASSWD\n$DEFAULT_PASSWD\n" | passwd "$USER"
    # create subfolders if necessary
    mkdir -p /home/$USER/{Maildir,sieve}
    chown -R "$host_uid:$host_gid" "/home/$USER"
    chmod 700 /home/$USER/{Maildir,sieve,.getmail} || true
  fi
  for RC in $(ls -1 /home/$USER/.getmail/getmailrc-*); do
    echo "\t- $RC"
    # fix log permissions
    LOG="/var/log/getmail/${RC##*/getmailrc-}.log"
    touch "$LOG"
    chown "$host_uid:$host_guid" "$LOG"
    chmod 644 "$LOG"
  done
done

# start services
echo "Starting services..."
/etc/init.d/dovecot start
/etc/init.d/cron start

exec "$@"
