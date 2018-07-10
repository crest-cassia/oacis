# Preparing the development environment

OACIS doc uses "github pages" for page rendering.
Jekyll gem is used to render markdown in the github-pages service.

In order to render the markdown on your machine, install the gem by `bundle install` and then run

```shell
bundle exec jekyll serve -w --baseurl ''
```

This command launches a web server which hosts rendered pages.
Please access [localhost:4000](http://localhost:4000).

In addition to ruby, Jekyll depends on python2.
If you find an error like "Liquid Exception: Failed to get header.", then please setup the environment for python 2. 

