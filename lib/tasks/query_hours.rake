namespace :query_hours do
  desc "UPDATE queries over the time entries data and manipulate hours to handle decimal values"
  task :update_queries => :environment do

	sql_query1 = "UPDATE `time_entries` SET hours=0.15 WHERE hours like '%0.01%' OR hours like '%0.02%' OR hours like '%0.05%' OR hours like '%0.06%' OR hours like '%0.1%' OR hours like '%0.2%'"
	database_operations(sql_query1)
	sql_query2 = "UPDATE `time_entries` SET billable=0.15 WHERE billable like '%0.01%' OR billable like '%0.02%' OR billable like '%0.05%' OR billable like '%0.06%' OR billable like '%0.1%' OR billable like '%0.2%'"
	database_operations(sql_query2)
	sql_query3 = "UPDATE `time_entries` SET non_billable=0.15 WHERE non_billable like '%0.01%' OR 	non_billable like '%0.02%' OR non_billable like '%0.05%' OR non_billable like '%0.06%' OR non_billable like '%0.1%' OR non_billable like '%0.2%'"
	database_operations(sql_query3)

	sql_query4 = "UPDATE `time_entries` SET hours=0.30 WHERE hours like '%0.25%'"
	database_operations(sql_query4)
	sql_query5 = "UPDATE `time_entries` SET billable=0.30 WHERE billable like '%0.25%'"
	database_operations(sql_query5)
	sql_query6 = "UPDATE `time_entries` SET non_billable=0.30 WHERE non_billable like '%0.25%'"
	database_operations(sql_query6)

	sql_query7 = "UPDATE `time_entries` SET hours=1.0 WHERE hours like '%0.55%' OR hours like '%0.6%'"
	database_operations(sql_query7)
	sql_query8 = "UPDATE `time_entries` SET billable=1.0 WHERE billable like '%0.55%' OR billable like '%0.6%'"
	database_operations(sql_query8)
	sql_query9 = "UPDATE `time_entries` SET non_billable=1.0 WHERE non_billable like '%0.55%' OR non_billable like '%0.6%'"
	database_operations(sql_query9)

	sql_query10 = "UPDATE `time_entries` SET hours=0.45 WHERE hours like '%0.4%' OR hours like '%0.5%'"
	database_operations(sql_query10)
	sql_query11 = "UPDATE `time_entries` SET billable=0.45 WHERE billable like '%0.4%' OR billable like '%0.5%'"
	database_operations(sql_query11)
	sql_query12 = "UPDATE `time_entries` SET non_billable=0.45 WHERE non_billable like '%0.4%' OR non_billable like '%0.5%'"
	database_operations(sql_query12)

	sql_query13 = "UPDATE `time_entries` SET hours=1.15 WHERE hours like '%0.7%' OR hours like '%0.8%'"
	database_operations(sql_query13)
	sql_query14 = "UPDATE `time_entries` SET billable=1.15 WHERE billable like '%0.7%' OR billable like '%0.8%'"
	database_operations(sql_query14)
	sql_query15 = "UPDATE `time_entries` SET non_billable=1.15 WHERE non_billable like '%0.7%' OR non_billable like '%0.8%'"
	database_operations(sql_query15)

	sql_query16 = "UPDATE `time_entries` SET hours=1.30 WHERE hours like '%0.9%'"
	database_operations(sql_query16)
	sql_query17 = "UPDATE `time_entries` SET billable=1.30 WHERE billable like '%0.9%'"
	database_operations(sql_query17)
	sql_query18 = "UPDATE `time_entries` SET non_billable=1.30 WHERE non_billable like '%0.9%'"
	database_operations(sql_query18)

	sql_query19 = "UPDATE `time_entries` SET hours=0 WHERE hours < 0.0999 and hours != 0"
	database_operations(sql_query19)
	sql_query20 = "UPDATE `time_entries` SET billable=0 WHERE billable  < 0.0999 and billable != 0"
	database_operations(sql_query20)
	sql_query21 = "UPDATE `time_entries` SET non_billable=0 WHERE non_billable < 0.0999 and non_billable != 0"
	database_operations(sql_query21)

	sql_query22 = "UPDATE `time_entries` SET hours=0.25 WHERE hours like '%0.15%'"
	database_operations(sql_query22)
	sql_query23 = "UPDATE `time_entries` SET billable=0.25 WHERE billable like '%0.15%'"
	database_operations(sql_query23)
	sql_query24 = "UPDATE `time_entries` SET non_billable=0.25 WHERE non_billable like '%0.15%'"
	database_operations(sql_query24)

	sql_query25 = "UPDATE `time_entries` SET hours=0.5 WHERE hours like '%0.3%'"
	database_operations(sql_query25)
	sql_query26 = "UPDATE `time_entries` SET billable=0.5 WHERE billable like '%0.3%'"
	database_operations(sql_query26)
	sql_query27 = "UPDATE `time_entries` SET non_billable=0.5 WHERE non_billable like '%0.3%'"
	database_operations(sql_query27)

	sql_query28 = "UPDATE `time_entries` SET hours=0.75 WHERE hours like '%0.45%'"
	database_operations(sql_query28)
	sql_query29 = "UPDATE `time_entries` SET billable=0.75 WHERE billable like '%0.45%'"
	database_operations(sql_query29)
	sql_query30 = "UPDATE `time_entries` SET non_billable=0.75 WHERE non_billable like '%0.45%'"
	database_operations(sql_query30)

  end

  def database_operations(sql_query)
  	ActiveRecord::Base.connection.execute(sql_query)
  end

end