require 'spec_helper'

describe Puppet::Type.type(:iptables_optimize).provider(:notify) do
  let(:resource) {
    Puppet::Type.type(:iptables_optimize).new(
      name: @target
    )
  }

  let(:provider) {
    Puppet::Type.type(:iptables_optimize).provider(:optimize).new(resource)
  }

  let(:test_rules) {
    <<-EOM
# NAT Routing with Docker
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
:DOCKER - [0:0]
-A PREROUTING -m addrtype --dst-type LOCAL -j DOCKER
-A OUTPUT ! -d 127.0.0.0/8 -m addrtype --dst-type LOCAL -j DOCKER
-A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE
-A DOCKER -i docker0 -j RETURN
COMMIT
# Filter Table
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:DOCKER - [0:0]
:DOCKER-ISOLATION - [0:0]
:LOCAL-INPUT - [0:0]
-A INPUT -m comment --comment "SIMP:" -j LOCAL-INPUT
-A FORWARD -j DOCKER-ISOLATION
-A FORWARD -o docker0 -j DOCKER
-A FORWARD -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -i docker0 ! -o docker0 -j ACCEPT
-A FORWARD -i docker0 -o docker0 -j ACCEPT
-A FORWARD -m comment --comment "SIMP:" -j LOCAL-INPUT
-A DOCKER-ISOLATION -j RETURN
-A LOCAL-INPUT -m state --state RELATED,ESTABLISHED -m comment --comment "SIMP:" -j ACCEPT
-A LOCAL-INPUT -i lo -m comment --comment "SIMP:" -j ACCEPT
-A LOCAL-INPUT -p tcp -m state --state NEW -m tcp -m multiport --dports 22 -m comment --comment "SIMP:" -j ACCEPT
-A LOCAL-INPUT -p icmp -m icmp --icmp-type 8 -m comment --comment "SIMP:" -j ACCEPT
-A LOCAL-INPUT -s 1.2.3.4/24 -p tcp -m state --state NEW -m tcp -m multiport --dports 876 -m comment --comment "SIMP:" -j ACCEPT
-A LOCAL-INPUT -m pkttype --pkt-type broadcast -m comment --comment "SIMP:" -j DROP
-A LOCAL-INPUT -m addrtype --src-type MULTICAST -m comment --comment "SIMP:" -j DROP
-A LOCAL-INPUT -m state --state NEW -m comment --comment "SIMP:" -j LOG --log-prefix "IPT:"
-A LOCAL-INPUT -m comment --comment "SIMP:" -j DROP
COMMIT
    EOM
  }

  before(:each) do
    @tmpdir = Dir.mktmpdir('rspec_iptables_optimize')
    @target = File.join(@tmpdir, 'iptables_rules')
  end

  after(:each) do
    FileUtils.remove_dir(@tmpdir) if File.exist?(@tmpdir)
  end

  context '#optimize' do
    before(:each) do
      @catalog = Puppet::Resource::Catalog.new
      Puppet::Type::Iptables_optimize.any_instance.stubs(:catalog).returns(@catalog)

      Puppet::Type::Iptables_optimize::ProviderOptimize.stubs(:iptables_save).returns(test_rules)
    end

    it 'should run without issue' do
      expect(provider.optimize).to eq :optimized
    end
  end

  context '#system_insync?' do
    before(:each) do
      @catalog = Puppet::Resource::Catalog.new
      Puppet::Type::Iptables_optimize.any_instance.stubs(:catalog).returns(@catalog)
      Puppet::Type::Iptables_optimize::ProviderOptimize.stubs(:iptables_save).returns(test_rules)

      # Need to call this to prep some of the internal data structures
      provider.optimize
    end

    it 'should run without issue' do
      expect(provider.system_insync?).to be true
    end
  end

  context '#optimize=(should)' do
    context 'when rules have not changed' do
      before(:each) do
        @catalog = Puppet::Resource::Catalog.new
        Puppet::Type::Iptables_optimize.any_instance.stubs(:catalog).returns(@catalog)
        Puppet::Type::Iptables_optimize::ProviderOptimize.stubs(:iptables_save).returns(test_rules)

        # Need to call this to prep some of the internal data structures
        provider.optimize
      end

      it 'should run without issue' do
        expect{ provider.optimize=(nil) }.not_to raise_error
      end

      it 'should not create an output file' do
        expect(File.exist?(@target)).to be false
      end
    end

    context 'when rules have changed' do
      before(:each) do
        @catalog = Puppet::Resource::Catalog.new

        new_rule = Puppet::Type.type(:iptables_rule).new(
          name: 'test rule',
          comment: 'Some test rule',
          content: '-p tcp -m state --state NEW -m tcp -port 1234 -j ACCEPT'
        )

        @catalog.add_resource(new_rule)

        Puppet::Type::Iptables_optimize.any_instance.stubs(:catalog).returns(@catalog)
      end

      it 'should create an output file' do
        Puppet::Type::Iptables_optimize.any_instance.stubs(:catalog).returns(@catalog)
        expect{ provider.optimize=(nil) }.not_to raise_error
        expect(File.exist?(@target)).to be true

        content = File.read(@target)

        expect(content).to match(/-A LOCAL-INPUT -p tcp -m state --state NEW -m tcp -port 1234 -j ACCEPT/)
      end
    end
  end
end
