---
layout: default
title: "TIPs"
lang: en
---

# {{page.title }}

---

## Backup and Restore

OACIS manages data both on MongoDB and on file system. In order to make a backup of the data, we need to save both of them.
We are going to explain how to make a backup of the data managed by OACIS.

### If you are NOT using Docker

#### Backup

First, run the following command in order to make a backup of MongoDB.
The following command is available for OACIS v3.8.0 or later. If you're using an older version of OACIS, update OACIS or use the command line in the lower line.

{% highlight sh %}
./bin/oacis_dump_db
(for v3.7 or prior: mongodump --db oacis_development )
{% endhighlight %}

Second, we need to make a backup of the files in the file system. All the files are stored in **"OACIS_PROJECT_ROOT/public/Result_development"** directory, where *"OACIS_PROJECT_ROOT"* is the directory where the source code of OACIS is cloned.
To make a backup of the directory, run the following command for example.
(Although you can simply use `cp` command, we recommend `rsync` if you have a large amount of files.)

{% highlight sh %}
rsync -av -P --delete /path/to/OACIS/public/Result_development /backup_dir
{% endhighlight %}

#### Restore

Run the following command. Please replace the path of the second line depending on the actual path.

{% highlight sh %}
./bin/oacis_restore_db
(for v3.7 or prior: mongorestore --db oacis_development --drop /path/to/DB_data/dump/oacis_development )
{% endhighlight %}

(Warning) The above command is deleting the existing record once. In other words, the old documents are overwritten.

To restore the files in the file system, use `rsync` command as follows. Please replace with your actual path.

{% highlight sh %}
rsync -av -P --delete /backup_dir/Result_development /path/to/OACIS/public
{% endhighlight %}

#### Reference

* MongoDB mongodump: [http://docs.mongodb.org/manual/reference/program/mongodump/](http://docs.mongodb.org/manual/reference/program/mongodump/)
* MongoDB mongorestore: [http://docs.mongodb.org/manual/reference/program/mongorestore/](http://docs.mongodb.org/manual/reference/program/mongorestore/)
* MongoDB ObjectID: [http://docs.mongodb.org/manual/reference/object-id/](http://docs.mongodb.org/manual/reference/object-id/)

### If you are using Docker

Refer to [Backup and Restore](https://github.com/crest-cassia/oacis_docker/blob/master/README.md#backup-and-restore).

## accessibility control (READ ONLY mode)


If you would like to share your results with a person in a distant place, you can launch another OACIS in a public (cloud) server and sync the results in your local OACIS to the public one.
In that case, it is safe to prohibit job submission on the public OACIS. Otherwise, a malicious user can, in principle, execute any command on the computational host.
In order to prevent job submissions, OACIS provides *"Read Only"* mode. With *"Read Only"* mode, any modification on the data, including the job submission, is prohibited.

In order to enable Read-Only mode, make a file *"config/user_config.yml"* in the directory where the source code of OACIS exists.
You can find a sample file *"config/user_config.sample.yml"*.
To control the accessibility, edit the configuration file as follows and restart OACIS.

{% highlight yaml %}
---
access_level: 0
{% endhighlight %}

`access_level: 2` corresponds to the normal mode. When `access_level: 1`, creation, update, deletion of Simulator, Analyzer, and Host are prohibited.
You can submit a job for a Simulator that is already defined.

With `access_level: 0`, the worker process is not launched, and any modification from web browsers become impossible, i.e., READ ONLY mode is set.
Furthremore, OACIS is bound to IP address `0.0.0.0` under this setting by default, making OACIS accessible from other hosts.
If you would like to customize the binding IP address, add a line like `binding_ip: 'localhost'`.

It is easy to share data with other people by running jobs from OACIS on the local machine with access level 2, while launching another OACIS on a shared machine with access level 0 and periodically synchronizing the data to the shared server with the backup commands.

