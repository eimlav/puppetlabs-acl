require 'spec_helper_acceptance'

describe 'Identity' do
  [
    { id: 'S-1-15-2-1',
      acl_regex: %r{.*APPLICATION PACKAGE AUTHORITY\\ALL APPLICATION PACKAGES:\(OI\)\(CI\)\(F\)},
      minimum_kernel: 6.3 },
    # NOTE: 'APPLICATION PACKAGE AUTHORITY\\ALL APPLICATION PACKAGES' doesn't work due to Windows API
    { id: 'ALL APPLICATION PACKAGES',
      acl_regex: %r{.*APPLICATION PACKAGE AUTHORITY\\ALL APPLICATION PACKAGES:\(OI\)\(CI\)\(F\)},
      minimum_kernel: 6.3 },
    { id: 'S-1-15-2-2',
      acl_regex: %r{.*APPLICATION PACKAGE AUTHORITY\\ALL RESTRICTED APPLICATION PACKAGES:\(OI\)\(CI\)\(F\)},
      minimum_kernel: 10.0 },
    # NOTE: 'APPLICATION PACKAGE AUTHORITY\\ALL RESTRICTED APPLICATION PACKAGES' doesn't work due to Windows API
    { id: 'ALL RESTRICTED APPLICATION PACKAGES',
      acl_regex: %r{.*APPLICATION PACKAGE AUTHORITY\\ALL RESTRICTED APPLICATION PACKAGES:\(OI\)\(CI\)\(F\)},
      minimum_kernel: 10.0 },
  ].each do |account|

    target = "c:/#{SecureRandom.uuid}"
    verify_acl_command = "icacls #{target}"

    windows_agents.each do |agent|
      context "Specify APPLICATION PACKAGE AUTHORITY accounts on #{agent}" do
        it "Check Minimum Supported OS for #{account[:id]}" do
          kernelmajversion = on(agent, facter('kernelmajversion')).stdout.chomp.to_f
          # try next agent if user is unsupported on this Windows version
          if kernelmajversion < account[:minimum_kernel]
            warn("This test requires Windows kernel #{account[:minimum_kernel]} but this host only has #{kernelmajversion}")
            skip

            acl_manifest = <<-MANIFEST
              file { '#{target}':
                ensure => directory
              }

              acl { '#{target}':
                permissions => [
                  { identity => '#{account[:id]}', rights => ['full'] },
                  { identity => 'Administrators', rights => ['full'] },
                ],
              }
            MANIFEST

            it 'applies manifest' do
              # exit code 2: The run succeeded, and some resources were changed.
              execute_manifest_on(agent, acl_manifest, expect_changes: true) do |result|
                expect(result.stderr).not_to match(%r{Error:})
              end
            end

            original_acl_rights = ''
            it 'verifies ACL rights' do
              on(agent, verify_acl_command) do |result|
                original_acl_rights = result.stdout
                expect(original_acl_rights).to match(%r{#{account[:acl_regex]}})
              end
            end

            it 'applies manifest again' do
              execute_manifest_on(agent, acl_manifest, catch_changes: true) do |result|
                expect(result.stderr).to match(%r{Error:})
              end
            end

            it 'verifies ACL rights again' do
              on(agent, verify_acl_command) do |result|
                expect(result.stdout).to match(%r{account[:acl_regex]})
                expect(result.stdout).to eq(original_acl_rights)
              end
            end
          end
        end
      end
    end
  end
end
