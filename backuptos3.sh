#!/bin/sh

function log() {
  echo "$(date +"[%d/%b/%Y:%k:%M:%S %z]"): $1"
}

function usage() {
  echo "USAGE: ${BASH_SOURCE[0]} ..."
  echo "   -e Set name of environment app is associated with"
  echo "   -a Name of application being backed up"
  echo "   -s Source to be backed up"
  echo "   -b S3 bucket name where tar file will be uploaded to "
 
}

while getopts e:a:s:b: flag; do
  case "$flag" in
    e)
      ENVIRONMENT="$OPTARG"
      echo "Environment is $ENVIRONMENT"
      ;;
    a)
      APP_NAME="$OPTARG"
      echo "App Name is $OPTARG"
      ;;
    s)
      SOURCE="$OPTARG"
      echo "Source directory to backup is $OPTARG"
      ;;
    b)
      BUCKET="$OPTARG"    
      echo "S3 Bucket backup is uploaded to is $OPTARG"
      ;;
  esac
done

for arg in ENVIRONMENT APP_NAME SOURCE BUCKET; do
  if [[ -z "${!arg}" ]]; then
    echo "Missing required argument for ${arg}"
    usage
    exit 1
  fi
done

S3PREFIX="$APP_NAME/$ENVIRONMENT/"                                                       # S3 bucket prefix - NOTE the prefix name must end with / character else AWS CLI creates a file instead of a folder prefix
USER=$(whoami)                                                                           # Linux user account
DEST="/home/$USER/$APP_NAME/$ENVIRONMENT/"                                               # Backup directory
TIME=$(/bin/date +%d-%m-%Y)                                                              # Current time
TAR="$APP_NAME-$TIME.tar.gz"                                                              # Tar file of backup directory                                                              


log "[INFO] Starting backup script Run..."  

log "[INFO] Environment name is: [$ENVIRONMENT]"  

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
  exit 1
else
  log "[INFO] Successfully created s3 prefix: [$S3PREFIX]" 

fi

# Create backup dir
/bin/mkdir -p $DEST
RESPONSE=$?
if [ $RESPONSE -ne 0 ]; then
  log "[ERROR] Unable to create backup directory [$DEST]. Check [$USER] permission" 
  exit 1
else
  log "[INFO] Created backup dir [$DEST]." 
fi


# Create tar file of source
/bin/tar -czf "$DEST/$TAR" $SOURCE
RESPONSE=$?
if [ $RESPONSE -ne 0 ]; then
  log "[ERROR] Unable to tar [$DEST/$TAR]."
  exit 1
else
  log "[INFO] Created tar file: [$DEST/$TAR] from source: $SOURCE."
fi

# Upload tar to s3
/usr/bin/aws s3 cp "$DEST/$TAR" s3://$BUCKET/$S3PREFIX
RESPONSE=$?
if [ $RESPONSE -ne 0 ]; then
  log "[ERROR] Unable to upload tar [$TAR] to s3 bucket [$BUCKET] in prefix [$S3PREFIX]."
  exit 1
else
  log "[INFO] Uploaded tar: [$TAR] to s3 bucket: [$BUCKET] in prefix: [$S3PREFIX]."
fi

# Remove tar file locally
/bin/rm -f "$DEST/$TAR"
RESPONSE=$?
if [ $RESPONSE -ne 0 ]; then
  log "[ERROR] Unable to remove locally created tar file: [$TAR]."
  exit 1
else
  log "[INFO] Removed locally created tar file: [$DEST/$TAR]."
fi

log "[INFO] Ending script run...."


exit 0