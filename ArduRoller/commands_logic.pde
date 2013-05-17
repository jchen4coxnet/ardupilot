/// -*- tab-width: 4; Mode: C++; c-basic-offset: 4; indent-tabs-mode: nil -*-

/********************************************************************************/
// Command Event Handlers
/********************************************************************************/
// process_nav_command - main switch statement to initiate the next nav command in the command_nav_queue
static void process_nav_command()
{
    switch(command_nav_queue.id) {

    case MAV_CMD_NAV_WAYPOINT:                  // 16  Navigate to Waypoint
        do_nav_wp();
        break;

    case MAV_CMD_NAV_LOITER_UNLIM:              // 17 Loiter indefinitely
        do_loiter_unlimited();
        break;

    case MAV_CMD_NAV_LOITER_TURNS:              //18 Loiter N Times
        do_circle();
        break;

    case MAV_CMD_NAV_LOITER_TIME:              // 19
        do_loiter_time();
        break;

    case MAV_CMD_NAV_RETURN_TO_LAUNCH:             //20
        do_RTL();
        break;

    // point the copter and camera at a region of interest (ROI)
    case MAV_CMD_NAV_ROI:             // 80
        do_nav_roi();
        break;

    default:
        break;
    }

}

static void process_cond_command()
{
    switch(command_cond_queue.id) {

    case MAV_CMD_CONDITION_DELAY:             // 112
        do_wait_delay();
        break;

    case MAV_CMD_CONDITION_DISTANCE:             // 114
        do_within_distance();
        break;

    case MAV_CMD_CONDITION_YAW:             // 115
        do_yaw();
        break;

    default:
        break;
    }
}

static void process_now_command()
{
    switch(command_cond_queue.id) {

    case MAV_CMD_DO_JUMP:              // 177
        do_jump();
        break;

    case MAV_CMD_DO_CHANGE_SPEED:             // 178
        do_change_speed();
        break;

    case MAV_CMD_DO_SET_HOME:             // 179
        do_set_home();
        break;

    case MAV_CMD_DO_SET_SERVO:             // 183
        do_set_servo();
        break;

    case MAV_CMD_DO_SET_RELAY:             // 181
        do_set_relay();
        break;

    case MAV_CMD_DO_REPEAT_SERVO:             // 184
        do_repeat_servo();
        break;

    case MAV_CMD_DO_REPEAT_RELAY:             // 182
        do_repeat_relay();
        break;

#if CAMERA == ENABLED
    case MAV_CMD_DO_CONTROL_VIDEO:                      // Control on-board camera capturing. |Camera ID (-1 for all)| Transmission: 0: disabled, 1: enabled compressed, 2: enabled raw| Transmission mode: 0: video stream, >0: single images every n seconds (decimal)| Recording: 0: disabled, 1: enabled compressed, 2: enabled raw| Empty| Empty| Empty|
        break;

    case MAV_CMD_DO_DIGICAM_CONFIGURE:                  // Mission command to configure an on-board camera controller system. |Modes: P, TV, AV, M, Etc| Shutter speed: Divisor number for one second| Aperture: F stop number| ISO number e.g. 80, 100, 200, Etc| Exposure type enumerator| Command Identity| Main engine cut-off time before camera trigger in seconds/10 (0 means no cut-off)|
        break;

    case MAV_CMD_DO_DIGICAM_CONTROL:                    // Mission command to control an on-board camera controller system. |Session control e.g. show/hide lens| Zoom's absolute position| Zooming step value to offset zoom from the current position| Focus Locking, Unlocking or Re-locking| Shooting Command| Command Identity| Empty|
        do_take_picture();
        break;
#endif

#if MOUNT == ENABLED
    case MAV_CMD_DO_MOUNT_CONFIGURE:                    // Mission command to configure a camera mount |Mount operation mode (see MAV_CONFIGURE_MOUNT_MODE enum)| stabilize roll? (1 = yes, 0 = no)| stabilize pitch? (1 = yes, 0 = no)| stabilize yaw? (1 = yes, 0 = no)| Empty| Empty| Empty|
        camera_mount.configure_cmd();
        break;

    case MAV_CMD_DO_MOUNT_CONTROL:                      // Mission command to control a camera mount |pitch(deg*100) or lat, depending on mount mode.| roll(deg*100) or lon depending on mount mode| yaw(deg*100) or alt (in cm) depending on mount mode| Empty| Empty| Empty| Empty|
        camera_mount.control_cmd();
        break;
#endif

    default:
        // do nothing with unrecognized MAVLink messages
        break;
    }
}

