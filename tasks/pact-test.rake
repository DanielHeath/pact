require 'pact/tasks'

Pact::VerificationTask.new(:stubbing) do | pact |
	pact.uri './spec/support/stubbing.json', :pact_helper => './spec/support/stubbing.rb'
end

Pact::VerificationTask.new(:stubbing_using_allow) do | pact |
	pact.uri './spec/support/stubbing.json', :pact_helper => './spec/support/stubbing_using_allow.rb'
end

Pact::VerificationTask.new(:pass) do | pact |
	pact.uri './spec/support/test_app_pass.json'
end

Pact::VerificationTask.new(:fail) do | pact |
	pact.uri './spec/support/test_app_fail.json'
end

Pact::VerificationTask.new(:term) do | pact |
	pact.uri './spec/support/term.json'
end

Pact::VerificationTask.new(:case_insensitive_response_header_matching) do | pact |
	pact.uri './spec/support/case-insensitive-response-header-matching.json', :pact_helper => './spec/support/case-insensitive-response-header-matching.rb'
end

RSpec::Core::RakeTask.new('spec:standalone:fail') do | task |
	task.pattern = FileList["spec/standalone/**/*_fail_test.rb"]
end

RSpec::Core::RakeTask.new('spec:standalone:pass') do | task |
	task.pattern = FileList["spec/standalone/**/*_pass_test.rb"]
end

namespace :pact do

	desc 'Runs pact tests against a sample application, testing failure and success.'
	task :tests => ['pact:verify:stubbing','pact:verify:stubbing_using_allow', 'pact:verify:case_insensitive_response_header_matching', 'spec:standalone:pass'] do

		require 'pact/provider/pact_spec_runner'
		require 'open3'

		silent = true
		puts "Running task pact:tests"
		# Run these specs silently, otherwise expected failures will be written to stdout and look like unexpected failures.
		Pact.configuration.output_stream = StringIO.new if silent

		result = Pact::Provider::PactSpecRunner.new([{ uri: './spec/support/test_app_pass.json' }], silent: silent).run
		fail 'Expected pact to pass' unless (result == 0)

		result = Pact::Provider::PactSpecRunner.new([{ uri: './spec/support/test_app_fail.json', pact_helper: './spec/support/pact_helper.rb' }], silent: silent).run
		fail 'Expected pact to fail' if (result == 0)

		expect_to_pass "bundle exec rake pact:verify"
		expect_to_pass "bundle exec rake pact:verify:at[./spec/support/test_app_pass.json]"
		expect_to_fail "bundle exec rake pact:verify:at[./spec/support/test_app_fail.json]"
		expect_to_fail "bundle exec rake spec:standalone:fail"

		puts "Task pact:tests completed succesfully."
	end

	def expect_to_fail command
		success = execute_command command
		fail "Expected '#{command}' to fail" if success
	end

	def expect_to_pass command
		success = execute_command command
		fail "Expected '#{command}' to pass" unless success
	end

	def execute_command command
		result = nil
		Open3.popen3(command) {|stdin, stdout, stderr, wait_thr|
		  result = wait_thr.value
		}
		result.success?
	end

end