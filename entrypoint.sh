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
    # create user with default password
    useradd --groups=users --no-create-home --shell='/bin/true' "$USER"
    echo -e "$DEFAULT_PASSWD\n$DEFAULT_PASSWD\n" | passwd "$USER"
    chown -R "$USER:$USER" "/home/$USER"
    chmod 700 /home/$USER/{Maildir,sieve,.getmail} || true
  fi
  for RC in $(ls -1 /home/$USER/.getmail/getmailrc-*); do
    echo "- $RC"
    # fix log permissions
    LOG="/var/log/getmail/${RC##*/getmailrc-}.log"
    touch "$LOG"
    chown "$USER:$USER" "$LOG"
    chmod 644 "$LOG"
  done
done

# start services
echo "Starting services..."
/etc/init.d/dovecot start
/etc/init.d/cron start

exec "$@"
