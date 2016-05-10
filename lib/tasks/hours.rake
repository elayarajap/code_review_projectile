namespace :hours do
  desc "Process which performs hours conversion in the decimal level from time entries table data"
  task :hours_conversion => :environment do
  	@time_entries = TimeEntry.all

	  	@time_entries.each do |entry|

			hrs = entry.hours.to_s
			hrs_bill = entry.billable.to_s
			hrs_non_bill = entry.non_billable.to_s
			hours_split = hrs.try(:split, ".")
			hours_bill_split = hrs_bill.try(:split, ".")
			hours_non_bill_split = hrs_non_bill.try(:split, ".")

			if hours_split[0].to_i > 0 and hours_split[1].to_i > 0
			pure_val_h = hours_split[0].to_i
		    decimal_val_h = hours_split[1].to_i
		    hours_converted = hours_math(pure_val_h,decimal_val_h)
		    @time_entry_update = entry.update_attributes(:hours=>hours_converted)
			end
			if hours_bill_split[0].to_i > 0 and hours_bill_split[1].to_i > 0
			pure_val_b = hours_bill_split[0].to_i
		  	decimal_val_b = hours_bill_split[1].to_i
		  	billable_hours_converted = hours_math(pure_val_b,decimal_val_b)
		  	@time_entry_update = entry.update_attributes(:billable=>billable_hours_converted)
			end
			if hours_non_bill_split[0].to_i > 0 and hours_non_bill_split[1].to_i > 0
			pure_val_ub = hours_non_bill_split[0].to_i
		    decimal_val_ub = hours_non_bill_split[1].to_i
		    non_billable_hours_converted = hours_math(pure_val_ub,decimal_val_ub)
		    @time_entry_update = entry.update_attributes(:non_billable=>non_billable_hours_converted)
			end

		end	

  	end

  	def hours_math(primaryval,decival)
  	decimal_constant_alloc = 30
  	if "#{decival}".length==1
  		decival_updated = "#{decival}0" 
  		decival = decival_updated.to_i
  	end	

  	if decival==0
  		deci_result = 0
  	elsif decival <=15
  		deci_result = 25
  	elsif decival <=30
  		deci_result = 50
  	else 
  		deci_result = 75
  	end

	float_result = "#{primaryval}.#{deci_result}"
  	result = float_result.to_f

  	return result
  	end

end
