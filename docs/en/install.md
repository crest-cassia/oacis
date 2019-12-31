---
layout: default
title: "Installation"
lang: en
next_page: tutorial
---

# Install

To start using OACIS, you need to set up both

- (1) OACIS
- (2) hosts where simulators run

There are two ways to set up OACIS.

- (1.1) using a virtual machine image in which OACIS is already set up.
- (1.2) using a native (non virtual machine) environment and setup prerequisites manually.

If your OS is Windows, you must select (1.1).
For Unix-based OS (Linux, Mac), either (1.1) or (1.2) is fine.

If you use OACIS for the first time, we recommend (1.1) since you can quickly start trying OACIS.
With the virtual machine environment, you can quickly start the tutorial on the next page.
If you would like to use it more seriously, we recommend to move to the native environment.

We also need to setup the host where the simulator runs. Hereafter we call it "computational host".

In this page, the setup procedure are shown for each option.

---

## (1.1) Installing OACIS using a virtual machine

Using [Docker](https://www.docker.com/), you can easily install a virtual machine in which OACIS is installed.
Docker is available not only on Linux but on Windows and MacOS X.

The installation procedure is summarized in the README of [oacis_docker](https://github.com/crest-cassia/oacis_docker).
**oacis_docker** is a project developing a docker image for OACIS.
In the docker images, step 1 of the tutorial in the next page has already been setup.

## (1.2) Installing OACIS on a native machine

### Platform

- OACIS
    - Unix-like OS, such as Mac OS X and Linux.
    - Windows is not supported.
- host where simulators run
    - Unix-like OS which runs bash and ssh.
- browser
    - Google Chrome, Firefox, Safari

### Prerequisites

- Ruby 2.5.1 or later ([https://www.ruby-lang.org/](https://www.ruby-lang.org/))
- MongoDB 3.6 or later ([http://www.mongodb.org/](http://www.mongodb.org/))
- bundler ([http://bundler.io/](http://bundler.io/))
    - You may skip the installation for Ruby2.6.0 or later as it is built into Ruby as a standard library.
- redis ([https://redis.io/](https://redis.io/))

We recommend rbenv or rvm to install a proper version of Ruby.

For MacOS X users, it is easy to use [homebrew](http://brew.sh/) to install rbenv and MongoDB.
For Linux users, yum or apt commands are available to install these.

In order to install bundler, run `gem install bundler` after you have installed Ruby.

#### Setting up prerequisites in MacOS X

Here we show the instructions on how to setup prerequisites using homebrew.

- installing rbenv
    - Follow the instruction of [the official document of rbenv](https://github.com/rbenv/rbenv#homebrew-on-macos)
- install ruby using rbenv (The following is an example to install Ruby 2.5.1)
    ``` sh
    rbenv install 2.5.1 && rbenv global 2.5.1
    rbenv rehash
    ruby --version
    ```
    - verify output is like `ruby 2.5.1....`.
- installing MongoDB
    - Follow the instruction of [the official document.](https://docs.mongodb.com/manual/tutorial/install-mongodb-on-os-x/)
        - After installation, start MongoDB as a service (`brew services start mongodb-community`).
- install and update bundler
    ``` sh
    gem install bundler
    gem udpate bundler
    rbenv rehash
    ```
    - After installation, run `which bundle` to verify that the bundle command is available.
- installing redis
    ``` sh
    brew install redis
    brew services start redis
    ```

#### Setting up prerequisites in Linux

Here we show the instruction on how to setup prerequisites using apt-get, using Ubuntu14.04 as an example.

- install pre-requied packages
    ``` sh
    sudo apt-get update
    sudo apt-get install -y git build-essential wget libssl-dev libreadline-dev zlib1g-dev
    ```
- installing rbenv
    - Follow the instruction of [the official document of rbenv](https://github.com/rbenv/rbenv#installation)
- install ruby using rbenv (The following is an example to install Ruby 2.5.1)
    ``` sh
    rbenv install 2.5.1 && rbenv global 2.5.1
    rbenv rehash
    ruby --version
    ```
    - verify output is like `ruby 2.5.1....`.
- install mongoDB
    - Follow the instruction of [the official document.](https://docs.mongodb.com/manual/administration/install-on-linux/)
- install and update bundler
    ``` sh
    gem install bundler
    gem update bundler
    rbenv rehash
    ```
    - After installation, run `which bundle` to verify that the bundle command is available.
- install redis
    ``` sh
    sudo apt-get install redis
    service redis-server start
    ```



### Installing OACIS and rails startup check

Prepare the source code of OACIS. If git is not installed on your system, install git first.

```shell
git clone --recursive -b master https://github.com/crest-cassia/oacis.git
```

After this command, source codes for OACIS is downloaded to `oacis/` directory.
Run the following command to verify that appropriate prerequisites are already installed.
If you get an error, please check the installation of prerequisites.

```shell
cd oacis
./bin/check_oacis_env
```

Then, install dependent libraries. Run the following command. This will take a while.

```shell
bundle install
```

If these installation have been successfully finished, you can boot a web server.

```shell
bundle exec rails s
```

Access [localhost:3000](http://localhost:3000) and verify the top page is properly displayed.
Then, stop the server by typing `Ctrl-C`.
If the page is not properly displayed, please check if the prerequisites are properly installed.

### Booting

To boot OACIS, run the following command.

```shell
bundle exec rake daemon:start
```

Access [localhost:3000](http://localhost:3000) to see the top page of OACIS.

In order to restart, stop the process, run these commands.

```shell
bundle exec rake daemon:restart   # stop the current process and reboot
bundle exec rake daemon:stop
```

{% capture tips %}
You can gracefully stop the server even if a submitted job is not finished.
Even while OACIS is stopped, the jobs remain running on the remote hosts. When you boot OACIS again, the finished jobs are included in the database.
{% endcapture %}{% include tips %}

## (2) Setting up Computational Host

**If you are going to use a virtual machine environment, this step is not necessary since we are going to use it also as a computational host.**

A typical sequence for setting up computational host is as follows.
Hereafter, we call the host where OACIS is running "OACIS host" while the host where the simulation is executed is called "computational host".
![OACIS host and computational host]({{ site.baseurl }}/images/SSH_connection.png){:width="600px"}

1. (At OACIS host) Setting up SSH authorization key so that SSH connection is available without password from OACIS host.
    - Execute `ssh-keygen -t rsa` to generate SSH key.
        - Please type an arbitrary passphrase.
        - Public and private keys are generated at `~/.ssh/id_rsa`, `~/.ssh/id_rsa.pub`.
    - Run `ssh-copy-id USER@HOST_NAME` to send the public key to the computational host.
        - Please replace USER and HOST_NAME depending on your host.
    - create `~/.ssh/config` formatted as shown below:
      ```config
      Host my_host
        HostName 127.0.0.1
        Port 22
        User my_user
        IdentityFile ~/.ssh/id_rsa
      ```
      - `Host` : specify a name.
      - `HostName` : Specify the IP address (or the hostname) of the computational host.
      - `User`: Specify the user name used to login the computational host.
      - `IdentityFile`: A path to the secret key file.
      - Please replace `my_host` and `my_user` depending on your host.
      - specify path to the secret key in `IdentityFile` value field if you created it in non-default path.
      - OACIS v3 refers `~/.ssh/config` to specify IP, port and USER instead of web interface like in v2.
    - Run `cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys`.
    - Check connection.
        - Run `ssh my_host` and verify that the password is not required to login. 
            - If you entered a passphrase when you made the key, you will be required to enter the passphrase (not password) when conducting SSH. OACIS host and computational host must be setup so that neither password nor passphrase is required. To skip entering the passphrase, see the following.
                - (macOS Sierra or later) Execute `ssh-add ~/.ssh/id_rsa` to register the key to the agent.
                    - The command will ask you to enter the passphrase. After you entered the passphrase, you will not be required to enter the passphrase thereafter.
                - (Linux) Use SSH Agent to skip entering passphrase. Run the following commands to launch SSH agent. (These steps are necessary each time you login.)
                    - ``eval `ssh-agent` `` This will launch ssh-agent process.
                    - `ssh-add ~/.ssh/id_rsa` Specify the path of private key. This command will ask you to enter the passphrase. After you entered passphrase, you will be no longer required to enter the passphrase on the same shell session.
                        - You may also use [Keychain](http://www.funtoo.org/Keychain) instead, which is a tool to reduce the number of times you need to enter you passphrase.
2. (At Computational host) Install [xsub](https://github.com/crest-cassia/xsub).
    - XSUB is a small script which absorbs the difference of the specification of job schedulers. OACIS uses XSUB to submit a job therefore you must install xsub in advance.
    - For setting up XSUB, plesae refer to the [README of XSUB](https://github.com/crest-cassia/xsub/blob/master/README.md).
        - XSUB requires Ruby 2.0 or later as a prerequisites. Install Ruby if it is not installed yet.
3. (At OACIS host) Verifying the set up
    - Run `ssh remotehost 'bash -l -c xstat'`. If you find the job status of the remote host without an error, all the setup has been correctly finished.
        - If you find an SSH error, please check Procedure 1.
        - If you find an error like "no such command : xsub", then please check Procedure 3.

## Note on security ( for both (1.1),(1.2) )

Please do not expose OACIS to the Internet.
Since OACIS can invoke an arbitrary command on the computational host, a serious security issue can happen if a malicious user has access to OACIS.
We recommend you to run OACIS on a personal machine, and prevent others from using your OACIS.

From OACIS 2.11.0, OACIS is bound to `127.0.0.1` by default, which means you can access OACIS only from the localhost.
Since MongoDB is also bound to `127.0.0.1` by default, you do not have to take further actions.
If you are using OACIS 2.10.0 or earlier, use firewall to deny access from other host.
The web server uses port 3000 so deny access to these ports from other host.

If you use Docker, we recommend to publish the port of the container only to the localhost. To do so, run `docker run` command with `-p` option as follows.

```shell
docker run -p 127.0.0.1:3000:3000 -dt oacis/oacis
```

You might worry that limiting access from another host may cause some inconvenience.
You can still use OACIS remotely using SSH port forwarding even under this constraint.
If your OACIS is running on "server.example.com" for example, you can forward the port of OACIS to localhost:3000 by running the following command.

```shell
ssh -N -f -L 3000:localhost:3000 server.example.com
```
(replace "server.example.com" with the host name of OACIS)

# Updating OACIS

## Procedure for updating OACIS
To update OACIS, run the following commands at "oacis" directory.

```shell
bundle exec rake daemon:stop            # tentatively stop OACIS
git pull origin master                  # get the latest source code of OACIS
git pull origin master --tags
git submodule update --init --recursive
gem update bundler                      # update bundler
bundle install                          # install dependency
bundle exec rake daemon:start           # restart OACIS
```

## Update OACIS v2 -> v3
OACIS v3 requires MongoDB v3.6 or later, Ruby v2.5.1 or later, and redis.


#### Updating MongoDB
To upgrade MongoDB, it is required to upgrade MongoDB incrementally, like 2.6->3.0->3.2...->3.6.
Here, to avoid such an incremental upgrade, we first dump the data of OACIS, upgrade the MongoDB, and restore the data to new MongoDB.
Refer to [the official document of MongoDB.](https://docs.mongodb.com/manual/tutorial/upgrade-revision/)

- dump the database
``` sh
mongodump --db oacis_development #dump database
```
  - verify the data is exported in `dump/oacis_development`.

- upgrading MongoDB
    - Follow [the official instructions.](https://docs.mongodb.com/manual/tutorial/upgrade-revision/)
- restore the database
``` sh
mongorestore --db oacis_development dump/oacis_development #import database into MongoDB
```

#### Editing SSH-config

From version 3, OACIS refers to "~/.ssh/config" file to retrieve the SSH information. Fields "Hostname", "User", "Port", "IdentityFile" are removed from the Host setting.

#### reboot OACIS
``` sh
bundle install                          # install dependent libraries
bundle exec rake daemon:start           # restart OACIS
```

Please consider subscribing to [oacis-users mailing list](https://groups.google.com/forum/#!forum/oacis-users). A new release will be notified via this mailing list.

