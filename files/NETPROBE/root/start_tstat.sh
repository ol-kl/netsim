tstat -p -N ./nets.conf -S -L -R ./rrd.conf -r /var/www/databases -l -i vlan40 -E 80 
# add -e option to collect separate ip_bitrate log statistics
# add -3 option to enable ooo_dup.log file, which dumps all results of every coming by packet inspection
