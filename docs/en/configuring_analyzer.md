---
layout: default
title: "Configuring Analyzer"
lang: en
next_page: cli
---

# {{ page.title }}

It is often necessary to do some post-process against simulation results, such as statistical analysis and visualization.
OACIS provides a way to conduct such post-processes as well. The post-processes is called **Analyzer** in OACIS.
In this page, we are goint to describe how to define an analyzer and execute it.

* TOC
{:toc}

---

## Registering an analyzer

You can define two types of analyzers. One is analyzers conducted against the simulation result of a single Run. The other one is analyzers conducted against the simulation results for all the runs in a single ParameterSet. Hereafter, we call them **Run-Analyzer**, **PS-Analyzer** for explanation.
Examples of Run-Analyzer include visualization of simulation snapshot, conducting a Fourier transformation against a certain time series, and calculation of a certain quantity based on a result of a single job.
Examples of **PS-Analyzer** include a statistical analysis conducted over independent Monte-Carlo runs, such as calculation of statistical average, variance, and errors.

In OACIS, a result of Analyzer is called **Analysis**. The relation between Analyzer and Analysis is similar to the relation between Simulator and Run. Analyzer can make multiple Analyses against Run or ParameterSet.

Execution sequence of an Analyzer is quite similar to that of a Simulator.

- Worker process makes an SSH connection to the specified computational host.
- A temporary directory (called work directory) for each analysis is created. All the files created in the work directory is included in the OACIS as the result of this analysis.
- The directory *_input* is created, where the target result files are copied.
- Then, a shell script containing the command to execute the Analyzer is created. The script is called "job script".
- The job script is then submitted to the job scheduler in the computational host.
- Worker periodically checks if the job is finished.
- When the job finished, all the files included in the work directory are downloaded and stored in the database. Log information, such as execution date, elapsed time, and executed host are recorded as well.

Similarly to Simulators, you can define *pre-process* to prepare prerequisites. *print\_version\_command* is also available to record the version information of the Analyzer.
If **_ouptut.json** file is included in the work directory, the contents of the JSON file is recorded in DB. Such values can be plotted on OACIS web-UI. This is exactly the same specification with that of Simulator. 

You can also define parameters for Analyzers. If you define some parameters, you can specify the value of the parameters when you make an Analysis.

The fundamental difference of Analyzer from Simulator is that the target files (i.e. result files of Runs) are copied to the working directory.
For Run-Analyzer, the result files of the target Run are copied to the *_input* directory in the work directory. For PS-Analyzer, all the result files of the target Runs are copied.
Analyzers must be implemented so that they analyze the files in *_input* directory.
The detailed location of the input files are shown later in the following.

### Requirements for Analyzer

Analyzers must satisfy the following requirements.

1. The output files or directories must be created in the current directory.
    - OACIS creates a work directory for each job and executes the job in that directory. All the files and directories in the work directory are stored in OACIS as the outputs.
2. (Optional) Analyzer can take input parameters. In that case, an analyzer must receive input parameters as either command line arguments or JSON file. You can choose one of these when registering an analyzer on OACIS.
    - If you choose the former one as a way to set input parameters, the parameters are given as the command line arguments in the defined sequence with a trailing random number seed.
        - For example, if an input parameter is "*param1=100, param2=3.0, random number seed=12345*", the following command is embedded in the shell script.
            -  `~/path/to/simulator.out 100 3.0 12345`
    - If you choose JSON format as a way to set input parameters, a JSON file named **_input.json** is prepared in the temporary directory before execution of the jobs. An analyzer must be implemented such that it reads the json file in the current directory.
        - `{"param1":100,"param2":3.0,"_seed":12345}`
            - Random number seed is specified by the key *"_seed"*.
        - The command is executed without command line argument as follows.
            - `~/path/to/simulator.out`
3. An analyzer must work even with the files listed below in the current directory. These files must not be overwritten.
    - *_input.json* , *_output.json* , *_status.json* , *_time.txt*, *_version.txt*
    - These files are used by OACIS in order to record the information of the job. Avoid conflicts with these files.
4. An analyzer must return 0 when finished successfully. The return code must be non-zero when an error occurs during the simulation.
    - OACIS judges if the job finished successfully or not based on the return code.

### An Example of Run-Analyzer

Here, we are going to show an example of a Run-Analyzer.

Suppose you are going to implement an analyzer, which makes a plot showing the time series data created by a simulator.
Let us assume that the simulator creates a file *sample.dat* in the following format. The first and the second columns respectively shows the time and data.

```
1 0.25
2 0.3
3 0.4
...
```

