module JobScriptUtil

  DEFAULT_TEMPLATE = <<-EOS
#!/bin/bash
LANG=C

# VARIABLE DEFINITIONS ------------
OACIS_RUN_ID=<%= run_id %>
OACIS_IS_MPI_JOB=<%= is_mpi_job %>
OACIS_WORK_BASE_DIR=<%= work_base_dir %>
OACIS_MOUNTED_WORK_BASE_DIR=<%= mounted_work_base_dir %>
OACIS_MPI_PROCS=<%= mpi_procs %>
OACIS_OMP_THREADS=<%= omp_threads %>
OACIS_PRINT_VERSION_COMMAND="<%= print_version_command %>"

# PRE-PROCESS ---------------------
mkdir -p ${OACIS_WORK_BASE_DIR}
cd ${OACIS_WORK_BASE_DIR}
mkdir -p ${OACIS_RUN_ID}
cd ${OACIS_RUN_ID}
if [ -e ../${OACIS_RUN_ID}_input.json ]; then
\\mv ../${OACIS_RUN_ID}_input.json ./_input.json
fi
echo "{" > ../${OACIS_RUN_ID}_status.json
echo "  \\"started_at\\": \\"`date`\\"," >> ../${OACIS_RUN_ID}_status.json
echo "  \\"hostname\\": \\"`hostname`\\"," >> ../${OACIS_RUN_ID}_status.json

# PRINT SIMULATOR VERSION ---------
if [ -n "$OACIS_PRINT_VERSION_COMMAND" ]; then
  (eval ${OACIS_PRINT_VERSION_COMMAND}) > _version.txt
fi

# JOB EXECUTION -------------------
export OMP_NUM_THREADS=${OACIS_OMP_THREADS}
if ${OACIS_IS_MPI_JOB}
then
  { time -p { { mpiexec -n ${OACIS_MPI_PROCS} <%= cmd %>; } 1>> _stdout.txt 2>> _stderr.txt; } } 2>> ../${OACIS_RUN_ID}_time.txt
else
  { time -p { { <%= cmd %>; } 1>> _stdout.txt 2>> _stderr.txt; } } 2>> ../${OACIS_RUN_ID}_time.txt
fi
echo "  \\"rc\\": $?," >> ../${OACIS_RUN_ID}_status.json
echo "  \\"finished_at\\": \\"`date`\\"" >> ../${OACIS_RUN_ID}_status.json
echo "}" >> ../${OACIS_RUN_ID}_status.json

# POST-PROCESS --------------------
cd ..
\\mv -f ${OACIS_RUN_ID}_status.json ${OACIS_RUN_ID}/_status.json
\\mv -f ${OACIS_RUN_ID}_time.txt ${OACIS_RUN_ID}/_time.txt
tar cf ${OACIS_RUN_ID}.tar ${OACIS_RUN_ID}
if test $? -ne 0; then { echo "// Failed to make an archive for ${OACIS_RUN_ID}" >> ./_log.txt; exit; } fi
bzip2 ${OACIS_RUN_ID}.tar
if test $? -ne 0; then { echo "// Failed to compress for ${OACIS_RUN_ID}" >> ./_log.txt; exit; } fi
if ! ${OACIS_MOUNTED_WORK_BASE_DIR}
then
  rm -rf ${OACIS_RUN_ID}
fi
EOS

  DEFAULT_EXPANDED_VARIABLES = ["run_id", "is_mpi_job", "work_base_dir", "mounted_work_base_dir", "omp_threads", "mpi_procs", "cmd", "print_version_command"]

  def self.script_for(run, host)
    default_variables = {
      "run_id" => run.id.to_s,
      "is_mpi_job" => run.simulator.support_mpi ? "true" : "false",
      "work_base_dir" => host ? host.work_base_dir : '.',
      "mounted_work_base_dir" => host ? host.mounted_work_base_dir.to_s : "false",
      "omp_threads" => run.omp_threads,
      "mpi_procs" => run.mpi_procs,
      "cmd" => run.command_and_input[0].sub(/;$/, ''),
      "print_version_command" => run.simulator.print_version_command.to_s.gsub(/\"/, '\\"')
    }
    # semi-colon in the last of the command causes bash syntax error

    variables = {}
    variables = run.host_parameters.dup if run.host_parameters
    variables.update(default_variables)

    template = host ? host.template : DEFAULT_TEMPLATE
    rendered_script = SafeTemplateEngine.render(template, variables)
    rendered_script.gsub(/(\r\n|\r|\n)/, "\n")
  end

  def self.expand_result_file(run)

    Dir.chdir(run.dir.join('..')) {
      cmd = "tar xjf #{run.id}.tar.bz2"
      system(cmd)
      raise "failed to extract the archive"  unless $?.to_i == 0
    }
  end

  def self.update_run(run)

    Dir.chdir(run.dir) {
      is_updated = false

      if File.exist?("_status.json")
        begin
          parsed = JSON.load(File.open("_status.json"))
          run.hostname = parsed["hostname"]
          run.started_at = parsed["started_at"]
          run.finished_at = parsed["finished_at"]
          run.status = (parsed["rc"].to_i == 0) ? :finished : :failed
          is_updated = true
        rescue => ex
          $stderr.puts ex.message
        end
      end

      if File.exist?("_time.txt")
        begin
          File.open("_time.txt", 'r').each do |line|
            if line =~ /^real \d/
              run.real_time = line.sub(/^real /, '').to_f
            elsif line =~ /^user \d/
              # sum up cpu_times over processes
              run.cpu_time = run.cpu_time.to_f + line.sub(/^user /,'').to_f
            end
          end
          is_updated = true
        rescue => ex
          $stderr.puts ex.message
        end
      end

      if File.exist?("_version.txt")
        begin
          version = File.open("_version.txt", 'r').read.chomp
          run.simulator_version = version
          is_updated = true
        rescue => ex
          $stderr.puts ex.message
        end
      end

      json_path = '_output.json'
      if File.exist?(json_path)
        begin
          run.result = JSON.load(File.open(json_path))
          run.result = {"result"=>run.result} unless run.result.is_a?(Hash)
          is_updated = true
        rescue => ex
          $stderr.puts ex.message
        end
      end

      if is_updated
        run.included_at = DateTime.now
        run.save!
      end
    }
  end
end
