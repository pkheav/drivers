class DNB::DeskBooker < PlaceOS::Driver
  descriptive_name "Vergesense Desk Booker"
  generic_name :DeskBooker
  description %(detects desk usage from Vergesense sensors and books desk to make them unavailable)

  accessor vergesense : Vergesense_1
  accessor staff_api : StaffAPI_1

  default_settings({
    timezone: "America/New_York",
    # user_id: "user-id",
    user_email: "user@email.com",
    vergesense_floor_key: "30_Hudson_Yards-81",
    zone_id: "zone-HD_ZoJfBs5t"
  })

  @timezone : Time::Location = Time::Location.load("America/New_York")
  @user_email : String = ""
  @vergesense_floor_key : String = ""
  @zone_id : String = ""

  def on_load
    on_update
  end

  def on_update
    subscriptions.clear

    tz = setting?(String, :timezone).presence
    @timezone = Time::Location.load(time_zone) if tz
    @user_email = setting?(String, :user_email) || ""
    @vergesense_floor_key = setting?(String, :vergesense_floor_key) || ""

    logger.debug { "vergesense_floor_key is #{vergesense_floor_key}" }

    system.subscribe(:Vergesense_1, @vergesense_floor_key) do |_subscription, vergesense_data|
      parse_data(vergesense_data)
    end unless @vergesense_floor_key.empty?
  end

  private def parse_data(vergesense_data)
    vergesense_data = JSON.parse(vergesense_data)

    desks_by_floor = {} of String => Hash(String, JSON::Any)
    vergesense_data.as_h.each do |building_name, v|
      next if building_name == "connected"
      puts building_name
      puts v["spaces"].size
      v["spaces"].as_a.each do |s|
        next unless s["space_type"] == "desk"
        floor_ref_id = s["floor_ref_id"].as_s
        puts "floor_ref_id = #{floor_ref_id}"
        desks_by_floor[floor_ref_id] ||= {} of String => JSON::Any
        desks_by_floor[floor_ref_id][s["space_ref_id"].as_s] = s
      end
      puts "There are #{desks_by_floor.values.first.values.size} desks"
    end

    if self[:previous_data] = self[:current_data]?
      check_desks(self[:previous_data], desks_by_floor)
    end
    self[:current_data] = desks_by_floor
  end

  private def check_desks(old_desk_data, new_desk_data)
    old_desk_data.as_h.each do |level_name, desks|
      desks.as_h.each do |desk_id, desk_object|
        previous_desk_presence = desk_object["people"]["count"].as_i > 0
        current_desk_presence = new_desk_data[level_name][desk_id]["people"]["count"] == 1
        book_desk(desk_object) if previous_desk_presence && current_desk_presence
      end
    end
  end

  private def book_desk(desk_object)
    current_time = Time.utc.in(@timezone)
    end_of_day = current_time.at_end_of_day

    staff_api.create_booking(
      booking_type: "desk",
      asset_id: "desk_#{desk_object["space_ref_id"].as_s}",
      user_email: @user_email,
      user_name: "Desk Booker",
      zones: [@zone_id],
      booking_start: current_time,
      booking_end: end_of_day,
      title: "Automatic booking",
      description: nil
    )
  end
end
