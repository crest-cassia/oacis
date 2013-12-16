require 'spec_helper'
require File.join(Rails.root, 'lib/cli/oacis_cli')

describe OacisCli do

  describe "#usage" do

    it "prints usage" do
      capture(:stdout) {
        OacisCli.new.invoke(:usage)
      }.should_not be_empty
    end
  end
end
