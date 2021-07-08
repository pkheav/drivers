class DNB::DeskBooker < PlaceOS::Driver
  descriptive_name "Vergesense Desk Booker"
  generic_name :DeskBooker
  description %(detects desk usage from Vergesense sensors and books desk to make them unavailable)

  accessor vergesense : Vergesense_1
  accessor staff_api : StaffAPI_1

  default_settings({
    timezone: "America/New_York",
    user_email: "desk_booker@place.tech",
    vergesense_floor_key: "30_Hudson_Yards-81",
    zone_id: "zone-HD_ZoJfBs5t"
  })

  @timezone : Time::Location = Time::Location.load("America/New_York")
  @user_email : String = ""
  @user_id : String = ""
  @vergesense_floor_key : String = ""
  @zone_id : String = ""

  def on_load
    on_update
  end

  def on_update
    subscriptions.clear

    tz = setting?(String, :timezone).presence
    @timezone = Time::Location.load(tz) if tz
    @user_email = setting?(String, :user_email) || ""
    @user_id = Base64.encode(@user_email.downcase)
    @vergesense_floor_key = setting?(String, :vergesense_floor_key) || ""

    system.subscribe(:Vergesense_1, @vergesense_floor_key) do |_subscription, vergesense_data|
      update_data(JSON.parse(vergesense_data))
    end
  end

  private def extract_desks(vergesense_data)
    desks = {} of String => JSON::Any
    vergesense_data["spaces"].as_a.each do |s|
      next unless s["space_type"] == "desk"
      desks[s["space_ref_id"].as_s] = s
    end
    desks
  end

  private def update_data(vergesense_data)
    new_data = extract_desks(vergesense_data)
    self[:recently_booked_desks] = check_desks(self[:previous_data], new_data) if self[:previous_data] = self[:current_data]?
    self[:current_data] = new_data
  end

  private def check_desks(old_desk_data, new_desk_data)
    desks_booked = [] of String
    old_desk_data.as_h.each do |desk_id, desk_object|
      previous_desk_presence = desk_object["people"]["count"].as_i > 0
      current_desk_presence = new_desk_data[desk_id]["people"]["count"] == 1
      if previous_desk_presence && current_desk_presence
        book_desk(desk_id = desk_object["space_ref_id"].as_s)
        desks_booked.push(desk_id)
      end
    end
    desks_booked
  end

  def book_desk(desk_id : String)
    current_time = Time.utc.in(@timezone)
    end_of_day = current_time.at_end_of_day
    info = "Automatic booking for #{desk_id}"

    params = {
      booking_type: "desk",
      asset_id: "desk_#{desk_id}",
      user_id: @user_id,
      user_email: @user_email,
      user_name: "Desk Booker",
      zones: [@zone_id],
      booking_start: current_time,
      booking_end: end_of_day,
      approved: true,
      title: info,
      description: info
    }

    logger.debug { "Booking desk with params" }
    logger.debug { params }

    response = staff_api.create_booking(**params)

    logger.debug { "Successfully booked desk #{desk_id}" }
    response
  end
end
