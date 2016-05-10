namespace :migration do

	desc 'Migrate the approved time entries with user,group,account,project and time entries'
	task :aprroved_time_entries => :environment do
		puts "Migration Process is Running..."
		# Write you code here
		puts "Migration Process is Done."
	end

	task :update_default_estimated_hours => :environment do 
		puts "Estimated hours started updating default value as 0 for nil value."
		@issues = Issue.where(:estimated_hours => nil)
		@issues.each do |issue|
			issue.update_attributes(:estimated_hours => 0)
		end
		puts "Estimated hours Ended updating default value as 0 for nil value."
	end

end
