# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

require 'openstudio'

# start the measure
class IdealLoadsOptions < OpenStudio::Measure::EnergyPlusMeasure

  # human readable name
  def name
    return "Ideal Loads Options"
  end

  # human readable description
  def description
    return "This measure allows the user to edit ideal air loads fields including availability schedules, maximum and minimum supply air temperatures, humidity ratios and flow rates, humidity control, outdoor air requirements, demand controlled ventilation, economizer operation, and heat recovery."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This measure assigns fields to all IdealLoadsAirSystem objects."
  end

  def getScheduleLimitType(workspace,schedule)
    sch_type_limits_name = schedule.getString(1).to_s
    if sch_type_limits_name == ""
      return ""
    else
      sch_type_limits = workspace.getObjectsByTypeAndName("ScheduleTypeLimits".to_IddObjectType,sch_type_limits_name)
      sch_type = sch_type_limits[0].getString(4).to_s
      if sch_type != ""
        return sch_type
      else
        return ""
      end
    end
  end

  def filterSchedulesByLimitType(workspace, schedules, limit_type)
    filtered_schedules = []
    schedules.each do |sch|
      sch_typ = getScheduleLimitType(workspace,sch)
      if  (sch_typ == limit_type)
        filtered_schedules << sch.getString(0).to_s
      end
    end
    return filtered_schedules
  end  

  # check to see if we have an exact match for this object already
  def check_for_object(runner, workspace, idf_object, idd_object_type)
    workspace.getObjectsByType(idd_object_type).each do |object|
      # all of these objects fields are data fields
      if idf_object.dataFieldsEqual(object)
        return true
      end
    end
    return false
  end

  # merge all summary reports that are not in the current workspace
  def merge_output_table_summary_reports(current_object, new_object)
    current_fields = []
    current_object.extensibleGroups.each do |current_extensible_group|
      current_fields << current_extensible_group.getString(0).to_s
    end

    fields_to_add = []
    new_object.extensibleGroups.each do |new_extensible_group|
      field = new_extensible_group.getString(0).to_s
      if !current_fields.include?(field)
        current_fields << field
        fields_to_add << field
      end
    end

    if !fields_to_add.empty?
      fields_to_add.each do |field|
        values = OpenStudio::StringVector.new
        values << field
        current_object.pushExtensibleGroup(values)
      end
      return true
    end

    return false
  end
  
  # examines object and determines whether or not to add it to the workspace
  def add_object(runner, workspace, idf_object)
    num_added = 0
    idd_object = idf_object.iddObject

    allowed_objects = []
    allowed_objects << "Output:Surfaces:List"
    allowed_objects << "Output:Surfaces:Drawing"
    allowed_objects << "Output:Schedules"
    allowed_objects << "Output:Constructions"
    allowed_objects << "Output:Table:TimeBins"
    allowed_objects << "Output:Table:Monthly"
    allowed_objects << "Output:Variable"
    allowed_objects << "Output:Meter"
    allowed_objects << "Output:Meter:MeterFileOnly"
    allowed_objects << "Output:Meter:Cumulative"
    allowed_objects << "Output:Meter:Cumulative:MeterFileOnly"
    allowed_objects << "Meter:Custom"
    allowed_objects << "Meter:CustomDecrement"

    if allowed_objects.include?(idd_object.name)
      if !check_for_object(runner, workspace, idf_object, idd_object.type)
        runner.registerInfo("Adding idf object #{idf_object.to_s.strip}")
        workspace.addObject(idf_object)
        num_added += 1
      else
        runner.registerInfo("Workspace already includes #{idf_object.to_s.strip}")
      end
    end

    allowed_unique_objects = []
    #allowed_unique_objects << "Output:EnergyManagementSystem" # TODO: have to merge
    #allowed_unique_objects << "OutputControl:SurfaceColorScheme" # TODO: have to merge
    allowed_unique_objects << "Output:Table:SummaryReports" # TODO: have to merge
    # OutputControl:Table:Style # not allowed
    # OutputControl:ReportingTolerances # not allowed
    # Output:SQLite # not allowed

    if allowed_unique_objects.include?(idf_object.iddObject.name)
      if idf_object.iddObject.name == "Output:Table:SummaryReports"
        summary_reports = workspace.getObjectsByType(idf_object.iddObject.type)
        if summary_reports.empty?
          runner.registerInfo("Adding idf object #{idf_object.to_s.strip}")
          workspace.addObject(idf_object)
          num_added += 1
        elsif merge_output_table_summary_reports(summary_reports[0], idf_object)
          runner.registerInfo("Merged idf object #{idf_object.to_s.strip}")     
        else
          runner.registerInfo("Workspace already includes #{idf_object.to_s.strip}")
        end
      end
    end

    return num_added
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Measure::OSArgumentVector.new

    #make choice argument for availability_schedule
    sch_choices = OpenStudio::StringVector.new
  
    sch_files = workspace.getObjectsByType("Schedule:File".to_IddObjectType)
    sch_files.each do |sch|
        sch_choices << sch.getString(0).to_s
    end
    idealLoadAirSystems = workspace.getObjectsByType("HVACTemplate_Zone_IdealLoadsAirSystem".to_IddObjectType)
    idealLoadAirSystem_choices = OpenStudio::StringVector.new
    idealLoadAirSystems.each {|x| idealLoadAirSystem_choices << x.getString(0).get }

    system_name = "test"
    system_names = idealLoadAirSystems.map  {|x| x.getString(0).get.to_s}
    if system_names.include?"Conditioned_Zone"
      system_name = "Conditioned_Zone"
    elsif system_names.include?"ConditionedZone"
      system_name = "ConditionedZone"
    else
      system_name = "ConditionedZone"
    end
    
    #argument for system selection
    idealLoadSystem = OpenStudio::Measure::OSArgument::makeChoiceArgument("idealLoadSystem", idealLoadAirSystem_choices, true,true)
    idealLoadSystem.setDisplayName("IdealLoadSystem")
    idealLoadSystem.setDefaultValue(system_name)
    args << idealLoadSystem
