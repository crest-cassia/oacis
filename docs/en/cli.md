---
layout: default
title: "Command Line Interface"
lang: en
next_page: mcp
---

# Command Line Interface(CLI)

---

In addition to the interactive operations available through the web browser, OACIS provides a command line program (CLI) for creating Simulators, ParameterSets, and Runs from the command line.
This is useful not only when you want to create a large number of ParameterSets or Runs at once (which is cumbersome through the interactive UI) but also when you want to operate OACIS from another program.
This page explains the basic usage of the CLI.


## List of available operations

The following operations are available through the CLI.

- Show the list of registered hosts (show_host)
- Create a template for a Simulator (simulator_template)
- Create a Simulator (create_simulator)
- Create a template for ParameterSets (parameter_sets_template)
- Create ParameterSets (create_parameter_sets)
- Destroy ParameterSets (destroy_parameter_sets)
- Create a template for job parameters (job_parameter_template)
- Create Runs (create_runs)
- Check the status of created Runs (run_status)
- Destroy Runs (destroy_runs)
- Destroy Runs specified by IDs (destroy_runs_by_ids)
- Replace Runs (replace_runs)
- Replace Runs specified by IDs (replace_runs_by_ids)
- Create a template for an Analyzer (analyzer_template)
- Create an Analyzer (create_analyzer)
- Create a template for Analyses (analyses_template)
- Create Analyses (create_analyses)
- Check the status of created Analyses (analysis_status)
- Destroy Analyses (destroy_analyses)
- Destroy Analyses specified by IDs (destroy_analyses_by_ids)
- Replace Analyses (replace_analyses)
- Replace Analyses specified by IDs (replace_analyses_by_ids)
- Append a ParameterDefinition to an existing Simulator (append_parameter_definition)

You specify the operation by passing an argument to `bin/oacis_cli`, which is located under the OACIS checkout directory.
For example,

{% highlight sh %}
./bin/oacis_cli usage
{% endhighlight %}

Throughout this document, the command examples assume that they are executed from the OACIS checkout directory, but you may run them from any directory.

---

## usage

Print the usage of each CLI command.

#### How to run

{% highlight sh %}
./bin/oacis_cli usage
{% endhighlight %}

---

## show_host

Get the information of the registered hosts.

#### How to run

{% highlight sh %}
./bin/oacis_cli show_host -o host.json
{% endhighlight %}

#### Options

|----------|--------|--------------------------------|-----------|
|Option    |alias   |description                     |required?  |
|:---------|:-------|:-------------------------------|:----------|
|--output  |-o      |output file path                |yes        |
|----------|--------|--------------------------------|-----------|

#### Output

- The information of the registered hosts is written as an array of Objects in JSON format, as shown below.
- Only the id, name, hostname, and user of each host are output.

{% highlight json %}
[
  {
    "id": "522fe89a899e53ec05000005",
    "name": "localhost",
    "hostname": "localhost",
    "user": "murase"
  }
]
{% endhighlight %}

---

## simulator_template

Create a template of the simulator.json file used by create_simulator.

#### How to run

{% highlight sh %}
./bin/oacis_cli simulator_template -o simulator.json
{% endhighlight %}

#### Options

|----------|--------|--------------------------------|-----------|
|Option    |alias   |description                     |required?  |
|:---------|:-------|:-------------------------------|:----------|
|--output  |-o      |output file path                |yes        |
|----------|--------|--------------------------------|-----------|

#### Output

Output a template of the attributes of a Simulator.

{% highlight json %}
{
  "name": "a_sample_simulator",
  "command": "/Users/murase/program/oacis/lib/lib/samples/tutorial/simulator/simulator.out",
  "support_input_json": false,
  "support_mpi": false,
  "support_omp": false,
  "print_version_command": null,
  "pre_process_script": null,
  "executable_on_ids": [],
  "parameter_definitions": [
    {"key": "p1","type": "Integer","default": 0,"description": "parameter1"},
    {"key": "p2","type": "Float","default": 5.0,"description": "parameter2"}
  ]
}
{% endhighlight %}

---

## create_simulator

Create a new Simulator.

#### How to run
{% highlight sh %}
./bin/oacis_cli create_simulator -h host.json -i simulator.json -o simulator_id.json
{% endhighlight %}

