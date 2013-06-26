module JobScriptUtil

  def self.script_for(run, host)
    cmd, input = run.command_and_input

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
echo "{" > _status.json
echo "  started_at: `date`" >> _status.json
echo "  hostname: `hostname`" >> _status.json
# JOB EXECUTION -------------------
{ time -p { #{cmd} 1> _stdout.txt 2> _stderr.txt; } } 2>> _time.txt
echo "  rc: $?" >> _status.json
echo "  finished_at: `date`" >> _status.json
echo "}" >> _status.json
# POST-PROCESS --------------------
cd ..
tar cf #{run.id}.tar #{run.id}/
if test $? -ne 0; then { echo "// Failed to make an archive for #{run.id}" >> ./_log.txt; exit; } fi
bzip2 #{run.id}.tar
if test $? -ne 0; then { echo "// Failed to compress for #{run.id}" >> ./_log.txt; exit; } fi
rm -rf #{run.id}

EOS
    script
  end
end