#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for access to C++ documentation on model air_loop_objects (click on "model" in the main window to view model air_loop_objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html
require 'csv'
require_relative './resources/os_lib_helper_methods.rb'
# require_relative './resources/data_file.csv'
require 'open3'
#start the measure
class ModelInputRCoil < OpenStudio::Measure::ModelMeasure

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return 'ModelInputRCoil'
  end

    def description
    return 'Clean seedFile and create all necessary input with RCoil'
  end

  def modeler_description
    return 'purge all standard objects and add load inputs with Rcoil'
  end
 
  def output_var(model,ob,variable_name,output_name = nil,step = "timestep" )
    out = OpenStudio::Model::OutputVariable.new(variable_name,model)
    if output_name.nil?
    out.setName("#{ob.nameString} Output Variable") 
    elsif output_name == "*"
    out.setName("All keys Output Variable")
    else
    out.setName(output_name)
    end
    if output_name == "*"
    out.setKeyValue("*")
    else
    out.setKeyValue(ob.nameString)
    end
    out.setReportingFrequency(step)
    return out
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    

    # Make an argument for evap effectiveness
    run_csv_path = OpenStudio::Measure::OSArgument::makePathArgument("input_csv_path",true,".csv")
    run_csv_path.setDisplayName("external_file_input")
    run_csv_path.setDefaultValue("data_file.csv")
    args << run_csv_path
   
    rcoil_coff = OpenStudio::Measure::OSArgument::makeDoubleArgument("rcoil_coff",true)
    rcoil_coff .setDisplayName("RCoil")
    rcoil_coff.setDefaultValue(1.0)
    args << rcoil_coff

   

    inside_convection_coff = OpenStudio::Measure::OSArgument::makeDoubleArgument("zone_capacitance_value",true)
    inside_convection_coff.setDisplayName("zone_capacitance_value")
    inside_convection_coff.setDefaultValue(1.0)
    args << inside_convection_coff


    r_value = OpenStudio::Measure::OSArgument::makeDoubleArgument("r_value",true)
    r_value.setDisplayName("r_value")
    r_value.setDefaultValue(0.019)
    args << r_value

    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)


	 # Use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    # args_map =  user_arguments.map { |x| runner.getPathArgumentValue(x,user_arguments) }
    input_csv_path =  runner.getPathArgumentValue("input_csv_path",user_arguments).to_s 
    rcoil = runner.getDoubleArgumentValue("rcoil_coff",user_arguments)
    
    zone_capacity_value = runner.getDoubleArgumentValue("zone_capacitance_value",user_arguments)
    r_value = runner.getDoubleArgumentValue("r_value",user_arguments)
    # run_csv_path = File.expand_path(run_csv_path) 
    # if !File.exist?run_csv_path
    measure_run_csv_path = OsLib_HelperMethods.check_upstream_measure_for_arg(runner, 'measure_run_csv_path')
    cooling_power = false
    plenum_test = false
    if measure_run_csv_path
      run_csv_path = measure_run_csv_path[:value]
      if File.basename(measure_run_csv_path[:value]).start_with?"Experiment3"
     
      elsif File.basename(measure_run_csv_path[:value]).start_with?"Experiment6"
      
        cooling_power = true
      elsif File.basename(measure_run_csv_path[:value]).start_with?"Experiment8"
        cooling_power = true
        plenum_test = true
      end
    else
      run_csv_path = input_csv_path
    end
    runner.registerValue("Input File Error: #{run_csv_path}") unless File.exist?run_csv_path

   
   
   

    runner.registerInitialCondition("Input: #{run_csv_path}")

    ## set external File
    runner.registerInfo(model.getExternalFiles.map {|x|  x.to_s}.join("\n"))
    external_file = OpenStudio::Model::ExternalFile::getExternalFile(model,run_csv_path).get
      
    external_file.setName("chosen ExternalFileTest")
    
    
    # csv_file_path="../../../lib/Experiment2_200114_input_out.csv"
    # runner.registerInfo('csvfilepath:' +csv_file_path)
    
    # if runner.workflow.findFile(csv_file_path).is_initialized
    #   runner.registerInfo('runnerFindFile:' +runner.workflow.findFile(csv_file_path).get.to_s)    
    # else 
    #   runner.registerInfo("runnerFindFile csv_file_path : cant not find #{csv_file_path}")    
    # end
    # root_osw_path =  runner.workflow.absoluteRootDir.to_s
    # analyis_lib_path =  File.expand_path("../lib/", root_osw_path)
    # run_csv_path = File.join(analyis_lib_path,run_csv_name)
    # stdout,stderr,status = Open3.capture3("ls -la #{analyis_lib_path}")
    # runner.registerInfo("analyis_lib_path: #{analyis_lib_path}")
    # runner.registerInfo("run_csv_path: #{run_csv_path} - exist? #{File.exist?run_csv_path}")
    # runner.registerInfo("analyis_lib_path cmd :stdout #{stdout}\nstderr #{stderr}\nstatus #{status}")
    # runner.registerValue('csvfilepath',run_csv_path)

    ## remove schedule limits
  
    scheduleTypeLimit_Names =  ["Temperature","Fraction","Fractional"]
    model.getScheduleTypeLimitss.each {|x| x.remove unless scheduleTypeLimit_Names.include?(x.nameString) }
 
    ## remove schedule 
    removed_schedules = model.getSchedules.select {|x| !x.iddObject.type.valueName.end_with?("Constant") }    
    removed_schedules.each {|x| x.to_Schedule.get.remove}
    #remove dual setpoint
    model.getThermostatSetpointDualSetpoints.select {|x| x.targets.size == 0}.each {|x| x.remove}
    model.getThermostatSetpointDualSetpoints.each { |thermostat|  thermostat.setName(thermostat.thermalZone.get.nameString+" Dual Setpoint Thermostats")}
    # remove internal source
    model.getObjectsByType("OS_Construction_InternalSource".to_IddObjectType).each {|x| x.remove}
    runner.registerInfo("Clean up model done")
    ## remove all EMS objects
    model.getEnergyManagementSystemPrograms.each {|x| x.remove}
    model.getEnergyManagementSystemSensors.each {|x| x.remove}
    model.getEnergyManagementSystemActuators.each {|x| x.remove}
    model.getEnergyManagementSystemProgramCallingManagers.each {|x| x.remove}
    ## remove all internal mass
    model.getInternalMasss.each {|x| x.remove}
    ## setup simulation control
    run_period = model.getRunPeriod
    run_period.setEndMonth(1)
    run_period.setEndDayOfMonth(10)
    simulation_control = model.getSimulationControl
    time_step = simulation_control.timestep.get
    time_step.setNumberOfTimestepsPerHour(60)
    
    simulation_control.setDoZoneSizingCalculation(false)
    simulation_control.setDoSystemSizingCalculation(false)
    simulation_control.setDoPlantSizingCalculation(false)
    simulation_control.setRunSimulationforSizingPeriods(false)

    ems_report  = model.getOutputEnergyManagementSystem
    ems_report.setName("Weather_Test")
    ems_report.setActuatorAvailabilityDictionaryReporting("Verbose")
    ems_report.setInternalVariableAvailabilityDictionaryReporting("Verbose")
    ems_report.setEMSRuntimeLanguageDebugOutputLevel("ErrorsOnly")

    model.getThermalZones.each {|x| x.setUseIdealAirLoads(true)}
    
    ## zone_capacity
    zone_capacity = model.getZoneCapacitanceMultiplierResearchSpecial
    zone_capacity.setTemperatureCapacityMultiplier(zone_capacity_value) if zone_capacity_value != 1.0
    
  ##R value change
  insulation_material = model.getMaterialByName("Cyclopentance").get
  insulation_material.setThickness(0.1)
  insulation_material.to_StandardOpaqueMaterial.get.setThermalConductivity(r_value)

