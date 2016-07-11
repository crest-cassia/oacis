---
layout: default
title: "Introduction"
lang: en
next_page: overview
---

# {{ page.title }}

---

## What is OACIS?

OACIS (''Organizing Assistant for Comprehensive and Interactive Simulations'') is a job management software for simulation studies.

When we conduct scientific research by numerical simulations, we usually carry out many simulation jobs changing models and parameters through a trial and error process. 
This kind of trial-and-error approach often causes a problem of job management since a large amount of jobs are often created while we are exploring the parameter space. 
As the number of simulation jobs increases, it is often difficult to keep track of vast and various simulation results in an organized way and, as a result, we inevitably suffer from inefficiency and human errors.

OACIS is being developed aiming at overcoming these difficulties.
For instance, submitting only one simulation job would require the following tasks.

1. login to a remote host
1. compile your simulation program
1. make a directory for a job
1. create a shell script to submit a job
1. submit your job to the job-scheduler
1. wait until the job finishes
1. transfer result files to the local machine
1. analyze the results
1. (If another job is necessary) go back to the first one.

Using OACIS, you can automate most of the above tasks, which lets you efficiently explore the parameter space.
With a user-friendly interface, you can easily submit various jobs to appropriate remote hosts.
After these jobs are finished, all the result files are automatically downloaded from the remote hosts and stored in a traceable way together with logs of the date, host, and elapsed time of the jobs.
You can easily find the status of the jobs or results files from the browser-based UI, which lets you focus on more productive and essential parts of your research activities.

## Screenshots

<div id="carousel-screen-shot" class="carousel slide" data-ride="carousel">
  <!-- Indicators -->
  <ol class="carousel-indicators">
    <li data-target="#carousel-screen-shot" data-slide-to="0" class="active"></li>
    <li data-target="#carousel-screen-shot" data-slide-to="1"></li>
    <li data-target="#carousel-screen-shot" data-slide-to="2"></li>
    <li data-target="#carousel-screen-shot" data-slide-to="3"></li>
    <li data-target="#carousel-screen-shot" data-slide-to="4"></li>
    <li data-target="#carousel-screen-shot" data-slide-to="5"></li>
    <li data-target="#carousel-screen-shot" data-slide-to="6"></li>
    <li data-target="#carousel-screen-shot" data-slide-to="7"></li>
  </ol>

  <!-- Wrapper for slides -->
  <div class="carousel-inner" role="listbox">
    <div class="item active">
      <img src="{{ site.baseurl }}/images/screenshots/1.png" alt="1">
      <div class="carousel-caption">
      </div>
    </div>
    <div class="item">
      <img src="{{ site.baseurl }}/images/screenshots/2.png" alt="2">
      <div class="carousel-caption">
      </div>
    </div>
    <div class="item">
      <img src="{{ site.baseurl }}/images/screenshots/3.png" alt="3">
      <div class="carousel-caption">
      </div>
    </div>
    <div class="item">
      <img src="{{ site.baseurl }}/images/screenshots/4.png" alt="4">
      <div class="carousel-caption">
      </div>
    </div>
    <div class="item">
      <img src="{{ site.baseurl }}/images/screenshots/5.png" alt="5">
      <div class="carousel-caption">
      </div>
    </div>
    <div class="item">
      <img src="{{ site.baseurl }}/images/screenshots/6.png" alt="6">
      <div class="carousel-caption">
      </div>
    </div>
    <div class="item">
      <img src="{{ site.baseurl }}/images/screenshots/7.png" alt="7">
      <div class="carousel-caption">
      </div>
    </div>
    <div class="item">
      <img src="{{ site.baseurl }}/images/screenshots/8.png" alt="8">
      <div class="carousel-caption">
      </div>
    </div>
  </div>

  <!-- Controls -->
  <a class="left carousel-control" href="#carousel-screen-shot" role="button" data-slide="prev">
    <span class="glyphicon glyphicon-chevron-left" aria-hidden="true"></span>
    <span class="sr-only">Previous</span>
  </a>
  <a class="right carousel-control" href="#carousel-screen-shot" role="button" data-slide="next">
    <span class="glyphicon glyphicon-chevron-right" aria-hidden="true"></span>
    <span class="sr-only">Next</span>
  </a>
</div>

## About this document

This document illustrates the usage of OACIS.
The remaining pages are organized as follows.

- System Overview
- Installation
- Tutorial
- Configuration
- Command Line Interface(CLI)
- Tips

You will be able to start using OACIS if you read the first three pages.
In order to fully make use of OACIS, read other pages when necessary.

## Contact

If you have questions, requests, or bug reports, please send your feedback to the developers (`oacis-dev _at_ googlegroups.com`). Replace _at_ with @.

