require 'spec_helper'

RSpec.shared_examples "SSHUtil backend" do |backend_name, ssh_module|

  around(:each) do |example|
    @temp_dir = Pathname.new('__temp__').expand_path
    FileUtils.mkdir_p(@temp_dir)
    @hostname = 'localhost'
    ssh_module.start(@hostname, ENV['USER'], non_interactive: true, timeout: 1) do |ssh|
      SSHUtil::ShellSession.start(ssh) do |sh|
        @sh = sh
        example.run
      end
    end
  ensure
    FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
  end

  describe ".download_file" do

    it "download remote path" do
      remote_path = @temp_dir.join('__abc__').expand_path
      FileUtils.touch(remote_path)
      local_path = @temp_dir.join('__def__').expand_path
      SSHUtil.download_file(@hostname, remote_path, local_path)
      expect(File.exist?(local_path)).to be_truthy
    end

    it "handles spaces and shell metacharacters in remote and local paths" do
      remote_path = @temp_dir.join(%q{remote ; $(not_a_command) 'quoted'}).expand_path
      FileUtils.touch(remote_path)
      local_path = @temp_dir.join(%q{local ; $(not_a_command) 'quoted'}).expand_path

      SSHUtil.download_file(@hostname, remote_path, local_path)

      expect(File.exist?(local_path)).to be_truthy
    end
  end

  describe ".download_directory" do

    it "download directory recursively" do
      remote_path = @temp_dir.join('remote').expand_path
      FileUtils.mkdir_p(remote_path)
      remote_path2 = remote_path.join('file').expand_path
      FileUtils.touch(remote_path2)
      local_path = @temp_dir.join('local')
      FileUtils.mkdir_p(local_path)
      SSHUtil.download_directory(@hostname, remote_path, local_path)
      expect(File.exist?(local_path.join('file'))).to be_truthy
    end

    it "creates local directory if specified directory does not exist" do
      remote_path = @temp_dir.join('remote').expand_path
      FileUtils.mkdir_p(remote_path)
      remote_path2 = remote_path.join('file').expand_path
      FileUtils.touch(remote_path2)
      local_path = @temp_dir.join('local')

      SSHUtil.download_directory(@hostname, remote_path, local_path)
      expect(File.directory?(local_path)).to be_truthy
      expect(File.exist?(local_path.join('file'))).to be_truthy
    end

    it "handles spaces and shell metacharacters while expanding directory contents" do
      remote_path = @temp_dir.join(%q{remote dir ; $(not_a_command) 'quoted'}).expand_path
      FileUtils.mkdir_p(remote_path)
      FileUtils.touch(remote_path.join(%q{file ; $(not_a_command) 'quoted'}))
      local_path = @temp_dir.join('local directory')

      SSHUtil.download_directory(@hostname, remote_path, local_path)

      expect(File.exist?(local_path.join(%q{file ; $(not_a_command) 'quoted'}))).to be_truthy
    end

    it "raise exception if the remote_path is not directory but file" do
      remote_path = @temp_dir.join('file').expand_path
      FileUtils.touch(remote_path)

      local_path = @temp_dir.join('local')
      FileUtils.touch(local_path)
      expect {
        SSHUtil.download_directory(@hostname, remote_path, local_path)
      }.to raise_error(/File exists/)
      expect(File.directory?(local_path)).to be_falsey
    end
  end

  describe ".download_recursive_if_exist" do

    it "downloads directory recursively" do
      remote_path = @temp_dir.join('remote').expand_path
      FileUtils.mkdir_p(remote_path)
      remote_path2 = remote_path.join('file').expand_path
      FileUtils.touch(remote_path2)
      local_path = @temp_dir.join('local')
      FileUtils.mkdir_p(local_path)
      SSHUtil.download_recursive_if_exist(@sh, @hostname, remote_path, local_path)
      expect(File.exist?(local_path.join('file'))).to be_truthy
    end

    it "creates local directory if local directory does not exist" do
      remote_path = @temp_dir.join('remote').expand_path
      FileUtils.mkdir_p(remote_path)
      remote_path2 = remote_path.join('file').expand_path
      FileUtils.touch(remote_path2)
      local_path = @temp_dir.join('local')

      SSHUtil.download_recursive_if_exist(@sh, @hostname, remote_path, local_path)
      expect(File.directory?(local_path)).to be_truthy
      expect(File.exist?(local_path.join('file'))).to be_truthy
    end

    it "does not cause an error if specified directory is an empty directory" do
      remote_path = @temp_dir.join('empty')
      FileUtils.mkdir_p(remote_path)
      local_path = @temp_dir.join('local')
      SSHUtil.download_recursive_if_exist(@sh, @hostname, remote_path, local_path)
      expect(File.directory?(local_path)).to be_truthy
    end

    it "download file if the remote_path is not directory but file" do
      remote_path = @temp_dir.join('file').expand_path
      FileUtils.touch(remote_path)

      local_path = @temp_dir.join('local')
      SSHUtil.download_recursive_if_exist(@sh, @hostname, remote_path, local_path)
      expect(File.exist?(local_path)).to be_truthy
    end

    it "does nothing even if the remote path does not exist" do
      remote_path = @temp_dir.join('file').expand_path
      local_path = @temp_dir.join('local')
      expect {
        SSHUtil.download_recursive_if_exist(@sh, @hostname, remote_path, local_path)
      }.to_not raise_error
      expect(File.exist?(local_path)).to be_falsey
    end
  end

  describe ".upload" do

    it "upload local file" do
      local_path = @temp_dir.join('__abc__')
      FileUtils.touch(local_path)
      remote_path = @temp_dir.join('__def__').expand_path
      SSHUtil.upload(@hostname, local_path, remote_path)
      expect(File.exist?(remote_path)).to be_truthy
    end

    it "handles spaces and shell metacharacters in local and remote paths" do
      local_path = @temp_dir.join(%q{local ; $(not_a_command) 'quoted'})
      FileUtils.touch(local_path)
      remote_path = @temp_dir.join(%q{remote ; $(not_a_command) 'quoted'}).expand_path

      SSHUtil.upload(@hostname, local_path, remote_path)

      expect(File.exist?(remote_path)).to be_truthy
    end

    it "upload local directory recursively" do
      local_dir = @temp_dir.join('dir/dir2')
      FileUtils.mkdir_p(local_dir)
      local_file = local_dir.join('file')
      FileUtils.touch(local_file)
      remote_path = @temp_dir.join('remote').expand_path
      FileUtils.mkdir_p(remote_path)
      SSHUtil.upload(@hostname, @temp_dir.join('dir'), remote_path.join('dir'))
      expect( File.directory?(@temp_dir.join('remote/dir/dir2')) ).to be_truthy
      expect( File.exist?( @temp_dir.join('remote/dir/dir2/file')) ).to be_truthy
    end

    it "keeps tilde expansion for remote paths" do
      remote_dir_name = ".oacis_ssh_util_#{SecureRandom.hex(8)}"
      remote_dir = Pathname.new(Dir.home).join(remote_dir_name)
      FileUtils.mkdir_p(remote_dir)
      local_path = @temp_dir.join('local file')
      File.write(local_path, "content")
      remote_path = "~/#{remote_dir_name}/remote file"

      SSHUtil.upload(@hostname, local_path, remote_path)

      expect(remote_dir.join('remote file').read).to eq "content"
    ensure
      FileUtils.rm_rf(remote_dir) if remote_dir
    end
  end

  describe ".rm_r" do

    before(:each) do
      @temp_file = @temp_dir.join('__abc__')
      FileUtils.touch(@temp_file)
    end

    it "removes specified file" do
      SSHUtil.rm_r(@sh, @temp_file.expand_path)
      expect(File.exist?(@temp_file)).to be_falsey
    end

    it "removes specified directory even if the directory is not empty" do
      SSHUtil.rm_r(@sh, @temp_dir.expand_path)
      expect(File.directory?(@temp_dir)).to be_falsey
    end
  end

  describe ".uname" do

    it "returns the result of 'uname' on remote host" do
      expect(SSHUtil.uname(@sh)).to satisfy {|u|
        ["Linux", "Darwin"].include?(u)
      }
    end
  end

  describe ".execute" do

    it "executes command and returns its standard output" do
      expect(SSHUtil.execute(@sh, 'pwd').chomp).to eq ENV['HOME']
    end
  end

  describe ".execute2" do

    it "execute command and return outputs and exit_codes" do
      stdout, stderr, rc = SSHUtil.execute2(@sh, 'pwd')
      expect(stdout.chomp).to eq ENV['HOME']
      expect(stderr).to eq ""
      expect(rc).to eq 0
    end

    it "for error case" do
      out, err, rc = SSHUtil.execute2(@sh, 'foobar')
      expect(out).to eq ""
      expect(err).not_to be_empty
      expect(rc).not_to eq 0
    end

    it "does not freeze if execute2 is called after write_remote_file" do
      output_file = @temp_dir.join('abc').expand_path
      SSHUtil.write_remote_file(@hostname, output_file, "foobar")
      expect {
        stdout, stderr, rc = SSHUtil.execute2(@sh, 'pwd')
      }.to change { Time.now }.by_at_most(1)
    end
  end

  describe ".write_remote_file" do

    it "write contents to remote file" do
      output_file = @temp_dir.join('abc').expand_path
      SSHUtil.write_remote_file(@hostname, output_file, "foobar")
      expect(File.open(output_file, 'r').read).to eq "foobar"
    end

    it "succeeds even when called twice" do
      output_file = @temp_dir.join('abc').expand_path
      SSHUtil.write_remote_file(@hostname, output_file, "foobar")
      SSHUtil.write_remote_file(@hostname, output_file, "foobar")
      expect(File.open(output_file, 'r').read).to eq "foobar"
    end
  end

  describe ".exist?" do

    it "returns true when the remote file exists" do
      remote_path = @temp_dir.join('abc').expand_path
      FileUtils.touch(remote_path)
      expect(SSHUtil.exist?(@sh, remote_path)).to be_truthy
    end

    it "returns false when the remote file does not exist" do
      remote_path = @temp_dir.join('abc').expand_path
      expect(SSHUtil.exist?(@sh, remote_path)).to be_falsey
    end

    it "returns true if the remote directory exist" do
      remote_path = @temp_dir.join('abc').expand_path
      FileUtils.mkdir_p(remote_path)
      expect(SSHUtil.exist?(@sh, remote_path)).to be_truthy
    end
  end

  describe ".file?" do

    it "returns true when the remote file exists" do
      remote_path = @temp_dir.join('abc').expand_path
      FileUtils.touch(remote_path)
      expect(SSHUtil.file?(@sh, remote_path)).to be_truthy
    end

    it "returns false when the remote file does not exist" do
      remote_path = @temp_dir.join('abc').expand_path
      expect(SSHUtil.file?(@sh, remote_path)).to be_falsey
    end

    it "returns false if the path is a directory" do
      remote_path = @temp_dir.join('abc').expand_path
      FileUtils.mkdir_p(remote_path)
      expect(SSHUtil.file?(@sh, remote_path)).to be_falsey
    end
  end

  describe ".directory?" do

    it "returns true if the path is a directory" do
      remote_path = @temp_dir.join('abc').expand_path
      FileUtils.mkdir_p(remote_path)
      expect(SSHUtil.directory?(@sh, remote_path)).to be_truthy
    end

    it "returns false if the path is a file" do
      remote_path = @temp_dir.join('abc').expand_path
      FileUtils.touch(remote_path)
      expect(SSHUtil.directory?(@sh, remote_path)).to be_falsey
    end

    it "returns false if the path does not exist" do
      remote_path = @temp_dir.join('abc').expand_path
      expect(SSHUtil.directory?(@sh, remote_path)).to be_falsey
    end
  end
