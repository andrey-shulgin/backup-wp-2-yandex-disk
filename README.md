## Bash script for automatic backup/restore WP site to Yandex.Disk

### Description

This script allow to backup your website data (files/DB) on daily basis (via CRON) to [Yandex.Disk](https://disk.yandex.ru) and restore data, if needed, from console. Data combined by sitename and weeks (for example `sitename/01.01-06.01/` and `/sitename/07-01/`). It also support automatic removal of expired data (configurated amount ow weeks) to keep your disk clean. All credentials getting from `wp-config.php`.

### Requirements
- Ubuntu
- CURL

### How it works
Script supports following actions:
- Backup whole wp-content/uploads directory (excluding any amount of directories)
- Backup today wp-content/uploads files only (to keep normal size of your backup)
- Backup database
- Delete expired data from server
- Restore database
- Restore files


### Usage
1. Clone `backup.sh` to your root WP directory
2. Make executable `chmod +x backup.sh`
3. Add Yandex.Disk credentials to your `wp-config.php` and define `WP_HOME` (this variable using for Yandex.Disk folder structure. If you don't want to set this variable, you must set `SITENAME=""` variable in `backup.sh`)

```
define( 'YA_USER', '' );
define( 'YA_PASS', '' );
define( 'YA_FILES_FOLDER', 'files' );
define( 'YA_DB_FOLDER', 'db' );
```
4. Change `OFFSET=2`, if you need to keep data more than 2 weeks
5. Add cron job with supported params `0 10 * * 1 cd /var/www/DOCUMENT_ROOT/ && sh backup.sh [param1 param2 param 3]`

### CLI
```markdown

# Usage:

    sh backup.sh [param1 param2 param 3]

# Params:

    db            : Backup database
    files         : Backup current day files from wp-content/uploads
    fullbackup    : Backup whole wp-content/uploads directory
    restorefiles  : Restore files from backup. Download full backup and daily backups of current week and extract to wp-content/uploads. This action must be called from console.
    restoredb     : Restore database from backup. This action must be called from console.
    clearexpired  : Remove expired data (data, which older than `OFFSET` value in weeks)
```

### Notes
This script was tested with total 0.5-1Gb dump sizes. To decrease final full backup archive size, you can exclude folders like cache or import plugins data from archive.

For full backup you can add any amount of exluded folders on line `105` code:

`tar -czf backups/backup.files.full.tar.gz wp-content/uploads`

must be change to:

`tar -czf --exclude='./folder1' --exclude='./folder2' backups/backup.files.full.tar.gz wp-content/uploads`

### Recommendations
* Run full backup once a week on monday morning
* Clear expired data once a week on sunday/monday
* Backup database daily
* Backup files daily
