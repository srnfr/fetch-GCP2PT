#!/bin/bash
# ver=0.8
# author=srn

#-------
debug=0
iddir="$HOME/insertid"  ## default storage dir
[ -f "$HOME"/fetch-GCP2PT.conf ] || die echo "$HOME/fetch-GCP2PT.conf non-existant !"
source "$HOME/fetch-GCP2PT.conf" 
#------

# config test
if [ -z ${fresh+x} ]; then echo "Exiting: var fresh is unset" ; exit 1; else [ $debug == 1 ] &&  echo "fresh is set to '$fresh'"; fi
if [ -z ${organization+x} ]; then die echo "Exiting: var organization is unset";  exit 1; else [ $debug == 1 ] && echo "organization is set to '$organization'"; fi
if [ -z ${syslogsrv+x} ]; then die echo "Exiting: var syslogsrv is unset"; exit 1; else [ $debug == 1 ] && echo "syslogsrv is set to '$syslogsrv'"; fi
if [ -z ${syslogport+x} ]; then die echo "Exiting: var syslogport is unset"; exit 1; else [ $debug == 1 ] && echo "syslogport is set to '$syslogport'"; fi


# create dir if not exists
mkdir -p "$iddir"

# fetching logs form GCP
gcloud logging read "resource.type=\"audited_resource\"" --organization="$organization" --freshness="$fresh" --format json | jq -Mc > "$iddir"/logGCP.json.lst

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

# sending only the new logs
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

##Nettoyage des fichiers .old de +5 jours
find "$iddir" -type f -name "*.json.old" -mtime +5 -exec rm {} \;
