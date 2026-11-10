# frozen_string_literal: true

require 'spec_helper'

describe 'zabbix::agent::fragment' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:title) { 'application' }
      let(:params) { { settings: { 'UserParameter' => ['app.ping,echo 1', 'app.version,echo 2'] } } }
      let(:fragment) { "/etc/zabbix/#{(os_facts[:os]['name'] == 'Fedora') ? 'agent' : 'agent2'}.puppet.d/application.conf" }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_class('zabbix::agent') }
      it { is_expected.not_to contain_class('zabbix') }

      it do
        is_expected.to contain_file(fragment).with(
          ensure: 'file', owner: 'root', group: 'zabbix', mode: '0640', show_diff: false,
          content: "UserParameter=app.ping,echo 1\nUserParameter=app.version,echo 2\n"
        ).that_notifies('Exec[zabbix-agent-validate]')
      end

      context 'when removed' do
        let(:params) { { ensure: 'absent' } }

        it { is_expected.to contain_file(fragment).with_ensure('absent').that_notifies('Exec[zabbix-agent-validate]') }
      end

      context 'with configuration managed externally' do
        let(:pre_condition) { "class { 'zabbix::agent': manage_config => false }" }

        it { is_expected.to compile.and_raise_error(%r{Agent fragments require manage_config => true}) }
      end

      context 'with a path as title' do
        let(:title) { '../outside' }

        it { is_expected.to compile.and_raise_error(%r{Invalid agent fragment name}) }
      end

      context 'with a singleton directive' do
        let(:params) { { settings: { 'Server' => '192.0.2.1' } } }

        it { is_expected.to compile.and_raise_error(%r{Server must be configured in the main agent settings}) }
      end

      context 'with unordered access rules' do
        let(:params) { { settings: { 'DenyKey' => '*' } } }

        it { is_expected.to compile.and_raise_error(%r{DenyKey must be configured in the main agent settings}) }
      end
    end
  end
end
