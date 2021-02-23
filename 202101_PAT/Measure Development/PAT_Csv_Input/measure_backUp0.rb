#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for access to C++ documentation on model air_loop_objects (click on "model" in the main window to view model air_loop_objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html
require 'csv'
require 'time'
require 'date'
#start the measure
class Input_CSV < OpenStudio::Measure::ModelMeasure

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "InputCSV"
  end

    def description
    return 'read csv input from data'
  end

  def modeler_description
    return 'process data input into file for process model'
  end
 

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new



    # Make an argument for evap effectiveness
    input_csv_path = OpenStudio::Measure::OSArgument::makeStringArgument("input_csv_folder_path",true)
    input_csv_path.setDisplayName("raw_data_input_folder_path")
    input_csv_path.setDefaultValue("data_file")
    args << input_csv_path

    test_numbers =  OpenStudio::StringVector.new
    test_numbers << 'Experiment3_200124_input.csv'
    test_numbers << 'Experiment6_200210_input.csv'
    test_numbers << 'Experiment8_200214_input.csv'
    
    test_names =  OpenStudio::StringVector.new
    test_names << 'UA_test'
    test_names << 'Cooling_test'
    test_names << 'Plenum_test'

    test_selections = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('test_data',test_numbers,test_names,true)

    
    test_selections.setDisplayName("Experiment")
    test_selections.setDefaultValue("Experiment3_200124_input.csv")
    args << test_selections

   
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)


	 # Use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    
    input_folder_path  = runner.getStringArgumentValue("input_csv_folder_path",user_arguments) 
    input_csv_name = runner.getStringArgumentValue("test_data",user_arguments) 


    input_csv_path = File.join(input_folder_path,input_csv_name)
    if !File.exist?input_csv_path
      runner.registerError("Input CSV Path is not exist: #{input_folder_path}")
    end

    run_csv_path = File.join(runner.workflow.absoluteRootDir.to_s ,File.basename(input_csv_path,".csv")+"_out.csv")
    runner.registerInitialCondition("Input: #{File.expand_path(input_csv_path)}")
   
    csv_input_file =  CSV.read(input_csv_path, :encoding => 'windows-1251:utf-8', :headers => true )
    header_csv = csv_input_file.headers
      data_csv = csv_input_file.to_a[2..-1]
   
    
    

    
 
      counted = data_csv.size
      one_day_minutes = 60 * 24
      header_csv += ["HVAC_Schedule","ConvectionLoadRatio","RadiationLoadRatio"]
  ## headers: TimePST,Internal_Temperature_C,External_Temperature_C,Heat_gain,HVAC_Schedule,ConvectionLoadRatio,RadiationLoadRatio
    ## Note: The 2-4 is from source data. HVAC_Schedule is idealLoad running status for start up period
    ## convection and radiation load ratios are ratio to designed load defnitions (default 500 W)
    ## the Zone Electrical Equipment is matched with data input 


    # puts data_csv[0][0]
    start_time = DateTime.strptime(data_csv[0][0].strip,"%m/%d/%Y %H:%M")
    begin_time =   DateTime.new(start_time.year,1,1,0,1)
    
      start_up_days = 0 ## 3 day start_up
      start_up_ranges = (start_up_days*60*24).times.map {|i|begin_time+i/24.0/60.0 }
      run_ranges = data_csv.size.times.map {|i| start_up_ranges[-1]+(i+1)/24.0/60.0}
      
      
      start_up_gain = 0.0 # internal_heatgain during startup in W
   
      # puts (1..start_up_days).step(1/24.0/60.0).map {|x| DateTime.new(x)+}[0]
      # put

      stable_radiation_frac = 0.0 #  radiation fraction after peak (constinously 25 W)
      total_internal_gain_def_desgin_level= 100.0
      # start_up_times = start_up_days * 24 *60 
      start_up_data = [start_up_gain.to_s]+data_csv[0][2..3]+["1.0",(start_up_gain/total_internal_gain_def_desgin_level).to_f.round(5).to_s,"0.0"]
    
     
      
      CSV.open(run_csv_path,"wb") do |csv|
        csv <<  header_csv #+ ["hybrid_ach"]  
        start_up_ranges.each do |i|  
          csv <<  [i.strftime("%Y/%m/%d %H:%M")]+start_up_data #+ [data_inversed_csv[i]]
        end
        
        data_csv.size.times.each do |i| 
          
          row = [run_ranges[i].strftime("%Y/%m/%d %H:%M")] + data_csv[i][1..-1]
          
          total_heat_gain_value = row[1].to_f
          
          
          total_heat_gain_fraction =  total_heat_gain_value/total_internal_gain_def_desgin_level
          radiation_fraction_schedule = stable_radiation_frac * total_heat_gain_fraction
          convection_fraction_schedule =  total_heat_gain_fraction - radiation_fraction_schedule
          hvac_shedule_value =  i == 0 ? "1.0" : "0.0"
          row += [hvac_shedule_value,convection_fraction_schedule.to_s, radiation_fraction_schedule.to_s ] 
         # row += [data_inversed_csv[start_up_times+counted+i]]
          csv << row
        end
        
        
        # row = ["01/01/2020 00:02:00","0.0"]+data_csv[-1][3..-1]+["0.0","0.0","0.0"]
    
        # (8760*60-counted-start_up_times-warm_up_times).times.each {|i| csv << row}
      end
      # external_file = OpenStudio::Model::ExternalFile::getExternalFile(model,run_csv_path).get
      # external_file.setName("ExternalFileTest")
  
      runner.registerFinalCondition("Output: #{File.expand_path(run_csv_path)}")
      runner.registerValue('run_csv_path',File.expand_path(run_csv_path))
  return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
Input_CSV.new.registerWithApplication
