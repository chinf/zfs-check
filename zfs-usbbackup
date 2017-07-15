#!/bin/bash
# Full and incremental ZFS backups
# Author: Francis Chin
#
# This script backs up all datasets on the host to a designated
# backup pool which is accessible to the host. This backup pool
# may reside on an external USB hard drive for example.
#
# The scope is fixed to all datasets in all currently imported
# pools, excluding the designated backup pool.
#
# Usage:
# sudo zfs-usbbackup [backuppool]

BACKUPZPOOLDEFAULT=usbbackup
BACKUPSNAPSHOTNAME=backup

echo -e "Starting zfs-usbbackup on `date`"

## Prerequisites
if [[ `id -u` -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

# Check backup target zpool is available
BACKUPZPOOL=${1:-$BACKUPZPOOLDEFAULT}
if [ "$BACKUPZPOOL" != `zpool list -Ho name $BACKUPZPOOL` ]; then
  zpool import $BACKUPZPOOL
  if [ $? = 1 ]; then
    echo -e "Failed to import pool $BACKUPZPOOL for backup target"
    echo -e "Check backup target pool name or backup device"
    exit 1
  fi
fi
echo -e "Found target pool for backups: $BACKUPZPOOL"

ZPOOLCONDITION=`zpool status -x $BACKUPZPOOL`
if [ "$ZPOOLCONDITION" != "pool '$BACKUPZPOOL' is healthy" ]; then
  echo -e "Error: Problem with $BACKUPZPOOL:\n`zpool status -v`"
  exit 1
fi

# Assess zpool health status
ZPOOLCONDITION=`zpool status -x`
if [ $ZPOOLCONDITION != "all pools are healthy" ]; then
  echo -e "Warning: zpool health:\n`zpool status -v`"
fi

ZPOOLLIST=`zpool list -Ho name`
SOURCEZPOOLS="${ZPOOLLIST//$BACKUPZPOOL/}"

# Snapshot deletions during long running zfs send processes will cause the zfs send to fail
echo -e "Warning: Do not destroy any datasets or snapshots on $SOURCEZPOOLS while this backup process is running"
# Disable auto snapshots to prevent it causing snapshot deletions
echo -e "zfs-auto-snapshot will be disabled while this backup process is running"
mkdir -p /tmp/zfs-usbbackup
mv /etc/cron.d/zfs-auto-snapshot /tmp/zfs-usbbackup/cron.d.zfs-auto-snapshot
mv /etc/cron.hourly/zfs-auto-snapshot /tmp/zfs-usbbackup/cron.hourly.zfs-auto-snapshot
mv /etc/cron.daily/zfs-auto-snapshot /tmp/zfs-usbbackup/cron.daily.zfs-auto-snapshot
mv /etc/cron.weekly/zfs-auto-snapshot /tmp/zfs-usbbackup/cron.weekly.zfs-auto-snapshot
mv /etc/cron.monthly/zfs-auto-snapshot /tmp/zfs-usbbackup/cron.monthly.zfs-auto-snapshot


## Main backup process
for POOL in ${SOURCEZPOOLS}
do
  # Check if this is an incremental backup
  zfs rename -r $POOL@$BACKUPSNAPSHOTNAME $POOL@previous_$BACKUPSNAPSHOTNAME
  if [ $? = 0 ]; then
    BACKUPTYPE="incremental"
    echo -e "Incremental backup will be made for $POOL"
  else
    BACKUPTYPE="full"
    echo -e "Full backup will be made for $POOL"
  fi
  # Possible failure modes:
  # - backup snapshot left from last time has been removed/renamed
  # - backup snapshot name changed in this script
  # - name clash for previous snapshot
  # - an unrelated process left a snapshot with a name clashing with the backup snapshot

  # Create snapshot of source pool
  zfs snapshot -r $POOL@$BACKUPSNAPSHOTNAME
  
  echo -e "Backing up pool $POOL"
  if [ "$BACKUPTYPE" = "full" ]; then
    # Backup all snapshots up to this snapshot recursively
    zfs send -R $POOL@$BACKUPSNAPSHOTNAME | zfs recv -v $BACKUPZPOOL/$POOL
    # Remote server version might look like:
    # zfs send -R $POOL@$BACKUPSNAPSHOTNAME | ssh user@ip.ad.dr.ess zfs recv -v $BACKUPZPOOL/$POOL
    # would need credential handling
    # Amazon S3 would need encryption & compression of the serial stream, stored serialised not via zfs recv.
  else
    # Incremental backup all snapshots from previous snapshot to this one recursively
    zfs send -RI @previous_$BACKUPSNAPSHOTNAME $POOL@$BACKUPSNAPSHOTNAME | zfs recv -v $BACKUPZPOOL/$POOL
  fi

  # Remove old backup snapshot
  echo -e "Backup transferred; removing old snapshot (recursively) $POOL@previous_$BACKUPSNAPSHOTNAME"
  #zfs destroy -r $POOL@previous_$BACKUPSNAPSHOTNAME
done

## Post backup tidying
# Disable auto snapshots on backups
echo -e "Setting com.sun:auto-snapshot property on backup datasets"
zfs inherit -r com.sun:auto-snapshot $BACKUPZPOOL

# Restore auto snapshot property on source pools:
echo -e "Re-enabling zfs-auto-snapshot"
mv /tmp/zfs-usbbackup/cron.d.zfs-auto-snapshot /etc/cron.d/zfs-auto-snapshot
mv /tmp/zfs-usbbackup/cron.hourly.zfs-auto-snapshot /etc/cron.hourly/zfs-auto-snapshot
mv /tmp/zfs-usbbackup/cron.daily.zfs-auto-snapshot /etc/cron.daily/zfs-auto-snapshot
mv /tmp/zfs-usbbackup/cron.weekly.zfs-auto-snapshot /etc/cron.weekly/zfs-auto-snapshot
mv /tmp/zfs-usbbackup/cron.monthly.zfs-auto-snapshot /etc/cron.monthly/zfs-auto-snapshot
rmdir /tmp/zfs-usbbackup

# Print summary
echo -e "Backups complete for:\n`zfs list -r ${SOURCEZPOOLS}`\n"
echo -e "Backups now on $BACKUPZPOOL:"
zfs list -r $BACKUPZPOOL
zpool export $BACKUPZPOOL
echo -e "$BACKUPZPOOL exported, backup device(s) may now be removed"
echo -e "zfs-usbbackup finished on `date`"

echo -e "ZFS backups complete on `date` for:\n`zfs list -r ${SOURCEZPOOLS}`" | mail -s "zfs-usbbackup complete on `uname -n`" fchin.uk@gmail.com
