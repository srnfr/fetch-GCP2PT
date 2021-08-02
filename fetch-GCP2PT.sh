#!/bin/bash
ver="0.92"
# author=srn

#-------
debug=1
iddir="$HOME/insertid"  ## default storage dir

[ $debug == 1 ] && echo "------- Version: $ver ---"
[ $debug == 1 ] && echo "-------"

if [ ! -f "$HOME"/fetch-GCP2PT.conf ]; then 
	echo "$HOME/fetch-GCP2PT.conf non-existant!"
      	printf "Create a key=value pair config file with the following keys :\n"
	printf " fresh,\n organization,\n syslogsrv,\n syslogport.\n" 
	printf "Exiting..\n"
	exit 1
fi
##source "$HOME/fetch-GCP2PT.conf" 
. "$HOME/fetch-GCP2PT.conf" 
#------

# test if "jq" installed
if ! which jq &> /dev/null
then
    echo "jq could not be found. Please install it."
    exit
fi
[ $debug == 1 ] && jq --version
[ $debug == 1 ] && echo "-------"


# config file test
if [ -z ${fresh+x} ]; then echo "Exiting: var fresh is unset" ; exit 1; else [ $debug == 1 ] &&  echo "fresh is set to '$fresh'"; fi
if [ -z ${organization+x} ]; then die echo "Exiting: var organization is unset";  exit 1; else [ $debug == 1 ] && echo "organization is set to '$organization'"; fi
if [ -z ${syslogsrv+x} ]; then die echo "Exiting: var syslogsrv is unset"; exit 1; else [ $debug == 1 ] && echo "syslogsrv is set to '$syslogsrv'"; fi
if [ -z ${syslogport+x} ]; then die echo "Exiting: var syslogport is unset"; exit 1; else [ $debug == 1 ] && echo "syslogport is set to '$syslogport'"; fi

# test if gcloud is working and authenticated
[ $debug == 1 ] && echo "-------"
[ $debug == 1 ] && gcloud --version
[ $debug == 1 ] && echo "-------"
[ $debug == 1 ] && gcloud auth list
if [ ! $(gcloud auth list --format=json | jq -r ".[].status") == "ACTIVE" ] ; then
	echo "Gcloud not working. Fix it first !"
	exit 1;
fi

# create dir if not exists
mkdir -p "$iddir"

# fetching logs from GCP and testing JSON validity
gcloud logging read "resource.type=\"audited_resource\"" --organization="$organization" --freshness="$fresh" --format json > "$iddir"/gcp.log

if jq empty "$iddir"/gcp.log; then
  [ $debug == 1 ] &&  echo "JSON from GCP is valid"
else
  echo "JSON from GCP is invalid, exiting..."
  exit
fi

[ $debug == 1 ] &&  echo "Now parsing the logs bulk... "
if [ -s "$iddir"/gcp.log ]; then
	cat "$iddir"/gcp.log | jq -Mc > "$iddir"/logGCP.json.lst
else
	[ $debug == 1 ] && echo "Bulk log file exmpty. Now exiting"
	exit
fi

# parsing the logs
i=0
for f in $( jq -r '.[].insertId' "$iddir"/logGCP.json.lst) ; do 
	i=$((i+1))
        [ $debug == 1 ] && printf "%s:\n  Id fetched: $f" $i;
        if [ ! -f "$iddir/$f.json.old" ] ; then
                ## nouveau, n a pas deja ete envoye
                [ $debug == 1 ] && echo "  $iddir/$f.json.old not found => $f is a new InsertID!"
                jq -cM ".[] | select (.insertId==\"$f\")" "$iddir"/logGCP.json.lst > "$iddir"/"$f".json
        else
                [ $debug == 1 ] && echo "  Skipping; $iddir/$f.json.old already existing."
        fi
	[ $debug == 1 ] && echo "------------------"
done
[ $debug == 1 ] && echo "Parsing done."

# Sending only the new logs
shopt -s nullglob
i=0
for full in "$iddir"/*.json; do
	i=$((i+1))
        [ $debug == 1 ] &&  printf "%s:\n  Selecting f = $full" $i
        [ $debug == 1 ] && echo -n "  Sending $full to papertrail...."
        ncat --ssl "$syslogsrv" "$syslogport" < "$full"
        [ $debug == 1 ] && echo "done."
        filename=$(basename "$full")
        [ $debug == 1 ] && echo "  New target filename $filename"
        mv "$iddir"/"$filename" "$iddir"/"$filename".old
        [ $debug == 1 ] && echo "  Just renamed $full to $filename.old"
	[ $debug == 1 ] && echo "------------------"
done

# Delete older than +5 days files
find "$iddir" -type f -name "*.json.old" -mtime +5 -exec rm {} \;
