# Deployment Assignment: Laravel Guestbook on Two Servers

**Student:** Haroon Bacha
**Repository:** https://github.com/HaroonIMS/Laravel_Deployment
**Live site:** http://guests-books.duckdns.org

## 1. Environment

| Server | EC2 name | Role | Private IP |
|---|---|---|---|
| app-vm | devops for laravel | Nginx, PHP-FPM, Laravel, backups, log cleanup | 172.31.45.87 |
| db-vm | mysql for database | MySQL 8.4 | 172.31.38.213 |

Both servers run Ubuntu 26.04 LTS, but the brief specifies 24.04. [Instructor approval: fill in.] The commands in this report work on either version; the PHP-FPM socket here is `php8.5-fpm.sock`.

The domain is a free DuckDNS name. The name `guest-book` was already taken, so I used `guests-books`.

## 2. Task 1: Deploy on one server

**What I did:** Installed Nginx, PHP-FPM, MySQL, and Composer on app-vm. Created a database and a MySQL user that can only connect from 127.0.0.1. Set `APP_ENV=production` and `APP_DEBUG=false`, and set `APP_URL` to the domain. Locked `.env` to mode 640, owned by `deploy:www-data`. Added an Nginx catch-all server that drops requests for any other host.

**Why:** [Explain in your own words why the production settings, the app-only database user, and the catch-all server matter.]

**Evidence:**
- Screenshot: browser showing guestbook entries at the domain
- `curl -i http://guests-books.duckdns.org/health` returns `200 OK` with body `OK`
- `curl -i http://3.106.141.223/` returns `Empty reply from server`

**Problems and fixes:**
- The Laravel template defaulted to SQLite and the local environment. I replaced those values with MySQL and production settings.
- Saving entries failed with a mass-assignment error. The model lacked `$fillable`, so I added it.
- Closure routes break `route:cache`, so the health check uses a controller.

## 3. Task 2: Move the database to db-vm

**What I did:** Installed MySQL on db-vm and bound it to its private IP. Created `guestbook_app` for `172.31.45.87` only. Copied the data with `mysqldump` piped into the remote server, switched `.env` to `172.31.38.213`, then stopped and disabled MySQL on app-vm. In AWS, the database's MySQL rule accepts only the app server's security group.

**Why:** [Explain in your own words why the database should accept connections only from the app server.]

**Evidence:**
- Row counts matched on both servers before local MySQL was stopped
- `systemctl is-enabled mysql` on app-vm prints `disabled`
- From a laptop outside AWS, port 3306 on the database server prints `BLOCKED`

**Problems and fixes:**
- The launch wizard had opened port 3306 to `0.0.0.0/0`. I removed that rule and referenced the app server's security group instead.
- MySQL's password policy rejected weak passwords. I used longer ones.

## 4. Task 3: Deploy with GitHub Actions

**What I did:** Created a read-only deploy key for the server to read the private repository. Created a separate key pair for GitHub Actions and stored its private key as a secret. Added a sudoers rule that lets `deploy` reload only PHP-FPM. The workflow runs on every push to `main` and can be started manually. A concurrency group prevents parallel deploys. The deploy script fetches the code, runs `composer install`, runs migrations, rebuilds the caches, reloads PHP-FPM, and then the workflow checks `/health`.

**Updates:**
- **Update 1:** Changed the page heading and pushed. The change appeared without logging in to a server. Screenshot: green run and new heading.
- **Update 2:** Added an `author` column with a migration. The deploy ran the migration, and a new entry saved its author. Screenshot: the `DESCRIBE` output and the saved row.
- **Broken update:** Pushed a syntax error in `HealthController.php`. The run failed at `composer install` with `syntax error, unexpected token "->"`. While the run was red, the health check and homepage returned `500`. I fixed it with `git revert`, and the health check returned `200 OK`.

**Problems and fixes:**
- The deploy resets the server to GitHub (`git reset --hard`). That overwrote a routes change I had edited directly on the server. From then on, all changes went through Git.
- The personal access token needed both Contents and Workflows permissions.

## 5. Task 4: Backups and disaster drill

