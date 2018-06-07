require 'spec_helper'

describe SSHUtil do

  around(:each) do |example|
    @temp_dir = Pathname.new('__temp__').expand_path
    FileUtils.mkdir_p(@temp_dir)
    @hostname = 'localhost'
    Net::SSH.start(@hostname, ENV['USER'], password: "", timeout: 1) do |ssh|
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

    it "creates local directory if specified directory does not exist" do
      remote_path = @temp_dir.join('remote').expand_path
      FileUtils.mkdir_p(remote_path)
      remote_path2 = remote_path.join('file').expand_path
      FileUtils.touch(remote_path2)
      local_path = @temp_dir.join('local')

      SSHUtil.download_recursive_if_exist(@sh, @hostname, remote_path, local_path)
      expect(File.directory?(local_path)).to be_truthy
      expect(File.exist?(local_path.join('file'))).to be_truthy
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

  describe ".stat" do

    it "returns :directory if the remote path is a directory" do
      remote_path = @temp_dir.join('abc').expand_path
      FileUtils.mkdir_p(remote_path)
      expect(SSHUtil.stat(@sh, remote_path)).to eq :directory
    end

    it "returns :file if the remote path is a file" do
      remote_path = @temp_dir.join('abc').expand_path
      FileUtils.touch(remote_path)
      expect(SSHUtil.stat(@sh, remote_path)).to eq :file
    end

    it "returns nil if the path does not exist" do
      remote_path = @temp_dir.join('abc').expand_path
      expect(SSHUtil.stat(@sh, remote_path)).to be_nil
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
