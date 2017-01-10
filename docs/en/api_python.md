---
layout: default
title: "Python API"
lang: en
next_page: api_watcher
---

# How to use APIs

---

In this page, we are going to demonstrate how to use Python APIs.

Since OACIS is implemented in Ruby, we developed a [library](https://github.com/yohm/rb_call) to call Ruby methods from Python.
Using this library, almost all methods in Ruby is directly translated into Python.

## Prerequisites

In the following, we assume that a Simulator "my_simulator" is registered on OACIS, which has three parameters "p1", "p2", and "p3".
We assume that you know basics of Python programming language.

To use OACIS, Python 3 is necessary. It also requires "msgpack-rpc-python" library.

```
$ pip install msgpack-rpc-python
```

## Executing script

To use OACIS APIs, we can either write a Python script or execute in an interactive environment.
We recommend the interactive environment for testing and debugging. Once you fix your procedure, we recommend to use a script.


### Interactive environment

Run `bin/oacis_python` command in the repository of OACIS and you'll find an interactive shell.
Import `oacis` module to access OACIS APIs.

```
$ ~/oacis/bin/oacis_python
Python 3.5.2 |Continuum Analytics, Inc.| (default, Jul  2 2016, 17:52:12)
[GCC 4.2.1 Compatible Apple LLVM 4.2 (clang-425.0.28)] on darwin
Type "help", "copyright", "credits" or "license" for more information.
>>> import oacis
```

or you can use **ipython** or **Jupyter** if you prefer. In that case, set `PYTHONPATH` environment variable such that you can import `oacis.py`.

```
$ export PYTHONPATH="/path/to/oacis:$PYTHONPATH"
$ ipython
```

### Running a script

You can run a script by giving the path to your script to `oacis_python` command.

```
$ echo 'import oacis; print( oacis.Simulator.first().name() )' > test.py   # preparing test.rb
$ ~/oacis/bin/oacis_python test.py
"my_simulator"
```

## List of APIs

To operate OACIS, we are going to use the methods of the following classes. Major methods of these classes are shown in the following.

- Simulator
- ParameterSet
- Run
- Host
- Analyzer
- Analysis

These APIs are available for OACIS 2.9.0 or later.

### Simulator

#### getting

- Get a simulator by ID

```python
sim = oacis.Simulator.find("...ID...")
```

- Get a simulator by name

```python
sim = oacis.Simulator.find_by_name("my_simulator")
# If you are using OACIS v2.9.0 or prior, use the following.
# sim = oacis.Simulator.where(name="my_simulator").first()
```

#### referring

```python
sim.name()  #=> "my_simulator"

for d in sim.parameter_definitions():
    print( d.inspect() )    # If you call `inspect` method against an instance of RubyObject, you'll have a more human-friendly output
#=>
[#<ParameterDefinition _id: 522d751f899e533149000003, key: "p1", type: "Integer", default: 1, description: "first parameter">,
 #<ParameterDefinition _id: 522d751f899e533149000004, key: "p2", type: "Integer", default: 1, description: "second parameter">,
 #<ParameterDefinition _id: 522d751f899e533149000005, key: "p3", type: "Float", default: 0.0, description: "third parameter">]

sim.default_parameters()
#=> {'p1': 1.0, 'p2': 2.0, 'p3': 3.0}
```

### ParameterSet

#### getting

```python
ps = oacis.ParameterSet.find("...ID...")
```

- Find a ParameterSet by parameters
    - `Simulator#find_parameter_set` returns None if a matching ParameterSet is not found.
    - If all the parameters are not specified by the argument, it raises an exception.

```python
sim = oacis.Simulator.where(name: "my_simulator").first()
ps = sim.find_parameter_set( {"p1":1.0, "p2":2.0, "p3":3.0} )
#=> RubyObject( ParameterSet, 70231167310880 )
```

#### searching

```python
sim = Simulator.where(name: "my_simulator").first()
[ ps.id().to_s() for ps in sim.parameter_sets().where({"v.p1":1.0,"v.p2":2.0}) ]
#=> ['5805c089b93f969922b863a9']
```

The above code is searching for a ParameterSet under a given Simulator. The values of parameters are stored in the field "v". Queries on the sub-elements of "v" is used for searching.
After matching ParameterSets are found, an iteration over them is conducted by `for` syntax.

#### referring

- `v()` returns the values of parameters as a Hash.
- `dir()` returns the path to the directory where the data are stored.
- `average_result` returns the average (and the number of runs) of the specified result

```python
ps.v()  #=> {'p1': 1.0, 'p2': 2.0, 'p3': 3.0}
ps.dir().to_s()   # => '/path/oacis/public/Result_development/5805c082b93f969922b863a1/5805c089b93f969922b863a9'
ps.average_result("result1")   # => [0.25, 5]   Average of "result1" is 0.25, which is averaged over 5 runs
```

#### creating

```python
sim.find_or_create_parameter_set( {"p1":1.0, "p2":2.0, "p3": 3.0} )   #=> RubyObject( ParameterSet, 70231135107120 )
```

If a ParameterSet of `{"p1"=>1, "p2"=>2.0}` already exists, it return that ParameterSet.
If such ParameterSet does not exist, a new ParameterSet is created.

#### removing

```python
ps.discard()
```

Call `discard` method to remove a ParameterSet. This method automatically removes its sub-elements (i.e., runs and analysis) as well even if remote jobs are running on a remote host.

### Run

#### getting

```python
run = oacis.Run.find("...ID...")
```

or

```
run = parameter_set.runs()[0]   # getting the first Run of a PS
```

#### searching

```python
for run in ps.runs().where( {'status': 'finished'} ):
    print( run.id() )
```

#### referring

You can get information of a Run as the following.

```python
run = ps.runs().where( {'status': 'finished'} )[0]
run.status()         #=> either 'created', 'submitted', 'running', 'finished', or 'failed'
run.submitted_to()   #=> The host to which a job is submitted to.
run.host_parameters()#=> {"ppn": "1", "walltime": "1:00:00"}
run.mpi_procs()      #=> 1
run.omp_threads()    #=> 1
run.priority()       #=> 1
run.result()         #=> {"result1": -0.016298, "result2": 0.0264882}
```

#### creating

```python
host = oacis.Host.where(name='localhost').first()
host_param = {'ppn':"4",'walltime':"1:00:00"}
# To get default host parameters, the following method is available.
#  host.default_host_parameters

runs = ps.find_or_create_runs_upto( 10, submitted_to=host, host_param=host_param, mpi_procs=4, priority=0 )
# The keyword arguments "host_param", "mpi_procs", "omp_threads", "priority" are optional.
# For priority, you can choose from [0,1,2], where "0" has the highest priority.
```

`ParameterSet#find_or_create_runs_upto` method create runs until the number of Runs becomes the specified number.
If there already exists enough number of Runs, runs are not newly created.
The returned value is an array of Runs.

You can also specify "HostGroup" as follows.

```
host_group = oacis.HostGroup.where(name="my_host_group").first
runs = ps.find_or_create_runs_upto( 10, host_group=host_group)
```

#### removing

```python
run.discard()
```

### Host

#### getting

```python
host = oacis.Host.find_by_name("localhost")
# If you are using OACIS v2.9.0 or prior, use the following.
# host = oacis.Host.where(name="localhost").first()
```

#### referring

```python
host.status()     #=> either 'enabled' or 'disabled' is returned
host.user()       #=> user name
host.port()       #=> 22
host.ssh_key()    #=> '~/.ssh/id_rsa'
host.host_parameter_definitions().inspect()
=> [#<HostParameterDefinition _id: 57babbb46b696d52bf240000, key: "ppn", default: "1", format: "^[1-9]\\d*$">,
    #<HostParameterDefinition _id: 57babbb46b696d52bf250000, key: "walltime", default: "1:00:00", format: "^\\d+:\\d{2}:\\d{2}$">]
```

For other available fields, refer to [app/models/host.rb](https://github.com/crest-cassia/oacis/blob/Development/app/models/host.rb).

### Analyzer

#### getting

```python
azr = oacis.Analyzer.find("...ID...")
```

#### searching

```python
azr = sim.find_analyzer_by_name("my_analyzer")
# If you are using OACIS v2.9.0 or prior, use the following.
# azr = sim.analyzers().where(name:"my_analyzer").first()
```

#### referring

```python
azr.support_mpi()     #=> true/false
azr.support_omp()     #=> true/false
azr.command()         #=> execution command
```

### Analysis

#### getting

```python
anl = oacis.Analysis.find("...ID...")
```

#### searching

To find an Analysis on a ParameterSet, you search for it as `parameter_set.analyses().where()`.
For an Analysis on a Run, use `run.analyses().where()` idiom.

```python
sim = oacis.Simulator.find("...ID...")
azr = sim.analyzers().where( {"name":"my_analyzer"} ).first
for anl in ps.analyses.where( {"analyzer": azr, "status": "finished"} ):
    print( anl.id() )
```

#### referring

Almost same set of APIs to those of Runs are available.

```python
anl.status()           #=> one of [:created,:submitted,:running,:failed,:finished] is returned.
anl.submitted_to()     #=> #<Host _id: 53a3f583b93f964b7f0000fc, ...>
anl.host_parameters()  #=> {"ppn"=>"1","walltime"=>"1:00:00"}
anl.result()           #=> {"result1"=>-0.016298, "result2"=>0.0264882}
```

#### creating

When creating an Analysis, we need to specify its Analyzer, host, and host_parameters.

```python
host_param = {"ppn": "1", "walltime": "1:00:00"}
ps.analyses().create( analyzer=azr, submitted_to=host, host_parameters=host_param )
```

#### removing

```python
anl.discard()
```