#### Options

|----------|--------|--------------------------------|-----------|
|Option    |alias   |description                     |required?  |
|:---------|:-------|:-------------------------------|:----------|
|--host    |-h      |executable hosts                |no         |
|----------|--------|--------------------------------|-----------|
|--input   |-i      |input file path                 |yes        |
|----------|--------|--------------------------------|-----------|
|--output  |-o      |output file path                |yes        |
|----------|--------|--------------------------------|-----------|

#### Input files

- For the host file, specify the JSON file output by show_host.
- For the input file, specify the JSON file output by simulator_template.
    - You may specify the path to the JSON file, or pass the JSON string directly.

#### Output

Output the id of the newly created simulator as an Object in JSON format.

{% highlight json %}
{
  "simulator_id": "52b3bcd7b93f964178000001"
}
{% endhighlight %}

---

## parameter_sets_template

Create a template of the parameter_sets.json file used by create_parameter_sets.

#### How to run

{% highlight sh %}
./bin/oacis_cli parameter_sets_template -s 5361e421b93f96bbc500000e -o parameter_sets.json
{% endhighlight %}

#### Options

|----------|--------|--------------------------------|-----------|
|Option    |alias   |description                     |required?  |
|:---------|:-------|:-------------------------------|:----------|
|--simulator|-s      |simulator                       |yes        |
|-----------|--------|--------------------------------|-----------|
|--output   |-o      |output file path                |yes        |
|-----------|--------|--------------------------------|-----------|

#### Input files

For the simulator, either pass the ID of the Simulator or specify the JSON file output by create_simulator.

#### Output

Output a template of the parameter file used when creating ParameterSets.

{% highlight json %}
[
  {"p1":0,"p2":5.0}
]
{% endhighlight %}

---

## create_parameter_sets

Create new ParameterSets.

#### How to run

{% highlight sh %}
./bin/oacis_cli create_parameter_sets -s simulator_id.json -i parameter_sets.json -o parameter_set_ids.json
{% endhighlight %}

{% highlight sh %}
./bin/oacis_cli create_parameter_sets -s 5361e421b93f96bbc500000e -i '{"p1":1,"p2":[2.0,3.0]}' -o parameter_set_ids.json
{% endhighlight %}

#### Options

|----------|--------|--------------------------------|-----------|
|Option    |alias   |description                     |required?  |
|:---------|:-------|:-------------------------------|:----------|
|--simulator|-s      |simulator                       |yes        |
|-----------|--------|--------------------------------|-----------|
|--input    |-i      |input json                      |yes        |
|-----------|--------|--------------------------------|-----------|
|--run      |-r      |run-option json                 |yes        |
|-----------|--------|--------------------------------|-----------|
|--output   |-o      |output file path                |yes        |
|-----------|--------|--------------------------------|-----------|

#### Input files

- For the simulator, either pass the ID or specify the JSON file output by create_simulator.
- For the input file, specify the JSON file output by parameter_sets_template.
    - Alternatively, you may specify a JSON string.
    - By specifying an array as a parameter value, you can create multiple parameter sets at once.
- Specify `run` when you want to create Runs for the given ParameterSets at the same time.
    - Specify a JSON string or the path to a JSON file.
    - The format of `run` is as follows.

{% highlight json %}
{
  "num_runs":1,"mpi_procs":1,"omp_threads":1,"priority":1,
  "submitted_to":"522fe89a899e53ec05000005",
  "host_parameters":{"nodes":"1","ppn":"1","walltime":"10:00"}
}
{% endhighlight %}

- Specify the ID of the Host in the "submitted_to" field.
- In the "host_parameters" field, enter the parameters required by each host.
- Runs are created until each ParameterSet has "num_runs" Runs.

#### Output

Output the ids of the newly created ParameterSets as an array of Objects in JSON format.

{% highlight json %}
[
  {"parameter_set_id":"52b3ddc7b93f969b8c000001"}
]
{% endhighlight %}

#### Notes

If a ParameterSet with the same parameter values already exists, the id of the existing ParameterSet is returned as output without creating a new ParameterSet. This is not an error.

---

## destroy_parameter_sets

Destroy all the ParameterSets under the specified Simulator at once.

#### How to run

