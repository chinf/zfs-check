#!/bin/bash

# zfs-check - ZFS health check, utilisation logging and alerting
# Copyright (C) 2017 Francis Chin <dev@fchin.com>
#
# Repository: https://github.com/chinf/zfs-check.git
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser
# General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

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
# Options
#
REPORT=/tmp/zfs-check-$$.log
DEFAULTLOG=/var/log/zfs-check.log
MAXCAPACITY=75
ZFSAUTOSNAPLABEL=zfs-auto-snap_

print_usage() {
  echo "Usage: $0 [options] [-l|-L LOGFILE]
Use ZFS utilities to log the health and status of all mounted pools, and
optionally alert via email if there are any warnings.

  -c CAPACITY  Use a zpool utilisation upper limit of CAPACITY% instead
               of the default upper limit ${MAXCAPACITY}%.

  -m ADDRESS   Email warnings to ADDRESS.

  -n           No pools alert. If no pools are available on the host,
               trigger an email warning if the -m option is set.

  -s           Summary mode.

  -l           Instead of sending output to STDOUT, append to a log at
               the default location ${DEFAULTLOG}

  -L LOGFILE   Append output to LOGFILE instead of STDOUT. 
" >&2
exit 2
}

while getopts ":c:m:nslL:" OPT; do
  case "${OPT}" in
    c)
      if [ "${OPTARG}" ]; then
        MAXCAPACITY="${OPTARG}"
      else
        print_usage
      fi
      ;;
    m)
      if [ "${OPTARG}" ]; then
        EMAIL="${OPTARG}"
      else
        print_usage
      fi
      ;;
    n) NOPOOLS=yes ;;
    s) SUMMARY=yes ;;
    l) LOG="${DEFAULTLOG}" ;;
    L) LOG="${OPTARG}" ;;
    *) print_usage ;;
  esac
done
shift $((OPTIND-1))

#
# Configuration validation
#
if [ "${LOG}" ]; then
  if [ ! -w "${LOG}" ]; then
    log error "Log file ${LOG} cannot be written to."
    mail_report "Error: cannot write to log"
    write_log
    exit 1
  fi
fi

#
# main()
#
log summary "zfs-check started: `date`\n"

# Show general zpool status and configuration
# ZPOOLLIST=`sudo zpool list -H -o name`
ZPOOLSTATUSV=`sudo zpool status -v`
if [ "${ZPOOLSTATUSV}" = "no pools available" ]; then
  if [ "${NOPOOLS}" ]; then
    log warning "No pools available"
    mail_report "[no ZFS pools available]"
  else
    log summary "No pools available"
  fi
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
  SUBJECT+="[ZFS pool health warning]"
fi
# Check for drive errors on ONLINE VDEVs
VDEVERRORS=`echo "${ZPOOLSTATUSV}" \
| awk '$1 != "state:" && $2 == "ONLINE" && $3 $4 $5 != "000"'`
if [ "$VDEVERRORS" ]; then
  log warning "vdev errors reported"
  SUBJECT+="[vdev errors]"
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
  SUBJECT+="[ZFS pool capacity warning]"
fi

# Show zfs dataset usage
log info "zfs dataset utilisation:\n`sudo zfs list`\n"
log info "zfs non-auto snapshot utilisation:"
log info "`sudo zfs list -rt snapshot | grep -v ${ZFSAUTOSNAPLABEL}`\n"

# End zfs-check
log info "zfs-check finished: `date`"
log info "---------------------------------------------------------------"
if [ "${MAILNOTIFY}" ]; then
  mail_report "${SUBJECT}"
fi
write_log
