#!/bin/sh

function log() {
  echo "$(date +"[%d/%b/%Y:%k:%M:%S %z]"): $1"
}
ENVIRONMENT="testenvironment"                                                                           # Name of the cluster
S3PREFIX="test/prefix/$ENVIRONMENT/"                                                 # S3 bucket prefix - NOTE the prefix name must end with / character else AWS CLI creates a file instead of a folder prefix
DBNAME="graylog"                                                                         # Mongodb Database name
BUCKET="testname"                                                                       # S3 bucket name
SLACKURI=""                                                                              # Slack URI
USER=$(whoami)                                                                           # Linux user account
DEST="/home/$USER/tmp"                                                                   # Mongo Backup directory
TIME=$(/bin/date +%d-%m-%Y)                                                              # Current time
HOST=$(hostname)                                                                         # DB host
TAR="$HOST$TIME.tar.gz"                                                                  # Tar file of backup directory                                                              
DESTDUMP="$DEST/$DBNAME"                                                                 # Dump file literal path - need to tar gzip properly.


log "[INFO] Starting Script Run..."  

CHECKMASTER=$(mongo --quiet localhost:27017/$DBNAME --eval "printjson(db.isMaster().ismaster)")

if [ $CHECKMASTER == true ]; then
{

curl -X POST -H 'Content-type: application/json' --data '{"text":"Starting Mongodb backup on host: '$HOST'"}' $SLACKURI

log "[INFO] Environment name is: [$ENVIRONMENT]"  

log "[INFO] Mongodb Database name to backup is: [$DBNAME]"  

log "[INFO] S3 bucket the backup will be stored in is: [$BUCKET]" 

log "[INFO] Linux user account is: [$USER]"  

log "[INFO] S3 bucket prefix that the backup tar is stored in: [$S3PREFIX]" 

log "[INFO] Local Mongodump directory: [$DEST]"

log "[INFO] Tar file that will be created: [$TAR]" 

# Ensuring s3 bucket has the proper folder structure exist - if already exist nothing is done.
/usr/bin/aws s3api put-object --bucket $BUCKET --key $S3PREFIX 
RESPONSE=$?
if [ $RESPONSE -ne 0 ]; then
  log "[ERROR] Unable to create s3 prefix [$S3PREFIX]. Check AWS User permissions to S3 Bucket." 
  curl -X POST -H 'Content-type: application/json' --data '{"text":"Unable to create s3 prefix '$S3PREFIX' from host:'$HOST'"}' $SLACKURI
  exit 1
else
  log "[INFO] Successfully created s3 prefix: [$S3PREFIX]" 

fi

# Create backup dir
/bin/mkdir -p $DEST
RESPONSE=$?
if [ $RESPONSE -ne 0 ]; then
  log "[ERROR] Unable to create backup directory [$DEST]. Check [$USER] permission" 
  curl -X POST -H 'Content-type: application/json' --data '{"text":"Unable to create backup directory '$DEST' on host: '$HOST'"}' $SLACKURI
  exit 1
else
  log "[INFO] Created backup dir [$DEST]." 
fi

# Dump from mongodb host into backup directory
/usr/bin/mongodump -h $HOST -d $DBNAME -o $DEST  
RESPONSE=$?
if [ $RESPONSE -ne 0 ]; then
  log "[ERROR] Unable to mongodump: [$HOST] database [$DBNAME] to [$DEST] destination. Check mongodb logs..." 
  curl -X POST -H 'Content-type: application/json' --data '{"text":"Unable to create mongodump on host: '$HOST'"}' $SLACKURI
  exit 1
else
  log "[INFO] mongodump of: [$HOST] database [$DBNAME] to [$DEST] destination successful."
fi

# Create tar of backup directory
/bin/tar -czf "$DEST/$TAR" -C $DEST $DBNAME
RESPONSE=$?
if [ $RESPONSE -ne 0 ]; then
  log "[ERROR] Unable to tar [$DEST/$DBNAME]."
  curl -X POST -H 'Content-type: application/json' --data '{"text":"Unable to create tar file: '$TAR' of '$DEST'/'$DBNAME' on host: '$HOST'"}' $SLACKURI
  exit 1
else
  log "[INFO] Performed tar operation on [$DEST/$DBNAME] created tar file: [$TAR]."
fi

# Upload tar to s3
/usr/bin/aws s3 cp "$DEST/$TAR" s3://$BUCKET/$S3PREFIX
RESPONSE=$?
if [ $RESPONSE -ne 0 ]; then
  log "[ERROR] Unable to upload tar [$TAR] to s3 bucket [$BUCKET] in prefix [$S3PREFIX]."
  curl -X POST -H 'Content-type: application/json' --data '{"text":"Unable to upload tar file: '$TAR' on host: '$HOST' to s3 bucket '$BUCKET'"}' $SLACKURI
  exit 1
else
  log "[INFO] Uploaded tar: [$TAR] to s3 bucket: [$BUCKET] in prefix: [$S3PREFIX]."
fi

# Remove tar file locally
/bin/rm -f "$DEST/$TAR"
RESPONSE=$?
if [ $RESPONSE -ne 0 ]; then
  log "[ERROR] Unable to remove locally created tar file: [$TAR]."
  curl -X POST -H 'Content-type: application/json' --data '{"text":"Unable to remove local tar file: '$TAR' on host: '$HOST'"}' $SLACKURI
  exit 1
else
  log "[INFO] Removed locally created tar file: [$TAR]."
fi

# Remove dump directory
/bin/rm -rf "$DEST/$DBNAME"
RESPONSE=$?
if [ $RESPONSE -ne 0 ]; then
  log "[ERROR] Unable to remove dump directory [$DEST/$DBNAME]."
  curl -X POST -H 'Content-type: application/json' --data '{"text":"Unable to remove backup directory: '$DEST'/'$DBNAME' on host: '$HOST'"}' $SLACKURI
  exit 1
else
  log "[INFO] Removed dump directory [$DEST/$DBNAME]."
fi

log "[INFO] Ending script run...."
curl -X POST -H 'Content-type: application/json' --data '{"text":"Mongodb backup completed successfully for host: '$HOST' "}' $SLACKURI

}
else
log "$HOST is not a master. Ending Script Run."
fi
exit 0