{% highlight sh %}
./bin/oacis_cli destroy_parameter_sets -s simulator_id.json
{% endhighlight %}

{% highlight sh %}
./bin/oacis_cli destroy_parameter_sets -s 5361e421b93f96bbc500000e
{% endhighlight %}

#### Options

|----------|--------|--------------------------------|-----------|
|Option    |alias   |description                     |required?  |
|:---------|:-------|:-------------------------------|:----------|
|--simulator|-s      |simulator                       |yes        |
|-----------|--------|--------------------------------|-----------|

---

## job_parameter_template

Create a template of the job_parameter.json file used by create_runs and create_analyses.

#### How to run

{% highlight sh %}
./bin/oacis_cli job_parameter_template -h host_id -o job_parameter.json
{% endhighlight %}

#### Options

|----------|--------|--------------------------------|-----------|
|Option    |alias   |description                     |required?  |
|:---------|:-------|:-------------------------------|:----------|
|--host_id |-h      |host or host_group id (string)  |no         |
|----------|--------|--------------------------------|-----------|
|--output  |-o      |output file path                |yes        |
|----------|--------|--------------------------------|-----------|

#### Input

For the host id, specify the id of the Host as a string. If it is not specified, jobs are submitted manually.

#### Output

Output a template of the job parameter file used when creating Runs.

{% highlight json %}
{
  "submitted_to": "522fe89a899e53ec05000005",
  "host_parameters": {
    "nodes": "1",
    "ppn": "1",
    "walltime": "10:00"
  },
  "mpi_procs": 1,
  "omp_threads": 1,
  "priority": 1
}
{% endhighlight %}

---

## create_runs

Create new Runs.

#### How to run

{% highlight sh %}
./bin/oacis_cli create_runs -p parameter_set_ids.json -j job_parameter.json -n 1 -o run_ids.json
{% endhighlight %}

#### Options

|----------------|--------|--------------------------------|-----------|
|Option          |alias   |description                     |required?  |
|:---------------|:-------|:-------------------------------|:----------|
|--parameter_sets|-p      |parameter set id file           |yes        |
|----------------|--------|--------------------------------|-----------|
|--job_parameters|-j      |job parameter file              |yes        |
|----------------|--------|--------------------------------|-----------|
|--number_of_runs|-n      |number of runs (Integer)        |no         |
|----------------|--------|--------------------------------|-----------|
|--output        |-o      |output file path                |yes        |
|----------------|--------|--------------------------------|-----------|

#### Input files

- For the parameter_sets file, specify the JSON file or string output by create_parameter_sets.
- For the job_parameter file, specify the JSON file or string output by job_parameter_template.
- Specify number_of_runs as a number. For each ParameterSet, Runs are created until it has the specified number. The default is 1.

#### Output

Output the ids of the Runs as an array of Objects in JSON format.
Even for Runs that were not newly created, the ids of as many Runs as the number specified by -n are output for each ParameterSet.

{% highlight json %}
[
  {"run_id":"52b3eaebb93f96933f000001"}
]
{% endhighlight %}

#### Notes

If the specified number of Runs already exists, the ids of the existing Runs are returned as output without creating new Runs. This is not an error.

---

## run_status

Check the execution status of Runs.

#### How to run

{% highlight sh %}
./bin/oacis_cli run_status -r run_ids.json
{% endhighlight %}

#### Options

|----------------|--------|--------------------------------|-----------|
|Option          |alias   |description                     |required?  |
|:---------------|:-------|:-------------------------------|:----------|
|--run_ids       |-r      |run id file                     |yes        |
|----------------|--------|--------------------------------|-----------|

#### Input files

For the run_ids file, specify the JSON file output by create_runs.

#### Output

Aggregate the status of the specified Runs and print it to the standard output.

{% highlight json %}
{
  "total": 1,
  "created": 0,
  "submitted": 0,
  "running": 0,
  "failed": 1,
  "finished": 0
}
{% endhighlight %}

---

## destroy_runs

Destroy Runs.

#### How to run

{% highlight sh %}
./bin/oacis_cli destroy_runs -s 5226f430899e532cf6000008 -q status:failed
{% endhighlight %}

#### Options

