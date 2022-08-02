This cleans synapse's history, automating (and fixing) some bits from 
[https://levans.fr/shrink-synapse-database.html](https://levans.fr/shrink-synapse-database.html). 

This does *not* do anything with the PG database.

# Get your API key
- in element - settings, help and about, scroll down to advanced to get your access token

You have three options for storing this, used in this order of precedence:

* hardcoded API key into script
* $XDG_CONFIG_HOME/synapse_apikey
```
API_KEY=your_access_token
HOMESERVER=https://your.homeserver.url
```    
* as commandline arguments, so:  
`clean_synapse.sh API_ID=your_access_token HOMESERVER=homeserverurl`

If you have busy rooms (such as IRC rooms or RSS feeds) where you want a shorter 
history, get their full room ids and save them in a file `busy_rooms.cfg` in the 
script directory. The format is:
```
"!firstroom:faithcollapsing.com"
"!secondroom:faithcollapsing.com"
"!thirdroom:libera.chat"
```

By default, only one day of history is kept in these rooms. That length is configured 
in the script at this point (around line 58):
`ts=$(( $(date --date="1 days ago" +%s)*1000 ))`

All other rooms have one month of history retained.  That is configured in the 
script at this point (around line 75):
`ts=$(( $(date --date="1 month ago" +%s)*1000 ))`

#TODO:

* command to just pull full roomlist
* maybe use fzf to select "busy rooms" or rooms to clean on a PRN basis
