# frozen_string_literal: true

require 'spec_helper'

describe 'zabbix::agent' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) { {} }
      let(:agent) do
        fedora = os_facts[:os]['name'] == 'Fedora'
        variant = params.fetch(:variant, fedora ? 'agent' : 'agent2')
        basename = (variant == 'agent') ? 'zabbix_agentd' : 'zabbix_agent2'
        {
          package_name: "zabbix-#{variant}",
          config_file: fedora ? '/etc/zabbix_agentd.conf' : "/etc/zabbix/#{basename}.conf",
          binary_path: (os_facts[:os]['name'] == 'Archlinux') ? "/usr/bin/#{basename}" : "/usr/sbin/#{basename}",
        }
      end
      let(:content) { catalogue.resource('File', agent[:config_file])[:content] }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.not_to contain_class('zabbix') }
      it { is_expected.to contain_class('zabbix::repo') }
      it { is_expected.to contain_package(agent[:package_name]).with_ensure('present').that_requires('Class[zabbix::repo]').that_notifies('Exec[zabbix-agent-validate]') }
      it { is_expected.to contain_service(agent[:package_name]).with(ensure: 'running', enable: true) }
      it { is_expected.to contain_file('/etc/zabbix').with(ensure: 'directory', owner: 'root', mode: '0755') }
      it { is_expected.to contain_file("/etc/zabbix/#{(os_facts[:os]['name'] == 'Fedora') ? 'agent' : 'agent2'}.puppet.d").with(ensure: 'directory', mode: '0750') }

      it do
        is_expected.to contain_file(agent[:config_file]).with(
          ensure: 'file', owner: 'root', group: 'zabbix', mode: '0640', show_diff: false,
        ).that_requires("Package[#{agent[:package_name]}]").that_notifies('Exec[zabbix-agent-validate]')
      end

      it do
        is_expected.to contain_exec('zabbix-agent-validate').with(
          command: [agent[:binary_path], '-T', '-c', agent[:config_file]], refreshonly: true,
        ).that_notifies("Service[#{agent[:package_name]}]")
      end

      it { is_expected.to contain_service(agent[:package_name]).that_requires('Exec[zabbix-agent-validate]') }

      it 'renders a usable default configuration without active checks' do
        expect(content).to include("LogType=system\n", "Server=127.0.0.1\n")
        expect(content).not_to match(%r{^ServerActive=})
        expect(content).to end_with("\n")
      end

      context 'with classic agent' do
        let(:params) { { variant: 'agent' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('zabbix-agent') }
        it { is_expected.to contain_service('zabbix-agent') }

        it 'sets the PID file expected by packaged services' do
          expect(content).to include("PidFile=/run/zabbix/zabbix_agentd.pid\n")
        end
      end

      context 'with agent2' do
        let(:params) { { variant: 'agent2' } }

        if os_facts[:os]['name'] == 'Fedora'
          it { is_expected.to compile.and_raise_error(%r{Agent variant agent2 is not available on Fedora}) }
        else
          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_package('zabbix-agent2') }
          it { is_expected.to contain_service('zabbix-agent2') }
        end
      end

      context 'with native settings and ordered access rules' do
        let(:params) do
          {
            settings: {
              'Server' => '192.0.2.10,192.0.2.11',
              'ServerActive' => 'zabbix.example.net:10051',
              'Hostname' => 'node.example.net',
              'DebugLevel' => 4,
              'UserParameter' => ['app.ping,echo 1', 'app.version,echo 2'],
              'Alias' => ['app.cpu:system.cpu.load', 'app.uptime:system.uptime'],
            },
            access_rules: [
              { 'action' => 'deny', 'pattern' => 'vfs.file.*[*]' },
              { 'action' => 'allow', 'pattern' => 'system.run[/usr/bin/uptime]' },
              { 'action' => 'deny', 'pattern' => 'system.run[*]' },
            ],
          }
        end

        it { is_expected.to compile.with_all_deps }

        it 'overrides defaults and preserves native list and repeated directive syntax' do
          expect(content.scan(%r{^Server=})).to have_attributes(length: 1)
          expect(content).to include("Server=192.0.2.10,192.0.2.11\n", "DebugLevel=4\n", "Hostname=node.example.net\n")
          expect(content).to include("UserParameter=app.ping,echo 1\nUserParameter=app.version,echo 2\n")
          expect(content).to include("Alias=app.cpu:system.cpu.load\nAlias=app.uptime:system.uptime\n")
        end

        it 'preserves the relative order of allow and deny rules' do
          expect(content).to include("DenyKey=vfs.file.*[*]\nAllowKey=system.run[/usr/bin/uptime]\nDenyKey=system.run[*]\n")
        end
      end

      context 'with package management disabled' do
        let(:params) { { manage_package: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_package(agent[:package_name]) }
        it { is_expected.to contain_file(agent[:config_file]) }
        it { is_expected.to contain_service(agent[:package_name]) }
      end

      context 'with configuration management disabled' do
        let(:params) { { manage_config: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_file(agent[:config_file]) }
        it { is_expected.to contain_package(agent[:package_name]) }
        it { is_expected.to contain_service(agent[:package_name]).that_requires("Package[#{agent[:package_name]}]") }
      end

      context 'with service management disabled' do
        let(:params) { { manage_service: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_service(agent[:package_name]) }
        it { is_expected.to contain_file(agent[:config_file]) }
      end

      context 'with all management disabled' do
        let(:params) { { manage_package: false, manage_config: false, manage_service: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_package(agent[:package_name]) }
        it { is_expected.not_to contain_file(agent[:config_file]) }
        it { is_expected.not_to contain_service(agent[:package_name]) }
      end

      context 'with pinned package and stopped service' do
        let(:params) { { package_ensure: '8.0.1-1', service_ensure: 'stopped', service_enable: false } }

        it { is_expected.to contain_package(agent[:package_name]).with_ensure('8.0.1-1') }
        it { is_expected.to contain_service(agent[:package_name]).with(ensure: 'stopped', enable: false) }
      end

      context 'with resource overrides' do
        let(:params) do
          { package_name: 'custom-agent', service_name: 'custom-agent', config_file: '/etc/zabbix/custom.conf', binary_path: '/opt/zabbix agent/bin/agent' }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('custom-agent') }
        it { is_expected.to contain_service('custom-agent') }
        it { is_expected.to contain_exec('zabbix-agent-validate').with_command(['/opt/zabbix agent/bin/agent', '-T', '-c', '/etc/zabbix/custom.conf']) }
      end

      context 'with default settings explicitly omitted' do
        let(:params) { { settings: { 'Server' => :undef } } }

        it 'omits the directive instead of serializing undef' do
          expect(content).not_to match(%r{^Server=})
        end
      end

      context 'with the main class also declared' do
        let(:pre_condition) { 'include zabbix' }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package(agent[:package_name]) }
      end

      %i[manage_package manage_config manage_service].combination(2) do |flags|
        context "with #{flags.join(' and ')} disabled" do
          let(:params) { flags.to_h { |flag| [flag, false] } }

          it { is_expected.to compile.with_all_deps }
        end
      end

      context 'with native TLS configuration' do
        let(:params) do
          {
            settings: {
              'TLSConnect' => 'psk', 'TLSAccept' => 'psk',
              'TLSPSKIdentity' => 'node-01', 'TLSPSKFile' => '/etc/zabbix/agent.psk',
            },
          }
        end

        it 'references an externally provisioned PSK without managing its contents' do
          expect(content).to include("TLSPSKFile=/etc/zabbix/agent.psk\n", "TLSConnect=psk\n")
        end
      end

      context 'with a plugin setting' do
        let(:params) { { settings: { 'Plugins.Mysql.Timeout' => 10 } } }

        if os_facts[:os]['name'] == 'Fedora'
          it { is_expected.to compile.and_raise_error(%r{Plugins.Mysql.Timeout is not supported by agent}) }
        else
          it 'renders agent2 plugin directives' do
            expect(content).to include("Plugins.Mysql.Timeout=10\n")
          end
        end
      end

      context 'with Hiera settings' do
        let(:hiera_config) { File.expand_path('../fixtures/hiera/agent/hiera.yaml', __dir__) }

        it 'uses automatic parameter lookup without the main class' do
          expect(content).to include("Server=192.0.2.55\n")
        end
      end

      context 'with an externally managed repository' do
        let(:pre_condition) { "class { 'zabbix::repo': manage_repo => false }" }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package(agent[:package_name]) }
        it { is_expected.not_to contain_class('zabbix::repo::apt') }
        it { is_expected.not_to contain_class('zabbix::repo::yum') }
        it { is_expected.not_to contain_class('zabbix::repo::zypper') }
      end

      {
        'an unknown variant' => [{ variant: 'agent3' }, %r{variant}],
        'package removal' => [{ package_ensure: 'absent' }, %r{does not remove packages}],
        'an invalid service state' => [{ service_ensure: 'absent' }, %r{service_ensure}],
        'settings with unmanaged config' => [{ manage_config: false, settings: { 'Server' => '192.0.2.1' } }, %r{require manage_config}],
        'a newline in a setting' => [{ settings: { 'Hostname' => "node\nAllowRoot=1" } }, %r{single-line values}],
        'a NUL in a setting' => [{ settings: { 'Hostname' => "node\u0000suffix" } }, %r{single-line values}],
        'a malformed key' => [{ settings: { 'Server=bad' => '192.0.2.1' } }, %r{settings}],
        'an array for a singleton option' => [{ settings: { 'Server' => ['192.0.2.1', '192.0.2.2'] } }, %r{not a repeatable agent setting}],
        'an empty repeated option' => [{ settings: { 'UserParameter' => [] } }, %r{settings}],
        'an unmanaged Include' => [{ settings: { 'Include' => '/tmp/*.conf' } }, %r{structured agent parameters}],
        'unordered allow rules' => [{ settings: { 'AllowKey' => 'system.run[*]' } }, %r{structured agent parameters}],
        'legacy remote commands' => [{ settings: { 'EnableRemoteCommands' => 1 } }, %r{structured agent parameters}],
        'an invalid rule action' => [{ access_rules: [{ 'action' => 'permit', 'pattern' => '*' }] }, %r{access_rules}],
        'a newline in a rule' => [{ access_rules: [{ 'action' => 'allow', 'pattern' => "key\nAllowRoot=1" }] }, %r{access_rules}],
      }.each do |description, (invalid_params, error)|
        context "with #{description}" do
          let(:params) { invalid_params }

          it { is_expected.to compile.and_raise_error(error) }
        end
      end

      unless os_facts[:os]['name'] == 'Fedora'
        context 'with an agent-v1-only setting in agent2' do
          let(:params) { { settings: { 'StartAgents' => 0 } } }

          it { is_expected.to compile.and_raise_error(%r{StartAgents is not supported by agent2}) }
        end
      end

      context 'with an agent2-only setting in agent v1' do
        let(:params) { { variant: 'agent', settings: { 'ControlSocket' => '/run/zabbix/agent.sock' } } }

        it { is_expected.to compile.and_raise_error(%r{ControlSocket is not supported by agent}) }
      end
    end
  end
end