|----------------|--------|-----------------------------------------|-----------|
|Option          |alias   |description                              |required?  |
|:---------------|:-------|:----------------------------------------|:----------|
|--simulator_id  |-s      |simulator id or path to simulator_id.json|yes        |
|----------------|--------|-----------------------------------------|-----------|
|--query         |-q      |query for runs(Hash)                     |yes        |
|----------------|--------|-----------------------------------------|-----------|

#### Input format

- For simulator_id, specify the ID string or the path to simulator_id.json.
- Specify the query as an associative array.
    - The associative array is specified in the form {key}:{value}.
    - The only allowed keys are "status" and "simulator_version".

#### Examples

- Destroy Runs whose simulator_version is "1.0.0".
{% highlight sh %}
./bin/oacis_cli destroy_runs -s 5226f430899e532cf6000008 -q simulator_version:1.0.0
{% endhighlight %}

- Destroy Runs that have no simulator_version.

{% highlight sh %}
./bin/oacis_cli destroy_runs -s 5226f430899e532cf6000008 -q simulator_version:
{% endhighlight %}

- Destroy Runs whose status is "created" (before job submission).

{% highlight sh %}
./bin/oacis_cli destroy_runs -s 5226f430899e532cf6000008 -q status:created
{% endhighlight %}

---

## destroy_runs_by_ids

Destroy Runs specified by IDs.

#### How to run

{% highlight sh %}
./bin/oacis_cli destroy_runs_by_ids 52f9c5b4b93f963b8f000021 52f9c53db93f96a22200001d
{% endhighlight %}

#### Options

None

#### Input format

- Specify the IDs of the Runs to destroy as arguments.
- If a specified ID is not found, a dialog appears asking whether to destroy the other Runs.

#### Examples

- Destroy the Run whose ID is 52f9c5b4b93f963b8f000021.
{% highlight sh %}
./bin/oacis_cli destroy_runs_by_ids 52f9c5b4b93f963b8f000021
{% endhighlight %}

---

## replace_runs

Destroy the specified Runs and re-create new Runs with the same settings.

#### Use case

This can be used, for example, when you have submitted a large number of jobs but a bug is found in the old code and the experiment needs to be re-run.
The Runs are executed with the same job parameters as the previous Runs (the host to submit to, the number of MPI processes, the number of OMP threads, and the host parameters).
However, the random number seed _seed is changed.

#### How to run

{% highlight sh %}
./bin/oacis_cli replace_runs -s 5226f430899e532cf6000008 -q simulator_version:0.0.1
{% endhighlight %}

#### Options

|----------------|--------|-----------------------------------------|-----------|
|Option          |alias   |description                              |required?  |
|:---------------|:-------|:----------------------------------------|:----------|
|--simulator_id  |-s      |simulator id or path to simulator_id.json|yes        |
|----------------|--------|-----------------------------------------|-----------|
|--query         |-q      |query for runs(Hash)                     |yes        |
|----------------|--------|-----------------------------------------|-----------|

#### Input format

- For simulator_id, specify the ID string or the path to simulator_id.json.
- Specify the query as an associative array.
  - The associative array is specified in the form {key}:{value}.
  - The only allowed keys are "status" and "simulator_version".
  - To specify Runs whose "simulator_version" is empty, use "simulator_version:".

#### Examples

Destroy Runs whose simulator_version is "1.0.0" and re-create new Runs with the same settings.

{% highlight sh %}
./bin/oacis_cli replace_runs -s 5226f430899e532cf6000008 -q simulator_version:1.0.0
{% endhighlight %}

---

## replace_runs_by_ids

Replace Runs specified by IDs.

#### How to run

{% highlight sh %}
./bin/oacis_cli replace_runs_by_ids 52f9c5b4b93f963b8f000021 52f9c53db93f96a22200001d
{% endhighlight %}

#### Options

None

#### Input format

- Specify the IDs of the Runs to replace as arguments.
- If a specified ID is not found, a dialog appears asking whether to replace the other Runs.

#### Examples

- Replace the Run whose ID is 52f9c5b4b93f963b8f000021.
{% highlight sh %}
./bin/oacis_cli replace_runs_by_ids 52f9c5b4b93f963b8f000021
{% endhighlight %}

---

## analyzer_template

Create a template of the analyzer.json file used by create_analyzer.

#### How to run

