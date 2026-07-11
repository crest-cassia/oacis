require "securerandom"

# Provides a per-installation secret for `config.secret_key_base`.
# The secret is generated on first boot and persisted to a gitignored file,
# so every OACIS installation gets its own key without any configuration
# while sessions survive server restarts.
module OacisLocalSecret

  # Returns the secret stored at +path+, generating and persisting it first
  # if the file does not exist yet. Publication is atomic (write to a temp
  # file, then hard-link into place) because `rake daemon:start` boots four
  # Rails processes concurrently and all of them must end up with the same key.
  def self.load_or_generate(path)
    path = path.to_s
    secret = read_secret(path)
    return secret if secret

    tmp_path = "#{path}.#{Process.pid}.tmp"
    File.write(tmp_path, SecureRandom.hex(64), perm: 0o600)
    begin
      File.link(tmp_path, path)
    rescue Errno::EEXIST
      # another process published its secret first; use that one
    ensure
      File.unlink(tmp_path)
    end
    read_secret(path) or raise "failed to generate secret at #{path}"
  end

  def self.read_secret(path)
    return nil unless File.exist?(path)
    secret = File.read(path).strip
    secret.empty? ? nil : secret
  end
  private_class_method :read_secret
end
