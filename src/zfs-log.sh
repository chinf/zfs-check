#!/bin/bash
LOGFILE=/var/log/zfs-status.log
date >> $LOGFILE
echo -e "\nzpool health:\n" >> $LOGFILE
zpool status >> $LOGFILE
echo -e "\nzpool utilisation:\n" >> $LOGFILE
zpool list >> $LOGFILE
echo -e "\nzfs dataset utilisation:\n" >> $LOGFILE
zfs list >> $LOGFILE
echo -e "\nzfs non-auto snapshot utilisation:\n" >> $LOGFILE
zfs list -t snapshot -r palomino | grep -v "zfs-auto-snap_" >> $LOGFILE
echo -e "\n-----------------------------------------------------------------\n\n" >> $LOGFILE