{% highlight sh %}
./bin/oacis_cli analyzer_template -o analyzer.json
{% endhighlight %}

#### Options

|----------|--------|--------------------------------|-----------|
|Option    |alias   |description                     |required?  |
|:---------|:-------|:-------------------------------|:----------|
|--output  |-o      |output file path                |yes        |
|----------|--------|--------------------------------|-----------|

#### Output

Output a template of the attributes of an Analyzer.

{% highlight json %}
{
  "name": "a_sample_analyzer",
  "type": "on_run",
  "auto_run": "no",
  "files_to_copy": "*",
  "description": "",
  "command": "gnuplot /Users/murase/program/oacis/lib/samples/tutorial/analyzer/analyzer.plt",
  "support_input_json": true,
  "support_mpi": false,
  "support_omp": false,
  "print_version_command": null,
  "pre_process_script": null,
  "executable_on_ids": [],
  "parameter_definitions": [
    {"key": "p1","type": "Integer","default": 0,"description": "parameter1"},
    {"key": "p2","type": "Float","default": 5.0,"description": "parameter2"}
  ]
}
{% endhighlight %}

---

## create_analyzer

Create a new Analyzer.

#### How to run
{% highlight sh %}
./bin/oacis_cli create_analyzer -h host.json -s simulator_id.json -i analyzer.json -o analyzer_id.json
{% endhighlight %}

#### Options

|------------|--------|--------------------------------|-----------|
|Option      |alias   |description                     |required?  |
|:-----------|:-------|:-------------------------------|:----------|
|--host      |-h      |executable hosts                |no         |
|------------|--------|--------------------------------|-----------|
|--simulator |-s      |analyzer's simulator            |yes        |
|------------|--------|--------------------------------|-----------|
|--input     |-i      |input file path                 |yes        |
|------------|--------|--------------------------------|-----------|
|--output    |-o      |output file path                |yes        |
|------------|--------|--------------------------------|-----------|

#### Input files

- For the host file, specify the JSON file output by show_host.
- For the simulator, specify the JSON file output by create_simulator.
- For the input file, specify the JSON file output by analyzer_template.
    - You may specify the path to the JSON file, or pass the JSON string directly.

#### Output

Output the id of the newly created analyzer as an Object in JSON format.

{% highlight json %}
{
  "analyzer_id": "52b3bcd7b93f964178000002"
}
{% endhighlight %}

---

## analyses_template

Create a template of the analysis_parameters.json file used by create_analyses.

#### How to run

{% highlight sh %}
./bin/oacis_cli analyses_template -a 5226f430899e532cf6000009 -o analysis_parameters.json
{% endhighlight %}

#### Options

|--------------|--------|--------------------------------|-----------|
|Option        |alias   |description                     |required?  |
|:-------------|:-------|:-------------------------------|:----------|
|--analyzer_id |-a      |analyzer id                     |yes        |
|--------------|--------|--------------------------------|-----------|
|--output      |-o      |output file path                |yes        |
|--------------|--------|--------------------------------|-----------|

#### Input files

For analyzer_id, specify the ID string.

#### Output

Output a template of the parameter file used when creating Analyses.

{% highlight json %}
[
  {"parameter1":50,"parametr2":1.0}
]
{% endhighlight %}

---

## create_analyses

Create new Analyses.

#### How to run

{% highlight sh %}
./bin/oacis_cli create_analyses -a 5226f430899e532cf6000009 -i analysis_parameters.json -j job_parameter.json -o analysis_ids.json
{% endhighlight %}

#### Options

|-----------------|--------|---------------------------------------------------|-----------|
|Option           |alias   |description                                        |required?  |
|:----------------|:-------|:--------------------------------------------------|:----------|
|--analyzer       |-a      |analyzer id                                        |yes        |
|-----------------|--------|---------------------------------------------------|-----------|
|--input          |-i      |input file path                                    |no         |
|-----------------|--------|---------------------------------------------------|-----------|
|--job_parameters |-j      |job parameter file                                 |yes        |
|-----------------|--------|---------------------------------------------------|-----------|
|--output         |-o      |output file path                                   |yes        |
|-----------------|--------|---------------------------------------------------|-----------|
|--first_run_only |        |only on first runs                                 |no         |
|-----------------|--------|---------------------------------------------------|-----------|
|--target         |-t      |on targets(parmeter_set_ids.json or run_ids.json)  |no         |
|-----------------|--------|---------------------------------------------------|-----------|

