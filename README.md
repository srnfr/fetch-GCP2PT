# fetch-GCP2PT

Fetch logs from Google Worskpaces Audit and send them to a custom syslog server.
The script includes a logic not to send previously sent logs.

Requirements : You need a working "gcloud" and "jq"


You must create a config file named "fetch-GCP2PT.conf" located in your $HOME dir with the following content (to be customized) :

>fresh="1h" <= will just retrieve logs fresher than this
>
>organization=1234567890 <= whatever Google GCP org
>
>syslogsrv="my.syslogsrv.com" <= your syslog server
>
>syslogport=1514 <= TCP SSL Port the syslog srv is listening to
>

