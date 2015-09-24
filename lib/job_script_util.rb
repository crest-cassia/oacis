module JobScriptUtil

  TEMPLATE = <<-EOS
#!/bin/bash
export LANG=C
export LC_ALL=C

# VARIABLE DEFINITIONS ------------
OACIS_RUN_ID=<%= run_id %>
OACIS_IS_MPI_JOB=<%= is_mpi_job %>
OACIS_MPI_PROCS=<%= mpi_procs %>
OACIS_OMP_THREADS=<%= omp_threads %>
OACIS_PRINT_VERSION_COMMAND="<%= print_version_command %>"

# PRE-PROCESS ---------------------
if [ `basename $(pwd)` != ${OACIS_RUN_ID} ]; then  # for manual submission
  mkdir -p ${OACIS_RUN_ID} && cd ${OACIS_RUN_ID}
  if [ -e ../${OACIS_RUN_ID}_input.json ]; then
    \\mv ../${OACIS_RUN_ID}_input.json ./_input.json
  fi
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
{ time -p { { <%= cmd %>; } 1>> _stdout.txt 2>> _stderr.txt; } } 2>> ../${OACIS_RUN_ID}_time.txt
RC=$?
echo "  \\"rc\\": $RC," >> ../${OACIS_RUN_ID}_status.json
echo "  \\"finished_at\\": \\"`date`\\"" >> ../${OACIS_RUN_ID}_status.json
echo "}" >> ../${OACIS_RUN_ID}_status.json

# POST-PROCESS --------------------
if [ -d _input ] && [ $RC -eq 0 ]; then {
  \\rm -rf _input
} fi
cd ..
\\mv -f ${OACIS_RUN_ID}_status.json ${OACIS_RUN_ID}/_status.json
\\mv -f ${OACIS_RUN_ID}_time.txt ${OACIS_RUN_ID}/_time.txt
tar cf ${OACIS_RUN_ID}.tmp.tar ${OACIS_RUN_ID}
if test $? -ne 0; then { echo "// Failed to make an archive for ${OACIS_RUN_ID}" >> ./_log.txt; exit; } fi
bzip2 ${OACIS_RUN_ID}.tmp.tar
if test $? -eq 0; then {
  mv ${OACIS_RUN_ID}.tmp.tar.bz2 ${OACIS_RUN_ID}.tar.bz2
}
else {
  echo "// Failed to compress for ${OACIS_RUN_ID}" >> ./_log.txt; exit;
} fi
EOS

  EXPANDED_VARIABLES = ["run_id", "is_mpi_job", "omp_threads", "mpi_procs", "cmd", "print_version_command"]

  def self.script_for(job, host)
    variables = {
      "run_id" => job.id.to_s,
      "is_mpi_job" => job.executable.support_mpi ? "true" : "false",
      "work_base_dir" => host ? host.work_base_dir : '.',
      "omp_threads" => job.omp_threads,
      "mpi_procs" => job.mpi_procs,
      "cmd" => job.command_with_args.sub(/;$/, ''),
      "print_version_command" => job.executable.print_version_command.to_s.gsub(/\"/, '\\"')
    }
    # semi-colon in the last of the command causes bash syntax error

    rendered_script = SafeTemplateEngine.render(TEMPLATE, variables)
    rendered_script.gsub(/(\r\n|\r|\n)/, "\n")
  end

  def self.expand_result_file(job)

    Dir.chdir(job.dir.join('..')) {
      cmd = "tar xjf #{job.id}.tar.bz2"
      system(cmd)
      unless $?.to_i == 0
        job.update_attribute(:error_messages, "failed to extract the archive")
        raise "failed to extract the archive"
      end
    }
  end

  def self.update_run(job)

    Dir.chdir(job.dir) {
      is_updated = false
      error_message = job.error_messages || ""

      if File.exist?("_status.json")
        begin
          parsed = JSON.load(File.open("_status.json"))
          job.hostname = parsed["hostname"]
          job.started_at = parsed["started_at"]
          job.finished_at = parsed["finished_at"]
          if parsed["rc"].to_i == 0
            job.status = :finished
          else
            job.status = :failed
            error_message+="simulator return code: #{parsed["rc"]}\n"
          end
          is_updated = true
        rescue => ex
          error_message+="failed to load _status.json: #{ex.message}\n"
          job.update_attribute(:status, :failed)
        end
      end

      if File.exist?("_time.txt")
        begin
          File.open("_time.txt", 'r').each do |line|
            if line =~ /^real \d/
              job.real_time = line.sub(/^real /, '').to_f
            elsif line =~ /^user \d/
              # sum up cpu_times over processes
              job.cpu_time = job.cpu_time.to_f + line.sub(/^user /,'').to_f
            end
          end
          error_message+="_time.txt has invalid format"  if job.real_time.nil? or job.cpu_time.nil?
          is_updated = true
        rescue => ex
          error_message+="failed to load _time.json: #{ex.message}\n"
        end
      end

      if File.exist?("_version.txt")
        begin
          version = File.open("_version.txt", 'r').read.chomp
          job.version = version
          is_updated = true
        rescue => ex
          error_message+="failed to load _version.txt: #{ex.message}"
        end
      end

      json_path = '_output.json'
      if File.exist?(json_path)
        begin
          job.result = JSON.load(File.open(json_path))
          job.result = {"result"=>job.result} unless job.result.is_a?(Hash)
          is_updated = true
        rescue => ex
          error_message+="failed to load _output.json: #{ex.message}"
        end
      end

      if error_message.length > 0
        job.update_attribute(:error_messages, error_message)
      end

      if is_updated
        job.included_at = DateTime.now
        job.save!
      end
    }
  end
end