#### Input files

- For analyzer, specify the ID of the analyzer.
- For input, specify the JSON file or JSON string output by analyses_template. The default is the default values of the parameters registered in the Analyzer.
- For the job_parameter file, specify the JSON file or string output by job_parameter_template.
- You can specify the target Runs or ParameterSets with the --first_run_only option or the -t option. If neither is specified, Analyses are created for all Runs or ParameterSets.

#### Output

- Output the ids of the Analyses as an array of Objects in JSON format.
- The ids of Analyses that were not newly created are also output.

{% highlight json %}
  [
    {"analysis_id":"52b3eaebb93f96933f00000d"}
  ]
{% endhighlight %}

#### Examples

- Run the analyzer only on one Run of each ParameterSet.

{% highlight sh %}
./bin/oacis_cli create_analyses -a 5226f430899e532cf6000009 -i analysis_parameters.json -j job_parameter.json -o analysis_ids.json --first_run_only
{% endhighlight %}

- Run an analyzer(:on_parameter_set) on the specified ParameterSets.

{% highlight sh %}
./bin/oacis_cli create_analyses -a 5226f430899e532cf6000009 -i analysis_parameters.json -j job_parameter.json -o analysis_ids.json -t parameter_set_ids.json
{% endhighlight %}

- Run an analyzer(:on_run) on the specified Runs.

{% highlight sh %}
./bin/oacis_cli create_analyses -a 5226f430899e532cf6000009 -i analysis_parameters.json -j job_parameter.json -o analysis_ids.json -t run_ids.json
{% endhighlight %}

#### Notes

- If an Analysis already exists, the id of the existing Analysis is returned as output without creating a new Analysis. This is not an error.
- When running an Analyzer on a ParameterSet, no Analysis is created for a ParameterSet that has no Run whose status is finished.

---

## analysis_status

Check the execution status of Analyses.

#### How to run

{% highlight sh %}
./bin/oacis_cli analysis_status -a analysis_ids.json
{% endhighlight %}

#### Options

|----------------|--------|--------------------------------|-----------|
|Option          |alias   |description                     |required?  |
|:---------------|:-------|:-------------------------------|:----------|
|--analysis_ids  |-a      |analysis id file                |yes        |
|----------------|--------|--------------------------------|-----------|

#### Input files

For the analysis_ids file, specify the JSON file output by create_analyses.

#### Output

Aggregate the status of the specified Analyses and print it to the standard output.

{% highlight json %}
  {
    "total": 100,
    "created": 50,
    "running": 0,
    "failed": 1,
    "finished": 49
  }
{% endhighlight %}

---

## destroy_analyses

Destroy Analyses.

#### How to run

{% highlight sh %}
./bin/oacis_cli destroy_analyses -a 5226f430899e532cf6000009 -q status:failed analyzer_version:v0.1.0
{% endhighlight %}

#### Options

|----------------|--------|-----------------------------------------|-----------|
|Option          |alias   |description                              |required?  |
|:---------------|:-------|:----------------------------------------|:----------|
|--analyzer_id   |-a      |analyzer id                              |yes        |
|----------------|--------|-----------------------------------------|-----------|
|--query         |-q      |query for analyses(Hash)                 |yes        |
|----------------|--------|-----------------------------------------|-----------|

#### Input format

- For analyzer_id, specify the ID string.
- Specify the query as an associative array.
    - The associative array is specified in the form {key}:{value}.
    - The only allowed keys are "status" and "analyzer_version".
    - To specify Analyses whose "analyzer_version" is empty, use "analyzer_version:".

#### Examples

Destroy Analyses whose status is "failed" (analysis failed) and whose analyzer_version is "nil".

{% highlight sh %}
./bin/oacis_cli destroy_analyses -a 5226f430899e532cf6000009 -q status:failed analyzer_version:
{% endhighlight %}

---

## destroy_analyses_by_ids

Destroy Analyses specified by IDs.

#### How to run

{% highlight sh %}
./bin/oacis_cli destroy_analyses_by_ids 52f9c5b4b93f963b8f000021 52f9c53db93f96a22200001d
{% endhighlight %}

