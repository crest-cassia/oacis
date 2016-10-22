---
layout: default
title: "System Overview"
lang: en 
next_page: install
---

# {{ page.title }}

In this page, an overview of the system architecture and the data structure is presented.

---

## System architecture

The system architecture of OACIS is depicted in the following figure.

The web server is developed based on the Ruby on Rails framework (http://rubyonrails.org/), which provides an interactive user-interface to users.
MongoDB (http://www.mongodb.org/), a document-based database, is used as data storage. It stores the information of the jobs, such as the values of parameters, executed date, and executing host.
The files generated from the simulators are stored on the file system. Thus, you can directly access the simulation outputs using a file browser or a command-line terminal.

The application server is responsible for handling requests from users.
When a user creates a job using a web-browser front-end, the record of the job is created in the database.
Another daemon process, which we call "worker", periodically checks whether a job is ready to be submitted to a remote host.  If a job is found, the worker generates a shell script to execute a job and submits it to the job scheduler on the remote host via SSH connection.
Then the worker process periodically checks the status of the submitted jobs.
When one of the submitted jobs is finished, the worker downloads the results and stores them into the file storage and the database in an organized way.
Hence, users do not have to check the status of the remote host by themselves and they can trace the simulation results even after several months.


![System Architecture]({{ site.baseurl }}/images/SystemOverviewWithIcons.png){:width="600px"}

A typical flow of the job execution is depicted as follows.

1. A user specifies the jobs to be submitted via a web browser (①).
  * In addition to a browser, a command-line interface (⑥) is prepared as well.
1. The request by a user is handled by the application server (②). The job information is stored in the database (③).
1. A daemon process, called "Worker" (④), retrieves the job information and submits the job to the remote host (⑤) using SSH connection.
  * Worker is responsible for handling time-consuming jobs in the background. For example, SSH connection to remote hosts or file copy are handled by the Worker.
  * You need to configure OACIS for each host so that the jobs are executed using a job scheduler such as Torque.
  * Simulation programs must be prepared on each host in advance.
    * You register the command to be invoked to OACIS. OACIS embeds the command into the shell script and submits on a remote host.
  * For each job, a temporary directory is created. Each job is executed in that directory.
1. After a job is finished on the remote host, Worker downloads the result files to the local machine using SFTP.
  * Worker periodically polls the remote host and checks if the submitted jobs are finished.
  * After the job finishes, the results files are stored in the local file storage or DB (③).
    * All the files created in the temporary directory for the job are regarded as the simulation outputs, and stored in the file system.

All the results files are accessible either using a web-browser or a file system.

## Overview of the data structure

OACIS stores the simulation results in a three-layered structure (**Simulator**, **ParameterSet**, **Run**) as shown in the following figure.

![Data Structure]({{ site.baseurl }}/images/LayeredDataWithAnalysis.png){:width="600px"}

Each simulator has several ParameterSets, and each ParameterSet has several Runs.
A ParameterSet represents a set of parameter values which are required by the simulator.
A Run corresponds to a single MonteCarlo run having an independent random number seed.

Let us consider a simple traffic simulator as an example.
We assume that the simulator has three input parameters: road length *L*, time interval *T*, and the number of vehicles *N*.
A ParameterSet for this simulator corresponds to the set of these three values such as `{L=100, T=10, N=10}`.
If you conduct simulations for this ParameterSet five times with different random number seeds, you'll have five Runs.

Furthermore, you can define a post-process, called **Analyzer**, which is conducted on the simulation results.
For each Simulator, you can define several Analyzers. Analyzers are executed on a remote host similarly to Simulators.
The outputs of Analyzers are called **Analysis**. Analysis are stored below a ParameterSet or a Run depending on the type of Analyzers you define.