## set surface no sun no wind
model.getSurfaces.each {|x| x.setWindExposure("No");x.setSunExposure("No")}


    test_zones =  model.getThermalZones.select {|x| !x.nameString.downcase.include?"compressor"}
     
     
     ### Internal_gain create
     total_internal_gain_def_desgin_level= 100.0
     ## create internal_gain_def
    convective_internal_gain_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    convective_internal_gain_def.setName("Convective_Internal_gain_#{total_internal_gain_def_desgin_level}W")
    convective_internal_gain_def.setDesignLevel(total_internal_gain_def_desgin_level)
    
    radiative_internal_gain_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    radiative_internal_gain_def.setName("Radiative_Internal_gain_#{total_internal_gain_def_desgin_level}W")
    radiative_internal_gain_def.setDesignLevel(total_internal_gain_def_desgin_level)
    radiative_internal_gain_def.setFractionRadiant(1.0)
    
  
    ### scheduleTypeLimits
    temperature_schedule_limit = model.getScheduleTypeLimitsByName("Temperature").get
    fractional_schedule_limit = model.getScheduleTypeLimitsByName("Fractional").get
    heat_gain_load_schedule_limit = OpenStudio::Model::ScheduleTypeLimits.new(model)
    heat_gain_load_schedule_limit.setName("HeatGainSchedule")
    heat_gain_load_schedule_limit.setNumericType("CONTINUOUS")
    heat_gain_load_schedule_limit.setUnitType("Power")
    ach_schedule_limit = OpenStudio::Model::ScheduleTypeLimits.new(model)
    ach_schedule_limit.setName("ACHSchedule")
    ach_schedule_limit.setNumericType("CONTINUOUS")
    if model.getSpaceByName("Steca_Freezer_Cooling_Chamber").is_initialized
      space = model.getSpaceByName("Steca_Freezer_Cooling_Chamber").get
      space.setName("Conditioned_Space")
      space.thermalZone.get.setName("Conditioned_Zone")
      thermalZone=  space.thermalZone.get
    elsif model.getSpaceByName("ConditionedZone").is_initialized
      space = model.getSpaceByName("ConditionedZone").get
      # space.setName("Conditioned_Space")
      # space.thermalZone.get.setName("Conditioned_Zone")
      thermalZone=  space.thermalZone.get
    end
    cooling_space = space
    if plenum_test
      plenumSpace = model.getSpaceByName("PlenumZone").get
      gain_space = plenumSpace
    else
      gain_space = space

    end
    if cooling_power 
      cooling_space = space
    
    end
    

    
    ["Zone Electric Equipment Electric Power",
      "Zone Electric Equipment Total Heating Rate",
      # "Zone Electric Equipment Radiant Heating Rate",
      # "Zone Electric Equipment Convective Heating Rate",
      "Zone Total Internal Total Heating Rate",
      "Zone Total Internal Convective Heating Rate",
      "Zone Total Internal Radiant Heating Rate",
      "Zone Air Temperature",
    #       "Zone Mean Air Temperature",
    #       "Zone Operative Temperature","Zone Mean Radiant Temperature",
    #    #  "Zone Predicted Sensible Load to Setpoint Heat Transfer Rate",
          "Zone Air Heat Balance Internal Convective Heat Gain Rate",
          "Zone Air Heat Balance Surface Convection Rate",
    # "Zone Air Heat Balance Interzone Air Transfer Rate",
    "Zone Air Heat Balance Outdoor Air Transfer Rate",
        "Zone Air Heat Balance System Air Transfer Rate",
         "Zone Air Heat Balance System Convective Heat Gain Rate",
        "Zone Air Heat Balance Deviation Rate",
          "Zone Air Heat Balance Air Energy Storage Rate",
               
          "Zone Electric Equipment Total Heating Energy",
            # "Zone Lights Total Heating Energy",
            "Zone Opaque Surface Inside Faces Total Conduction Heat Gain Energy",
            "Zone Air System Sensible Heating Energy",
            # "Zone Infiltration Sensible Heat Gain Energy",   

            # "Zone Infiltration Sensible Heat Loss Energy",
            "Zone Opaque Surface Inside Faces Total Conduction Heat Loss Energy",
            "Zone Air System Sensible Cooling Energy"
     ].each do |var|
      output_var(model,space.thermalZone.get,var)
      output_var(model,gain_space.thermalZone.get,var) if plenum_test
      end
    runner.registerFinalCondition("Following objects created:
      #{convective_internal_gain_def.to_s},
      #{radiative_internal_gain_def.to_s}")


    ## setup gain
    convective_internal_gain = OpenStudio::Model::ElectricEquipment.new(convective_internal_gain_def)
    convective_internal_gain.setSpace(gain_space)
    convective_internal_gain.setName("#{gain_space.nameString}_ConvectiveInternalGain")
    convective_internal_gain_schedule_file = OpenStudio::Model::ScheduleFile.new(external_file,6,1)
    convective_internal_gain_schedule_file.setName("CONVECTIVE_LOAD_SCHEDULE")
    convective_internal_gain_schedule_file.setScheduleTypeLimits(fractional_schedule_limit)
    convective_internal_gain_schedule_file.setMinutesperItem("1")
    runner.registerInfo(convective_internal_gain_schedule_file.to_s)
    convective_internal_gain_schedule_file_output = output_var(model,convective_internal_gain_schedule_file,"Schedule Value")
    convective_internal_gain_schedule_file_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model,convective_internal_gain_schedule_file_output)
    convective_internal_gain_schedule_file_sensor.setName("CONVECTIVE_LOAD_SCHEDULE_EMS_SENSOR")

 ## Assign scheduleFile to internal_gain 
    convective_internal_gain.setSchedule(convective_internal_gain_schedule_file)
    output_var(model,convective_internal_gain,"Electric Equipment Electric Power")
    ## add radiation load
    radiation_internal_gain = OpenStudio::Model::ElectricEquipment.new(radiative_internal_gain_def)
    radiation_internal_gain.setSpace(gain_space)
    radiation_internal_gain.setName("#{gain_space.nameString}_radiationInternalGain")

    radiation_internal_gain_schedule_file = OpenStudio::Model::ScheduleFile.new(external_file,7,1)
    radiation_internal_gain_schedule_file.setName("RADIATION_LOAD_SCHEDULE")
    radiation_internal_gain_schedule_file.setScheduleTypeLimits(fractional_schedule_limit)
    radiation_internal_gain_schedule_file.setMinutesperItem("1")

    radiation_internal_gain_schedule_file_output = output_var(model,radiation_internal_gain_schedule_file,"Schedule Value")
    radiation_internal_gain_schedule_file_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model,radiation_internal_gain_schedule_file_output)
    radiation_internal_gain_schedule_file_sensor.setName("RADIATION_LOAD_SCHEDULE_EMS_SENSOR")
    
    ## Assign scheduleFile to internal_gain 
    radiation_internal_gain.setSchedule(radiation_internal_gain_schedule_file)
    output_var(model,radiation_internal_gain,"Electric Equipment Electric Power")