end

describe SSHUtil do
  context "with Net::SSH backend" do
    it_behaves_like "SSHUtil backend", "Net::SSH", Net::SSH
  end

  context "with PopenSSH backend" do
    it_behaves_like "SSHUtil backend", "PopenSSH", PopenSSH
  end

  describe ".escape_remote_path" do

    it "escapes shell special characters" do
      expect(SSHUtil.escape_remote_path("/tmp/dir with space")).to eq "/tmp/dir\\ with\\ space"
    end

    it "keeps a leading tilde intact so that it is expanded by the remote shell" do
      expect(SSHUtil.escape_remote_path("~/oacis work/run1")).to eq "~/oacis\\ work/run1"
      expect(SSHUtil.escape_remote_path("~")).to eq "~"
    end

    it "accepts a Pathname" do
      expect(SSHUtil.escape_remote_path(Pathname.new("/tmp/abc"))).to eq "/tmp/abc"
    end
  end

  describe "scp command construction" do

    let(:status) { double(success?: true) }

    it "passes download arguments separately from the local shell" do
      remote_path = %q{~/remote path;$(touch injected)'quoted}
      local_path = Pathname.new(%q{/tmp/local path;$(touch injected)'quoted})
      remote_operand = "host_alias:~/#{Shellwords.escape(remote_path[2..])}"
      expect(Open3).to receive(:capture3)
        .with("scp", "-O", "-Bqr", "--", remote_operand, local_path.to_s)
        .and_return(["", "", status])

      SSHUtil.download_file("host_alias", remote_path, local_path)
    end

    it "leaves only the directory contents wildcard unescaped" do
      remote_path = %q{/remote path;$(touch injected)'quoted}
      local_path = Pathname.new("/tmp/local path")
      remote_operand = "host_alias:#{Shellwords.escape(remote_path)}/*"
      allow(FileUtils).to receive(:mkdir_p)
      expect(Open3).to receive(:capture3)
        .with("scp", "-O", "-Bqr", "--", remote_operand, local_path.to_s)
        .and_return(["", "", status])

      SSHUtil.download_directory("host_alias", remote_path, local_path)
    end

    it "passes file upload arguments separately from the local shell" do
      local_path = Pathname.new(%q{/tmp/local path;$(touch injected)'quoted})
      remote_path = %q{~/remote path;$(touch injected)'quoted}
      remote_operand = "host_alias:~/#{Shellwords.escape(remote_path[2..])}"
      allow(File).to receive(:directory?).with(local_path).and_return(false)
      expect(Open3).to receive(:capture3)
        .with("scp", "-O", "-Bqr", "--", local_path.to_s, remote_operand)
        .and_return(["", "", status])

      SSHUtil.upload("host_alias", local_path, remote_path)
    end

    it "preserves the trailing slash when uploading a directory" do
      local_path = Pathname.new("/tmp/local directory")
      remote_path = "/tmp/remote directory"
      remote_operand = "host_alias:#{Shellwords.escape(remote_path)}"
      allow(File).to receive(:directory?).with(local_path).and_return(true)
      expect(Open3).to receive(:capture3)
        .with("scp", "-O", "-Bqr", "--", "#{local_path}/", remote_operand)
        .and_return(["", "", status])

      SSHUtil.upload("host_alias", local_path, remote_path)
    end

    it "falls back when the local scp is too old to accept -O" do
      unsupported_status = double(success?: false)
      remote_path = "/tmp/remote path"
      local_path = Pathname.new("/tmp/local path")
      remote_operand = "host_alias:#{Shellwords.escape(remote_path)}"
      expect(Open3).to receive(:capture3)
        .with("scp", "-O", "-Bqr", "--", remote_operand, local_path.to_s)
        .and_return(["", "scp: illegal option -- O", unsupported_status])
      expect(Open3).to receive(:capture3)
        .with("scp", "-Bqr", "--", remote_operand, local_path.to_s)
        .and_return(["", "", status])

      SSHUtil.download_file("host_alias", remote_path, local_path)
    end
  end

  describe ".validate_hostname!" do

    it "accepts SSH config aliases beyond a restrictive hostname whitelist" do
      valid_hostnames = [
        "host-1.example_name",
        "gpu+cluster%2",
        "user@host"
      ]

      valid_hostnames.each do |hostname|
        expect(SSHUtil.validate_hostname!(hostname)).to eq hostname
      end
    end

    it "rejects only values that can break SSH or scp argument parsing" do
      invalid_hostnames = [
        "-oProxyCommand=touch",
        "host:22",
        "host/path",
        "host\\name",
        "[host]",
        "host name",
        "host\nname",
        "host\0name"
      ]

      invalid_hostnames.each do |hostname|
        expect {
          SSHUtil.validate_hostname!(hostname)
        }.to raise_error(SSHUtil::InvalidHostnameError)
      end
    end
  end
end
