#!/bin/bash
# Docker entrypoint
#
# Author: gw0 [http://gw.tnode.com/] <gw.2021@ena.one>
set -e

# initialize on first run
echo "Initializing..."
echo "Set Timezone to '$TZ' ..."
ln -sf /usr/share/zoneinfo/$TZ /etc/localtime
echo -e "... `date`"
echo "cron-schedule: $CRON"
touch /etc/cron.d/getmail
echo -e "# system-wide crontab for getmail\nSHELL=/bin/sh\n\n# m h dom mon dow user  command" >> /etc/cron.d/getmail
mkdir -p /var/log/dovecot /var/log/getmail
touch /var/log/dovecot/dovecot.log
chown root:users /var/log/dovecot/dovecot.log
chmod 664 /var/log/dovecot/dovecot.log
for USER in $(ls -1 /home); do
  echo "home permissions: $(stat -c '%u' /home):$(stat -c '%g' /home)"
  echo "User '$USER':"
  if ! id -u "$USER" >/dev/null 2>&1; then
    # respect hosts permissions by cloning uid, gid and group into container
    host_uid=$(stat -c '%u' /home/$USER)
    host_gid=$(stat -c '%g' /home/$USER)
    echo "Found uid:gid $host_uid:$host_gid"
    # create user with default password
    useradd --uid=$host_uid --gid=$host_gid --groups=users --no-create-home --shell='/bin/true' "$USER"
    echo -e "$DEFAULT_PASSWD\n$DEFAULT_PASSWD\n" | passwd "$USER"
    # create subfolders if necessary
    mkdir -p /home/$USER/{Maildir,sieve}
    chown -R "$host_uid:$host_gid" "/home/$USER/"
    chmod 700 /home/$USER/{Maildir,sieve,.getmail} || true
  fi
  for RC in $(ls -1 /home/$USER/.getmail/getmailrc-*); do
    echo "- $RC"
    ACC=${RC##*/getmailrc-}
    echo -e "${CRON:1:-1} $USER (date; flock -n ~/.getmail/lock-$ACC getmail --rcfile=\"$RC\" --idle INBOX) >> \"/var/log/getmail/$ACC.log\" 2>&1" >> /etc/cron.d/getmail
    # fix log permissions
    LOG="/var/log/getmail/$ACC.log"
    touch "$LOG"
    chown "$host_uid:$host_gid" "$LOG"
    chmod 644 "$LOG"
  done
done

# start services
echo "Starting services..."
/etc/init.d/dovecot start
/etc/init.d/cron start

exec "$@"
