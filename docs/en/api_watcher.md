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
It monitors the progress of submitted jobs, and calls callback functions registered by user's code when the specified job is finished.

You can find some samples in [samples]({{ site.baseurl }}/{{ page.lang }}/api_samples).

## Getting Started

This is an introductory example.
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

## Defining your callback functions

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

### methods of OACIS watcher

- `watch_ps( ps ) {|finished| ... }`
    - The block is called when all the runs under `ps` has completed.
    - The block argument is the completed parameter set.
- `watch_all_ps( [ps1, ps2, ps3, ...] ) {|finished| ... }`
    - The block is called when all the parameter sets have completed.
    - The block argument is an array of the completed parameter sets.

A ParameterSet is regarded as completed when all of its runs become either "finished" or "failed".
It does **not** depend on the status of Analysis.

