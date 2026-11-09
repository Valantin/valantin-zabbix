# frozen_string_literal: true

require 'spec_helper'

describe 'zabbix::repo' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }

      it { is_expected.to contain_class('zabbix::repo') }

      context 'with an explicit version', skip: %w[Archlinux Fedora].include?(os_facts[:os]['name']) do
        let(:params) { { version: '7.0' } }

        it { is_expected.to compile.with_all_deps }

        it { is_expected.to contain_class('zabbix::repo').with_version('7.0') }
      end

      context 'with repository management disabled' do
        let(:params) { { manage_repo: false } }

        it { is_expected.to compile.with_all_deps }

        it { is_expected.to contain_class('zabbix::repo').with_manage_repo(false) }

        it { is_expected.not_to contain_class('zabbix::repo::apt') }

        it { is_expected.not_to contain_class('zabbix::repo::yum') }

        it { is_expected.not_to contain_class('zabbix::repo::zypper') }
      end

      context 'with repository management enabled' do
        let(:params) { { manage_repo: true } }
        let(:repository) do
          {
            'AlmaLinux'   => 'alma',
            'Amazon'      => 'amazonlinux',
            'CentOS'      => 'centos',
            'OracleLinux' => 'oracle',
            'RedHat'      => 'rhel',
            'Rocky'       => 'rocky',
          }.fetch(os_facts[:os]['name'])
        end

        case os_facts[:os]['family']
        when 'Debian'
          it { is_expected.to contain_class('zabbix::repo::apt') }

          it do
            is_expected.to contain_apt__source('zabbix').with(
              'comment'  => 'Zabbix stable repo 8.0',
              'ensure'   => 'present',
              'key'      => {
                'name'   => 'zabbix.gpg',
                'source' => 'https://repo.zabbix.com/zabbix-official-repo-apr2024.gpg',
              },
              'location' => "https://repo.zabbix.com/zabbix/8.0/stable/#{os_facts[:os]['name'].downcase}",
              'release'  => [os_facts[:os]['distro']['codename']],
              'repos'    => ['main'],
            )
          end
        when 'RedHat'
          if os_facts[:os]['name'] == 'Fedora'
            it { is_expected.to compile.and_raise_error(%r{Unsupported RPM distribution: #{os_facts[:os]['name']}}) }
          else
            it { is_expected.to contain_class('zabbix::repo::yum') }

            it do
              is_expected.to contain_yumrepo('zabbix').with(
                'baseurl'  => "https://repo.zabbix.com/zabbix/8.0/stable/#{repository}/#{os_facts[:os]['release']['major']}/$basearch/",
                'descr'    => 'Zabbix 8.0',
                'enabled'  => '1',
                'ensure'   => 'present',
                'gpgcheck' => '1',
                'gpgkey'   => 'https://repo.zabbix.com/RPM-GPG-KEY-ZABBIX-B5333005',
              )
            end
          end
        when 'Suse'
          it { is_expected.to contain_class('zabbix::repo::zypper') }

          it do
            is_expected.to contain_zypprepo('zabbix').with(
              'ensure'      => 'present',
              'autorefresh' => '1',
              'baseurl'     => "https://repo.zabbix.com/zabbix/8.0/stable/#{os_facts[:os]['name'].downcase}/#{os_facts[:os]['release']['major']}/$basearch/",
              'enabled'     => '1',
              'gpgcheck'    => '1',
              'gpgkey'      => 'https://repo.zabbix.com/RPM-GPG-KEY-ZABBIX-B5333005',
              'type'        => 'rpm-md',
            )
          end
        else
          it { is_expected.to compile.and_raise_error(%r{Unsupported OS family: #{os_facts[:os]['family']}}) }
        end
      end
    end
  end
end
