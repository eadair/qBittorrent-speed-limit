# qBittorrent-mgmt
Toggle qBittorrent alternative limit setting when total data transferred exceeds threshold.
Download and update tracker list in qBittorrent.

Parameters are defined in `qbt_limits.sh`
The `-save` parameter should be used at the beginning of each data interval.  Ex: if the desired cap is 30GB per day, run `qbt-limits.sh -save` daily and use the parameter `-threshold_bytes 30GB`

### Example scheduling with `crontab -e`
```
# at 2:00AM daily save the current number of total QBT bytes transferred to file
0 2 * * * $HOME/qbt_limits.sh -save

# every 15 minutes check if data limit (15GB) has been exceeded
*/15 0,2-23 * * * $HOME/qbt_limits.sh -threshold_bytes 15GB

# on Sunday at 155AM update the tracker list
55 1 * * 0 $HOME/qbt_trackers.sh 
```
