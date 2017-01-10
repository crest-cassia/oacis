---
layout: default
title: "Ruby API"
lang: en
next_page: api_python
---

# How to use APIs

---

OACIS is implemented in Ruby, and has Ruby and Python APIs. You can operate OACIS by writing a script that calls these APIs.
In this page, we will give a brief instruction on how to use the Ruby APIs. 
If you write Python, please go to the [next page](/en/api_python.html).
You can find samples at [samples page](/en/api_samples.html).

## Prerequisites

In the following, we assume that a Simulator "my_simulator" is registered on OACIS, which has three parameters "p1", "p2", and "p3".
We assume that you know the basics of Ruby programming language.

## Executing script

To use OACIS APIs, we can either write a Ruby script or execute in an interactive environment.
We recommend the interactive environment for testing and debugging. Once you fix your procedure, we recommend to use a script.

### Interactive environment

At the project directory of OACIS (the directory where you cloned the source code of OACIS), run `bundle exec rails c`. An interactive shell will be launched, and you can execute the operation on that.

```
$ bundle exec rails c
Loading development environment (Rails 4.2.0)
irb(main):001:0> Simulator.first.name
=> "my_simulator
irb(main):002:0>
```

### Running a script

At the project directory of OACIS (the directory where you cloned the source code of OACIS), run the script with loading `./config/environment.rb` file.

```
$ echo 'p Simulator.first.name' > test.rb   # preparing test.rb
$ bundle exec ruby -r ./config/environment test.rb
"my_simulator"
```

If you would like to run a script from other directory, you also need to set `BUNDLE_GEMFILE` environment variable.
We provide a command `bin/oacis_ruby`, which runs Ruby with loading 'environment.rb' and the necessary environment variable.
Run your script as follows.

```
$ echo 'p Simulator.all.map(&:name)' > test.rb   # preparing test.rb
$ ~/your_path/to/oacis/bin/oacis_ruby test.rb
```

## List of APIs

To operate OACIS, we are going to use the methods of the following classes. Major methods of these classes are shown in the following.

- Simulator
- ParameterSet
- Run
- Host
- Analyzer
- Analysis


These APIs are available for OACIS 2.7.0 or later. If you are using 2.6.0 or earlier, update OACIS first.

### [Optional] Reference materials

