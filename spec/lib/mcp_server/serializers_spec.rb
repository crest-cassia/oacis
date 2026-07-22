require 'spec_helper'
require Rails.root.join('lib/mcp_server/serializers')

describe McpServer::Serializers do

  describe ".map_dir" do

    after(:each) do
      ENV.delete('OACIS_MCP_DIR_MAP')
    end

    it "returns the path unchanged when OACIS_MCP_DIR_MAP is unset" do
      expect(described_class.map_dir("/srv/oacis/public/Result/sim")).to eq "/srv/oacis/public/Result/sim"
    end

    it "rewrites the mapped prefix to the client-side prefix" do
      ENV['OACIS_MCP_DIR_MAP'] = "/srv/oacis/public/Result=/host/Result"
      expect(described_class.map_dir("/srv/oacis/public/Result/sim/ps/run")).to eq "/host/Result/sim/ps/run"
    end

    it "maps a path equal to the prefix itself" do
      ENV['OACIS_MCP_DIR_MAP'] = "/srv/oacis/public/Result=/host/Result"
      expect(described_class.map_dir("/srv/oacis/public/Result")).to eq "/host/Result"
    end

    it "does not rewrite a partial path-component match" do
      ENV['OACIS_MCP_DIR_MAP'] = "/srv/oacis/public/Result=/host/Result"
      expect(described_class.map_dir("/srv/oacis/public/Result_backup/sim")).to eq "/srv/oacis/public/Result_backup/sim"
    end

    it "leaves paths outside the prefix unchanged" do
      ENV['OACIS_MCP_DIR_MAP'] = "/srv/oacis/public/Result=/host/Result"
      expect(described_class.map_dir("/var/log/oacis.log")).to eq "/var/log/oacis.log"
    end

    it "accepts Pathname input and trailing separators in the mapping" do
      ENV['OACIS_MCP_DIR_MAP'] = "/srv/oacis/public/Result/=/host/Result/"
      expect(described_class.map_dir(Pathname.new("/srv/oacis/public/Result/sim"))).to eq "/host/Result/sim"
    end

    it "ignores a malformed mapping" do
      ENV['OACIS_MCP_DIR_MAP'] = "no-separator-here"
      expect(described_class.map_dir("/srv/oacis/public/Result/sim")).to eq "/srv/oacis/public/Result/sim"
    end
  end
end
