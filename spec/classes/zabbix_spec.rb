# frozen_string_literal: true

require 'spec_helper'

describe 'zabbix' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_class('zabbix').with_version('8.0') }

      context 'with an explicit version' do
        let(:params) { { version: '7.0' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('zabbix').with_version('7.0') }
      end
    end
  end
end