/********************************************************************************/
// Verify command Handlers
/********************************************************************************/

// verify_must - switch statement to ensure the active navigation command is progressing
// returns true once the active navigation command completes successfully
static bool verify_must()
{
    switch(command_nav_queue.id) {

    case MAV_CMD_NAV_WAYPOINT:
        return verify_nav_wp();
        break;

    case MAV_CMD_NAV_LOITER_UNLIM:
        return verify_loiter_unlimited();
        break;

    case MAV_CMD_NAV_LOITER_TURNS:
        return verify_circle();
        break;

    case MAV_CMD_NAV_LOITER_TIME:
        return verify_loiter_time();
        break;

    case MAV_CMD_NAV_RETURN_TO_LAUNCH:
        return verify_RTL();
        break;

    case MAV_CMD_NAV_ROI:             // 80
        return verify_nav_roi();
        break;

    default:
        //gcs_send_text_P(SEVERITY_HIGH,PSTR("<verify_must: default> No current Must commands"));
        return false;
        break;
    }
}

// verify_may - switch statement to ensure the active conditional command is progressing
// returns true once the active conditional command completes successfully
static bool verify_may()
{
    switch(command_cond_queue.id) {

    case MAV_CMD_CONDITION_DELAY:
        return verify_wait_delay();
        break;

    case MAV_CMD_CONDITION_DISTANCE:
        return verify_within_distance();
        break;

    case MAV_CMD_CONDITION_YAW:
        return verify_yaw();
        break;

    default:
        //gcs_send_text_P(SEVERITY_HIGH,PSTR("<verify_must: default> No current May commands"));
        return false;
        break;
    }
}

/********************************************************************************/
//
/********************************************************************************/

// do_RTL - start Return-to-Launch
static void do_RTL(void)
{
	// set navigation mode
	set_nav_mode(NAV_WP);

	// Set wp navigation target to above home
	set_destination(Vector3f(0,0,0));
}

/********************************************************************************/
//	Nav (Must) commands
/********************************************************************************/

// do_nav_wp - initiate move to next waypoint
// note: caller should set yaw mode
static void do_nav_wp()
{
    // set nav mode
    set_nav_mode(NAV_WP);

    // Set wp navigation target
    set_destination(pv_location_to_vector(command_nav_queue));

    // initialise original_wp_bearing which is used to check if we have missed the waypoint
    wp_bearing = get_bearing_to_destination();
    original_wp_bearing = wp_bearing;

    // this will be used to remember the time in millis after we reach or pass the WP.
    loiter_time     = 0;
    // this is the delay, stored in seconds and expanded to millis
    loiter_time_max = command_nav_queue.p1;
}

// do_loiter_unlimited - start loitering with no end conditions
// note: caller should set yaw_mode
static void do_loiter_unlimited()
{
    // get current position
    // To-Do: change this to projection based on current location and velocity
    Vector3f curr = encoder_nav.get_position();

    // default to use position provided
    Vector3f pos = pv_location_to_vector(command_nav_queue);

    // use current altitude if not provided
    if( command_nav_queue.alt == 0 ) {
        pos.z = curr.z;
    }

    // use current location if not provided
    if(command_nav_queue.lat == 0 && command_nav_queue.lng == 0) {
        pos.x = curr.x;
        pos.y = curr.y;
    }

    // start way point navigator and provide it the desired location
    set_nav_mode(NAV_WP);
    set_destination(pos);
}

