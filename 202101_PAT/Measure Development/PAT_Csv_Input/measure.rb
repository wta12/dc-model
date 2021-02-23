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
    test_numbers << 'Experiment9_200707_input.csv'
    # test_numbers << 'Experiment8_200214_input_cooling.csv'
    test_names =  OpenStudio::StringVector.new
    test_names << 'UA_test'
    test_names << 'Cooling_test'
    test_names << 'Plenum_test'
    test_names << 'Inverter_test'
    # test_names << 'Plenum_test_cooling'
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

    
    
    if File.exist?File.join(input_folder_path,input_csv_name)
      input_csv_path = File.join(input_folder_path,input_csv_name)
      runner.registerInfo("Join input exist: #{input_csv_path }")
    elsif  runner.workflow.findFile(input_csv_name).is_initialized
      input_csv_path = runner.workflow.findFile(input_csv_name).get.to_s
      runner.registerInfo("workflow find  exist: #{input_csv_path }")
    else
      runner.registerInfo("#{runner.workflow.filePaths.map {|x| x.to_s}.join("\n")}")
      runner.registerError("Input CSV Path is not exist: #{File.expand_path(input_csv_path)}")
    end

    run_csv_path = File.join(runner.workflow.absoluteRootDir.to_s,File.basename(input_csv_path,".csv")+"_out.csv")
    runner.registerInitialCondition("Input: #{File.expand_path(input_csv_path)}")
    
    
    if input_csv_name == "Experiment3_200124_input.csv"
      steady_time_start = DateTime.strptime("1/22/2020 14:16:17","%m/%d/%Y %H:%M:%S") 
      steady_time_end = DateTime.strptime("1/23/2020 22:41:19","%m/%d/%Y %H:%M:%S")
      cooling_time_start = steady_time_start
      metered_col = 3
      add_header  = ["HVAC_Schedule","ConvectionLoadRatio","RadiationLoadRatio","Measure_PeriodShedule"]
    elsif input_csv_name == "Experiment6_200210_input.csv"
       steady_time_start = DateTime.strptime("2/10/2020 10:31:56","%m/%d/%Y %H:%M:%S") 
       steady_time_end = DateTime.strptime("2/10/2020 18:24:56","%m/%d/%Y %H:%M:%S")
       cooling_time_start = steady_time_start
       metered_col = 3
       add_header  = ["HVAC_Schedule","ConvectionLoadRatio","RadiationLoadRatio","Measure_PeriodShedule","CoolingPower","Inlet_water"]
    elsif input_csv_name.start_with?"Experiment8_200214_input.csv"
      steady_time_start = DateTime.strptime("2/12/2020 16:46:09","%m/%d/%Y %H:%M:%S") 
       steady_time_end = DateTime.strptime("2/14/2020 15:57:11","%m/%d/%Y %H:%M:%S")
       cooling_time_start = DateTime.strptime("2/14/2020 01:00:00","%m/%d/%Y %H:%M:%S") 
       metered_col = 3
       second_metered_col = 6
       add_header  = ["HVAC_Schedule","ConvectionLoadRatio","RadiationLoadRatio","Measure_PeriodShedule","CoolingPower","Inlet_water","Plenum_Temp","Cooling_Schedule","Mixing_Schedule"]
      # elsif input_csv_name.start_with?"Experiment8_200214_input_cooling.csv"
      #   steady_time_start = DateTime.strptime("2/14/2020 11:58:11","%m/%d/%Y %H:%M:%S") 
      #   steady_time_end = DateTime.strptime("2/14/2020 15:58:11","%m/%d/%Y %H:%M:%S")
      #    metered_col = 3
    elsif input_csv_name.start_with?"Experiment9_200707_input.csv"
      steady_time_start = DateTime.strptime("7/7/2020 16:00:30","%m/%d/%Y %H:%M:%S") 
       steady_time_end = DateTime.strptime("7/9/2020 20:58:30","%m/%d/%Y %H:%M:%S")
       cooling_time_start = DateTime.strptime("7/9/2020 08:00:30","%m/%d/%Y %H:%M:%S") 
       metered_col = 3
       second_metered_col = 6
       add_header  = ["HVAC_Schedule","ConvectionLoadRatio","RadiationLoadRatio","Measure_PeriodShedule","CoolingPower","Inlet_water","Plenum_Temp","Cooling_Schedule","Mixing_Schedule"]
    end
    meter_csv_path =  File.join(runner.workflow.absoluteRootDir.to_s,File.basename(input_csv_path,".csv")+"_metered.csv")
    csv_input_file =  CSV.read(input_csv_path, :encoding => 'windows-1251:utf-8', :headers => true )
    csv_input_header = csv_input_file.headers


    if input_csv_name == "Experiment6_200210_input.csv"
      header_csv = csv_input_header[0..-3]+add_header
    elsif input_csv_name == "Experiment8_200214_input.csv"
      header_csv = csv_input_header[0..-4]+add_header
    elsif input_csv_name == "Experiment9_200707_input.csv"
      header_csv = csv_input_header[0..-4]+add_header
    else
      header_csv = csv_input_header
    end
    
   
    data_csv = csv_input_file.to_a[2..-1]
    
      counted = data_csv.size
      one_day_minutes = 60 * 24
      
     
  ## headers: TimePST,Internal_Temperature_C,External_Temperature_C,Heat_gain,HVAC_Schedule,ConvectionLoadRatio,RadiationLoadRatio
    ## Note: The 2-4 is from source data. HVAC_Schedule is idealLoad running status for start up period
    ## convection and radiation load ratios are ratio to designed load defnitions (default 500 W)
    ## the Zone Electrical Equipment is matched with data input 

    metered_data = []
    # puts data_csv[0][0]
    start_time = DateTime.strptime(data_csv[0][0].strip,"%m/%d/%Y %H:%M")
    year_input = start_time.year-1
    begin_time =   DateTime.new(year_input,1,1,0,1)
    total_internal_gain_def_desgin_level = 100.0
    stable_radiation_frac = 0.0
    start_up_periods  = 1.0 
    start_up_timestep = (start_up_periods*one_day_minutes).to_i


    runner.registerInfo((header_csv).join(" ; "))
    
    warm_up_data  = []

    start_up_timestep.times.each do |i|
      if input_csv_name == "Experiment3_200124_input.csv"
    
        row = [begin_time.strftime("%Y/%m/%d %H:%M"),"0.0"]+data_csv[0][2..-1]+["1.0","0.0","0.0","0.0"]
      elsif input_csv_name == "Experiment6_200210_input.csv"
        row = [begin_time.strftime("%Y/%m/%d %H:%M"),"0.0"]+data_csv[0][2..-3]+["1.0","0.0","0.0","0.0","0.0",data_csv[0][-1]]
        # runner.registerInfo(header_csv.zip(row).map {|x,y| "#{x} | #{y}"}.join(" :*: "))
        # put
      elsif input_csv_name.start_with?"Experiment8_200214_input.csv"
        row = [begin_time.strftime("%Y/%m/%d %H:%M"),"0.0"]+data_csv[0][2..-4]+["1.0","0.0","0.0","0.0","0.0",data_csv[0][-2],data_csv[0][-1],0.0,0.0]
      elsif input_csv_name.start_with?"Experiment9_200707_input.csv"
        row = [begin_time.strftime("%Y/%m/%d %H:%M"),"0.0"]+data_csv[0][2..-4]+["1.0","0.0","0.0","0.0","0.0",data_csv[0][-2],data_csv[0][-1],0.0,0.0]
        
      end
      begin_time +=  (1.0/1440.0)
      warm_up_data << row
    end
    runner.registerInfo("#{__LINE__} - First_Warmup_row: " + header_csv.zip(warm_up_data[0]).to_s)
    runner.registerInfo("#{__LINE__} - End_Warmup_row: " + header_csv.zip(warm_up_data[-1]).to_s)

    test_data = []
    data_csv.size.times.each do |i| 
          
      # runner.registerInfo(begin_time.strftime("%Y/%m/%d %H:%M"))
      if input_csv_name == "Experiment6_200210_input.csv"
        row = [begin_time.strftime("%Y/%m/%d %H:%M")] + data_csv[i][1..-3]
      elsif input_csv_name.start_with?"Experiment8_200214_input.csv"
        row = [begin_time.strftime("%Y/%m/%d %H:%M")] + data_csv[i][1..-4]
      elsif input_csv_name.start_with?"Experiment9_200707_input.csv"
        row = [begin_time.strftime("%Y/%m/%d %H:%M")] + data_csv[i][1..-4]
      else
        row = [begin_time.strftime("%Y/%m/%d %H:%M")] + data_csv[i][1..-1]
      end

      metered_period = (DateTime.strptime(data_csv[i][0].strip,"%m/%d/%Y %H:%M:%S") >= steady_time_start) & (DateTime.strptime(data_csv[i][0].strip,"%m/%d/%Y %H:%M:%S") <= steady_time_end)
      unsteady_cooling_period = (DateTime.strptime(data_csv[i][0].strip,"%m/%d/%Y %H:%M:%S") >= DateTime.strptime("2/13/2020 16:00:00","%m/%d/%Y %H:%M:%S")) & \
       (DateTime.strptime(data_csv[i][0].strip,"%m/%d/%Y %H:%M:%S") < cooling_time_start)
      # if input_csv_name.start_with?"Experiment8_200214_input.csv"
       
      #   metered_period = metered_period &   
      # end

      cooling_period = (DateTime.strptime(data_csv[i][0].strip,"%m/%d/%Y %H:%M:%S") >= cooling_time_start) & (DateTime.strptime(data_csv[i][0].strip,"%m/%d/%Y %H:%M:%S") <= steady_time_end)
      
      if  metered_period
        if input_csv_name.start_with?"Experiment8_200214_input.csv"
        
         metered_data << [begin_time.strftime("%m/%d/%Y %H:%M"), data_csv[i][metered_col],data_csv[i][second_metered_col],data_csv[i][0]] unless unsteady_cooling_period
        elsif input_csv_name.start_with?"Experiment9_200707_input.csv"
          metered_data << [begin_time.strftime("%m/%d/%Y %H:%M"), data_csv[i][metered_col],data_csv[i][second_metered_col],data_csv[i][0]] 
        else
         metered_data << [begin_time.strftime("%m/%d/%Y %H:%M"), data_csv[i][metered_col],data_csv[i][0]]
        end
      end
      
      total_heat_gain_value = row[1].to_f
      
      
      total_heat_gain_fraction =  total_heat_gain_value/total_internal_gain_def_desgin_level
      radiation_fraction_schedule = stable_radiation_frac * total_heat_gain_fraction
      convection_fraction_schedule =  total_heat_gain_fraction - radiation_fraction_schedule
   
      hvac_shedule_value =  i == 0 ? "1.0" : "0.0"
      mixing_shedule_value =  i == 0 ? "0.0" : "1.0"
      cooling_schedule_value = cooling_period ? "1.0" : "0.0"
      if input_csv_name == "Experiment6_200210_input.csv"
        row += [hvac_shedule_value,convection_fraction_schedule.to_s, radiation_fraction_schedule.to_s,"1.0",data_csv[i][-2],data_csv[i][-1]]
      elsif input_csv_name.start_with?"Experiment8_200214_input.csv"
     
        row += [hvac_shedule_value,convection_fraction_schedule.to_s, radiation_fraction_schedule.to_s,"1.0",
          data_csv[i][-3],data_csv[i][-2],data_csv[i][-1],cooling_schedule_value,mixing_shedule_value]
        # runner.registerInfo(header_csv.zip(row).join(" _|_ "))
        # put
      elsif input_csv_name.start_with?"Experiment9_200707_input.csv"
        convection_fraction_schedule = convection_fraction_schedule/2.0
         radiation_fraction_schedule = 0
         convection_fraction_schedule = 0
        row += [hvac_shedule_value,convection_fraction_schedule.to_s, radiation_fraction_schedule.to_s,"1.0",
          data_csv[i][-3],data_csv[i][-2],data_csv[i][-1],cooling_schedule_value,mixing_shedule_value]
      else
       
        row += [hvac_shedule_value,convection_fraction_schedule.to_s, radiation_fraction_schedule.to_s,"1.0",data_csv[i][-1]] 
      end
      
      begin_time +=  (1.0/1440.0)

     
      test_data << row
     
        
    end
    runner.registerInfo("#{__LINE__} - First_Test_row: " + header_csv.zip(test_data[0]).to_s)
    runner.registerInfo("#{__LINE__} - Second_Test_row: " + header_csv.zip(test_data[1]).to_s)
    runner.registerInfo("#{__LINE__} - End_Cooling_row: " + header_csv.zip(test_data[-50]).to_s)
    runner.registerInfo("#{__LINE__} - End_Test_row: " + header_csv.zip(test_data[-1]).to_s)

    remain_data = []
    (8760*60-counted-start_up_timestep).times.each do |i|
      if input_csv_name == "Experiment3_200124_input.csv"
        row = [begin_time.strftime("%Y/%m/%d %H:%M"),"0.0"]+data_csv[-1][2..-1]+["1.0","0.0","0.0","0.0"]
      elsif input_csv_name == "Experiment6_200210_input.csv"
        row = [begin_time.strftime("%Y/%m/%d %H:%M"),"0.0"]+data_csv[-1][2..-3]+["1.0","0.0","0.0","0.0","0.0",data_csv[-1][-1]]
      elsif input_csv_name.start_with?"Experiment8_200214_input.csv"
        row = [begin_time.strftime("%Y/%m/%d %H:%M"),"0.0"]+data_csv[-1][2..-4]+["1.0","0.0","0.0","0.0",data_csv[-1][-3],data_csv[-1][-2],data_csv[-1][-1],0.0,0.0]
      elsif input_csv_name.start_with?"Experiment9_200707_input.csv"
        row = [begin_time.strftime("%Y/%m/%d %H:%M"),"0.0"]+data_csv[-1][2..-4]+["1.0","0.0","0.0","0.0",data_csv[-1][-3],data_csv[-1][-2],data_csv[-1][-1],0.0,0.0]
      end
      remain_data << row
      begin_time +=  (1.0/1440.0)
    end
    
    
  runner.registerInfo("#{__LINE__} - First_Remain_row: " + header_csv.zip(remain_data[0]).to_s)
  
 
  runner.registerInfo("#{__LINE__} - End_Remain_row: " + header_csv.zip(remain_data[-1]).to_s)

  CSV.open(run_csv_path,"wb") do |csv|
    csv << header_csv
    (warm_up_data+test_data+remain_data).each do |row|
      csv << row
    end
  end
  
    
      CSV.open(meter_csv_path,"wb") do |csv|
      if input_csv_name.start_with?"Experiment8_200214_input.csv"
        csv << ["Date/Time","ZoneTemperature","PlenumTemperature"]
      elsif input_csv_name.start_with?"Experiment9_200707_input.csv"
        csv << ["Date/Time","ZoneTemperature","PlenumTemperature"]
      else
        csv << ["Date/Time","ZoneTemperature"]
      end
        metered_data.each do |row|
          csv << row
        end
      end

      # simulationControl = model.getSimulationControl
      # run_period = simulationControl.runPeriods[0]
      year =  model.getYearDescription 
      year.setCalendarYear(year_input)
      runner.registerValue('year_input',year_input)
      runner.registerInfo("RawInput_period: #{steady_time_start.strftime("%Y/%m/%d %H:%M")} - #{steady_time_end.strftime("%Y/%m/%d %H:%M")}")
      runner.registerInfo("Metered_period: #{metered_data[0][0]} - #{metered_data[-1][0]}")
      # external_file = OpenStudio::Model::ExternalFile::getExternalFile(model,run_csv_path).get
      # external_file.setName("ExternalFileTest")
      
      runner.registerFinalCondition("Output: #{File.expand_path(run_csv_path)}")
      runner.registerValue('measure_run_csv_path',File.expand_path(run_csv_path))
      runner.registerValue('measure_meter_csv_path',File.expand_path(meter_csv_path))
  
  return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
Input_CSV.new.registerWithApplication