**What I did:** Created `backup_ro` on the database server with only `SELECT`, `SHOW VIEW`, `TRIGGER`, and `EVENT` on `guestbook`. Stored its password in `/home/backup/.my.cnf` with mode 600, so it isn't in the script or the process list. An hourly cron job runs `backup-db.sh` as `backup`. Each dump is written to a `.partial` file, checked with `gzip -t` and the `Dump completed` line, then renamed. Failed dumps are deleted and logged. Backups older than 7 days are deleted.

**Tests:**
- Failure test: a dump of a missing database exited with code 1, created no file, and logged an `ERROR` line.
- Retention test: [result from Step 1].

**Drill (UTC, 1 November 2026):**

| Time | Event |
|---|---|
| 13:04:15 | Backup taken. Contains rows 1–5. |
| after 13:04 | Row 6, "Written after the backup", added |
| 13:12 | Database server stopped |
| 13:12:51 | Health check returns `500` |
| [time] | Backup restored to app-vm local MySQL; health check returns `OK` |
| [time] | Outage entry copied back to db-vm; counts match at 6 rows; health check returns `OK` |

- **Downtime:** about [X] minutes.
- **Data lost:** row 6, written after the last backup.
- **Data kept:** rows 1–5 from the backup, plus the outage entry, which was written locally and then copied back.

**Problems and fixes:**
- The backup user's password didn't match the database. I reset it on the database server.
- A wildcard in a `sudo ls` command was expanded by the wrong user. I used `sudo sh -c` instead.
- After the database server started again, MySQL needed a short time before accepting connections.

**Caveat:** Stopping an instance keeps its disk, so the lost row could be recovered from it. A real disk failure would lose it permanently. The drill tests recovery from the backup.

## 6. Task 5: Log cleanup

**What I did:** Set `LOG_CHANNEL=daily` and `LOG_DAILY_DAYS=30` in `.env`. `scripts/clean-logs.sh` compresses `laravel-*.log` files older than one day and never touches today's file. It deletes compressed logs older than 14 days. It writes a warning to its own log if `storage/logs` is larger than 500 MB. Cron runs it nightly at 02:30.

**Tests:**
- Fake files 3 days and 20 days old, plus `keep-me.txt`. The first run compressed the 3-day file, deleted the 20-day `.gz`, and left `keep-me.txt` and today's log alone. The second run changed nothing.
- Size warning: [result from Step 1].

**System logs:** Ubuntu runs `logrotate.timer` daily. The nginx configuration rotates `/var/log/nginx/*.log` daily, keeps 14 copies, and compresses them. MySQL has its own rotation in `/etc/logrotate.d/mysql-server`.

## 7. Security

- Port 22 on app-vm is open to `0.0.0.0/0`, so GitHub Actions can connect. Password login and root login are disabled, and the deploy user has only the one sudo permission it needs. A further step would be to restrict the source to GitHub's published IP ranges or add fail2ban.
- MySQL accepts connections only from the app server's security group.
- No passwords, keys, or `.env` files are in the repository or this report.

## 8. Limitations and next steps

- The deploy script updates files in place before checking them, so broken code reached visitors during the failed run. The next step is to deploy into a new release folder, check it, and only then switch a `current` symlink. A test job before deploy would also stop broken code earlier.
- Backups are stored only on app-vm. A copy on a second machine would survive app-vm failing.
- No alert is sent when a backup fails.

## 9. Answers to the questions

1.MySQL identifies a user by both name and host, so guestbook_app at 172.31.45.87 can only log in from the app server. A stolen password is useless from any other machine, which limits the damage.
2.Yes. The deploy script updates the files on the server before it checks anything, so visitors got the broken code until I reverted it. To prevent this, I would deploy into a new release folder, test it there, and switch to it only if the tests pass.",
3.Backups on app-vm survive a failure of db-vm. If app-vm itself dies, its backups are lost with it, so a copy stored on a third machine is needed for full protection.",
4.About one hour of data. The backup runs hourly, so anything written after the last backup can be lost if a failure happens. In my drill, the entry written after the 13:04 backup was lost.",
5.A backup is only useful if it can be restored. A file can look fine and still be incomplete or unreadable, so restore tests prove it works. I would test monthly and after any change to the backup script.",
6.Laptop DNS translates the domain name into the server's IP address, and the browser connects to it on port 80. Nginx reads the Host header in the request and uses the server block whose server_name matches it.", 