#argument for system availability schedule
availability_schedule = OpenStudio::Measure::OSArgument::makeChoiceArgument("availability_schedule", sch_choices, true,true)
availability_schedule.setDisplayName("System Availability Schedule:")
availability_schedule.setDefaultValue("HVAC_SCHEDULE")
args << availability_schedule

mixing_flowrate = OpenStudio::Measure::OSArgument::makeDoubleArgument("mixing_flowrate",true)
mixing_flowrate.setDisplayName("mixing_flowrate")
mixing_flowrate.setDefaultValue(0.02)
mixing_flowrate.setUnits("m3/s")
args << mixing_flowrate



    return args
  end

  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    # use the built-in error checking 
    if not runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end
  
    #default is OpenStudio version >= 2.0, set to OSv1 for OpenStudio version <=1.14
    # version = "OSv1"
    version = "OSv2"

    #assign the user inputs to variables
    availability_schedule = runner.getStringArgumentValue("availability_schedule",user_arguments)
    idealLoadSystem = runner.getStringArgumentValue("idealLoadSystem",user_arguments)
    mixing_flowrate = runner.getDoubleArgumentValue("mixing_flowrate",user_arguments)

    measure_run_csv_path = OsLib_HelperMethods.check_upstream_measure_for_arg(runner, 'measure_run_csv_path')
    col_add = 0
    cooling_power = false
    plenum_test = false
    if measure_run_csv_path
      run_csv_path = measure_run_csv_path[:value]
      if File.basename(measure_run_csv_path[:value]).start_with?"Experiment3"
        col_add = 0
        cooling_power = false
      elsif File.basename(measure_run_csv_path[:value]).start_with?"Experiment6"
        col_add = 1
        cooling_power = true
      elsif File.basename(measure_run_csv_path[:value]).start_with?"Experiment8"
        col_add = 2
        cooling_power = true
        plenum_test = true
      elsif File.basename(measure_run_csv_path[:value]).start_with?"Experiment9"
        col_add = 2
        cooling_power = true
        plenum_test = true
      end
  
     
    end


    output_diagnostic = OpenStudio::IdfObject.load("Output:Diagnostics, DisplayAdvancedReportVariables, DisplayZoneAirHeatBalanceOffBalance ;").get 
    inserted = workspace.addObject(output_diagnostic).get
    ideal_load_output = OpenStudio::IdfObject.load("Output:Variable, *, Zone Ideal Loads Zone Total Cooling Rate, timestep;").get
    workspace.addObject(ideal_load_output).get
    ideal_load_output = OpenStudio::IdfObject.load("Output:Variable, *, Zone Ideal Loads Zone Total Cooling Energy, timestep;").get
    workspace.addObject(ideal_load_output).get
    ideal_load_output = OpenStudio::IdfObject.load("Output:Variable, *, Zone Mixing Current Density Volume Flow Rate, timestep;").get
    workspace.addObject(ideal_load_output).get

    hvac_schedule_file = workspace.getObjectByTypeAndName("Schedule_File".to_IddObjectType,availability_schedule).get

    style = workspace.getObjectsByType("OutputControl:Table:Style".to_IddObjectType)[0]

    
    idealLoadAirSystems =  workspace.getObjectsByType("HVACTemplate_Zone_IdealLoadsAirSystem".to_IddObjectType)

    idealLoadAirSystems_names = idealLoadAirSystems.map {|x| x.getString(0).get}
    runner.registerInfo("TEst: #{idealLoadAirSystems_names.include?"ConditionedZone"}")
    idealLoadAirSystems.each do |x|
    runner.registerInfo("System Name: #{x.getString(0).get}")
    ## apply HVAC shedule to idealLoadsystem 
    if x.getString(0).get.downcase.include?idealLoadSystem.downcase
          x.setString(2,hvac_schedule_file.nameString)
      end
      if x.getString(0).get.downcase.include?"plenum"
        x.setString(2,hvac_schedule_file.nameString)
      end
     x.setString(3,(80.0).to_s) # 
     x.setString(4,(4.0).to_s)  
  end
  



    
   zoneAirHB= workspace.getObjectsByType("ZoneAirHeatBalanceAlgorithm".to_IddObjectType)[0]
     zoneAirHB.setString(0,"AnalyticalSolution")
    puts zoneAirHB
    thermostat_idf = OpenStudio::IdfObject.new("ThermostatSetpoint_SingleHeatingOrCooling".to_IddObjectType)

  workspace.getObjectsByType("ThermostatSetpoint_DualSetpoint".to_IddObjectType).each do |dual_thermostat|
  thermostat_workspace_obj = workspace.addObject(thermostat_idf).get
  thermostat_workspace_obj.setString(1,dual_thermostat.getString(1).get)
  dual_thermostat.sources.each do | zone_control|
    thermostat_workspace_obj.setName(zone_control.getString(1).get+"SingleThermoStat")
    zone_control.setString(3,"ThermostatSetpoint:SingleHeatingOrCooling")
    
    zone_control.setString(4,thermostat_workspace_obj.nameString)
    schedule = workspace.getObjectsByName(zone_control.getString(2).get)[0]
    schedule.setString(5,"3")
 
    # puts workspace.getObjectsByType("Output_Variable".to_IddObjectType)
  
  end

