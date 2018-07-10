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

- Ruby 2.2 or 2.3. (2.4 is supported since v2.12.0.)
- Ruby 2.5.1 ([https://www.ruby-lang.org/](https://www.ruby-lang.org/))
- MongoDB 3.6 ([http://www.mongodb.org/](http://www.mongodb.org/))
- bundler ([http://bundler.io/](http://bundler.io/))
- redis ([https://redis.io/](https://redis.io/))

We recommend rbenv or rvm to install proper version of Ruby.

For MacOS X users, it is easy to use [homebrew](http://brew.sh/) to install rbenv and MongoDB.
For Linux users, yum or apt commands are available to install these.

In order to install bundler, run `gem install bundler` after you have installed Ruby.

#### Setting up prerequisites in MacOS X

Here we show the instructions on how to setup prerequisites using homebrew.

- installing rbenv
    ``` sh
    brew install rbenv ruby-build
    echo 'if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi' >> ~/.bashrc
    ```
- install ruby 2.5.1 using rbenv
    ``` sh
    rbenv install 2.5.1 && rbenv global 2.5.1
    ruby --version
    ```
    - verify output is like `ruby 2.5.1....`.
- installing MongoDB
    ``` sh
    brew install mongo #install
    brew services start mongodb #start mongo service
    ```
    - `brew info mongo` will display the command to launch mongodb daemon.
    - Once you hit the command above, mongodb will be automatically launched at login.
    - Run `mongo` and find a terminal to control MongoDB is launched. Type `exit` to stop the terminal.
- installing bundler
    ``` sh
    gem install bundler
    which bundle
    ```
    - find path to the bundle command to verify the installation.
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
    ``` sh
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi' >> ~/.bashrc
    eval "$(rbenv init -)"
    ```
- install ruby 2.5.1 using rbenv
    ``` sh
    rbenv install 2.5.1 && rbenv global 2.5.1
    ruby --version
    ```
    - verify the output is like `ruby 2.5.1....`.
- install mongoDB v3.6

  Please refer to [Install MongoDB Community Edition on Linux](https://docs.mongodb.com/manual/administration/install-on-linux/) for other Linux versions other than Ubuntu.
    ``` sh
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 2930ADAE8CAF5059EE73BB4B58712A2291FA4AD5`
    echo "deb http://repo.mongodb.org/apt/debian jessie/mongodb-org/3.6 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.6.list`
    sudo apt-get update && sudo apt-get install mongodb-org
    ```
    - when it asks `Geographic area` and `time zone`, choose appropreate one from options displayed.
    - Run `mongo` and verify that a terminal for MongoDB is launched. Type `exit` to stop the terminal.

    ``` sh
    sudo service mongod start
    ```
    - The command above will launch mongod process. After this command, mongod process is automatically launched whenever you restart the system.

- installing bundler
    ``` sh
    gem install bundler
    which bundle
    ```
    - find the path of the bundle command to verify the installation.

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
Hereafter, we call the host where OACIS is running "OACIS host".

1. Setting up SSH authorization key so that SSH connection is available without password from OACIS host.
    - (At OACIS host) Execute `ssh-keygen -t rsa` to generate SSH key.
        - Please type an arbitrary passphrase.
        - Public and private keys are generated at `~/.ssh/id_rsa`, `~/.ssh/id_rsa.pub`.
    - (At OACIS host) Send the public key to the computational host.
        - The command would be like `scp ~/.ssh/id_rsa.pub USER@HOST_NAME:~`
        - Please replace USER and HOST_NAME depending on your host.
    - (At OACIS host) create `~/.ssh/config` formatted as shown below:
      ```config
      Host CONNECTION_NAME
        HostName HOST_NAME
        User USER
        IdentityFile ~/.ssh/id_rsa
        port 22
      ```
      - `CONNECTION_NAME` : specify any alphabet string.
      - Please replace `USER` and `HOST_NAME` depending on your host.
      - specify path to the secret key in `IdentityFile` value field if you created it in non-default path.
      - OACIS v3 refers `~/.ssh/config` to specify IP, port and USER instead of web interface like in v2.
    - (At Computational host) Run `cat ~/id_rsa.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys`.
    - (At OACIS host) Check connection.
        - Run `ssh CONNECTION_NAME` and verify that the password is not required to login. 
            - If you enter passphrase when you made the key, you will be required to enter the passphrase (not password) when conducting SSH. OACIS host and computational host must be setup so that neither password nor passphrase is required. To skip the passphrase, see the following.
                - (macOS El Capitan or earlier) Keychain access requires you to enter your passphrase for the first time. After you entered the passphrase, you will not be required to enter the passphrase thereafter.
                - (macOS Sierra or later) Execute `ssh-add ~/.ssh/id_rsa` to register the key to the agent.
                    - The command will ask you to enter the passphrase. After you entered the passphrase, you will not be required to enter the passphrase thereafter.
                - (Linux) Use SSH Agent to skip entering passphrase. Run the following commands to launch SSH agent. (These steps are necessary each time you login.)
                    - ``eval `ssh-agent` `` This will launch ssh-agent process.
                    - `ssh-add ~/.ssh/id_rsa` Specify the path of private key. This command will ask you to enter the passphrase. After you entered passphrase, you will be no longer required to enter the passphrase on the same shell session.
                        - You may also use [Keychain](http://www.funtoo.org/Keychain) instead, which is a tool to reduce the number of times you need to enter you passphrase.
2. (At Computational host) Install ruby 1.8 or later.
    - Ruby is installed by default in most of the recent OS. If it is installed, please skip this step.
    - You can verify the version of Ruby by running `ruby --version`.
3. (At Computational host) Install [xsub](https://github.com/crest-cassia/xsub)
    - XSUB is a small script which absorbs the difference of the specification of job schedulers. OACIS uses XSUB to submit a job therefore you must install xsub in advance.
    - For setting up XSUB, plesae refer to the [README of XSUB](https://github.com/crest-cassia/xsub/blob/master/README.md).
4. (At OACIS host) Verifying the set up
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

# Updating

## Usual OACIS update
To update OACIS, run the following commands at "oacis" directory.

```shell
bundle exec rake daemon:stop            # tentatively stop OACIS
git pull origin master                  # get the latest source code of OACIS
git pull origin master --tags
git submodule update --init --recursive
```

## Update v2 -> v3
OACIS v3 requires MongoDB v3.6, Ruby v2.5.1 and redis, which are installed by following:


### Updating MongoDB
To upgrade MongoDB, it is required to upgrade MongoDB incrementally, like 2.6->3.0->3.2...->3.6.
Here, to avoid such an incremental upgrade, we first dump the data of OACIS, upgrade the MongoDB, and restore the data to new MongoDB.

- dump the database
``` sh
mongodump --db oacis_development #dump database
```
  - verify the data is exported in `dump/oacis_development`.

- upgrading MongoDB
    - For MacOSX

      refer "(1.2)Installing OACIS on a native machine"--"Setting up prerequisites in MacOS X"--"installing MongoDB" of this document for details.
      ``` sh
      brew uninstall mongo                         # uninstall old MongoDB
      mv /usr/local/var/mongodb ~/mongodb.backup   # make a backup of the data file just in case
      brew update
      brew install mongo                           # install MongoDB3.6
      brew services start mongodb                  # start service
      ```
    - For Ubuntu

      refer "(1.2)Installing OACIS on a native machine"--"Setting up prerequisites in Linux"--"install MongoDB v3.6" of this document for details.
      ``` sh
      sudo apt-get autoremove mongodb-org #uninstall
      sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 2930ADAE8CAF5059EE73BB4B58712A2291FA4AD5
      echo "deb http://repo.mongodb.org/apt/debian jessie/mongodb-org/3.6 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.6.list
      sudo apt-get update && sudo apt-get install mongodb-org
      sudo service mongod start #restart
      ```
- restore the database
``` sh
mongorestore --db oacis_development dump/oacis_development #import database into MongoDB
```

### updating Ruby and redis
- updating Ruby
  ``` sh
  rbenv install 2.5.1 && rbenv global 2.5.1
  ```
- install & restart redis
    - For MacOSX
      ```sh
      brew install redis
      brew services start redis
      ```
    - For Ubuntu
      ``` sh
      sudo apt-get install redis
      sudo service redis-server start
      ```

### Editing SSH-config

From version 3, OACIS refers to "~/.ssh/config" file to retrieve the SSH information. Fields "Hostname", "User", "Port", "IdentityFile" are removed from the Host setting.

## reboot OACIS
``` sh
bundle install                          # install dependent libraries
bundle exec rake daemon:start           # restart OACIS
```

Please consider subscribing to [oacis-users mailing list](https://groups.google.com/forum/#!forum/oacis-users). A new release will be notified via this mailing list.

