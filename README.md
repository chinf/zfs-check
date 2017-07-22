# zfs-check
ZFS health check, utilisation logging and alerting

Depends upon:

* the standard ZFS utilities
* a POSIX standard shell
* (for email alerts) the host being set up to send emails; one possibility is to use `bsd-mailx` and `ssmtp`, but several alternatives exist.

## Installation
```
wget https://github.com/chinf/zfs-check/archive/master.zip
unzip master.zip
cd zfs-check-master
sudo make install
```
This will install a cron entry for zfs-check under `/etc/cron.daily/`, configured by default to limit output to summary level and output to the default log location `/var/log/zfs-check.log`.

The default installation also includes a logrotate entry under `/etc/logrotate.d/` to ensure the default logfile is rotated.
