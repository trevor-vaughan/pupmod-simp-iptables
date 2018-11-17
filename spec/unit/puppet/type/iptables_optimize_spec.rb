#!/usr/bin/env rspec

require 'spec_helper'

iptables_optimize_type = Puppet::Type.type(:iptables_optimize)

describe iptables_optimize_type do
  before(:each) do
    @catalog = Puppet::Resource::Catalog.new
    Puppet::Type::Iptables_optimize.any_instance.stubs(:catalog).returns(@catalog)
  end

  context 'when setting parameters' do
    it 'should accept a path as a name parameter' do
      resource = iptables_optimize_type.new(
        :name => '/foo/bar'
      )

      expect(resource[:name]).to eq('/foo/bar')
    end

    it 'should fail on a non-path as a name parameter' do
      expect {
        iptables_optimize_type.new(
        :name => 'foo/bar'
        )
      }.to raise_error(/fully qualified/)
    end
  end
end

