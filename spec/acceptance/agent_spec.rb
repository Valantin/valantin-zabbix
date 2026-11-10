# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'zabbix::agent' do
  os_name = fact('os.name')
  variants = (os_name == 'Fedora') ? ['agent'] : %w[agent agent2]

  variants.each do |variant|
    context "with #{variant}" do
      agent_binary = (variant == 'agent') ? 'zabbix_agentd' : 'zabbix_agent2'
      binary_path = (os_name == 'Archlinux') ? "/usr/bin/#{agent_binary}" : "/usr/sbin/#{agent_binary}"
      config_file = (os_name == 'Fedora') ? '/etc/zabbix_agentd.conf' : "/etc/zabbix/#{agent_binary}.conf"

      let(:manifest) do
        <<~PUPPET
          class { 'zabbix::agent':
            variant  => '#{variant}',
            settings => {
              'Server' => '127.0.0.1',
              'ListenIP' => '127.0.0.1',
              'Hostname' => 'acceptance-node',
              'DebugLevel' => 3,
            },
          }
          zabbix::agent::fragment { 'acceptance':
            settings => { 'UserParameter' => 'puppet.ping,echo 1' },
          }
        PUPPET
      end

      # Each variant owns this service in the test; stop it before testing the
      # next one, since the production class deliberately does not migrate agents.
      after(:context) do
        apply_manifest("service { 'zabbix-#{variant}': ensure => stopped, enable => false }", catch_failures: true)
      end

      it_behaves_like 'an idempotent resource'

      describe package("zabbix-#{variant}") do
        it { is_expected.to be_installed }
      end

      describe file(config_file) do
        it { is_expected.to be_file }
        it { is_expected.to be_owned_by('root') }
        it { is_expected.to be_grouped_into('zabbix') }
        it { is_expected.to be_mode(640) }
        its(:content) { is_expected.to match(%r{^Hostname=acceptance-node$}) }
      end

      describe service("zabbix-#{variant}") do
        it { is_expected.to be_enabled }
        it { is_expected.to be_running }
      end

      describe command("#{binary_path} -T -c #{config_file}") do
        its(:exit_status) { is_expected.to eq(0) }
      end

      describe command("#{binary_path} -t puppet.ping -c #{config_file}") do
        its(:stdout) { is_expected.to match(%r{\[[tsu]\|1\]}) }
        its(:exit_status) { is_expected.to eq(0) }
      end

      describe 'after a configuration change' do
        it 'restarts the service and converges again' do
          original_pid = on(default, "systemctl show zabbix-#{variant} --property MainPID --value").stdout.strip
          updated_manifest = manifest.sub("'DebugLevel' => 3", "'DebugLevel' => 4")
          apply_manifest(updated_manifest, catch_failures: true)
          updated_pid = on(default, "systemctl show zabbix-#{variant} --property MainPID --value").stdout.strip

          expect(updated_pid).not_to eq('0')
          expect(updated_pid).not_to eq(original_pid)
          apply_manifest(updated_manifest, catch_changes: true)
        end
      end
    end
  end
end
