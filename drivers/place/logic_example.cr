module Place; end

class Place::LogicExample < PlaceOS::Driver
  descriptive_name "Example Logic"
  generic_name :ExampleLogic

  accessor main_lcd : Display_1, implementing: Powerable

  def on_update
    logger.info { "woot! an update #{setting?(String, :name)}" }
  end

  def power_state?
    main_lcd[:power]
  end

  def power(state : Bool)
    main_lcd.power(state)
  end

  def module_count(module_name : String)
    system.count(module_name)
  end

  def module_exec(module_name : String, method_name : String)
    system[module_name][method_name]
  end

  def module_exec_access_token(module_name : String, method_name : String)
    system[module_name].access_token
  end
end