if cooling_power
    ## measured_cooling power
    cooling_power_schedule_file = OpenStudio::Model::ScheduleFile.new(external_file,9,1)
    cooling_power_schedule_file.setName("MEASURED_COOLING_POWER")
    cooling_power_schedule_file.setScheduleTypeLimits(temperature_schedule_limit)
    cooling_power_schedule_file.setMinutesperItem("1")
    cooling_power_schedule_file_output = output_var(model,cooling_power_schedule_file,"Schedule Value")
    cooling_power_schedule_file_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model,cooling_power_schedule_file_output)
    cooling_power_schedule_file_sensor.setName(cooling_power_schedule_file.nameString+"_ems_sensor")
    ##measured water inlet
    water_inlet_schedule_file = OpenStudio::Model::ScheduleFile.new(external_file,10,1)
    water_inlet_schedule_file.setName("MEASURED_WATER_INLET_TEMPERATURE")
    water_inlet_schedule_file.setScheduleTypeLimits(temperature_schedule_limit)
    water_inlet_schedule_file.setMinutesperItem("1")
    water_inlet_schedule_file_output = output_var(model,water_inlet_schedule_file,"Schedule Value")
    water_inlet_schedule_file_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model,water_inlet_schedule_file_output)
    water_inlet_schedule_file_sensor.setName(water_inlet_schedule_file.nameString+"_ems_sensor")

