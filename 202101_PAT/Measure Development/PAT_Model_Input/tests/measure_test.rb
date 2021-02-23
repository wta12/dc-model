require 'openstudio'

require 'openstudio/ruleset/ShowRunnerOutput'

require "#{File.dirname(__FILE__)}/../measure.rb"

require 'test/unit'

class COP_modifying_Test < Test::Unit::TestCase

  # Description of test models:

  # model_5.osm is a 10 space, 10 zone office building with a packaged VAV system.
  # all of the zones use the same heating and cooling setpoint schedules
  # test no delete dx should result "Air Loop HVAC 1" with an indirect evap unit and an ERV and a 2 speed DX.
  # test yes delete dx should result in same thing except with the DX coil deleted

  def test_model_5_specific_air_loop

    # Create an instance of the measure
    measure = Model_Input.new


    osw = OpenStudio::WorkflowJSON.new()
    # Create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(osw)
    @msg_log = OpenStudio::StringStreamLogSink.new
    if @debug
      @msg_log.setLogLevel(OpenStudio::Debug)
    else
      @msg_log.setLogLevel(OpenStudio::Info)
    end
    @start_time = Time.new
    # Load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/05_NewFreezer_Thermal_mass_20191212.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # Get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(1, arguments.size)
    argument_map = OpenStudio::Measure::convertOSArgumentVectorToMap(arguments)
    # Create an empty argument map (this measure has no arguments)
    puts arguments
    puts argument_map
    input_csv_path = arguments[0]
    input_csv_path.setValue("./tests/Experiment5_200205_input_out.csv")
    # Run the measure
    argument_map["input_csv_path"] = input_csv_path
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)

    # Ensure the measure finished successfully
    assert(result.value.valueName == "Success")




  end#def
end#class
