Description
==============

This script will take a mongodump of the specified mongodb database. It will then copy the dump to an s3 bucket. 
It will also send a status update for when the script is ran to the room that is connected to the **SLACKURI** that you provide.
Be sure to run this script as root.

Usage
==============

1. Install awscli. - `apt-get install awscli`
2. Create an s3 bucket. - Add a lifecycle rule to expire files after a specified time.
3. Create a user that has access to add files to s3 bucket.
4. Configure awscli with a user with access to your s3 bucket. - `aws configure`
5. Add the environment to the `ENVIRONMENT` variable in script.
6. Add the prefix you want in the `S3PREFIX` variable.
7. Add the name of your s3 bucket in the `BUCKET` variable.
8. Create a new webhook in your slack and assign it to a channel you want to receive alerts on. Add the webhook URL to the `BUCKET` variable.
9. Make the script executable. - `chmod +x /path/to/script/mongobackup.sh`
10. Setup a cron with `crontab -e` to a backup period you want. For example, if you want this script to run everynight at 11pm,
set your cron settings to `0 23 * * * /path/to/script/mongobackup.sh`. If you want to have the scripts log to a file when it runs then do `0 23 * * * /path/to/script/mongobackup.sh >> /path/to/log/logfile.log 2>&1`. You will need to make sure the directory you want to store the log file in exists already.

Requirements
==============

awscli 


