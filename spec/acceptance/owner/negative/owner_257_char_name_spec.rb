require 'spec_helper_acceptance'

shared_examples 'apply manifest and verify' do |agent, target_name, file_content, user_id, owner_id|
  let(:acl_manifest) do
    <<-MANIFEST
      file { "#{target_parent}":
        ensure => directory
      }

      file { "#{target_parent}/#{target_name}":
        ensure  => file,
        content => '#{file_content}',
        require => File['#{target_parent}']
      }

      user { "#{user_id}":
        ensure     => present,
        groups     => 'Users',
        managehome => true,
        password   => "L0v3Pupp3t!"
      }

      acl { "#{target_parent}/#{target_name}":
        permissions  => [
          { identity => '#{user_id}',
            rights   => ['modify']
          },
        ],
        owner        => '#{owner_id}'
      }
    MANIFEST
  end

  let(:verify_content_path) { "c:\\temp\\#{target_name}" }

  it 'applies manifest, raises error' do
    execute_manifest_on(agent, acl_manifest, debug: true) do |result|
      expect(result.stderr).to match(%r{Error:.*User does not exist})
    end
  end

  it 'verifies file data integrity' do
    expect(file(verify_content_path)).to be_file
    expect(file(verify_content_path).content).to match(%r{#{file_content}})
  end
end

describe 'Owner - Negative' do
  context 'Specify 257 Character String for Owner' do
    file_content = 'I AM TALKING VERY LOUD!'
    target_name = 'owner_257_char_name.txt'
    owner_id = 'jasqddsweruwqiouroaysfyuasudyfaisoyfqoiuwyefiaysdiyfzixycivzixyvciqywifyiasdiufyasdygfasirfwerqiuwyeriatsdtfastdfqwyitfastdfawerfytasdytfasydgtaisdytfiasydfiosayghiayhidfhygiasftawyegyfhgaysgfuyasgdyugfasuiyfguaqyfgausydgfaywgfuasgdfuaisydgfausasdfuygsadfyg' # rubocop:disable Metrics/LineLength

    windows_agents.each do |agent|
      include_examples 'apply manifest and verify', agent, target_name, file_content, user_id, owner_id
    end
  end
end
