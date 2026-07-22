require_relative 'common'

module McpServer
  module Tools
    module FileTools
      extend Common

      MAX_ENTRIES = 500
      DEFAULT_READ_BYTES = 64_000
      MAX_READ_BYTES = 256_000

      def self.register(registry)
        register_list(registry)
        register_read(registry)
      end

      def self.register_list(registry)
        registry.register(
          "list_result_files",
          description: "List the files in the result directory of a run or an analysis " \
                       "(give exactly one of run_id / analysis_id). Pass relative_path to descend into a subdirectory. " \
                       "base_dir in the response is the result directory; if it is accessible from your filesystem, " \
                       "prefer reading files there directly (binary files included) over read_result_file.",
          input_schema: {
            "type" => "object",
            "properties" => {
              "run_id" => { "type" => "string" },
              "analysis_id" => { "type" => "string" },
              "relative_path" => { "type" => "string", "description" => "Subdirectory to list, relative to the result directory (default: the directory itself)" }
            },
            "required" => []
          }
        ) do |args|
          base = result_dir(args)
          dir = resolve_in_base(base, args["relative_path"] || ".")
          unless dir.directory?
            raise ToolError.new("invalid_arguments", "'#{args["relative_path"]}' is not a directory")
          end
          children = dir.children.sort
          entries = children.first(MAX_ENTRIES).map do |child|
            stat = child.stat
            {
              "path" => child.relative_path_from(base).to_s,
              "directory" => stat.directory?,
              "size" => stat.size,
              "mtime" => stat.mtime.utc.iso8601
            }
          end
          {
            "base_dir" => Serializers.map_dir(base),
            "entries" => entries,
            "total" => children.size,
            "truncated" => children.size > MAX_ENTRIES
          }
        end
      end

      def self.register_read(registry)
        registry.register(
          "read_result_file",
          description: "Read a text file from the result directory of a run or an analysis " \
                       "(give exactly one of run_id / analysis_id). Reads at most max_bytes " \
                       "(default #{DEFAULT_READ_BYTES}, max #{MAX_READ_BYTES}) starting at offset_bytes; " \
                       "when the response says truncated, call again with a larger offset_bytes to page through. " \
                       "Binary files are rejected. This is a fallback for when the result directory is not " \
                       "accessible from your filesystem; when it is, read the files under base_dir directly.",
          input_schema: {
            "type" => "object",
            "properties" => {
              "run_id" => { "type" => "string" },
              "analysis_id" => { "type" => "string" },
              "path" => { "type" => "string", "description" => "File path relative to the result directory, e.g. \"_stdout.txt\"" },
              "offset_bytes" => { "type" => "integer" },
              "max_bytes" => { "type" => "integer" }
            },
            "required" => ["path"]
          }
        ) do |args|
          base = result_dir(args)
          file = resolve_in_base(base, args["path"])
          unless file.file?
            raise ToolError.new("invalid_arguments", "'#{args["path"]}' is not a regular file")
          end
          offset = [args["offset_bytes"].to_i, 0].max
          max_bytes = (args["max_bytes"] || DEFAULT_READ_BYTES).clamp(1, MAX_READ_BYTES)
          size = file.size
          data = file.open('rb') do |f|
            f.seek(offset)
            f.read(max_bytes) || ""
          end
          if data.include?("\x00")
            raise ToolError.new("binary_file", "'#{args["path"]}' appears to be a binary file",
                                hint: "Use list_result_files to see file sizes; only text files can be read with this tool.")
          end
          content = data.force_encoding(Encoding::UTF_8)
          scrubbed = !content.valid_encoding?
          content = content.scrub("�") if scrubbed
          response = {
            "path" => args["path"],
            "size" => size,
            "offset" => offset,
            "bytes_read" => data.bytesize,
            "truncated" => offset + data.bytesize < size,
            "content" => content
          }
          response["encoding_scrubbed"] = true if scrubbed
          response
        end
      end

      def self.result_dir(args)
        target_key = exactly_one_of!(args.slice("run_id", "analysis_id"), "run_id", "analysis_id")
        target = target_key == "run_id" ? Resolvers.run(args["run_id"]) : Resolvers.analysis(args["analysis_id"])
        target.dir
      end

      # Resolves rel against base and guarantees the result stays inside base,
      # following symlinks (realpath), so neither "../" nor symlink escapes work.
      def self.resolve_in_base(base, rel)
        rel_path = Pathname.new(rel.to_s)
        if rel_path.absolute? || rel_path.each_filename.include?("..")
          raise ToolError.new("invalid_path", "'#{rel}' must be a relative path inside the result directory (no '..')")
        end
        base_real =
          begin
            base.realpath
          rescue Errno::ENOENT
            raise ToolError.new("not_found", "The result directory does not exist (no output has been produced yet)")
          end
        target_real =
          begin
            base_real.join(rel).realpath
          rescue Errno::ENOENT
            raise ToolError.new("not_found", "No such file or directory: '#{rel}'",
                                hint: "Use list_result_files to see available files.")
          end
        unless target_real == base_real || target_real.to_s.start_with?(base_real.to_s + File::SEPARATOR)
          raise ToolError.new("invalid_path", "'#{rel}' points outside the result directory")
        end
        target_real
      end
    end
  end
end
