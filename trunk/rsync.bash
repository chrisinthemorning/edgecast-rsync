#!/bin/sh
set +e
rm -rf /tmp/rsync.ec.out
rm -rf /tmp/changedfiles

#move to directory so path names are good in outputs
cd /opt/www/htdocs/

#find recently modified files
find  . -cmin -20 > /tmp/changedfiles

echo "Starting:" >>  /tmp/ec.log

date >>  /tmp/ec.log
echo "Files changed:" `wc -l /tmp/changedfiles >> /tmp/ec.log`

#run rsync for these changed files, only changing existing files and logging output
/usr/bin/rsync --itemize-changes -az --existing  -e "ssh -i /home/rsync/.ssh/rsync_edgecast_id_rsa  -p8022 -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no" --files-from=/tmp/changedfiles /opt/www/htdocs/  rsyncuser@yourdomain.com@rsync.ams.edgecastcdn.net:/content/htdocs/ > /tmp/rsync.ec.out
cat /tmp/rsync.ec.out >> /tmp/ec.log
#loop through output so we can purge changed files
for filetopurge in `grep "^<f" /tmp/rsync.ec.out | cut -d " " -f2`; do
        if [ -f $filetopurge ]
                then
                ecresponse=$(echo '<MediaContentPurge xmlns="http://www.whitecdn.com/schemas/apiservices/"><MediaPath>http://wpc.007.edgecastcdn.net/00007/content/htdocs/'$filetopurge'</MediaPath><MediaType>3</MediaType></MediaContentPurge>' |  curl --insecure -X PUT  -H "Authorization: TOK:e034fba5-7c45-4fcd-a018-752eb1229203" -H 'Content-type: text/xml' -d @- https://api.edgecast.com/v2/mcc/customers/007/edge/purge --write-out %{http_code} --silent)
                if [ $ecresponse == 200 ]
                then
                        echo -e "Purged ${filetopurge}"  >>  /tmp/ec.log
                else
                        sleep 15
                        ecresponse2=$(echo '<MediaContentPurge xmlns="http://www.whitecdn.com/schemas/apiservices/"><MediaPath>http://wpc.007.edgecastcdn.net/00007/content/htdocs//'$filetopurge'</MediaPath><MediaType>3</MediaType></MediaContentPurge>' |  curl --insecure -X PUT  -H "Authorization: TOK:mytoken" -H 'Content-type: text/xml' -d @- https://api.edgecast.com/v2/mcc/customers/007/edge/purge --write-out %{http_code} --silent)
                        if [ $ecresponse2 == 200 ]
                        then
                                echo -e "Purged ${filetopurge} on retry"  >>  /tmp/ec.log
                        else
                                echo -e "Failed to purge ${filetopurge} - code $(ecresponse2)"  >>  /tmp/ec.log
                        fi
                fi
        fi
done

#now run rsync for remainder of files
/usr/bin/rsync -azv --ignore-existing  -e "ssh -i /home/rsync/.ssh/rsync_edgecast_id_rsa  -p8022 -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no" --files-from=/tmp/changedfiles /opt/www/htdocs/  rsyncuser@yourdomain.com@rsync.ams.edgecastcdn.net:/content/htdocs/

echo "Finished: " >>  /tmp/ec.log
date >>  /tmp/ec.log
