# frozen_string_literal: true

require 'spec_helper'

describe 'zabbix' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_class('zabbix').with_version('8.0') }

      if %w[Archlinux Fedora].include?(os_facts[:os]['name'])
        it { is_expected.to contain_class('zabbix::repo').with_manage_repo(false) }
      else
        it { is_expected.to contain_class('zabbix::repo').with_manage_repo(true) }

        it { is_expected.to contain_class('zabbix::repo::apt') } if os_facts[:os]['family'] == 'Debian'

        it { is_expected.to contain_class('zabbix::repo::yum') } if os_facts[:os]['family'] == 'RedHat'

        it { is_expected.to contain_class('zabbix::repo::zypper') } if os_facts[:os]['family'] == 'Suse'
      end

      context 'with an explicit version', skip: %w[Archlinux Fedora].include?(os_facts[:os]['name']) do
        let(:params) { { version: '7.0' } }

        it { is_expected.to compile.with_all_deps }

        it { is_expected.to contain_class('zabbix').with_version('7.0') }
      end
    end
  end
end
