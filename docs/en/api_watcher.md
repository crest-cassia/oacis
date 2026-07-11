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

You can find some samples in [samples]({{ site.baseurl }}/{{ page.lang }}/api_samples.html).

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

```shell
bin/oacis_ruby oacis_watcher_sample.rb
```

If all jobs of these ParameterSets have finished, the script will finish in seconds. If some of the jobs are still running, the script will wait until all the jobs under the specified ParameterSets get completed. You can type "ctrl-c" to gracefully stop monitoring.

## Ruby Interface

### Defining your callback functions in Ruby

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

- `#watch_ps( ps ) {|finished| ... }`
    - Registers the block which is called when `ps` has completed.
    - The block argument is the completed parameter set.
- `#watch_all_ps( [ps1, ps2, ps3, ...] ) {|finished| ... }`
    - Registers the block which is called when all the parameter sets in the argument have completed.
    - The block argument is an array of the completed parameter sets.

### Async/Await methods

<span class="label label-success">New in v2.13.0</span>

Altough `watch_ps` interface allows us to define any iterative procedure in principle, it often causes deep nests of callback functions, which is practically very hard to write a code.
One of the well known user-friendly interfaces for such concurrent programs is "async/await" syntax, which is adopted in other languages as well such as ES7 or C#.

Here is an example.

```ruby
OacisWatcher.start do |w|
  w.async do
    # --- (1)
    OacisWatcher.await_ps( ps1 )
    # --- (2)
  end

  w.async do
    # --- (3)
    OacisWatcher.await_all_ps( ps_list )
    # --- (4)
  end
end
```

In the above example, (1) and (3) are evaluated first while keeping (2) and (4) unexecuted. After the jobs for "ps1" and "ps_list" are finished, (2) and (4) are executed, respectively.
With these methods, we can write a asynchronous program similarly as for synchronous programs. This is much easier to understand compared to defining callback functions.

The available methods in `OacisWatcher` class are as follows.

- `#async { ... }`
    - The blocks are evaluated concurrently. In this block, you can call `await` methods.
    - An alias method `do_async` is also available in v3.3.
- `OacisWatcher.await_ps( ps )`
    - Block the execution until a ParameterSet "ps" becomes completed.
- `OacisWatcher.await_all_ps( ps_list )`
    - Block the execution until all the ParameterSets in "ps_list" become completed.

## Definition of "completed" ParameterSet

A ParameterSet is regarded as completed when all of its runs become either "finished" or "failed".
It does **not** depend on the status of Analysis.

