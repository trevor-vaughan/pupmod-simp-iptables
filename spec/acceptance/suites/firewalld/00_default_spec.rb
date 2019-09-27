require 'spec_helper_acceptance'

test_name "iptables class in firewalld mode"

hosts.each do |host|
  describe "iptables class #{host} in firewalld mode" do
    let(:default_manifest) {
      <<-EOS
        class { 'iptables':
          enable => 'firewalld'
        }

        # Ironically, if iptables applies correctly, its default settings will
        # deny Vagrant access via SSH.  So, it is neccessary for beaker to also
        # define a rule that permit SSH access from the standard Vagrant subnets:
        iptables::listen::tcp_stateful { 'allow_sshd':
          trusted_nets => ['0.0.0.0/0'],
          dports       => 22,
        }
      EOS
    }

    context 'default parameters' do
      it 'should work with no errors' do
        apply_manifest_on(host, default_manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(host, default_manifest, :catch_changes => true)
      end
    end
  end
end
