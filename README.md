# qBittorrent-speed-limit
Toggle qBittorrent alternative limit setting when total data transferred exceeds threshold.
Customizations are configured in the constants in `qbt-speed-limit.sh` 

The `--save` parameter should be used at the beginning of each data interval.  Ex: if the desired cap is 30GB per day, run `qbt-speed-limit.sh --save` daily and customize `XFRMAX` within `qbt-speed-limit.sh` to reflect 30GB

### Example scheduling with `/etc/crontab`
```
# at 1:20AM daily save the current number of total QBT bytes transferred to file
20 1 * * *   qbtUser    sh ~/qbt-speed-limit.sh --save

# every 15 minutes check if data limit has been exceeded
*/15 * * * *   qbtUser    sh ~/qbt-speed-limit.sh
```
