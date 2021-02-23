#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for access to C++ documentation on model air_loop_objects (click on "model" in the main window to view model air_loop_objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

#start the measure
class ThermalMassInput < OpenStudio::Measure::ModelMeasure

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return 'Thermal Mass Input'
  end

    def description
    return 'Create ThermalMass'
  end

  def modeler_description
    return 'create ThermalMass using Bronze properties with thickness and surface area as inpu'
  end
 

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new



    # Make an argument for evap effectiveness
  
   
    surface_area = OpenStudio::Measure::OSArgument::makeDoubleArgument("surface_area",true)
    surface_area.setDisplayName("surface_area")
    surface_area.setDefaultValue(0.05)
    args << surface_area
    bronze_thermal_mass_layer_thickness = OpenStudio::Measure::OSArgument::makeDoubleArgument("bronze_thermal_mass_layer_thickness",true)
    bronze_thermal_mass_layer_thickness.setDisplayName("bronze_thermal_mass_layer_thickness")
    bronze_thermal_mass_layer_thickness.setDefaultValue(0.12)
    args << bronze_thermal_mass_layer_thickness

    surface_area = OpenStudio::Measure::OSArgument::makeDoubleArgument("plenum_surface_area",true)
    surface_area.setDisplayName("plenum_surface_area")
    surface_area.setDefaultValue(0.0)
    args << surface_area
    bronze_thermal_mass_layer_thickness = OpenStudio::Measure::OSArgument::makeDoubleArgument("plenum_thickness",true)
    bronze_thermal_mass_layer_thickness.setDisplayName("plenum_thickness")
    bronze_thermal_mass_layer_thickness.setDefaultValue(0.05)
    args << bronze_thermal_mass_layer_thickness

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
  
    surface_area = runner.getDoubleArgumentValue("surface_area",user_arguments)
    bronze_thermal_mass_layer_thickness = runner.getDoubleArgumentValue("bronze_thermal_mass_layer_thickness",user_arguments)
 
    plenum_surface_area = runner.getDoubleArgumentValue("plenum_surface_area",user_arguments)
    plenum_surface_thickness = runner.getDoubleArgumentValue("plenum_thickness",user_arguments)
 
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
      end
  
     
    end



    runner.registerInitialCondition("Input - surface_area: #{surface_area}")
    runner.registerInitialCondition("Input - bronze_thermal_mass_layer_thickness: #{bronze_thermal_mass_layer_thickness}")
    if (surface_area == 0.0) || bronze_thermal_mass_layer_thickness == (0.0)
      runner.registerFinalCondition("No thermalMass applied")
      return true  
    end
    puts model.getSpaces
    

    if space= model.getSpaceByName("Conditioned_Space").is_initialized
      space= model.getSpaceByName("Conditioned_Space").get 
    elsif model.getSpaceByName("ConditionedZone").is_initialized
      space = model.getSpaceByName("ConditionedZone").get
    end


    thermalZone=  space.thermalZone.get
    thermal_mass_def = OpenStudio::Model::InternalMassDefinition.new(model)
    thermal_mass_def.setName("bronze_thermal_mass_def")
    thermal_mass_construction = model.getConstructionByName("ThermalMass_Construction").get
    thermal_mass_def.setConstruction(thermal_mass_construction.to_Construction.get)
    thermal_mass_def.setSurfaceArea(surface_area)
    thermal_mass = OpenStudio::Model::InternalMass.new(thermal_mass_def)
    thermal_mass.setSpace(space)
    
    thermal_mass.setName(space.nameString+'_bronze_thermal_mass')
    bronze_thermal_mass_layer = thermal_mass_construction.layers[0]
    bronze_thermal_mass_layer.setThickness(bronze_thermal_mass_layer_thickness)

    if plenum_test & (plenum_surface_area != 0)
       plenum_space=model.getSpaceByName("PlenumZone").get

      plenum_thermal_mass_def = OpenStudio::Model::InternalMassDefinition.new(model)
      plenum_thermal_mass_def.setName("plenum_bronze_thermal_mass_def")

      thermal_mass_construction = model.getConstructionByName("ThermalMass_Construction").get
      plenum_thermal_mass_construction = thermal_mass_construction.clone(model).to_Construction.get
      

      plenum_thermal_mass_construction.setName("PlenumThermalMass_Construction")
      plenum_thermal_mass_def.setConstruction(plenum_thermal_mass_construction)
      plenum_thermal_mass_def.setSurfaceArea(plenum_surface_area)
      plenum_thermal_mass = OpenStudio::Model::InternalMass.new(plenum_thermal_mass_def)
      plenum_thermal_mass.setSpace(plenum_space)

      plenum_thermal_mass.setName(plenum_space.nameString+'_bronze_thermal_mass')
      plenum_bronze_thermal_mass_layer = plenum_thermal_mass_construction.layers[0].clone(model).to_Material.get
      plenum_bronze_thermal_mass_layer.setName("plenum_thermalmass_bronzeMaterial")
      plenum_bronze_thermal_mass_layer.setThickness(plenum_surface_thickness)
      plenum_thermal_mass_construction.setLayer(0,plenum_bronze_thermal_mass_layer)
    end


  return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
ThermalMassInput.new.registerWithApplication
