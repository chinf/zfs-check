PREFIX := /usr/local

all:

install:
	install -d $(DESTDIR)/etc/cron.daily
	install etc/zfs-check.cron.daily    $(DESTDIR)/etc/cron.daily/zfs-check
	install -d $(DESTDIR)/etc/logrotate.d
	install -m 0644 etc/zfs-check.logrotate.d $(DESTDIR)/etc/logrotate.d/zfs-check
#	install -d $(DESTDIR)$(PREFIX)/share/man/man8
#	install -m 0644 src/zfs-check.8 $(DESTDIR)$(PREFIX)/share/man/man8/zfs-check.8
#	gzip $(DESTDIR)$(PREFIX)/share/man/man8/zfs-check.8
	install -d $(DESTDIR)$(PREFIX)/bin
	install src/zfs-check.sh $(DESTDIR)$(PREFIX)/bin/zfs-check
