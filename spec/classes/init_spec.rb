require 'spec_helper'
describe 'ffce' do
  context 'with default values for all parameters' do
    it { should contain_class('ffce') }
  end
end
