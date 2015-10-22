require 'spec_helper'

describe SSHUtil do

  before(:each) do
    @temp_dir = Pathname.new('__temp__').expand_path
    FileUtils.mkdir_p(@temp_dir)
    @ssh = Net::SSH.start('localhost', ENV['USER'], password: "", timeout: 1)
  end

  after(:each) do
    @ssh.close
    FileUtils.rm_r(@temp_dir) if File.directory?(@temp_dir)
  end

  describe ".download" do

    it "download remote path" do
      remote_path = @temp_dir.join('__abc__').expand_path
      FileUtils.touch(remote_path)
      local_path = @temp_dir.join('__def__').expand_path
      SSHUtil.download(@ssh, remote_path, local_path)
      expect(File.exist?(local_path)).to be_truthy
    end
  end

  describe ".download_recursive" do

    it "download directory recursively" do
      remote_path = @temp_dir.join('remote').expand_path
      FileUtils.mkdir_p(remote_path)
      remote_path2 = remote_path.join('file').expand_path
      FileUtils.touch(remote_path2)
      local_path = @temp_dir.join('local')
      FileUtils.mkdir_p(local_path)
      SSHUtil.download_recursive(@ssh, remote_path, local_path)
      expect(File.exist?(local_path.join('file'))).to be_truthy
    end

    it "creates local directory if specified directory does not exist" do
      remote_path = @temp_dir.join('remote').expand_path
      FileUtils.mkdir_p(remote_path)
      remote_path2 = remote_path.join('file').expand_path
      FileUtils.touch(remote_path2)
      local_path = @temp_dir.join('local')

      SSHUtil.download_recursive(@ssh, remote_path, local_path)
      expect(File.directory?(local_path)).to be_truthy
      expect(File.exist?(local_path.join('file'))).to be_truthy
    end

    it "download file if the remote_path is not directory but file" do
      remote_path = @temp_dir.join('file').expand_path
      FileUtils.touch(remote_path)

      local_path = @temp_dir.join('local')
      SSHUtil.download_recursive(@ssh, remote_path, local_path)
      expect(File.exist?(local_path)).to be_truthy
    end
  end

  describe ".upload" do

    it "upload local file" do
      local_path = @temp_dir.join('__abc__')
      FileUtils.touch(local_path)
      remote_path = @temp_dir.join('__def__').expand_path
      SSHUtil.upload(@ssh, local_path, remote_path)
      expect(File.exist?(remote_path)).to be_truthy
    end

    it "upload local directory recursively" do
      local_dir = @temp_dir.join('dir/dir2')
      FileUtils.mkdir_p(local_dir)
      local_file = local_dir.join('file')
      FileUtils.touch(local_file)
      remote_path = @temp_dir.join('remote').expand_path
      FileUtils.mkdir_p(remote_path)
      SSHUtil.upload(@ssh, @temp_dir.join('dir'), remote_path.join('dir'))
      expect( File.directory?(@temp_dir.join('remote/dir/dir2')) ).to be_truthy
      expect( File.exist?( @temp_dir.join('remote/dir/dir2/file')) ).to be_truthy
    end
  end

  describe ".rm_r" do

    before(:each) do
      @temp_file = @temp_dir.join('__abc__')
      FileUtils.touch(@temp_file)
    end

    it "removes specified file" do
      SSHUtil.rm_r(@ssh, @temp_file.expand_path)
      expect(File.exist?(@temp_file)).to be_falsey
    end

    it "removes specified directory even if the directory is not empty" do
      SSHUtil.rm_r(@ssh, @temp_dir.expand_path)
      expect(File.directory?(@temp_dir)).to be_falsey
    end
  end

  describe ".uname" do

    it "returns the result of 'uname' on remote host" do
      expect(SSHUtil.uname(@ssh)).to satisfy {|u|
        ["Linux", "Darwin"].include?(u)
      }
    end
  end

  describe ".execute" do

    it "executes command and returns its standard output" do
      expect(SSHUtil.execute(@ssh, 'pwd').chomp).to eq ENV['HOME']
    end
  end

  describe ".execute_in_background" do

    it "executes command in background and return it immediately" do
      expect {
        SSHUtil.execute_in_background(@ssh, 'sleep 3')
      }.to change { Time.now }.by_at_most(1)
    end

    it "does not hung up when execute is called after execute_in_background" do
      expect {
        SSHUtil.execute_in_background(@ssh, 'sleep 3')
        SSHUtil.execute(@ssh, 'pwd')
      }.to change { Time.now }.by_at_most(1)
    end

    it "handles redirection properly" do
      remote_path = @temp_dir.join('abc').expand_path
      SSHUtil.execute_in_background(@ssh, "echo $USER > #{remote_path}")
      sleep 1
      expect(File.exist?(remote_path)).to be_truthy
      expect(File.open(remote_path).read.chomp).to eq ENV['USER']
    end
  end

  describe ".execute2" do

    it "execute command and return outputs and exit_codes" do
      stdout, stderr, rc, sig = SSHUtil.execute2(@ssh, 'pwd')
      expect(stdout.chomp).to eq ENV['HOME']
      expect(stderr).to eq ""
      expect(rc).to eq 0
      expect(sig).to be_nil
    end

    it "for error case" do
      out, err, rc, sig = SSHUtil.execute2(@ssh, 'foobar')
      expect(out).to eq ""
      expect(err).not_to be_empty
      expect(rc).not_to eq 0
      expect(sig).to be_nil
    end

    it "does not freeze if execute2 is called after write_remote_file" do
      output_file = @temp_dir.join('abc').expand_path
      SSHUtil.write_remote_file(@ssh, output_file, "foobar")
      expect {
        stdout, stderr, rc, sig = SSHUtil.execute2(@ssh, 'pwd')
      }.to change { Time.now }.by_at_most(1)
    end
  end

  describe ".write_remote_file" do

    it "write contents to remote file" do
      output_file = @temp_dir.join('abc').expand_path
      SSHUtil.write_remote_file(@ssh, output_file, "foobar")
      expect(File.open(output_file, 'r').read).to eq "foobar"
    end

    it "succeeds even when called twice" do
      output_file = @temp_dir.join('abc').expand_path
      SSHUtil.write_remote_file(@ssh, output_file, "foobar")
      SSHUtil.write_remote_file(@ssh, output_file, "foobar")
      expect(File.open(output_file, 'r').read).to eq "foobar"
    end
  end

  describe ".exist?" do

    it "returns true when the remote file exists" do
      remote_path = @temp_dir.join('abc').expand_path
      FileUtils.touch(remote_path)
      expect(SSHUtil.exist?(@ssh, remote_path)).to be_truthy
    end

    it "returns false when the remote file does not exist" do
      remote_path = @temp_dir.join('abc').expand_path
      expect(SSHUtil.exist?(@ssh, remote_path)).to be_falsey
    end

    it "returns true if the remote directory exist" do
      remote_path = @temp_dir.join('abc').expand_path
      FileUtils.mkdir_p(remote_path)
      expect(SSHUtil.exist?(@ssh, remote_path)).to be_truthy
    end
  end

  describe ".directory?" do

    it "returns true if the path is a directory" do
      remote_path = @temp_dir.join('abc').expand_path
      FileUtils.mkdir_p(remote_path)
      expect(SSHUtil.directory?(@ssh, remote_path)).to be_truthy
    end

    it "returns false if the path is a file" do
      remote_path = @temp_dir.join('abc').expand_path
      FileUtils.touch(remote_path)
      expect(SSHUtil.directory?(@ssh, remote_path)).to be_falsey
    end

    it "returns false if the path does not exist" do
      remote_path = @temp_dir.join('abc').expand_path
      expect(SSHUtil.directory?(@ssh, remote_path)).to be_falsey
    end
  end
end