When conducting an analyzer, all the result files of a Run is stored in *_input/* directory. Hence, an analyzer must be implemented so that it reads the file in *_input/* directory.

[Tips] If you do not need all the files of a Run, you can specify the name of the files that need to be copied. When registering an analyzer, fill in the pattern of the file names to `Files to Copy` field.
The files which matched the pattern are copied to the *_input/* directory in the work directory.
You can use a wild card ('\*') in the pattern. The default value for this field is '\*', letting all the files to be copied by default.

Suppose you would like to plot the time series data shown above using "gnuplot".
Make an input file for gnuplot as follows. Suppose that the plot file is located in *~/path/to/plotfile.plt*.

```
set term postscript eps
set output "sample.eps"
plot "_input/time_series.dat" w l
```

Now an analyzer program is ready. Let us move to registering it on OACIS.
Open a page for a simulator and click [About] tab. You'll find a button **[New Analyzer]**, which is for registering a new analyzer on OACIS.
If you click the button, you will find a form as follows.

![Registering an analyzer]({{ site.baseurl }}/images/new_analyzer.png){:width="400px"}

Fill in the form to define the define the specification of an analyzer.
For this analyzer, fill in the form as follows. Leave the other fields as they are.
For the full list of these fields, see [Setting Items of Analyzers](#analyzer_specification).

- Name: "plot_timeseries" (An arbitrary name which consists of ASCII characters are OK.)
- Type: "on_run"
- Command: "gnuplot ~/path/to/plotfile.plt"

Click **[Create Analyzer]** button to finish the registration.

After you registered an analyzer, you can execute an analyzer from the UI after a Run is finished.
When an analysis is created, it is executed in the background as in the case of a Run. After an analysis finished, you can see all the results in the browser.

Although this sample is not the case, you can define an analyzer which accepts input parameters.
In that case, the input parameters are given by command line arguments or a JSON file "*_input.json*".

The format of *_input.json* is as follows. The JSON contains the fields **"analysis_parameters"**, **"simulation_parameters"**.
The field "analysis\_parameters" indicates the parameters for this analyzer while the field "simulation\_parameters" indicates the parameters used for a Run.

```shell
{
 "analysis_parameters": {
   "x": 0.1,
   "y": 2
 },
 "simulation_parameters": {
   "L": 32,
   "T": 0.5,
   "_seed": 1787809130
 }
}
```

### An Example of PS-Analyzer

You can define a PS-Analyzer almost similarly to a Run-Analyzer.
The differences from a Run-Analyzer is the format of *_input.json* and the files in *_input/* directory.

The file structure of the *_input/* directory is as follows.

```
_input/
  #{run_id1}/     # the results of run_id1
    xxx.txt
    yyy.txt
  #{run_id2}/     # the results of run_id2
    xxx.txt
    yyy.txt
 .....            # all the result files for Runs whose status is "finished" continues
```

The format of *_input.json* file is as follows.

```json
{
  "analysis_parameters": {
    "x": 0.1,
    "y": 2
  },
  "simulation_parameters": {
    "L": 32,
    "T": 0.5
  },
  "run_ids": [   // the list of IDs of Runs
    "run_id1",
    "run_id2",
    "run_id3"
  ]
}
```

The following is an example of an analyzer. This is a script to load the specified result files written in Ruby.

```ruby
require 'json'
require 'pathname'
persed = JSON.load(open('_input.json'))
RESULT_FILE_NAME = 'time_series.dat'
result_files = persed["run_ids"].map do |id|
  Pathname.new("_input").join(id).join(RESULT_FILE_NAME)
end
# => ["_input/526638c781e31e98cf000001/time_series.dat", "_input/526638c781e31e98cf000002/time_series.dat"]
```

## Setting Items of Analyzers {#analyzer_specification}

The following is the list of items we set when registering an analyzer.

|----------------------------|---------------------------------------------------------------------|
| field                      | explanation                                                         |
|:---------------------------|:--------------------------------------------------------------------|
| Name *                     | Name of the analyzer. Only alphanumeric characters and underscore (‘_’) are available. Must be unique within in each simualtor. |
| Type *                     | Select *on_run* for a Run-Analyzer. Select *on\_parameter\_set* for a PS-Analyzer.      |
| Definition of Parameters   | Definition of input parameters. Specify name, type(Integer, Float, String), default value, and explanation for each input parameter. |
| Pre process script         | Script executed before the job. If this is empty, no pre-process is executed. |
| Command *                  | The command to execute the analyzer. It is better to specify by the absolute path or the relative path from the home directory. (Ex. ~/path/to/analyzer.out) |
| Print version command      | The command to print the analyzer version information to standard output. (Ex. ~/path/to/analyzer.out –version) |
| Input type                 | How the input parameter is given to the simulator. Select either “Argument” or “JSON”. |
| Files to Copy              | Specify the files to be copied to "_input/" directory by a pattern. The pattern is used by [Dir.glob](http://ruby-doc.org/core-2.2.0/Dir.html#method-c-glob) method of Ruby. The default value is the wild card "\*", indicating that all the files are copied by default. |
| Support MPI                | Whether the simulator is an MPI parallel program or not. If you enable this option, you can specify the number of MPI processes when making a Run. |
| Support MPI                | Whether the simulator is an OpenMP parallel program or not. If you enable this option, you can specify the number of OpenMP threads when making a Run. |
| Auto Run                   | Set "Auto-Run" flag. (Details are shown in the follwoing section) |
| Description                | An explanation of the simulator. You can refer to the explanation from OACIS web UI. Markdown format is available. |
| Executable on              | Specify the hosts on which the simulator can be executed. You can select one of these as the computational host when making a Run. |
| Host for Auto Run          | Specify the host where auto-run is executed (Details are shown in the following section) |
|----------------------------|---------------------------------------------------------------------|

### Auto-Run of Analyzers

You can run analyzers automatically when the target Run or ParameterSet is finished by setting **"Auto Run"** flag when registering an analyzer.
It is convenient to set this flag since you do not have to manually create an analysis for all runs or parameter sets.

For Run-Analyzer, you can select from three options: *"Yes"*, *"No"*, and *"First Run Only"*.

- Yes: Analyzer is executed automatically whenever a Run is finished successfully. (When the status of a Run is "failed", the execution is skipped.)
- No: Analyzer is not automatically executed.
- First Run Only: Analyzer is executed only against the first successful Run for each ParameterSet.
    - This is useful for visualization. It is usually not necessary to conduct visualization for all the Monte Carlo runs since we would like to see a typical snapshot.

For PS-Analyzer, you can select either *"Yes"* or *"No"*.
When it is set to *Yes*, Analyzer is executed when all the Runs under a ParameterSet become *"finished"* or *"failed"*.

