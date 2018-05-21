---
layout: default
title: "Tutorial"
lang: en
next_page: configuring_host
---

# {{ page.title }}

In this tutorial, we are going to register a sample simulator, execute jobs, and see the simulation results on the web UI provided by OACIS.
This tutorial is designed so that you can experience a basic workflow of OACIS.

* TOC
{:toc}

---

## About the sample simulator

In this tutorial, we are going to execute simulations of the Nagel-Schereckenberg model, which is a simple model of traffic flow of vehicles.
This simple model, proposed in the 1990's, describes the motion of vehicles as a Cellular Automaton on a one-dimensional lattice.
For more information about the model, please see [this page](https://en.wikipedia.org/wiki/Nagel%E2%80%93Schreckenberg_model).

We provide a source code for this simulation. Please find the [repository on the github](https://github.com/yohm/nagel_schreckenberg_model).
Follow README to set up the simulator. When you run the script `run.sh`, give simulation parameters as command-line arguments.
The output file is generated in the current directory.
Please try running the simulator and see how the output files look.

From now on, let us assume that the script is located at `~/nagel_schreckenberg_model/run.sh`.

## Procedure

1. Registering a Host
1. Registering a Simulator
1. Making a ParameterSet
1. Making a Run
1. Checking the results
1. Sweeping parameter space

**For the docker environment, Step 1 and 2 are already finished. Please start from the step 3.**

## 1. Registering a Host

We are going to register a computational host to OACIS.
Here we use "localhost", which is the place where OACIS is running, as a computational host.

As a prior condition, we need to prepare a computational host where SSH and XSUB are appropriately setup.
In the following, we assume that settings of SSH key authentication and XSUB has already finished. If you have not finished these settings, please go back to the previous page and setup the computational host.

Let us register a computational host to OACIS.
From the web page of OACIS, click [Hosts] in the navigation bar displayed on top of the page.
You will find the [New Host] button. Click it.
(See the following video to check the place of the button.)

<iframe width="420" height="315" src="https://www.youtube.com/embed/PooTP9GTroc" frameborder="0" allowfullscreen class="youtube" ></iframe>

On this page, we are going to fill in the information about the computational host.
OACIS submits jobs to the computational host based on this information.

For this tutorial, fill in the form as follows. (For the fields not shown in this list, leave them with default values.)

- Name: *localhost*
    - The name used in OACIS which you specified in `HOST` field of `~/.ssh/config` in OACIS host.
{% comment %}
- Hostname: *localhost*
    - Hostname used when making SSH connection. Either hostname or IP address is okay.
- User: *[user name]*
    - This user name is used when making SSH connection.
{% endcomment %}
- Work base dir: *~/oacis_work*
    - The directories for job executions are created under this directory.
- Mounted work base dir: *~/oacis_work*
    - For this tutorial, please fill in the same path as the *work base dir*.
- Polling interval: *5*
    - Worker checks the status of the remote host with this interval in seconds. The unit is  For this tutorial, we adopt a shorter duration since we would like to check the results quickly.

The specification of these fields are shown in [another page]({{ site.baseurl }}/{{ page.lang }}/configuring_host.html#host_specification).
If you are going to register another computational host, please refer to this page.

## 2. Registering a Simulator

We are going to register a command to run the simulator on OACIS.
OACIS embeds the registered command into a shell script and then execute it. This command-line based implementation makes it possible to run various simulators implemented in any programming language.
In order to execute simulators from OACIS, your simulator must satisfy the following requirements.

- The output files or directories must be created in the current directory.
    - OACIS creates a temporary directory for each job and executes the job in that temporary directory. All the files and directories in the temporary directory are stored in OACIS as the simulation outputs.
- Simulator must receive input parameters as either command line arguments or JSON file. You can choose one of these when registering the simulator on OACIS.
    - If you choose the former one as a way to set input parameters, the parameters are given as the command line arguments in the defined sequence with a trailing random number seed.
        - For example, if an input parameter is "*param1=100, param2=3.0, random number seed=12345*", the following command is embedded in the shell script.
            -  `~/path/to/simulator.out 100 3.0 12345`
    - If you choose JSON format as a way to set input parameters, a JSON file named **_input.json** is prepared in the temporary directory before execution of the jobs. Simulator must be implemented such that it reads the json file in the current directory.
        - `{"param1":100,"param2":3.0,"_seed":12345}`
            - Random number seed is specified by the key *"_seed"*.
        - The command is executed without command line argument as follows.
            - `~/path/to/simulator.out`
- The simulator must work even with the files listed below in the current directory. These files must not be overwritten.
    - *_input.json* , *_output.json* , *_status.json* , *_time.txt*, *_version.txt*
    - These files are used by OACIS in order to record the information of the job. Avoid conflicts with these files.
- The simulator must return 0 when finished successfully. The return code must be non-zero when an error occurs during the simulation.
    - OACIS judges if the job finished successfully or not based on the return code.

Simulators must be prepared on the computational host in advance, i.e., the code must be compiled beforehand.
If you would like to run a simulator on more than one computational host, the simulator on these hosts must be in the same path. This is because the same command is embedded in the shell script.
In order to do so, we recommend to specify the path as a relative path from the home directory like *"~/my_project/my_simulator.out"*.


The traffic simulator we are going to use satisfies all the above requirements. Let us register the simulator on OACIS.

<iframe width="420" height="315" src="https://www.youtube.com/embed/tF_9EYMxVoA" frameborder="0" allowfullscreen class="youtube"></iframe>

From the top page, click the *[New Simulator]* button to go to the registration page of a simulator.
In this page, fill in the information of the simulator. For the full list of the specifications of these fields, visit [Specification of Simulators]({{ site.baseurl }}/{{ page.lang }}/configuring_simulator.html#simulator_specification).

In this tutorial, we setup the simulator as follows. Leave the unspecified fields with default values.

- Name: NS\_model
- Definition of Parameters:
    - [L, Integer, 100]
    - [Vmax, Integer, 5]
    - [density, Float, 0.3]
    - [p\_d, Float, 0.1]
    - [t\_init, Integer, 100]
    - [t\_measure, Integer, 100]
- Command: `~/nagel_schreckenberg_model/run.sh` (This is the path of the simulator you prepared.)
- Input type: Argument (Input parameters are given as the command line arguments.)
- Executable_on: check on "localhost"

If there is an inconsistency between the default value and type of parameter definitions, an error happens and you are required to fix the wrong field.

## 3. Making a ParameterSet

After you make a simulator, then a list of ParameterSets in the simulator is displayed.
At this moment, the list is empty since no ParameterSet is created. After you create ParameterSets, they are displayed on this page.

To make a ParameterSet, click the [New Parameter Set] button.

<iframe width="420" height="315" src="https://www.youtube.com/embed/hzVnuW2M7oc" frameborder="0" allowfullscreen class="youtube"></iframe>

You will find a form as in the above video. Fill in the parameters you want to create and set "Target # of Runs" to 0. Click [Create] to create a ParameterSet.
(For your information, we can create runs as well as the ParameterSets by setting the number of runs to a non-zero value. However, let us keep the number of runs "0" for simplicity for now.)

(Tips) You may create multiple ParameterSets at once if you fill in multiple values in a comma separated format. Since it may take some time, we limit the maximum number of runs that we can create at once to 100.

For this tutorial, let us create a ParameterSet with the default values.

## 4. Making a Run

Let us create runs for the created ParameterSet in order to execute simulation jobs.
See the section titled *"Create New Runs"*. You will find a form to fill in the number of runs (**# of Runs**) and the host the jobs are submitted (**Submitted to**).

<iframe width="420" height="315" src="https://www.youtube.com/embed/p6q9FYIxAIQ" frameborder="0" allowfullscreen class="youtube"></iframe>

(Warning) If no host is displayed in the **Submitted to**, then probably you forgot to specify the executable host when registering a simulator.
In that case, please edit the simulator information and fix the executable host field properly.

If the computational host requires additional parameters to submit a job, fields to set these parameters are also shown. Please see the next page for details.

So, let us make a run for this ParameterSet.
Fill in "1" and "localhost" for "# of Runs" and "Submitted to" fields, respectively.

When a run is created, a job is submitted to the computational host in the background automatically.

## 5. Checking the results

When a job is finished on the computational host, the results files are automatically included into the database of OACIS.
For this tutorial, it will take about 10 seconds to see the status of the run change to *"finished"*.
(If the job execution fails, you will find the status *"failed"*. Even if the job failed, the files are stored in the database. So you can investigate the cause of an error from these files.)

If you click a run, you can find a list of the output files from a browser.
All the files created in the temporary directory are stored in this place.
Contents of figure files, such as png, jpg, and bmp files, are also displayed.

If your output files contains a JSON file named "_output.json", you can save the contents of the JSON file to MongoDB. The values saved in MongoDB can be plotted on the web browser front-end provided by OACIS. We will show how to make a plot on a browser.

If you click the *"About"* tab, you will find more detailed logs such as executed date, elapsed time, and cpu time.
The path where the output files are stored is also shown in this page. Using the path, you can directly access the output files using a file browser or a terminal.

## 6. Sweeping parameter space

We have learned how to make ParameterSets and runs. We have also learned how to see the output files.
Next let us make multiple ParameterSets at once in order to investigate the parameter dependence of the simulator.

In this tutorial, we are going to change two parameters: the density and the maximum velocity. We create ParameterSets with five different values for each of these parameters. So we are going to create 30 ParameterSets in total.

<iframe width="420" height="315" src="https://www.youtube.com/embed/Lnta80r7vCA" frameborder="0" allowfullscreen class="youtube"></iframe>

Click the [New Parameter Set] button from the page showing the list of ParameterSets. You will find a form to create a ParameterSet as we have seen in step 3.
If you find a multiple value in a field, multiple ParameterSets are simultaneously created.
Let us fill in *"3,4,5,6,7"* and *"0.05,0.1,0.2,0.3,0.4,0.5"* at the "Vmax" and "density" fields, respectively.

Then, set *"Target # of Runs"* to 1. One run is created for each ParameterSet. Click the [Create] button, then 30 ParameterSets and 30 runs are created.
(More precisely speaking, 29 ParameterSets are newly created since one of them is identical to the one we have already created.)

If you click the [Runs] button in the navigation bar, you can check the list of running, submitted, and created runs.
The status *"created*" means that a job is not submitted to the job scheduler.
Here, the status *"running"* means that a job is running on a computational host.
The status *"submitted"* means that a job has been submitted to a job scheduler but is not running yet.
Since this list shows the status of all the jobs, it might be more convenient for you to see the overview of the job status.

If you make many runs, it is tedious (or hardly possible) to see the results one by one.
In order to quickly get a view of these results, OACIS provides a UI. With this UI, you can quickly investigate the parameter dependence.

<iframe width="420" height="315" src="https://www.youtube.com/embed/QXOycX9fnOw" frameborder="0" allowfullscreen class="youtube"></iframe>

First, let us investigate the parameter dependence of the total amount of traffic flow.
Select one of the ParameterSets from the list of ParameterSet and select the *"Plot"* tab.
Select [Line plot]-[density]-[flow] and click [Add line plot].
OACIS collects all the ParameterSets which have a different "density" parameter from the selected ParameterSet, and calculates the average value of flow for each ParameterSet and shows the dependence on density as a line plot.
If you increase the density, you will find an initial increasing behavior up to a certain critical density. When the density is larger than the critical value, the flow shows a decreasing trend as a function of the density.
If you double-click one of the data points, a page for the ParameterSet is opened in another tab, where you can check the details of the ParameterSet and its runs.

Let us also see the parameter dependence of the snapshots.
Select [Figure viewer]-[density]-[Vmax]-[/traffic.png] and click [Add figure viewer].
Snapshot figures are displayed on a scatter plot whose horizontal and vertical axes are density and Vmax, respectively.
If you move your mouse over these snapshots, you will see a magnified figure.
In this way, you can intuitively see how the snapshots change as these parameter values change.

Let us investigate the behavior in more detail at around the optimal density.
Go to the page of creating ParameterSets. Fill in *"3,4,5,6,7"* for Vmax, and *"0.05, 0.1, 0.15, 0.2, 0.25, 0.3"* for density.
In order to reduce statistical errors, let us set "Number of Runs" to 5.

<iframe width="560" height="315" src="https://www.youtube.com/embed/BBdLcDwtLcI" frameborder="0" allowfullscreen class="youtube"></iframe>

After the execution of these runs, you will find more detailed behavior at around the optimal density.

