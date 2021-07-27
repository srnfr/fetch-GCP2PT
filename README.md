# fetch-GCP2PT
Fetch logs from Google Worskpaces Audit and send them to custom syslog

PS : You need a working "gcloud"


You must create a conf dir named "fetch-GCP2PT.conf"  located in your $HOME with the custom content

>fresh="1h"
>
>organization=1234567890 <= whatever Google GCP org
>
>syslogsrv="my.syslogsrv.com"
>
>syslogport=1514 <= TCP SSL Port the syslog srv is listening to
>

