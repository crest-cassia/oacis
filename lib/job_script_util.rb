module JobScriptUtil

  def self.script_for(run, host)
    cmd, input = run.command_and_input
    cmd.sub!(/;$/, '')  # semi-colon in the last of the command causes bash syntax error

    # preprocess
    script = <<-EOS
#!/bin/bash
LANG=C
# PRE-PROCESS ---------------------
cd #{host.work_base_dir}
mkdir -p #{run.id}
cd #{run.id}
if [ -e ../#{run.id}_input.json ]; then
mv ../#{run.id}_input.json ./_input.json
fi
echo "{" > ../#{run.id}_status.json
echo "  \\"started_at\\": \\"`date`\\"," >> ../#{run.id}_status.json
echo "  \\"hostname\\": \\"`hostname`\\"," >> ../#{run.id}_status.json
# JOB EXECUTION -------------------
{ time -p { { #{cmd}; } 1> _stdout.txt 2> _stderr.txt; } } 2>> ../#{run.id}_time.txt
echo "  \\"rc\\": $?," >> ../#{run.id}_status.json
echo "  \\"finished_at\\": \\"`date`\\"" >> ../#{run.id}_status.json
echo "}" >> ../#{run.id}_status.json
# POST-PROCESS --------------------
cd ..
\\mv -f #{run.id}_status.json #{run.id}/_status.json
\\mv -f #{run.id}_time.txt #{run.id}/_time.txt
tar cf #{run.id}.tar #{run.id}
if test $? -ne 0; then { echo "// Failed to make an archive for #{run.id}" >> ./_log.txt; exit; } fi
bzip2 #{run.id}.tar
if test $? -ne 0; then { echo "// Failed to compress for #{run.id}" >> ./_log.txt; exit; } fi
rm -rf #{run.id}

EOS
    script
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
end