## zone temperature sensor
conditioned_zone_temperature_output = output_var(model,cooling_space.thermalZone.get,"Zone Air Temperature")
conditioned_zone_temperature_output_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model,conditioned_zone_temperature_output)
conditioned_zone_temperature_output_sensor.setName(conditioned_zone_temperature_output.nameString+"_ems_sensor")

  # add cooling load to zone
  chilled_water_gain_def  =  OpenStudio::Model::ElectricEquipmentDefinition.new(model)
  chilled_water_gain_def.setName("#{cooling_space.nameString}_chilled_water_gain_def_minus#{total_internal_gain_def_desgin_level}W")
  chilled_water_gain_def.setDesignLevel(total_internal_gain_def_desgin_level)

  chilled_water_gain = OpenStudio::Model::ElectricEquipment.new(chilled_water_gain_def)
  chilled_water_gain.setSpace(cooling_space)
  chilled_water_gain.setName(cooling_space.nameString+"_chilled_water_gain")
  chilled_water_gain_schedule = OpenStudio::Model::ScheduleConstant.new(model)
  chilled_water_gain_schedule.setScheduleTypeLimits(fractional_schedule_limit)
  chilled_water_gain_schedule.setValue(0.0)
  chilled_water_gain.setSchedule(chilled_water_gain_schedule)



