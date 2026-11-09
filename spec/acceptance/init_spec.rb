# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'zabbix' do
  describe 'with defaults' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        include zabbix
        PUPPET
      end
    end

    case fact('os.name')
    when 'Archlinux'
      describe 'repository management' do
        it 'is disabled by module data' do
          expect(file('/etc/apt/sources.list.d/zabbix.list')).not_to be_file
          expect(file('/etc/yum.repos.d/zabbix.repo')).not_to be_file
          expect(file('/etc/zypp/repos.d/zabbix.repo')).not_to be_file
        end
      end
    when 'Fedora'
      describe 'repository management' do
        it 'is disabled by module data' do
          expect(file('/etc/yum.repos.d/zabbix.repo')).not_to be_file
        end
      end
    else
      case fact('os.family')
      when 'Debian'
        describe file('/etc/apt/keyrings/zabbix.gpg') do
          it { is_expected.to be_file }
        end

        describe file('/etc/apt/sources.list.d/zabbix.list') do
          it { is_expected.to be_file }

          its(:content) do
            os_name = fact('os.name').downcase
            codename = fact('os.distro.codename')

            is_expected.to match(%r{signed-by=/etc/apt/keyrings/zabbix\.gpg})
            is_expected.to match(%r{https://repo\.zabbix\.com/zabbix/8\.0/stable/#{os_name}\s+#{codename}\s+main})
          end
        end
      when 'RedHat'
        describe file('/etc/yum.repos.d/zabbix.repo') do
          it { is_expected.to be_file }

          its(:content) do
            repository = {
              'AlmaLinux'   => 'alma',
              'Amazon'      => 'amazonlinux',
              'CentOS'      => 'centos',
              'OracleLinux' => 'oracle',
              'RedHat'      => 'rhel',
              'Rocky'       => 'rocky',
            }.fetch(fact('os.name'))
            os_major = fact('os.release.major')

            is_expected.to match(%r{^baseurl=https://repo\.zabbix\.com/zabbix/8\.0/stable/#{repository}/#{os_major}/\$basearch/$})
            is_expected.to match(%r{^enabled=1$})
            is_expected.to match(%r{^gpgcheck=1$})
            is_expected.to match(%r{^gpgkey=https://repo\.zabbix\.com/RPM-GPG-KEY-ZABBIX-B5333005$})
          end
        end
      when 'Suse'
        describe file('/etc/zypp/repos.d/zabbix.repo') do
          it { is_expected.to be_file }

          its(:content) do
            os_major = fact('os.release.major')

            is_expected.to match(%r{^baseurl=https://repo\.zabbix\.com/zabbix/8\.0/stable/sles/#{os_major}/\$basearch/$})
            is_expected.to match(%r{^enabled=1$})
            is_expected.to match(%r{^autorefresh=1$})
            is_expected.to match(%r{^gpgcheck=1$})
            is_expected.to match(%r{^gpgkey=https://repo\.zabbix\.com/RPM-GPG-KEY-ZABBIX-B5333005$})
            is_expected.to match(%r{^type=rpm-md$})
          end
        end
      end
    end
  end
end
