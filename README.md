# zfs-check
ZFS health check, utilisation logging and alerting

Depends on the standard ZFS utilities and bash shell. Email alerts depend upon the host being set up to send emails, a package like ssmtp will suffice.

## Installation
```
wget https://github.com/chinf/zfs-check/archive/master.zip
unzip master.zip
cd zfs-check-master
sudo make install
```
This will install a cron entry for zfs-check under `/etc/cron.daily/`, configured by default to limit output to summary level and output to the default log location `/var/log/zfs-check.log`.

The default installation also includes a logrotate entry under `/etc/logrotate.d/` to ensure the default logfile is rotated.