## create actuator for chilled water gain 
chilled_water_gain_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(chilled_water_gain,"ElectricEquipment","Electric Power Level")
chilled_water_gain_actuator.setName("ChilledWaterGainActuator")

end


### ambient schedule create:
    ## get weather file add output variable, sensor  and actuator
    weather_file = model.getWeatherFile.to_ModelObject.get
    site_drybulb_temperature_output = output_var(model,weather_file,"Site Outdoor Air Drybulb Temperature","Site drybulb temperature output variable")
    site_direct_solar_output = output_var(model,weather_file,"Site Direct Solar Radiation Rate per Area","Site direct solar output variable")
    site_diffuse_solar_output = output_var(model,weather_file,"Site Diffuse Solar Radiation Rate per Area","Site diffuse solar output variable")
    site_wind_speed_output = output_var(model,weather_file,"Site Wind Speed","Site Wind Speed output variable")
    


      ## create schedule file for measured data and HVAC Schedule
      ambient_schedule_file = OpenStudio::Model::ScheduleFile.new(external_file,3,1)
      ambient_schedule_file.setName("MEASURED_EXTERNAL_TEMPERATURE")
      ambient_schedule_file.setScheduleTypeLimits(temperature_schedule_limit)
      ambient_schedule_file.setMinutesperItem("1")
      ambient_schedule_file_output = output_var(model,ambient_schedule_file,"Schedule Value")
     
     

      hvac_schedule_file = OpenStudio::Model::ScheduleFile.new(external_file,5,1)
      hvac_schedule_file.setName("HVAC_SCHEDULE")
      hvac_schedule_file.setScheduleTypeLimits(temperature_schedule_limit)
      hvac_schedule_file.setMinutesperItem("1")
      hvac_schedule_file_output = output_var(model,hvac_schedule_file,"Schedule Value")
     
  
      measured_heat_gain_schedule_file = OpenStudio::Model::ScheduleFile.new(external_file,2,1)
      measured_heat_gain_schedule_file.setName("MEASURED_TOTAL_HEAT_GAIN")
      measured_heat_gain_schedule_file.setScheduleTypeLimits(heat_gain_load_schedule_limit)
      measured_heat_gain_schedule_file.setMinutesperItem("1")
      measured_heat_gain_schedule_file_output = output_var(model,measured_heat_gain_schedule_file,"Schedule Value")
    

      test_indoor_schedule_file = OpenStudio::Model::ScheduleFile.new(external_file,4,1)
      test_indoor_schedule_file.setName("MEASURED_CHAMBER_TEMPERATURE")
      test_indoor_schedule_file.setScheduleTypeLimits(temperature_schedule_limit)
      test_indoor_schedule_file.setMinutesperItem("1")
      test_indoor_schedule_file_output = output_var(model,test_indoor_schedule_file,"Schedule Value")

      thermostat = thermalZone.thermostatSetpointDualSetpoint.get
      # start_up_constant_temperature = OpenStudio::Model::ScheduleConstant.new(model)
      # start_up_constant_temperature.setScheduleTypeLimits(temperature_schedule_limit)
      # start_up_constant_temperature.setValue(start_up_temp)
      
      thermostat.setHeatingSchedule(test_indoor_schedule_file)
      thermostat.setCoolingSchedule(test_indoor_schedule_file)
      # thermalZone.setUseIdealAirLoads(true)

      ## add Measured_data_schedule

      measure_period_schedule = OpenStudio::Model::ScheduleFile.new(external_file,8,1)
      measure_period_schedule.setName("MeasuredPeriod")
      measure_period_schedule.setScheduleTypeLimits(fractional_schedule_limit)
      measure_period_schedule.setMinutesperItem("1")

    
      measure_period_schedule_output = output_var(model,measure_period_schedule,"Schedule Value")
      measure_period_schedule_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model,measure_period_schedule_output )
      measure_period_schedule_sensor.setName(measure_period_schedule.nameString+"_ems_sensor")
   ## turn on HVAC 
   if model.getThermalZoneByName("Thermal Zone: Steca_Freezer_Compressor_Chamber").is_initialized
    compressor_zone = model.getThermalZoneByName("Thermal Zone: Steca_Freezer_Compressor_Chamber").get
   elsif model.getThermalZoneByName("Compressor").is_initialized
    compressor_zone = model.getThermalZoneByName("Compressor").get
   end
   compressor_zone_thermostat = compressor_zone.thermostatSetpointDualSetpoint.get
   compressor_zone_thermostat.setHeatingSchedule(ambient_schedule_file)
   compressor_zone_thermostat.setCoolingSchedule(ambient_schedule_file)
