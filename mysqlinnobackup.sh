#!/bin/bash

DEFCONFIG='/etc/mysql/conf.d/bitrix.cnf'
PASSWD=`cat /root/.mysql`
BACKUP_DIR='/opt/mysql-xtra'
BACKUP_DIR_INC='/opt/mysql-xtra-inc'
THROTTLE='40'
SERVICE_MYSQL='/etc/init.d/mysql'
MYSQL_DATA_DIR='/var/lib/mysql'
MYSQL_USER='mysql'

set -e
ME=`basename $0`
print_help() {
echo "Innobackupex MySQL"
echo
echo "Use: $ME options..."
echo "Argument:"
echo " -a"
echo "   Full Backup"
echo " -b"
echo "   Inc Backup"
echo " -r"
echo "   Restore"
echo
}

full_backup(){
  innobackupex --defaults-file=$DEFCONFIG --password=$PASSWD --no-timestamp --rsync $BACKUP_DIR 2>&1
  innobackupex --apply-log --redo-only --defaults-file=$DEFCONFIG --password=$PASSWD --no-timestamp  --throttle=$THROTTLE $BACKUP_DIR 2>&1
}

inc_backup(){
  if [ `ls -a $BACKUP_DIR | wc -l` -eq 2 ] 
    then
      full_backup
      innobackupex --defaults-file=$DEFCONFIG --password=$PASSWD --no-timestamp --throttle=$THROTTLE --rsync --incremental $BACKUP_DIR_INC --incremental-basedir=$BACKUP_DIR 2>&1
      innobackupex --defaults-file=$DEFCONFIG --password=$PASSWD --no-timestamp --throttle=$THROTTLE --apply-log $BACKUP_DIR --incremental-dir=$BACKUP_DIR_INC 2>&1
    else
      innobackupex --defaults-file=$DEFCONFIG --password=$PASSWD --no-timestamp --throttle=$THROTTLE --rsync --incremental $BACKUP_DIR_INC --incremental-basedir=$BACKUP_DIR 2>&1
      innobackupex --defaults-file=$DEFCONFIG --password=$PASSWD --no-timestamp --throttle=$THROTTLE --apply-log $BACKUP_DIR --incremental-dir=$BACKUP_DIR_INC 2>&1      
  fi
}

restore_db(){
  $SERVICE_MYSQL stop
  mv $MYSQL_DATA_DIR $MYSQL_DATA_DIR.old
  mkdir $MYSQL_DATA_DIR
  innobackupex --defaults-file=$DEFCONFIG --copy-back $BACKUP_DIR
  chown -R $MYSQL_USER:$MYSQL_USER $MYSQL_DATA_DIR
  $SERVICE_MYSQL start
}

restore_inc_db(){
  $SERVICE_MYSQL stop
  mv $MYSQL_DATA_DIR $MYSQL_DATA_DIR.old
  mkdir $MYSQL_DATA_DIR
  innobackupex --defaults-file=$DEFCONFIG --copy-back $BACKUP_DIR
  innobackupex --apply-log --redo-only $BACKUP_DIR --incremental-dir=$BACKUP_DIR_INC
  chown -R $MYSQL_USER:$MYSQL_USER $MYSQL_DATA_DIR
  $SERVICE_MYSQL start
}

if [ $# = 0 ]
  then
    print_help
fi

# разбор аргументов командной строки в позиционные параметры.
set -- `getopt "abcdef" "$@"`
while [ ! -z "$1" ]
do
  case "$1" in
    -a) full_backup;;
    -b) inc_backup;;
    *) break;;
  esac
shift
done
