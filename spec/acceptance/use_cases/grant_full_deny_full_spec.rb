require 'spec_helper_acceptance'

describe 'Use Cases' do
  let(:acl_manifest) do
    <<-MANIFEST
      file { "#{target_parent}":
        ensure => directory
      }

      file { "#{target}":
        ensure => directory,
        require => File['#{target_parent}']
      }

      file { "#{target_child}":
        ensure  => file,
        content => '#{file_content}',
        require => File['#{target}']
      }

      acl { "#{target}":
        permissions  => [
          { identity => '#{group}',type => 'allow', rights => ['full'] },
        ],
      }
      ->
      acl { "#{target_child}":
        permissions  => [
          { identity => '#{user_id}',type => 'deny', rights => ['full'] },
        ],
      }
    MANIFEST
  end

  let(:update_manifest) do
    <<-MANIFEST
      file { "#{target_child}":
        ensure  => file,
        content => 'Better Content'
      }
    MANIFEST
  end

  context "Inherit 'full' Rights for User's Group on Container and Deny User 'full' Rights on Object in Container" do
    let(:test_short_name) { 'grant_full_deny_full' }
    let(:file_content) { 'Sad people' }
    let(:target_name) { "use_case_#{test_short_name}" }
    let(:target_child_name) { "use_case_child_#{test_short_name}.txt" }
    let(:target) { "#{target_parent}/#{target_name}" }
    let(:target_child) { "#{target}/#{target_child_name}" }
    let(:verify_content_command) { "cat /cygdrive/c/temp/#{target_name}/#{target_child_name}" }
    let(:group) { 'Administrators' }
    let(:user_id) { 'Administrator' }
    let(:verify_acl_child_command) { "icacls #{target_child}" }
    let(:target_child_first_ace_regex) { %r{.*\\Administrators:\(I\)\(F\)} }
    let(:target_child_second_ace_regex) { %r{.*\\Administrator:\(N\)} }

    it 'applies manifest' do
      idempotent_apply(acl_manifest)
    end

    it 'verifies ACL child rights' do
      run_shell(verify_acl_child_command) do |result|
        expect(result.stdout).to match(%r{#{target_child_first_ace_regex}})
        expect(result.stdout).to match(%r{#{target_child_second_ace_regex}})
      end
    end

    it 'attempts to update file, raises error' do
      apply_manifest(update_manifest, expect_failures: true) do |result|
        expect(result.stderr).to match(%r{Error:})
      end
    end

    it 'verifies file data integrity' do
      # Serverspec is unable to access the file
      run_shell(verify_content_command) do |result|
        expect(result.stdout).to match(file_content_regex(file_content))
      end
    end
  end
end