# set plenum
if plenum_test

  plenum_temp_schedule_file = OpenStudio::Model::ScheduleFile.new(external_file,11,1)
  plenum_temp_schedule_file.setName("MEASURED_PLENUM_TEMPERATURE")
  plenum_temp_schedule_file.setScheduleTypeLimits(temperature_schedule_limit)
  plenum_temp_schedule_file.setMinutesperItem("1")
  plenum_temp_schedule_file_output = output_var(model,plenum_temp_schedule_file,"Schedule Value")
  plenum_thermostat = gain_space.thermalZone.get.thermostatSetpointDualSetpoint.get
  plenum_thermostat.setHeatingSchedule(plenum_temp_schedule_file)
  plenum_thermostat.setCoolingSchedule(plenum_temp_schedule_file)
  output_var(model,gain_space.thermalZone.get,"Zone Air Temperature")
  output_var(model,gain_space.thermalZone.get,"Zone Electric Equipment Electric Power")

  cooling_schedule_file = OpenStudio::Model::ScheduleFile.new(external_file,12,1)
  cooling_schedule_file.setName("Cooling_schedule_file")
  cooling_schedule_file.setScheduleTypeLimits(fractional_schedule_limit)
  cooling_schedule_file.setMinutesperItem("1")
  cooling_schedule_file_output = output_var(model, cooling_schedule_file,"Schedule Value")
  cooling_schedule_file_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model,cooling_schedule_file_output )
  cooling_schedule_file_sensor.setName(cooling_schedule_file.nameString+"_ems_sensor")


  
  mixing_schedule_file = OpenStudio::Model::ScheduleFile.new(external_file,13,1)
  mixing_schedule_file.setName("Mixing_Schedule")
  mixing_schedule_file.setScheduleTypeLimits(fractional_schedule_limit)
  mixing_schedule_file.setMinutesperItem("1")
  mixing_schedule_file_output = output_var(model, mixing_schedule_file,"Schedule Value")

end
 surface_outputs = ["Surface Inside Face Conduction Heat Transfer Rate","Surface Outside Face Conduction Heat Transfer Rate",
  "Surface Inside Face Temperature","Surface Outside Face Temperature","Surface Inside Face Convection Heat Transfer Coefficient",
  "Surface Outside Face Outdoor Air Drybulb Temperature","Surface Heat Storage Rate"]
  # zone_outputs
  surfaces = cooling_space.surfaces #+ [thermal_mass] 

  if plenum_test 
    surfaces += gain_space.surfaces
  end


#   surfaces.each do |x|
#     absoluteAzimuth =  OpenStudio::convert(x.azimuth,"rad","deg").get + x.space.get.directionofRelativeNorth + model.getBuilding.northAxis
# until absoluteAzimuth < 360.0
#   absoluteAzimuth = absoluteAzimuth - 360.0
# end
# if (absoluteAzimuth >= 315.0 or absoluteAzimuth < 45.0)
#   facade = "North"
# elsif (absoluteAzimuth >= 45.0 and absoluteAzimuth < 135.0) 
#   facade = "East"
# elsif (absoluteAzimuth >= 135.0 and absoluteAzimuth < 225.0)
#   facade = "South"
# elsif (absoluteAzimuth >= 225.0 and absoluteAzimuth < 315.0)
#   facade = "West"
# else
#   runner.registerError("Unexpected value of facade: " + facade + ".")
#   return false
# end
     
#       pos = x.outsideBoundaryCondition == "Outdoors" ? "Ext" : "Int"
#       name_s = "#{x.space.get.nameString}_#{facade}_#{x.surfaceType}_#{pos}"
#       x.setName(name_s)
#       x.setSunExposure("NoSun")
#       x.setWindExposure("NoWind")
   