end

## add Zone CrossMixing

if plenum_test
zone_Cross_idf_txt = "ZoneCrossMixing,
Conditioned_SourcePlenum , !- Name
ConditionedZone , ! Zone Name
Mixing_Schedule, !- SCHEDULE Name
Flow/Zone, !- Design Flow Rate calculation method
#{mixing_flowrate}, !- Design Flow Rate {m3/s}
, !- Flow Rate per area {m3/s/m2}
, !- Flow Rate per person {m3/s/person}
10, !- Air Changes Per Hour
PlenumZone, ! Source Zone Name
0; ! Delta temp
"
zone_Cross_workspace = workspace.addObject(OpenStudio::IdfObject.load(zone_Cross_idf_txt).get).get
# zone_Cross_workspace.setString(11,"MEASURED_CHAMBER_TEMPERATURE")
# zone_Cross_workspace.setString(12,"MEASURED_CHAMBER_TEMPERATURE")
# zone_Cross_workspace.setString(13,"MEASURED_PLENUM_TEMPERATURE")
# zone_Cross_workspace.setString(14,"MEASURED_PLENUM_TEMPERATURE")

runner.registerInfo(zone_Cross_workspace.to_s)

end



argument_values = OsLib_HelperMethods.check_upstream_measure_for_arg(runner, 'csvfilepath')
external_file = argument_values[:value].to_s
runner.registerInfo(external_file)
# runner.registerInfo(runner.workflow.findFile(external_file).get.to_s)
workspace.getObjectsByType("Schedule_File".to_IddObjectType).each do |x| 
  x.setString(2,external_file) if x.getString(2).get.to_s.strip == ""
  # runner.registerInfo("ScheduleFile: ")
  runner.registerInfo("ScheduleFile\n"+x.to_s)
end
runner.registerInfo("ArgumentValue: "+ external_file )
if argument_values[:value]
  
end
workspace.getObjectsByType("Output_Variable".to_IddObjectType).each {|x| x.setString(2,"timestep")}
    return true
  end#def
end#class

# register the measure to be used by the application
IdealLoadsOptions.new.registerWithApplication