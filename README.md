# OACIS

*OACIS* (''Organizing Assistant for Comprehensive and Interactive Simulations'') is developed for efficient management of simulation jobs and results.
See docs (doc/build/html/index.html) for the sequence of installation and usage.

## Getting Started

This is a minimal procedure to try OACIS.
For the detailed installation process, please refer to the document.

- install [MongoDB](http://www.mongodb.org/) on your system.
    - using package management system such as yum or [homebrew](http://brew.sh/) will be easy for you.
    - check if MongoDB is running

        ```sh:check_db_daemons.sh
ps aux | grep "mongod"
        ```

- install ruby1.9.3 and [bundler](http://bundler.io/)
    - Only version 1.9.3 is supported
    - to install bundler gem, run the following command
        - when using Ruby installed to the system, you might need to run as `sudo`

    ```sh:install_bundler.sh
gem install bundler
    ```

- clone the git repository

    ```sh:clone.sh
git clone -b master git@github.com:crest-cassia/oacis.git
```
- install dependent gems using bundle command
    - cd to the project root directory `oacis`, and run the following command

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

## Mailing List

- You can post questions and feature requests to the following Google group.
    - [OACIS-users](https://groups.google.com/forum/#!forum/oacis-users)
- Announcements of new releases are also available.