// do_circle - initiate moving in a circle
static void do_circle()
{
    // set nav mode to CIRCLE
    set_nav_mode(NAV_CIRCLE);

    // override default horizontal location target
    if( command_nav_queue.lat != 0 || command_nav_queue.lng != 0) {
        circle_set_center(pv_location_to_vector(command_nav_queue), ahrs.yaw);
    }

    // set angle travelled so far to zero
    circle_angle_total = 0;

    // record number of desired rotations from mission command
    circle_desired_rotations = command_nav_queue.p1;
}

// do_loiter_time - initiate loitering at a point for a given time period
// note: caller should set yaw_mode
static void do_loiter_time()
{
    // get current position
    // To-Do: change this to projection based on current location and velocity
    Vector3f curr = encoder_nav.get_position();

    // default to use position provided
    Vector3f pos = pv_location_to_vector(command_nav_queue);

    // use current location if not provided
    if(command_nav_queue.lat == 0 && command_nav_queue.lng == 0) {
        pos.x = curr.x;
        pos.y = curr.y;
    }

    // start way point navigator and provide it the desired location
    set_nav_mode(NAV_WP);
    set_destination(pos);

    // setup loiter timer
    loiter_time     = 0;
    loiter_time_max = command_nav_queue.p1;     // units are (seconds)
}

/********************************************************************************/
//	Verify Nav (Must) commands
/********************************************************************************/

// verify_nav_wp - check if we have reached the next way point
static bool verify_nav_wp()
{
    // check if we have reached the waypoint
    if( !_reached_destination ) {
        return false;
    }

    // start timer if necessary
    if(loiter_time == 0) {
        loiter_time = millis();
    }

    // check if timer has run out
    if (((millis() - loiter_time) / 1000) >= loiter_time_max) {
        gcs_send_text_fmt(PSTR("Reached Command #%i"),command_nav_index);
        copter_leds_nav_blink = 15;             // Cause the CopterLEDs to blink three times to indicate waypoint reached
        return true;
    }else{
        return false;
    }
}

static bool verify_loiter_unlimited()
{
    return false;
}

// verify_loiter_time - check if we have loitered long enough
static bool verify_loiter_time()
{
    // return immediately if we haven't reached our destination
    if (!_reached_destination) {
        return false;
    }

    // start our loiter timer
    if( loiter_time == 0 ) {
        loiter_time = millis();
    }

    // check if loiter timer has run out
    return (((millis() - loiter_time) / 1000) >= loiter_time_max);
}

// verify_circle - check if we have circled the point enough
static bool verify_circle()
{
    // have we rotated around the center enough times?
    return fabsf(circle_angle_total/(2*M_PI)) >= circle_desired_rotations;
}

// verify_RTL - handles any state changes required to implement RTL
// do_RTL should have been called once first to initialise all variables
// returns true with RTL has completed successfully
static bool verify_RTL()
{
	// check if we've reached home
	if (_reached_destination) {
		return true;
	}else
		return false;
}

/********************************************************************************/
//	Condition (May) commands
/********************************************************************************/

static void do_wait_delay()
{
    //cliSerial->print("dwd ");
    condition_start = millis();
    condition_value = command_cond_queue.lat * 1000;     // convert to milliseconds
    //cliSerial->println(condition_value,DEC);
}


static void do_within_distance()
{
    condition_value  = command_cond_queue.lat * 100;
}

static void do_yaw()
{
    // get final angle, 1 = Relative, 0 = Absolute
    if( command_cond_queue.lng == 0 ) {
        // absolute angle
        yaw_look_at_heading = wrap_360_cd(command_cond_queue.alt * 100);
    }else{
        // relative angle
        yaw_look_at_heading = wrap_360_cd(nav_yaw + command_cond_queue.alt * 100);
    }

    // get turn speed
    if( command_cond_queue.lat == 0 ) {
        // default to regular auto slew rate
        yaw_look_at_heading_slew = AUTO_YAW_SLEW_RATE;
    }else{
        int32_t turn_rate = (wrap_180_cd(yaw_look_at_heading - nav_yaw) / 100) / command_cond_queue.lat;
        yaw_look_at_heading_slew = constrain(turn_rate, 1, 360);    // deg / sec
    }

    // TO-DO: restore support for clockwise / counter clockwise rotation held in command_cond_queue.p1
    // command_cond_queue.p1; // 0 = undefined, 1 = clockwise, -1 = counterclockwise
}


