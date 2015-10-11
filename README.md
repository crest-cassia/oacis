# OACIS

[![release](https://img.shields.io/github/release/crest-cassia/oacis.svg)](https://github.com/crest-cassia/oacis/releases/latest)
[![oaics_docker](http://img.shields.io/badge/oaics_docker-building-yellow.svg)](https://github.com/crest-cassia/oacis_docker)


## What is OACIS?

*OACIS* (''Organizing Assistant for Comprehensive and Interactive Simulations'') is a **job management software** for large scale simulations.

As the number of simulation jobs increases, it is often difficult to keep track of vast and various simulation results in an organized way.

OACIS is a job management software aiming at overcoming these difficulties.
With a user-friendly interface of OACIS, you can easily submit various jobs to appropriate remote hosts.
After these jobs are finished, all the result files are automatically downloaded from the remote hosts and stored in a traceable way together with logs of the date, host, and elapsed time of the jobs.

If you have a trouble of handling many simulation jobs, OACIS will definitely help you!

## Screenshots

![screenshot](https://raw.githubusercontent.com/crest-cassia/oacis/gh-pages/images/screenshots/1.png)
![screenshot](https://raw.githubusercontent.com/crest-cassia/oacis/gh-pages/images/screenshots/3.png)
![screenshot](https://raw.githubusercontent.com/crest-cassia/oacis/gh-pages/images/screenshots/5.png)
![screenshot](https://raw.githubusercontent.com/crest-cassia/oacis/gh-pages/images/screenshots/8.png)

## Getting Started

### Using Docker (Recommended)

The easiest way to start OACIS is using the docker image.

- Install [docker](https://www.docker.com/) (Linux) or [docker Toolbox](https://www.docker.com/toolbox) (MacOS, Windows).
- Then git clone [oacis_docker](https://github.com/crest-cassia/oacis_docker) repository, and follow the instruction there.

You can start OACIS in a few minutes!

### Manual installation

Basic procedure to install OACIS is as follows.
For the details, please refer to the document.

- Supported OS: you need unix like system such as Linux or MacOSX.
    - If you are using Windows, we recommend using a virtual machine.

- install [MongoDB](http://www.mongodb.org/) on your system.
    - using package management system such as yum or [homebrew](http://brew.sh/) will be easy for you.
    - check if MongoDB is running

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

- check if the prerequisites are installed correctly by running the following command.

    ```sh:check_oacis_env.sh
./bin/check_oacis_env
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

- Please refer to the documents located at `doc/build/html`.
    - At the moment, only Japanese documents are prepared.

## License

The MIT License (MIT)

Copyright (c) 2013,2014 RIKEN, AICS

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

http://crest-cassia.github.io/oacis/

## Publications
- A list of publications about OACIS is available at this [wiki page](https://github.com/crest-cassia/oacis/wiki/List-of-publications).
- We would greatly appreciate if you cite the following article when you publish your research using OACIS.
    - Y. Murase, T. Uchitane, and N. Ito, "A tool for parameter-space explorations", Physics Procedia, 57, p73-76 (2014)
      - http://www.sciencedirect.com/science/article/pii/S187538921400279X
    - You can cite it as **"The systematic simulations in this study were assisted by OACIS."**, for example, in appendix or method section.
- We would also like to create a list of researches to which OACIS contributed to.
    - We will be happy if you are willing to include your work. Let us know about your work when your paper is published.

## Contact

- Just send your feedback to us!
    - `oacis-dev _at_ googlegroups.com` (replace _at_ with @)
    - We appreciate your questions, feature requests, and bug reports.
- You'll have announcements of new releases if you join the following google group. Take a look.
    - https://groups.google.com/forum/#!forum/oacis-users