#### Options

None

#### Input format

- Specify the IDs of the Analyses to destroy as arguments.
- If a specified ID is not found, a dialog appears asking whether to destroy the other Analyses.

#### Examples

- Destroy the Analysis whose ID is 52f9c5b4b93f963b8f000021.
{% highlight sh %}
./bin/oacis_cli destroy_analyses_by_ids 52f9c5b4b93f963b8f000021
{% endhighlight %}

---

## replace_analyses

Destroy the specified Analyses and re-create new Analyses with the same settings.

#### Use case

- You want to re-run the computation with a fixed Analyzer after a bug was found in the Analyzer that was executed.

#### How to run

{% highlight sh %}
./bin/oacis_cli replace_analyses -a 5226f430899e532cf6000009 -q status:finished analyzer_version:v0.1.0
{% endhighlight %}

#### Options

|----------------|--------|-----------------------------------------|-----------|
|Option          |alias   |description                              |required?  |
|:---------------|:-------|:----------------------------------------|:----------|
|--analzyer_id   |-a      |analyzer id                              |yes        |
|----------------|--------|-----------------------------------------|-----------|
|--query         |-q      |query for analyses(Hash)                 |yes        |
|----------------|--------|-----------------------------------------|-----------|

#### Input format

- For analyzer_id, specify the ID string.
- Specify the query as an associative array.
    - The associative array is specified in the form {key}:{value}.
    - The only allowed keys are "status" and "analyzer_version".
    - To specify Analyses whose "analyzer_version" is empty, use "analyzer_version:".

#### Examples

- Destroy Analyses whose status is "finished" and re-create new Analyses with the same settings.

{% highlight sh %}
./bin/oacis_cli replace_analyses -a 5226f430899e532cf6000009 -q status:finished
{% endhighlight %}

---

## replace_analyses_by_ids

Replace Analyses specified by IDs.

#### How to run

{% highlight sh %}
./bin/oacis_cli replace_analyses_by_ids 52f9c5b4b93f963b8f000021 52f9c53db93f96a22200001d
{% endhighlight %}

#### Options

None

#### Input format

- Specify the IDs of the Analyses to replace as arguments.
- If a specified ID is not found, a dialog appears asking whether to replace the other Analyses.

#### Examples

- Replace the Analysis whose ID is 52f9c5b4b93f963b8f000021.
{% highlight sh %}
./bin/oacis_cli replace_analyses_by_ids 52f9c5b4b93f963b8f000021
{% endhighlight %}

---

## append_parameter_definition

Append a new Parameter to the specified Simulator.

#### Use case

Use this when you want to extend an existing Simulator without discarding the existing data.

#### How to run

{% highlight sh %}
./bin/oacis_cli append_parameter_definition -s 522442de899e53dd8d000034 -n "new_param" -t Float -e 0.0
{% endhighlight %}

#### Options

|----------------|--------|-----------------------------------------|-----------|
|Option          |alias   |description                              |required?  |
|:---------------|:-------|:----------------------------------------|:----------|
|--simulator_id  |-s      |simulator id or path to simulator_id.json|yes        |
|----------------|--------|-----------------------------------------|-----------|
|--name          |-n      |name of the new parameter                |yes        |
|----------------|--------|-----------------------------------------|-----------|
|--type          |-t      |type of the new parameter                |yes        |
|----------------|--------|-----------------------------------------|-----------|
|--default       |-e      |default value of the new parameter       |yes        |
|----------------|--------|-----------------------------------------|-----------|

#### Input format

- For simulator_id, specify the ID string or the path to simulator_id.json.
- For name, specify the name of the new parameter. It is an error if it duplicates an existing parameter.
- For type, specify the type of the new parameter. The allowed values are "Integer", "Float", and "String".
- For default, specify the default value of the new parameter.
    - It is an error if it is inconsistent with the type.
    - The parameters of the existing parameter sets are saved with this value.

#### Examples

Append an Integer parameter named "p3" with a default value of 0.

{% highlight sh %}
./bin/oacis_cli append_parameter_definition -s 522442de899e53dd8d000034 -n p3 -t Integer -e 0
{% endhighlight %}

#### Notes

Runs that have already been created are not updated.
