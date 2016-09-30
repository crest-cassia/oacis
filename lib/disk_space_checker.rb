module DiskSpaceChecker

  def self.rate
    stat = Sys::Filesystem.stat(ResultDirectory.root.to_s)
    (1.0 - stat.blocks_free.to_f/stat.blocks.to_f).round(2)
  end
end