/********************************************************************************/
// Verify Condition (May) commands
/********************************************************************************/

static bool verify_wait_delay()
{
    //cliSerial->print("vwd");
    if (millis() - condition_start > (uint32_t)max(condition_value,0)) {
        //cliSerial->println("y");
        condition_value = 0;
        return true;
    }
    //cliSerial->println("n");
    return false;
}


static bool verify_within_distance()
{
    //cliSerial->printf("cond dist :%d\n", (int)condition_value);
    if (wp_distance < max(condition_value,0)) {
        condition_value = 0;
        return true;
    }
    return false;
}

// verify_yaw - return true if we have reached the desired heading
static bool verify_yaw()
{
    if( labs(wrap_180_cd(ahrs.yaw_sensor-yaw_look_at_heading)) <= 200 ) {
        return true;
    }else{
        return false;
    }
}

// verify_nav_roi - verifies that actions required by MAV_CMD_NAV_ROI have completed
//              we assume the camera command has been successfully implemented by the do_nav_roi command
//              so all we need to check is whether we needed to yaw the copter (due to the mount type) and
//              whether that yaw has completed
//	TO-DO: add support for other features of MAV_NAV_ROI including pointing at a given waypoint
static bool verify_nav_roi()
{
#if MOUNT == ENABLED
    // check if mount type requires us to rotate the quad
    if( camera_mount.get_mount_type() != AP_Mount::k_pan_tilt && camera_mount.get_mount_type() != AP_Mount::k_pan_tilt_roll ) {
        // ensure yaw has gotten to within 2 degrees of the target
        if( labs(wrap_180_cd(ahrs.yaw_sensor-yaw_look_at_WP_bearing)) <= 200 ) {
            return true;
        }else{
            return false;
        }
    }else{
        // if no rotation required, assume the camera instruction was implemented immediately
        return true;
    }
#else
    // if we have no camera mount simply check we've reached the desired yaw
    // ensure yaw has gotten to within 2 degrees of the target
    if( labs(wrap_180_cd(ahrs.yaw_sensor-yaw_look_at_WP_bearing)) <= 200 ) {
        return true;
    }else{
        return false;
    }
#endif
}

/********************************************************************************/
//	Do (Now) commands
/********************************************************************************/

static void do_change_speed()
{
	// to-do : make the param resettable
	//wp_speed = command_cond_queue.p1 * 100;
}

static void do_jump()
{
    // Used to track the state of the jump command in Mission scripting
    // -10 is a value that means the register is unused
    // when in use, it contains the current remaining jumps
    static int8_t jump = -10;                                                                   // used to track loops in jump command

    //cliSerial->printf("do Jump: %d\n", jump);

    if(jump == -10) {
        //cliSerial->printf("Fresh Jump\n");
        // we use a locally stored index for jump
        jump = command_cond_queue.lat;
    }
    //cliSerial->printf("Jumps left: %d\n",jump);

    if(jump > 0) {
        //cliSerial->printf("Do Jump to %d\n",command_cond_queue.p1);
        jump--;
        change_command(command_cond_queue.p1);

    } else if (jump == 0) {
        //cliSerial->printf("Did last jump\n");
        // we're done, move along
        jump = -11;

    } else if (jump == -1) {
        //cliSerial->printf("jumpForever\n");
        // repeat forever
        change_command(command_cond_queue.p1);
    }
}

static void do_set_home()
{
    if(command_cond_queue.p1 == 1) {
        init_home();
    } else {
        home.id         = MAV_CMD_NAV_WAYPOINT;
        home.lng        = command_cond_queue.lng;                                       // Lon * 10**7
        home.lat        = command_cond_queue.lat;                                       // Lat * 10**7
        home.alt        = 0;
        //home_is_set 	= true;
        set_home_is_set(true);
    }
}

