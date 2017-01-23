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
**oacis_docker** is a project for developing a docker image for OACIS.

As indicated in the README, you can launch the virtual machine by `docker run --name oacis -p 3000:3000 -dt oacis/oacis` command.
If you would like to start the tutorial in the next page as quickly as possible, execute `docker run --name oacis -p 3000:3000 -dt oacis/oacis_tutorial`.
This command uses an image in which step 2 of the tutorial in the next page has already been setup.


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

- Ruby 2.2 or 2.3. (2.4 is not supported yet.)
- MongoDB 2.4.9 or later (http://www.mongodb.org/)
- bundler (http://bundler.io/)

We recommend rbenv or rvm to install proper version of Ruby.

For MacOS X users, it is easy to use [homebrew](http://brew.sh/) to install rbenv and MongoDB.
For Linux users, yum or apt commands are available to install these.

In order to install bundler, run `gem install bundler` after you have installed Ruby.

#### Setting up prerequisites in MacOS X

Here we show the instructions on how to setup prerequisites using homebrew.

- installing rbenv
    - `brew install rbenv ruby-build`
    - `echo 'if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi' >> ~/.bashrc`
- install ruby using rbenv
    - `rbenv install 2.2.4 && rbenv global 2.2.4`
    - Run `ruby --version` and verify the output is like `ruby 2.2.4....`.
- installing MongoDB
    - `brew install mongo` to install MongoDB.
    - `launchctl load ~/Library/LaunchAgents/homebrew.mxcl.mongodb.plist` to launch the daemon process of MongoDB. After this, mongod process is automatically launched after login.
    - Run `mongo` and find a terminal to control MongoDB is launched. Type `exit` to stop the terminal.
- installing bundler
    - `gem install bundler`
    - To verify the installation, run `which bundle` and find the path of the bundle command.


#### Setting up prerequisites in Ubuntu14.04

Here we show the instruction on how to setup prerequisites using apt-get.

- installing rbenv
    - `sudo apt-get update; sudo apt-get install -y git build-essential wget libssl-dev libreadline-dev zlib1g-dev`
    - `git clone https://github.com/rbenv/rbenv.git ~/.rbenv`
    - `git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build`
    - `echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc`
    - `echo 'if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi' >> ~/.bashrc`
    - `eval "$(rbenv init -)"`
- installing ruby using rbenv
    - `rbenv install 2.2.4 && rbenv global 2.2.4`
    - Run `ruby --version` and verify the output is like `ruby 2.2.4....`.
- installing mongoDB
    - `sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10`
    - `echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | sudo tee /etc/apt/sources.list.d/mongodb.list`
    - `sudo apt-get update && sudo apt-get install mongodb-org`
    - `sudo service mongod start` to launch mongod process. After this command, mongod process is automatically launched whenever you restart the system.
    - Run `mongo` and verify that a terminal for MongoDB is launched. Type `exit` to stop the terminal.
- installing bundler
    - `gem install bundler`
    - To verify the installation, run `which bundle` and find the path of the bundle command.


### Installing OACIS

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

Access http://localhost:3000 and verify the top page is properly displayed.
Then, stop the server by typing `Ctrl-C`.
If the page is not properly displayed, please check if the prerequisites are properly installed.

### Booting

To boot OACIS, run the following command.

```shell
bundle exec rake daemon:start
```

Access http://localhost:3000 to see the top page of OACIS.

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
    - (At Computational host) Run `cat ~/id_rsa.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys`.
    - (At OACIS host) Check connection.
        - Run `ssh USER@HOST_NAME` and verify that the password is not required to login. 
            - If you enter passphrase when you made the key, you will be required to enter the passphrase (not password) when conducting SSH. OACIS host and computational host must be setup so that neither password nor passphrase is required. To skip the passphrase, see the following.
                - (for Mac users) Keychain access requires you to enter your passphrase for the first time. After you entered the passphrase, you will not be required to enter the passphrase thereafter.
                - (for Linux users) Use SSH Agent to skip entering passphrase. Run the following commands to launch SSH agent. (These steps are necessary each time you login.)
                    - ``eval `ssh-agent` `` This will launch ssh-agent process.
                    - `ssh-add ~/.ssh/id_rsa` Specify the path of private key. This command will ask you to enter the passphrase. After you entered passphrase, you will be no longer required to enter the passphrase.
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

**Please skip this section if you are using docker from Mac or Windows.**

Please use OACIS in intranet.
Since OACIS can invoke an arbitrary command on the computational host, a serious security issue can happen if a malicious user has access to OACIS.
We recommend to run OACIS on a personal machine, and use firewall to deny access from other host.
The web server and MongoDB use 3000 and 27017 port, respectively. Please deny access to these ports from other host.

If you run Docker from Mac or Windows, the access from other host is prohibited by default. You do not have to do any further action.

If you use Docker from Linux, we recommend to use "iptables" command to setup firewall.
By running the following command, all access to OACIS via ethernet is denied.

```shell
iptables -I FORWARD -i eth+ -o docker0 -p tcp -m tcp --dport 3000 -j DROP
```

Even if you setup the firewall, you can access OACIS from other host using SSH port forwarding.
If your OACIS is running on "server.example.com" for example, you can forward the port of OACIS to localhost:3000 by running the following command.

```shell
ssh -N -f -L 3000:localhost:3000 server.example.com
```
(replace "server.example.com" with the host name of OACIS)

