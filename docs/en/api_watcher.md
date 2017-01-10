---
layout: default
title: "OACIS watcher"
lang: en
next_page: api_samples
---

# OACIS watcher

---

It is often the case that we want to iteratively determine parameters based on the results of finished jobs.
Such case includes optimization of parameters, binary search of phase boundaries, and Markov-chain Monte-Carlo sampling of parameter space.

OACIS watcher, which is one of the libraries implemented in OACIS, is useful for realizing such iterative processes.
It monitors the progress of submitted jobs, and calls callback functions registered by user's code when the specified jobs are finished.
The APIs are provided both in Ruby and in Python.

You can find some samples in [samples]({{ site.baseurl }}/{{ page.lang }}/api_samples).

## Getting Started

This is an introductory example written in Ruby.
It takes 10 arbitrary ParameterSets and registers callback functions for each of them.

```ruby
OacisWatcher::start do |w|                  # call start method, and define callbacks in the block
  puts "Hello OACIS Watcher"                # some initialization
  ParameterSet.all.limit(10).each do |ps|   # taking 10 arbitrary ParameterSet
    w.watch_ps(ps) do |finished|            # defining callback to the ParameterSet
      puts "jobs of ParameterSet #{finished.id} have finished"
    end
  end
end                                         # event loop will start after you defined callbacks
```

Save the above script to "oacis_watcher_sample.rb" and run the script using "oacis_ruby" command.

```
bin/oacis_ruby oacis_watcher_sample.rb
```

If all jobs of these ParameterSets have finished, the script will finish in seconds. If some of the jobs are still running, the script will wait until all the jobs under the specified ParameterSets get completed. You can type "ctrl-c" to gracefully stop monitoring.

A Python script corresponding to the above code would look like the following.

```python
import oacis
w = oacis.OacisWatcher()                              # create an instance of OacisWatcher
def on_ps_finished(ps):                               # define a function which is called when a ParameterSet is completed
    print("jobs of ParameterSet %s have finished" % str(ps.id()) )
for ps in oacis.ParameterSet.all().limit(10):         # taking 10 arbitrary ParameterSet
    w.watch_ps(ps, on_ps_finished)                    # setting callback function to each ParameterSet
w.loop()                                              # starting event loop. The method returns when all the callback functions finished
```

Run the above script as follows. It will do the same thing as the Ruby script.

```
bin/oacis_python oacis_watcher_sample.py
```

## Defining your callback functions in Ruby

In order to define callback functions, prepare a ruby script file.
Call `OacisWatcher.start`, and define your callbacks in the given block. Monitoring will start after the block is evaluated.
A script would look like the following.

```ruby
OacisWatcher.start do |w|       # w is an instance of OacisWatcher
  # some initialization
  ...

  w.watch_ps( ps ) do |finished|
    # callback function which is called when runs of the watched PS are finished.
    # you can also define another callback here.
    ...
  end
end
```

The method continues until all the callbacks have completed. In other words, `OacisWatcher.start` method returns when all the callbacks are finished.

You can recursively define another callback from inside of a callback functions. Thus, we can iterate job creation until a condition is satisfied.

The available methods of OACIS watcher are

- `watch_ps( ps ) {|finished| ... }`
    - Registers the block which is called when `ps` has completed.
    - The block argument is the completed parameter set.
- `watch_all_ps( [ps1, ps2, ps3, ...] ) {|finished| ... }`
    - Registers the block which is called when all the parameter sets in the argument have completed.
    - The block argument is an array of the completed parameter sets.

## Defining your callback functions in Python

Import `oacis` module and create an instance of `oacis.OacisWatcher`.
Then call `watch_ps` or `watch_all_ps` methods to register your callback functions.
Finally, call `loop` method, which will start the event loop monitoring the completion of the jobs.
The `loop` method returns after all the registered callback functions have been called.

```python
import oacis
w = oacis.OacisWatcher()

# add some initialization here if necessary
# ...

def my_callback(finished_ps):   # definition of callback function. The argument is the finished ParameterSet object.
    # do something

w.watch_ps( ps, my_callback )   # registers callback functions.
# You can register multiple functions by calling the method several times.

w.loop()                        # monitoring will start when this method is called.
```

The available methods of OACIS Watcher are

- `watch_ps( ps, callback_func )`
    - Registers `callback_func` as the callback function which is called when all the runs under `ps` has completed.
    - The argument of the callback function is the completed parameter set.
- `watch_all_ps( list_of_parameter_sets, callback_func )`
    - Registers `callback_func` as the callback function which is called when all the parameter sets in the list have completed.
    - The argument of the callback function is a list of the completed parameter sets.

You can recursively define another callback from inside of a callback functions.

### Definition of "completed" ParameterSet

A ParameterSet is regarded as completed when all of its runs become either "finished" or "failed".
It does **not** depend on the status of Analysis.