static void do_set_servo()
{
    uint8_t channel_num = 0xff;

    switch( command_cond_queue.p1 ) {
        case 1:
            channel_num = CH_1;
            break;
        case 2:
            channel_num = CH_2;
            break;
        case 3:
            channel_num = CH_3;
            break;
        case 4:
            channel_num = CH_4;
            break;
        case 5:
            channel_num = CH_5;
            break;
        case 6:
            channel_num = CH_6;
            break;
        case 7:
            channel_num = CH_7;
            break;
        case 8:
            channel_num = CH_8;
            break;
        case 9:
            // not used
            break;
        case 10:
            channel_num = CH_10;
            break;
        case 11:
            channel_num = CH_11;
            break;
    }

    // send output to channel
    if (channel_num != 0xff) {
        hal.rcout->enable_ch(channel_num);
        hal.rcout->write(channel_num, command_cond_queue.alt);
    }
}

static void do_set_relay()
{
    if (command_cond_queue.p1 == 1) {
        relay.on();
    } else if (command_cond_queue.p1 == 0) {
        relay.off();
    }else{
        relay.toggle();
    }
}

static void do_repeat_servo()
{
    event_id = command_cond_queue.p1 - 1;

    if(command_cond_queue.p1 >= CH_5 + 1 && command_cond_queue.p1 <= CH_8 + 1) {

        event_timer             = 0;
        event_value             = command_cond_queue.alt;
        event_repeat    		= command_cond_queue.lat * 2;
        event_delay             = command_cond_queue.lng * 500.0f;         // /2 (half cycle time) * 1000 (convert to milliseconds)

        switch(command_cond_queue.p1) {
        case CH_5:
            event_undo_value = g.rc_5.radio_trim;
            break;
        case CH_6:
            event_undo_value = g.rc_6.radio_trim;
            break;
        case CH_7:
            event_undo_value = g.rc_7.radio_trim;
            break;
        case CH_8:
            event_undo_value = g.rc_8.radio_trim;
            break;
        }
        update_events();
    }
}

static void do_repeat_relay()
{
    event_id                = RELAY_TOGGLE;
    event_timer             = 0;
    event_delay             = command_cond_queue.lat * 500.0f;     // /2 (half cycle time) * 1000 (convert to milliseconds)
    event_repeat    = command_cond_queue.alt * 2;
    update_events();
}

// do_nav_roi - starts actions required by MAV_CMD_NAV_ROI
//              this involves either moving the camera to point at the ROI (region of interest)
//              and possibly rotating the copter to point at the ROI if our mount type does not support a yaw feature
//				Note: the ROI should already be in the command_nav_queue global variable
//	TO-DO: add support for other features of MAV_NAV_ROI including pointing at a given waypoint
static void do_nav_roi()
{
#if MOUNT == ENABLED

    // check if mount type requires us to rotate the quad
    if( camera_mount.get_mount_type() != AP_Mount::k_pan_tilt && camera_mount.get_mount_type() != AP_Mount::k_pan_tilt_roll ) {
        yaw_look_at_WP = pv_location_to_vector(command_nav_queue);
    }
    // send the command to the camera mount
    camera_mount.set_roi_cmd(&command_nav_queue);

    // TO-DO: expand handling of the do_nav_roi to support all modes of the MAVLink.  Currently we only handle mode 4 (see below)
    //		0: do nothing
    //		1: point at next waypoint
    //		2: point at a waypoint taken from WP# parameter (2nd parameter?)
    //		3: point at a location given by alt, lon, lat parameters
    //		4: point at a target given a target id (can't be implmented)
#else
    // if we have no camera mount aim the quad at the location
    yaw_look_at_WP = pv_location_to_vector(command_nav_queue);
    set_yaw_mode(YAW_LOOK_AT_LOCATION);
#endif
}

// do_take_picture - take a picture with the camera library
static void do_take_picture()
{
#if CAMERA == ENABLED
    camera.trigger_pic();
    if (g.log_bitmask & MASK_LOG_CAMERA) {
        Log_Write_Camera();
    }
#endif
}
