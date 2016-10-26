# OACIS

[![GitHub version](https://badge.fury.io/gh/crest-cassia%2Foacis.svg)](https://badge.fury.io/gh/crest-cassia%2Foacis)
[![Build Status](https://travis-ci.org/crest-cassia/oacis.svg?branch=master)](https://travis-ci.org/crest-cassia/oacis)

## What is OACIS?

*OACIS* (''Organizing Assistant for Comprehensive and Interactive Simulations'') is a **job management software** for large scale simulations.

As the number of simulation jobs increases, it is often difficult to keep track of vast and various simulation results in an organized way.

OACIS is a job management software aiming at overcoming these difficulties.
With a user-friendly interface of OACIS, you can easily submit various jobs to appropriate remote hosts.
After these jobs are finished, all the result files are automatically downloaded from the remote hosts and stored in a traceable way together with logs of the date, host, and elapsed time of the jobs.

If you have a trouble of handling many simulation jobs, OACIS will definitely help you!

## Screenshots

![screenshot](docs/images/screenshots/1.png)
![screenshot](docs/images/screenshots/3.png)
![screenshot](docs/images/screenshots/5.png)
![screenshot](docs/images/screenshots/8.png)

## Getting Started

There are two ways to install OACIS. One is to use a virtual machine environment, and the other is to install on your system natively.
If you are using Linux or Mac, install it on your system directly.
If you are using Windows, please use a virtual machine environment using Docker.

### Installing on your system

Basic procedure to install OACIS is as follows.
For the details, please refer to the document.

- Supported OS: you need unix like system such as Linux or MacOSX.
    - If you are using Windows, we recommend using a virtual machine.

- install [MongoDB](http://www.mongodb.org/) on your system.
    - using package management system such as yum or [homebrew](http://brew.sh/) will be easy for you.
    - After the installation, check if MongoDB is running

        ```sh:check_db_daemons.sh
ps aux | grep "mongod"
        ```

- install ruby2.2.0 or later and [bundler](http://bundler.io/)
    - to install bundler gem, run the following command
        - when using Ruby installed to the system, you might need to run as `sudo`

    ```sh:install_bundler.sh
gem install bundler
    ```

- clone the git repository and checkout the master branch

    ```sh:clone.sh
git clone -b master https://github.com/crest-cassia/oacis.git
    ```

- install dependent gems using bundle command
    - change directory to _oacis/_, and run the following command

      ```sh:install_sh
bundle install --path=vendor/bundle
      ```

- run daemons
    - at the root directory, run the following command

    ```sh:start_daemon.sh
bundle exec rake daemon:start
    ```

    - to stop the daemons,

    ```sh:stop_daemon.sh
bundle exec rake daemon:stop
    ```

### Installing on virtual machine using Docker

The easiest way to start OACIS for windows users is using Docker.

- Install [docker](https://www.docker.com/) (Linux) or [docker Toolbox](https://www.docker.com/toolbox) (MacOS, Windows).
- Then git clone [oacis_docker](https://github.com/crest-cassia/oacis_docker) repository, and follow the instruction there.

You can start OACIS in a few minutes.

## License

The MIT License (MIT)

Copyright (c) 2013-2016 RIKEN, AICS

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so, 
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all 
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Documents

- http://crest-cassia.github.io/oacis/

## Publications

- We would greatly appreciate if you cite the following article when you publish your research using OACIS.
    - Y. Murase, T. Uchitane, and N. Ito, "A tool for parameter-space explorations", Physics Procedia, 57, p73-76 (2014)
      - http://www.sciencedirect.com/science/article/pii/S187538921400279X
    - You can cite it as **"The systematic simulations in this study were assisted by OACIS."**, for example, in appendix or method section.

## Contact

- Just send your feedback to us!
    - `oacis-dev _at_ googlegroups.com` (replace _at_ with @)
    - We appreciate your questions, feature requests, and bug reports. Do not hesitate to give us your feedbacks.
- You'll have announcements of new releases if you join the following google group. Take a look at
    - https://groups.google.com/forum/#!forum/oacis-users

