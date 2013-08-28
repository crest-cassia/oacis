module JobScriptUtil

  DEFAULT_TEMPLATE = <<-EOS
#!/bin/bash
LANG=C

# VARIABLE DEFINITIONS ------------
CM_RUN_ID=<%= run_id %>
CM_IS_MPI_JOB=<%= is_mpi_job %>
CM_WORK_BASE_DIR=<%= work_base_dir %>
CM_MPI_PROCS=<%= mpi_procs %>
CM_OMP_THREADS=<%= omp_threads %>

# PRE-PROCESS ---------------------
mkdir -p ${CM_WORK_BASE_DIR}
cd ${CM_WORK_BASE_DIR}
mkdir -p ${CM_RUN_ID}
cd ${CM_RUN_ID}
if [ -e ../${CM_RUN_ID}_input.json ]; then
\\mv ../${CM_RUN_ID}_input.json ./_input.json
fi
echo "{" > ../${CM_RUN_ID}_status.json
echo "  \\"started_at\\": \\"`date`\\"," >> ../${CM_RUN_ID}_status.json
echo "  \\"hostname\\": \\"`hostname`\\"," >> ../${CM_RUN_ID}_status.json

# JOB EXECUTION -------------------
export OMP_NUM_THREADS=${CM_OMP_THREADS}
if ${CM_IS_MPI_JOB}
then
  { time -p { { mpiexec -n ${CM_MPI_PROCS} <%= cmd %>; } 1> _stdout.txt 2> _stderr.txt; } } 2>> ../${CM_RUN_ID}_time.txt
else
  { time -p { { <%= cmd %>; } 1> _stdout.txt 2> _stderr.txt; } } 2>> ../${CM_RUN_ID}_time.txt
fi
echo "  \\"rc\\": $?," >> ../${CM_RUN_ID}_status.json
echo "  \\"finished_at\\": \\"`date`\\"" >> ../${CM_RUN_ID}_status.json
echo "}" >> ../${CM_RUN_ID}_status.json

# POST-PROCESS --------------------
cd ..
\\mv -f ${CM_RUN_ID}_status.json ${CM_RUN_ID}/_status.json
\\mv -f ${CM_RUN_ID}_time.txt ${CM_RUN_ID}/_time.txt
tar cf ${CM_RUN_ID}.tar ${CM_RUN_ID}
if test $? -ne 0; then { echo "// Failed to make an archive for ${CM_RUN_ID}" >> ./_log.txt; exit; } fi
bzip2 ${CM_RUN_ID}.tar
if test $? -ne 0; then { echo "// Failed to compress for ${CM_RUN_ID}" >> ./_log.txt; exit; } fi
rm -rf ${CM_RUN_ID}
EOS

  DEFAULT_EXPANDED_VARIABLES = ["run_id", "is_mpi_job", "work_base_dir", "omp_threads", "mpi_procs", "cmd"]

  def self.script_for(run, host)
    default_variables = {
      "run_id" => run.id.to_s,
      "is_mpi_job" => run.simulator.support_mpi ? "true" : "false",
      "work_base_dir" => host.work_base_dir,
      "omp_threads" => run.omp_threads,
      "mpi_procs" => run.mpi_procs,
      "cmd" => run.command_and_input[0].sub(/;$/, '')
    }
    # semi-colon in the last of the command causes bash syntax error

    variables = {}
    variables = run.runtime_parameters.dup if run.runtime_parameters
    variables.update(default_variables)

    expanded_script = expand_parameters(host.template, variables)

    expanded_script.gsub(/(\r\n|\r|\n)/, "\n")
  end

  def self.expand_result_file_and_update_run(run)
    Dir.chdir(run.dir.join('..')) {
      cmd = "tar xjf #{run.id}.tar.bz2"
      system(cmd)
      raise "failed to extract the archive"  unless $?.to_i == 0
    }

    Dir.chdir(run.dir) {
      parsed = JSON.load(File.open("_status.json"))
      run.hostname = parsed["hostname"]
      run.started_at = parsed["started_at"]
      run.finished_at = parsed["finished_at"]
      run.status = (parsed["rc"].to_i == 0) ? :finished : :failed

      File.open("_time.txt", 'r').each do |line|
        if line =~ /^real \d/
          run.real_time = line.sub(/^real /, '').to_f
        elsif line =~ /^user \d/
          # sum up cpu_times over processes
          run.cpu_time = run.cpu_time.to_f + line.sub(/^user /,'').to_f
        end
      end

      json_path = '_output.json'
      run.result = JSON.load(File.open(json_path)) if File.exist?(json_path)
      run.included_at = DateTime.now
      run.save!
    }
  end

  def self.extract_parameters(template)
    template.scan(/<%=\s*(\w+)\s*%>/).flatten.uniq
  end

  def self.expand_parameters(template, parameters)
    replaced = template.dup
    extract_parameters(template).each do |variable|
      value = parameters[variable].to_s
      pattern = /<%=\s*#{variable}\s*%>/
      replaced.gsub!(pattern, value)
    end
    replaced
  end
end