The data of OACIS are stored in MongoDB, and Mongoid, which is a library to handle MongoDB from Ruby, is adopted.
[The document of Mongoid](https://docs.mongodb.com/ruby-driver/master/mongoid-tutorials/) helps you understand this page more deeply. Especially the page for [Queries](https://docs.mongodb.com/ruby-driver/master/tutorials/mongoid-queries/) is useful.

In the source code of OACIS, the code for defining the data structure is in the [app/model](https://github.com/crest-cassia/oacis/tree/Development/app/models) directory.

### Simulator

#### getting

```ruby
sim = Simulator.find("...ID...")
```

- Get a simulator by name

```ruby
sim = Simulator.find_by_name("my_simulator")
# If you are using OACIS v2.9.0 or prior, use the following.
#   sim = Simulator.where(name: "my_simulator").first
```

#### referring

```ruby
sim.name  #=> "my_simulator"
sim.parameter_definitions
#=>
[#<ParameterDefinition _id: 522d751f899e533149000003, key: "p1", type: "Integer", default: 1, description: "first parameter">,
 #<ParameterDefinition _id: 522d751f899e533149000004, key: "p2", type: "Integer", default: 1, description: "second parameter">,
 #<ParameterDefinition _id: 522d751f899e533149000005, key: "p3", type: "Float", default: 0.0, description: "third parameter">]
sim.default_parameters
#=> {"p1" => 1, "p2" => 1, "p3" => 0.0}
```

### ParameterSet

#### getting

```ruby
ps = ParameterSet.find("...ID...")
```

- Find a ParameterSet by parameters
    - `Simulator#find_parameter_set` returns nil if a matching ParameterSet is not found.
    - If all the parameters are not specified by the argument, it raises an exception.


```ruby
ps = simulator.find_parameter_set( {"p1"=>1, "p2"=>2.0, "p3"=>0.0} )
```

#### searching

```ruby
sim = Simulator.where(name: "my_simulator").first
sim.parameter_sets.where("v.p1" => 1, "v.p2" => 2).each do |ps|
  puts ps.id
end
```

The above code is searching for a ParameterSet under a given Simulator. The values of parameters are stored in the field "v". Queries on the sub-elements of "v" is used for searching.
After matching ParameterSets are found, an iteration over them is conducted by `each` method.

#### referring

- `v` returns the values of parameters as a Hash.
- `dir` returns the path to the directory where the data are stored.
- `average_result` returns the average (and the number of runs) of the specified result

```ruby
ps.v  #=> {"p1"=>1, "p2"=>2, "p3"=>0.4}
ps.dir  # =><Pathname:/path/to/oacis/public/Result_development/522d751f899e533149000002/522d757d899e53a01400000b>
ps.average_result("result1")   # => [0.25, 5]   Average of "result1" is 0.25, which is averaged over 5 runs
```

#### creating

```ruby
sim.find_or_create_parameter_set( {"p1"=>1, "p2"=>2.0} )
```

If a ParameterSet of `{"p1"=>1, "p2"=>2.0}` already exists, it return that ParameterSet.
If such ParameterSet does not exist, a new ParameterSet is created.

#### removing

```ruby
ps.discard
```

Call `discard` method to remove a ParameterSet. This method automatically removes its sub-elements (i.e., runs and analysis) as well even if remote jobs are running on a remote host.

Do not call `destroy` method, which is defined by Mongoid library but not suitable for removing an element in OACIS.

### Run

#### getting

```ruby
run = Run.find("...ID...")
```

#### searching

```ruby
ps.runs.where( :status => :finished ).each do |run|
  puts run.id
end
```

#### referring

You can get information of a Run as the following.

```ruby
run.status           # => one of [:created,:submitted,:running,:failed,:finished] is returned
run.submitted_to     #=> The host to which a job is submitted to. #<Host _id: 53a3f583b93f964b7f0000fc, ...>
run.host_parameters  #=> {"ppn"=>"1", "walltime"=>"1:00:00"}
run.mpi_procs        #=> 1
run.omp_threads      #=> 1
run.priority         #=> 1
run.result           #=> {"result1"=>-0.016298, "result2"=>0.0264882}
```

#### creating

```ruby
host = Host.find("...HOSTID...")
host_param = {ppn:"4",walltime:"1:00:00"}
# To get default host parameters, the following method is available.
#  host.default_host_parameters

runs = ps.find_or_create_runs_upto( 10, submitted_to: host, host_param: host_param, mpi_procs: 4, priority: 0 )
# The paraemters "host_param", "mpi_procs", "omp_threads", "priority" are optional.
# Priority "0" is the highest priority. You can choose from 0,1, and 2.
```

`ParameterSet#find_or_create_runs_upto` method create runs until the number of Runs becomes the specified number.
If there already exists enough number of Runs, runs are not newly created.
The returned value is an array of Runs.

You can also specify "HostGroup" as follows.

```
host_group = HostGroup.where(name: "my_host_group").first
runs = ps.find_or_create_runs_upto( 10, host_group: host_group)
```

#### removing

```ruby
run.discard
```

### Host

#### getting

```ruby
host = Host.find_by_name("localhost")
# If you are using OACIS v2.9.0 or prior, use the following.
# host = Host.where(name: "localhost").first
```

#### referring

```ruby
host.status       #=> either [:enabled, :disabled] is returned
host.user         #=> user name
host.port         #=> 22
host.ssh_key      #=> '~/.ssh/id_rsa'
host.host_parameter_definitions
=> [#<HostParameterDefinition _id: 57babbb46b696d52bf240000, key: "ppn", default: "1", format: "^[1-9]\\d*$">,
 #<HostParameterDefinition _id: 57babbb46b696d52bf250000, key: "walltime", default: "1:00:00", format: "^\\d+:\\d{2}:\\d{2}$">]
```

For other available fields, refer to [app/models/host.rb](https://github.com/crest-cassia/oacis/blob/Development/app/models/host.rb).

### Analyzer

#### getting

```ruby
azr = Analyzer.find("...ID...")
```

#### searching

```ruby
azr = sim.find_analyzer_by_name("my_analyzer")
# If you are using OACIS v2.9.0 or prior, use the following.
# azr = sim.analyzers.where(name:"my_analyzer").first
```

#### referring

```ruby
azr.support_mpi     #=> true/false
azr.support_omp     #=> true/false
azr.command         #=> execution command
```

### Analysis

#### getting

```ruby
anl = Analysis.find("...ID...")
```

#### searching

To find an Analysis on a ParameterSet, you search for it as `parameter_set.analyses.where`.
For an Analysis on a Run, use `run.analyses.where` idiom.

```ruby
sim = Simulator.find("...ID...")
azr = sim.analyzers.where(name: "my_analyzer").first
ps.analyses.where( analyzer: azr, status: :finished ).each do |anl|
  p anl.id
end
```

#### referring

Almost same set of APIs to those of Runs are available.

```ruby
anl.status           #=> one of [:created,:submitted,:running,:failed,:finished] is returned
anl.submitted_to     #=> #<Host _id: 53a3f583b93f964b7f0000fc, ...>
anl.host_parameters  #=> {"ppn"=>"1","walltime"=>"1:00:00"}
anl.result           #=> {"result1"=>-0.016298, "result2"=>0.0264882}
```

#### creating

When creating an Analysis, we need to specify its Analyzer, host, and host_parameters.

```ruby
host_param = {"ppn"=>"1", "walltime"=>"1:00:00"}
ps.analyses.create!(analyzer: azr, submitted_to: host, host_parameters: host_param )
```

#### removing

```
anl.discard
```

