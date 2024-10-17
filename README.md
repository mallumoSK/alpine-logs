# Custom logger, which read from one or more inputs into on file
- Be careful => input file will we wiped

## INSTALL
```shell
wget https://raw.githubusercontent.com/mallumoSK/alpine-logs/refs/heads/main/logs.sh -O /usr/bin/logs && chmod +x /usr/bin/logs
/usr/bin/logs
```
## Logic: 
1. read line from input file
2. delete line from input file
3. write line to output file
4. delete overflow lines from output file

# ARGS:
## Required WATCHER arguments: --watcher, -i
## Required READER arguments: --reader

-  -w, --watcher  work mode as watcher, etc. --watcher alias-name
-  -r, --reader reader mode as reader, etc. --reader alias-name
-  -i, --input  path to input file
-  -p, --prefix line prefix for output file, etc. I (info), E (error) ..., default 'I'
-  -l, --lines  how many lines are cached, default 1000
-  -s, --stream stream mode for reader

-  -ws, --watcher-service 	 create setvice, whitch will be run in background

# Example
## WATCHER:
```shell
logs --watcher sample -i /var/log/server.log
```
## READER:
```shell
logs --reader sample
#or
logs --reader sample --stream
```

## Watcher service:
If sample service has 2 outputs
- /var/log/sample.log
- /var/log/sample.err
  
These 2 logs will join files 'sample.log' and 'sample.err' into one output

```shell
logs --watcher-service sample \ 
 -i /var/log/sample.log \ 
 -p "I" \ 
 -l 1000 

logs --watcher-service sample \ 
 -i /var/log/sample.err \ 
 -p "E" \ 
 -l 1000 

# SEE LOGS 
logs -r sample

# SEE LOGS LIVE
logs -r sample --stream
```

