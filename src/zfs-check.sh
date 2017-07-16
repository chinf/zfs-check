#!/bin/bash

# zfs-check
# Copyright (C) 2017 Francis Chin <dev@fchin.com>

REPORT=/tmp/zfs-check-$$.log

log() { # level, message
  local LEVEL=$1
  shift 1
  case $LEVEL in
    (err*)
      echo -e "zfs-check error: $*" | tee -a $REPORT >&2
      MAILNOTIFY=yes
      ;;
    (war*)
      echo -e "zfs-check warning: $*" >> $REPORT
      MAILNOTIFY=yes
      ;;
    (sum*) echo -e "$*" >> $REPORT ;;
    (inf*) if [ -z "${SUMMARY}" ]; then echo -e "$*" >> $REPORT; fi ;;
  esac
}

#
# Options
#
DEFAULTLOG=/var/log/zfs-check.log
MAXCAPACITY=95
ZFSAUTOSNAPLABEL=zfs-auto-snap_

print_usage() {
  echo "Usage: $0 [-l|-L LOGFILE] [-m ADDRESS] [-c CAPACITY] [-s]
Use ZFS utilities to log the health and status of all mounted pools, and
optionally alert via email if there are any warnings.

  -l           Instead of sending output to STDOUT, append to a log at
               the default location ${DEFAULTLOG}

  -L LOGFILE   Append output to LOGFILE instead of STDOUT. 

  -m ADDRESS   Email warnings to ADDRESS.

  -c CAPACITY  Use a zpool utilisation upper limit of CAPACITY% instead
               of the default upper limit ${MAXCAPACITY}%.

  -s           Summary mode.
" >&2
exit 2
}

while getopts ":lL:m:c:s" OPT; do
  case "${OPT}" in
    l) LOG="${DEFAULTLOG}" ;;
    L) LOG="${OPTARG}" ;;
    m)
      if [ "${OPTARG}" ]; then
        EMAIL="${OPTARG}"
      else
        print_usage
      fi
      ;;
    c)
      if [ "${OPTARG}" ]; then
        MAXCAPACITY="${OPTARG}"
      else
        print_usage
      fi
      ;;
    s) SUMMARY=yes ;;
    *) print_usage ;;
  esac
done
shift $((OPTIND-1))

mail_report() { # email subject
  if [ "${EMAIL}" ]; then
    mail -s "zfs-check on `uname -n`: $*" "${EMAIL}" < "${REPORT}"
  fi
}

write_log() {
  if [ "${LOG}" ]; then
    # Append to log file if it already exists, otherwise create it
    cat $REPORT >> $LOG
  else
    cat $REPORT >&1
  fi
  rm $REPORT
}

#
# main()
#
log summary "zfs-check started: `date`\n"

# Show general zpool status and configuration
# ZPOOLLIST=`sudo zpool list -H -o name`
ZPOOLSTATUSV=`sudo zpool status -v`
if [ "$ZPOOLSTATUSV" = "no pools available" ]; then
  log warning "No pools mounted, aborting check"
  mail_report "warning: no ZFS pools mounted"
  write_log
  exit 3
fi
log info "zpool status:\n${ZPOOLSTATUSV}\n"

# Assess zpool health status
ZPOOLCONDITION=`sudo zpool status -x`
if [ "$ZPOOLCONDITION" = "all pools are healthy" ]; then
  log summary "zfs-check info: ${ZPOOLCONDITION}\n"
else
  log warning "zpool health: ${ZPOOLCONDITION}\n"
fi
# Check for drive errors on ONLINE VDEVs
VDEVERRORS=`echo "${ZPOOLSTATUSV}" \
| awk '$1 != "state:" && $2 == "ONLINE" && $3 $4 $5 != "000"'`
if [ "$VDEVERRORS" ]; then
  log warning "vdev errors reported"
  # Print title row
  log info `echo "${ZPOOLSTATUSV}" | awk '$1 == "NAME"' | head -1`
  log info "${VDEVERRORS}\n"
fi

# Assess zpool capacity utilisation
log summary "zpool utilisation summary:\n`sudo zpool list`\n"
CAPACITY=`sudo zpool list -H -o name,capacity,free`
CAPWARN=`echo "${CAPACITY}" | awk -v max="${MAXCAPACITY}" \
  '$2 > max { print "utilisation is "$2" in "$1" with "$3" free" }'`
if [ "${CAPWARN}" ]; then
  log warning "${CAPWARN}\n"
fi

# Show zfs dataset usage
log info "zfs dataset utilisation:\n`sudo zfs list`\n"
log info "zfs non-auto snapshot utilisation:"
log info "`sudo zfs list -rt snapshot | grep -v ${ZFSAUTOSNAPLABEL}`\n"

# End zfs-check
log info "zfs-check finished: `date`"
log info "---------------------------------------------------------------"
if [ "${MAILNOTIFY}" ]; then
  mail_report "ZFS health warning"
fi
write_log