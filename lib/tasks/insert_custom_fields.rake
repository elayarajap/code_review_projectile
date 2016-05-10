namespace :custom_fields do
  desc 'Inserting custom fields for additional fields based on project types'
  task :custom_fields_insertion => :environment do    
    custom_field_values = [
			  ['ProjectCustomField','Client Name','string',nil,'',0,0,1,1,0,3,0,nil,1,1,0],
    		  ['ProjectCustomField','Project Start Date','date',nil,'',0,0,1,1,0,3,0,nil,1,1,0],
    		  ['ProjectCustomField','Client company name','string',nil,'',0,0,1,1,0,3,0,nil,1,1,0],
    		  ['ProjectCustomField','SoW Date','date',nil,'',0,0,1,1,0,4,0,nil,1,1,0],
    		  ['ProjectCustomField','Location','string','--- \n...\n','',0,0,1,1,0,5,0,'Chennai, India',1,1,0],
    		  ['ProjectCustomField','Application Database','string',nil,'',0,0,1,1,0,6,0,nil,1,1,0],
    		  ['ProjectCustomField','Systems to be integrated with','string','--- \n...\n','',0,0,1,1,0,7,0,'',1,1,0],
    		  ['ProjectCustomField','Source control','string',nil,'',0,0,0,1,0,3,0,nil,1,1,0],
    		  ['ProjectCustomField','HTML Layouts','string',nil,'',0,0,0,1,0,3,0,nil,1,1,0],
    		  ['ProjectCustomField','APIs required','string',nil,'',0,0,0,0,0,3,0,nil,1,1,0],
    		  ['ProjectCustomField','Staging environment','string',nil,'',0,0,0,0,0,3,0,nil,1,1,0],
    		  ['ProjectCustomField','UAT environment','string',nil,'',0,0,0,0,0,3,0,nil,1,1,0],
    		  ['ProjectCustomField','Project Type','list',['Retainer Engagement','Fixed Bid Engagement','Time and Material Engagement'],'',0,0,0,1,0,3,0,'',1,1,0],
    		  ['UserCustomField','Contact Number','string',nil,'',0,0,0,0,0,3,0,nil,1,1,0],
    		  ['UserCustomField','Skype ID','string',nil,'',0,0,0,0,0,4,0,nil,1,1,0],
    		  ['UserCustomField','Designation','string',nil,'',0,0,0,0,0,5,0,nil,1,1,0],
    		  ['UserCustomField','Experience','string',nil,'',0,0,0,0,0,6,0,nil,1,1,0],
    		  ['ProjectCustomField','Effort /Schedule Months','string','--- \n...\n','',0,0,0,0,0,3,0,'',1,1,0],
    		  ['ProjectCustomField','Effort /Schedule Hours','string','--- \n...\n','',0,0,0,0,0,4,0,'',1,1,0],
          ['ProjectCustomField','is_mail_sent','bool',nil,'',0,0,0,1,0,4,0,'',1,1,0],
          ['ProjectCustomField','cc','string',nil,'',0,0,0,1,0,4,0,'',1,1,0]
    		]
    
    custom_field_values.each_with_index do |value,index|
			if value.present?
        begin
          if value[1] == "Project Type"
            is_created = CustomField.find_or_create_by_type_and_name_and_field_format_and_possible_values!(value[0],value[1],value[2],value[3])
          else
            is_created = CustomField.find_or_create_by_type_and_name_and_field_format!(value[0],value[1],value[2])
          end

          if is_created.try(:id).present?            
				    is_created.update_attributes(:possible_values=>value[3],:regexp=>value[4],:min_length=>value[5],:max_length=>value[6],:is_required=>value[7],:is_for_all=>value[8],:is_filter=>value[9],:position=>value[10],:searchable=>value[11],:default_value=>value[12],:editable=>value[13],:visible=>value[14],:multiple=>value[15])
          end          
          p "Inserted Custom Fields"
        rescue Exception => err
          p "Error in creating custom fields"
        end
			end			
		end
    p "Inserted All Custom Fields"        
	end
end

