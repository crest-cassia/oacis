require 'spec_helper'

describe ParameterKey do

  describe "validations" do
    
    describe "'name' field'" do
      it "must exist" do
        param_key = ParameterKey.new( type:"Integer",
                                      default: 0,
                                      description:"key without name")
        param_key.should_not be_valid
      end
      
      it "must be unique" do
        param_key1 = ParameterKey.create!(name:"L",
                                          type:"Integer",
                                          default:32,
                                          restriction:"",
                                          description:"size of a system")
        
        param_key2 = ParameterKey.new(name: "L",
                                      type: "Float",
                                      default: 1.234,
                                      description:"another definition of L")
        param_key2.should_not be_valid
      end
    end

    describe "'type' field" do

      it "must exist" do
        pk = ParameterKey.new(name: "L",
                              default: 1.234,
                              description:"another definition of L")
        pk.should_not be_valid
      end
      
      it "must be either 'Boolean', 'Integer', 'Float', or 'String'" do
        ParameterKey.new(name:"Boolean key", type:"Boolean").should be_valid
        ParameterKey.new(name:"Integer key", type:"Integer").should be_valid
        ParameterKey.new(name:"Float key", type:"Float").should be_valid
        ParameterKey.new(name:"String key", type:"String").should be_valid
        ParameterKey.new(name:"Date key", type:"DateTime").should_not be_valid
      end
    end
  end
end