#   end

  
#set EMS sensor/actuator

  weather_drybulb_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(weather_file,"Weather Data","Outdoor Dry Bulb")
  weather_drybulb_actuator.setName("EnviromentOdbActuator")
 
  ambient_temperature_output_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model,site_drybulb_temperature_output)
  ambient_temperature_output_sensor.setName("WEATHER_DBT_SENSOR")
  ems_direct_solar_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(weather_file,"Weather Data","Direct Solar")
  ems_direct_solar_actuator.setName("EnviromentDirectSolarActuator")
  ems_diffuse_solar_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(weather_file,"Weather Data","Diffuse Solar")
  ems_diffuse_solar_actuator.setName("EnviromentDiffSolarActuator")
  ems_wind_speed_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(weather_file,"Weather Data","Wind Speed")
  ems_wind_speed_actuator.setName("EnviromentWindSpeedActuator")

  ambient_schedule_file_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model,ambient_schedule_file_output)
  ambient_schedule_file_sensor.setName("EMS_OUTDOOR_SENSOR")
  hvac_schedule_file_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model,hvac_schedule_file_output)
  hvac_schedule_file_sensor.setName("HVAC_SCHEDULE_SENSOR")
  measured_heat_gain_schedule_file_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model,measured_heat_gain_schedule_file_output)
  measured_heat_gain_schedule_file_sensor.setName("MEASURED_TOTAL_HEAT_GAIN_SENSOR")
## add surface_output and actuators
    






  



# end
## create ems program
ems_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
ems_program.setName('AmbientConditionAndInsideConvectionOveride')

## create ems_program_manager
ems_program_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
ems_program_manager.setName("ValidateMeasuredData")
ems_program_manager.setCallingPoint("Begin Timestep Before Predictor".gsub(" ","") )
ems_program_manager.setProgram(ems_program,0)

weather_override_lines = []

enable_ems_program_lines = []
disable_ems_program_lines = []

## remove outdoor radiation and set measured to outside


weather_override_lines << "SET #{weather_drybulb_actuator.nameString} = #{ambient_schedule_file_sensor.nameString},"
weather_override_lines << "SET #{ems_direct_solar_actuator.nameString} = 0,"
weather_override_lines << "SET #{ems_diffuse_solar_actuator.nameString} = 0,"
weather_override_lines << "SET #{ems_wind_speed_actuator.nameString} = 0,"







surface_ems_program_lines = weather_override_lines
# if interior_override
# surface_ems_program_lines +=  ["IF #{hvac_schedule_file_sensor.nameString} == 1.0,"]
# surface_ems_program_lines += surface_ems_program_disable_lines
# surface_ems_program_lines += disable_ems_program_lines
# surface_ems_program_lines +=  ["ELSE,"]

# # surface_ems_program_lines +=  ["IF #{measured_heat_gain_schedule_file_sensor.nameString} > 0.0,"]
# surface_ems_program_lines += surface_ems_program_enable_lines
# # surface_ems_program_lines +=  ["ELSE,"]
# # surface_ems_program_lines += surface_ems_program_disable_lines
# # surface_ems_program_lines += ["ENDIF,"]
# surface_ems_program_lines += enable_ems_program_lines
# surface_ems_program_lines += ["ENDIF,"]
# end
if cooling_power
  if plenum_test
    surface_ems_program_lines +=  ["IF (#{measure_period_schedule_sensor.nameString} > 0.0) && (#{cooling_schedule_file_sensor.nameString} > 0.0) ,"]
  else
    surface_ems_program_lines +=  ["IF (#{measure_period_schedule_sensor.nameString} > 0.0),"]
  end
  surface_ems_program_lines +=  ["SET #{chilled_water_gain_actuator.nameString} = (-1.0 * (#{conditioned_zone_temperature_output_sensor.nameString} - #{water_inlet_schedule_file_sensor.nameString})/#{rcoil})"]
  # surface_ems_program_lines +=  ["SET #{chilled_water_gain_actuator.nameString} = (-1.0 * #{cooling_power_schedule_file_sensor.nameString})"]
  surface_ems_program_lines += ["ELSE,"]
  surface_ems_program_lines +=  ["SET #{chilled_water_gain_actuator.nameString} = Null"]
  surface_ems_program_lines += ["ENDIF,"]
end


ems_program.setLines(surface_ems_program_lines)
puts ems_program



  return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
ModelInputRCoil.new.registerWithApplication
