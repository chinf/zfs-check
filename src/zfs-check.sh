#!/bin/sh

# zfs-check - ZFS health check, utilisation logging and alerting
# Copyright (C) 2017 Francis Chin <dev@fchin.com>
#
# Repository: https://github.com/chinf/zfs-check
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
  local LEVEL="$1"
  shift 1
  case $LEVEL in
    (sum*) REPORT="${REPORT}$*\n" ;;
    (inf*) if [ -z "${SUMMARY}" ]; then REPORT="${REPORT}$*\n"; fi ;;
    (war*)
      REPORT="${REPORT}zfs-check warning: $*\n"
      MAILNOTIFY=yes
      ;;
    *)
      REPORT="${REPORT}zfs-check error: $*\n"
      echo "zfs-check error: $*" >&2
      MAILNOTIFY=yes
      ;;
  esac
}

mail_report() { # email subject
  if [ "${EMAIL}" ]; then
    echo "${REPORT}" | mail -r "zfs-check@`uname -n`" \
      -s "zfs-check on `uname -n`:$*" "${EMAIL}"
  fi
}

write_log() {
  if [ "${LOG}" ]; then
    # Append to log file if it already exists, otherwise create it
    echo "${REPORT}" >> "${LOG}"
  else
    echo "${REPORT}" >&1
  fi
}

#
# Options
#
readonly DEFAULTLOG="/var/log/zfs-check.log"
MAXCAPACITY=80
readonly ZFSAUTOSNAPLABEL="zfs-auto-snap_"

print_usage() {
  echo "Usage: $0 [options] [-l|-L LOGFILE]
Use ZFS utilities to log the health and status of all mounted pools, and
optionally alert via email if there are any warnings.

  -c CAPACITY  Use a zpool utilisation upper limit of CAPACITY% instead
               of the default upper limit ${MAXCAPACITY}%.

  -d           Show ZFS dataset (filesystem and snapshot) usage.

  -m ADDRESS   Email warnings to ADDRESS.  Repeat to specify multiple
               email addresses.

  -n           No pools alert. If no pools are available on the host,
               trigger an email warning if the -m option is set.

  -s           Summary mode.  Overrides -d.

  -l           Instead of sending output to STDOUT, append to a log at
               the default location ${DEFAULTLOG}

  -L LOGFILE   Append output to LOGFILE instead of STDOUT. 
" >&2
exit 2
}

while getopts ":c:dm:nslL:" OPT; do
  case "${OPT}" in
    c)
      if [ "${OPTARG}" ]; then
        MAXCAPACITY="${OPTARG}"
      else
        print_usage
      fi
      ;;
    d) DATASET=show ;;
    m)
      if [ "${OPTARG}" ]; then
        EMAIL="${EMAIL} ${OPTARG}"
      else
        print_usage
      fi
      ;;
    n) NOPOOLS=warn ;;
    s) SUMMARY=yes ;;
    l) LOG="${DEFAULTLOG}" ;;
    L) LOG="${OPTARG}" ;;
    *) print_usage ;;
  esac
done

#
# Configuration validation
#
if [ "${LOG}" ]; then
  if [ ! -w "${LOG}" ]; then
    log error "Log file ${LOG} cannot be written to."
    mail_report "Error: cannot write to log"
    exit 1
  fi
fi

#
# main()
#
log summary "zfs-check started: `date`\n"

# Show general zpool status and configuration
ZPOOLSTATUSV=`sudo zpool status -v`
if [ "${ZPOOLSTATUSV}" = "no pools available" ]; then
  if [ "${NOPOOLS}" ]; then
    log warning "No pools available"
    mail_report " [no ZFS pools available]"
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
  SUBJECT="${SUBJECT} [ZFS pool health warning]"
fi
# Check for drive errors on ONLINE VDEVs
VDEVERRORS=`echo "${ZPOOLSTATUSV}" \
| awk '$1 != "state:" && $2 == "ONLINE" && $3 $4 $5 != "000"'`
if [ "$VDEVERRORS" ]; then
  log warning "vdev errors reported"
  SUBJECT="${SUBJECT} [vdev errors]"
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
  SUBJECT="${SUBJECT} [ZFS pool capacity warning]"
fi

if [ "${DATASET}" ]; then
  # Show zfs dataset usage
  log info "zfs dataset utilisation:\n`sudo zfs list`\n"
  log info "zfs non-auto snapshot utilisation:"
  log info "`sudo zfs list -rt snapshot | grep -v ${ZFSAUTOSNAPLABEL}`\n"
fi

# End zfs-check
log info "zfs-check finished: `date`"
log info "---------------------------------------------------------------"
if [ "${MAILNOTIFY}" ]; then
  mail_report "${SUBJECT}"
fi
write_log
