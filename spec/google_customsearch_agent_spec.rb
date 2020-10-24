require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::GoogleCustomsearchAgent do
  before(:each) do
    @valid_options = Agents::GoogleCustomsearchAgent.new.default_options
    @checker = Agents::GoogleCustomsearchAgent.new(:name => "GoogleCustomsearchAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
