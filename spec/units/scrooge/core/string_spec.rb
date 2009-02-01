require 'spec/spec_helper'

describe Scrooge::Core::String do
  
  before(:each) do
    @string = 'scrooge/base'
  end
  
  it "should be able to convert itself to a constant" do
    @string.to_const().should == 'Scrooge::Base'
  end
  
  it "should be able to convert itself to a class" do
    @string.to_const!( false ).should == Scrooge::Base
  end
  
end