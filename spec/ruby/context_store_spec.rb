# require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')


describe "Basic:" do
  before do
    @sut = ContextStore.new
  end

  it "should initialise with empty results" do
    @sut.pages.should []
  end
end