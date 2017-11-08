#!/usr/bin/env bash

echo "Running mongo-s3-cron-backup-restore version 0.2"

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
  echo "AWS_ACCESS_KEY_ID must be set"
  HAS_ERRORS=true
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  echo "AWS_SECRET_ACCESS_KEY must be set"
  HAS_ERRORS=true
fi

if [ -z "$S3BUCKET" ]; then
  echo "S3BUCKET must be set"
  HAS_ERRORS=true
fi

if [ $HAS_ERRORS ]; then
  echo "Exiting.... "
  exit 1
fi


if [ -z "$FILEPREFIX" ]; then
  FILEPREFIX='mongo'
fi

if [ -z "$MONGO_HOST" ]; then
  MONGO_HOST="mongodb"
fi

if [ -z "$MONGO_PORT" ] ; then
  MONGO_PORT="27017"
fi

if [[ -n "$DB" ]]; then
  DB_ARG="--db $DB"
fi

FILENAME=$FILEPREFIX.latest.tar.gz

if [ "$1" == "backup" ] ; then
  echo "Starting backup (v4) ... $(date)"
  echo "mongodump --quiet -h $MONGO_HOST -p $MONGO_PORT $DB_ARG $DUMP_ARGS"
  mongodump -h $MONGO_HOST -p $MONGO_PORT $DB_ARG $DUMP_ARGS
  ls
  if [ -d dump ] ; then
      tar -zcvf latest.tar.gz dump/
      echo "s3api put-object --bucket $S3BUCKET --key $FILENAME --body latest.tar.gz"
      aws s3api put-object --bucket $S3BUCKET --key $FILENAME --body latest.tar.gz
      echo "Cleaning up..."
      rm -rf dump/ latest.tar.gz
  else
      echo "No data to backup"
  fi
  exit 0
fi


if [ "$1" == "restore" ] ; then
    echo "Restoring latest backup"
    echo "aws s3api get-object --bucket $S3BUCKET --key $FILENAME latest.tar.gz"
    aws s3api get-object --bucket $S3BUCKET --key $FILENAME latest.tar.gz
    if [ -e latest.tar.gz ] ; then
        tar zxfv latest.tar.gz
        mongorestore --drop -h $MONGO_HOST -p $MONGO_PORT $RESTORE_ARGS dump/
        echo "Cleaning up..."
        rm -rf dump/ latest.tar.gz
    else
        echo "No backup to restore"
    fi
    exit 0
fi

CRON_SCHEDULE=${CRON_SCHEDULE:-0 3 * * *}

LOGFIFO='/var/log/cron.fifo'
if [[ ! -e "$LOGFIFO" ]]; then
    touch "$LOGFIFO"
fi

CRON_ENV="MONGO_HOST='$MONGO_HOST'"
CRON_ENV="$CRON_ENV\nMONGO_PORT='$MONGO_PORT'"
CRON_ENV="$CRON_ENV\nAWS_ACCESS_KEY_ID='$AWS_ACCESS_KEY_ID'"
CRON_ENV="$CRON_ENV\nAWS_SECRET_ACCESS_KEY='$AWS_SECRET_ACCESS_KEY'"
CRON_ENV="$CRON_ENV\nS3BUCKET='$S3BUCKET'"
CRON_ENV="$CRON_ENV\nDB='$DB'"
CRON_ENV="$CRON_ENV\nPATH=$PATH"
CRON_ENV="$CRON_ENV\nDUMP_ARGS='$DUMP_ARGS'"
CRON_ENV="$CRON_ENV\nRESTORE_ARGS='$RESTORE_ARGS'"
CRON_ENV="$CRON_ENV\nFILEPREFIX=$FILEPREFIX"

echo -e "$CRON_ENV\n$CRON_SCHEDULE /entrypoint.sh backup > $LOGFIFO 2>&1" | crontab -
crontab -l
cron
tail -f "$LOGFIFO"
