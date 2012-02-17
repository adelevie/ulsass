use ULSTower
go

if exists(select name
           from sysobjects
           where name='ASRS_towair'
           and type='P')
  drop procedure ASRS_towair
go

Create Proc ASRS_towair ( 
     @lat_sec real ,
     @lon_sec real ,
     @str_hgt real ,
     @gnd_elev real ,
     @radius real ,
     @key_reg int output 
                   ) 
As
  Begin
/**********************************************************
*Procedure  Name: ASRS_towair
*Database: ULSTower
*Server: FCCSUN03W
*CAST SQL-Builder  R3.6
*
*Business Function : This stored procedure was copied from the ASRS tower development database on 4/19/98
The name was sp_towair_mm
Changes have been made to make everything metric
*Author BF: GEB		Date BF: 10/15/1998
*
*CODE After:
Grant Execute On ASRS_towair To User_grp
*File Path:
* C:\TEMP\towair.PRO
*********************************************************/
-- It is assumed that all heights and distances are being passed in in meters

Declare @air_seq varchar(11), @air_city varchar(30), @air_county varchar(30),
        @air_hgt_elev real,@air_lat_deg real, @air_lat_min real,
        @air_lat_sec real, @air_whole_lat real,@air_lon_deg real,
        @air_lon_min real, @air_lon_sec real,@air_whole_lon real,
        @air_state varchar(2), @air_name_facility varchar(42),
        @air_type_facility varchar(13), @radius_in_meters int, @test_radius int,
        @nlat real, @slat real, @elon real, @wlon real, @srch_rad int
Declare @rwy_site varchar(11), @rwy_id char(7), @rwy_ltdeg_base real,
        @rwy_ltmin_base real, @rwy_ltsec_base real, @rwy_ltdeg_recip real,
        @rwy_ltmin_recip real, @rwy_ltsec_recip real, @rwy_ltwhole_base real,
        @rwy_ltwhole_recip real, @rwy_length real, @rwy_lndeg_base real,
        @rwy_lnmin_base real, @rwy_lnsec_base real, @rwy_lndeg_recip real,
        @rwy_lnmin_recip real, @rwy_lnsec_recip real, @rwy_lnwhole_base real,
        @rwy_lnwhole_recip real, @rwy_base_mk varchar(5),
        @rwy_recip_mk varchar(5)
Declare @lowest_base real, @lowest_recip real, @lowest_elev real,
        @longest_rwy real, @lowest_rwy real, @type int, @meters real,
        @miles real, @runway int, @yn int, @ri int, @exei int,
        @fpei int, @disp_r real, @ddisp_fpe real, @flag int,
        @ddisp_r real, @ddisp_m real, @ddisp_exe real, @disp_m real,
        @slope char(7), @msg_flag char(1), @return_msg varchar(255),
        @lat_out_deg real, @lat_out_min real, @lat_out_sec real,
        @lon_out_deg real, @lon_out_min real, @lon_out_sec real,
        @type_cr char(1), @towair_count int,
        @feet_to_meters real, @feet_in_mile int

declare @flag_returned int

/*     initialize variables                    */
select @feet_to_meters = .3048
select @feet_in_mile = 5280

Declare runway_data cursor for select AIRPORT_SITE_ID,
        RUNWAY_ID,
        LAT_DEG_BASE,
        LAT_DEG_RECIP,
        LAT_MIN_BASE,
        LAT_MIN_RECIP,
        LAT_SEC_BASE,
        LAT_SEC_RECIP,
        LAT_TOTAL_SECS_BASE,
        LAT_TOTAL_SECS_RECIP,
        LENGTH_RUNWAY,
        LONG_DEG_BASE,
        LONG_DEG_RECIP,
        LONG_MIN_BASE,
        LONG_MIN_RECIP,
        LONG_SEC_BASE,
        LONG_SEC_RECIP,
        LONG_TOTAL_SECS_BASE,
        LONG_TOTAL_SECS_RECIP,
        TYPE_BASE_MARKINGS,
        TYPE_RECIP_MARKINGS
from    RUNWAY
where   AIRPORT_SITE_ID = @air_seq and
        (LAT_TOTAL_SECS_BASE > 0 or LAT_TOTAL_SECS_RECIP > 0)
order by LENGTH_RUNWAY
FOR READ ONLY

Declare airport_data cursor for
    select  AIRPORT_SITE_ID,
            CITY,
            COUNTY,
            HEIGHT_ELEVATION,
            LAT_DEG,
            LAT_MIN,
            LAT_SEC,
            abs(LAT_TOTAL_SECONDS),
            LONG_DEG,
            LONG_MIN,
            LONG_SEC,
            abs(LONG_TOTAL_SECONDS),
            AIRPORT_FACILITY_NAME,
            STATE_CODE,
            AIRPORT_FACILITY_TYPE
    from    AIRPORT
    where   abs(LAT_TOTAL_SECONDS) between @slat and @nlat and
            abs(LONG_TOTAL_SECONDS) between @elon and @wlon
    FOR READ ONLY

select @flag_returned = 0

if @radius = 0
begin
    select @radius_in_meters = (6 * @feet_in_mile * @feet_to_meters)    -- convert 6 miles to meters
    select @test_radius = (5 * @feet_in_mile * @feet_to_meters)     -- convert 5 miles to meters
end
else
begin
    select @radius_in_meters = @radius + (@feet_to_meters * @feet_in_mile) -- Add the equivalent of one mile
    select @test_radius = @radius
end

exec ASRS_box	@latitude_in = @lat_sec, @longitude_in = @lon_sec, @radius_in = @radius_in_meters,
				@max_north_latitude = @nlat output, @max_south_latitude = @slat output, 
				@max_east_longitude = @elon output,	@max_west_longitude = @wlon output
select @nlat = @nlat + 61
select @wlon = @wlon + 61
select @slat = @slat - 61
select @elon = @elon - 61

if @radius_in_meters = (6 * @feet_in_mile * @feet_to_meters)    -- convert 6 miles to meters
	select @srch_rad = (6 * @feet_in_mile * @feet_to_meters)+ (13728 * @feet_to_meters)   -- convert to meters 
else
	select @srch_rad = @radius_in_meters + (13728 * @feet_to_meters) - @feet_in_mile
	
	
-- Before we get started, first clear out the TOWAIR_EXCEPTIONS table of existing rows for this application
-- There may be some users that don't have a reg # so give them a usable id
if @key_reg = 0 or @key_reg = null
begin
	SELECT @key_reg = max(key_application) 
	from TOWAIR_EXCEPTIONS
	
	select @key_reg = @key_reg + 12345		-- create a key that is not likely to be used.  We clean up anyway
end
begin
    DELETE From TOWAIR_EXCEPTIONS 
    WHERE KEY_APPLICATION = @key_reg	
end

open airport_data
Fetch airport_data into @air_seq, @air_city, @air_county, @air_hgt_elev,
                        @air_lat_deg, @air_lat_min, @air_lat_sec, @air_whole_lat,
                        @air_lon_deg, @air_lon_min, @air_lon_sec, @air_whole_lon,
                        @air_name_facility, @air_state, @air_type_facility
While @@sqlstatus = 0
begin
    exec ASRS_tdist	@lat1 = @air_whole_lat ,  @lon1 = @air_whole_lon ,
					@lat2 = @lat_sec, @lon2 = @lon_sec,
					@meters = @meters output
    if @meters < @srch_rad
    begin
        select @lowest_rwy = null
        select @lowest_base = (select min(HEIGHT_ELEV_BASE)
        	from RUNWAY where AIRPORT_SITE_ID = @air_seq and HEIGHT_ELEV_BASE > 0)
		select @lowest_recip  = (select min(HEIGHT_ELEV_RECIP)
			from RUNWAY where AIRPORT_SITE_ID = @air_seq and HEIGHT_ELEV_RECIP > 0)
		if (@lowest_base = null) and (@lowest_recip != null)
			select @lowest_rwy = @lowest_recip
		else
			if (@lowest_recip = null) and (@lowest_base != null)
				select @lowest_rwy = @lowest_base
			else
				if @lowest_base = null and @lowest_recip = null
					select @lowest_rwy = NULL
				else
					if @lowest_base < @lowest_recip
						select @lowest_rwy =  @lowest_base
					else
						select @lowest_rwy =  @lowest_recip
/* END OF FIRST IF-ELSE  */

		if @lowest_rwy is NULL
			select @lowest_elev = @air_hgt_elev
		else
			if @air_hgt_elev is NULL
				select @lowest_elev = @lowest_rwy
			else
				if @lowest_rwy < @air_hgt_elev
					select @lowest_elev = @lowest_rwy
				else
					select @lowest_elev = @air_hgt_elev

		select @longest_rwy = (select max(LENGTH_RUNWAY)
        	from RUNWAY where AIRPORT_SITE_ID = @air_seq)
		if @longest_rwy = NULL
			select @longest_rwy = 0

		if substring(@air_type_facility,1,4) = 'HELI'
			select @type = 3
		else
			if @longest_rwy > 3200
				select @type = 1
			else
				select @type = 2
				
        /* find runways based on site id */
        /* calculate slope for each runway */

        select @runway = 0
        open runway_data
        fetch runway_data into	@rwy_site,@rwy_id,@rwy_ltdeg_base,@rwy_ltdeg_recip,
                                @rwy_ltmin_base, @rwy_ltmin_recip, @rwy_ltsec_base, @rwy_ltsec_recip,
                                @rwy_ltwhole_base, @rwy_ltwhole_recip, @rwy_length, @rwy_lndeg_base,
                                @rwy_lndeg_recip, @rwy_lnmin_base, @rwy_lnmin_recip, @rwy_lnsec_base,
                                @rwy_lnsec_recip, @rwy_lnwhole_base, @rwy_lnwhole_recip, @rwy_base_mk,
                                @rwy_recip_mk
        while @@sqlstatus = 0
        begin
            select @runway = 1
            if @rwy_ltwhole_base = 0
				exec ASRS_slope  @latitude = @lat_sec, @longitude = @lon_sec,
                            @lat_runway_start = @rwy_ltwhole_recip, @long_runway_start = @rwy_lnwhole_recip,
                            @lat_runway_end = 0, @long_runway_end = 0,
                            @structure_ground_elevation = @gnd_elev, @structure_height = @str_hgt,
                            @length_of_longest_runway = @longest_rwy, @min_airport_ground_elevation = @lowest_elev,
                            @type = @type, @oth = 0, @l = 0, @ri = @ri output, @exei = @exei output,
                            @yn = @yn output, @flag = @flag output, @fpei = @fpei output
            else if @rwy_ltwhole_recip = 0
                exec ASRS_slope  @latitude = @lat_sec, @longitude = @lon_sec,
                            @lat_runway_start = @rwy_ltwhole_base, @long_runway_start = @rwy_lnwhole_base,
                            @lat_runway_end = 0, @long_runway_end = 0,
                            @structure_ground_elevation = @gnd_elev, @structure_height = @str_hgt,
                            @length_of_longest_runway = @longest_rwy, @min_airport_ground_elevation = @lowest_elev,
                            @type = @type, @oth = 0, @l = 0, @ri = @ri output, @exei = @exei output,
                            @yn = @yn output, @flag = @flag output, @fpei = @fpei output
            else
                exec ASRS_slope  @latitude = @lat_sec, @longitude = @lon_sec,
                            @lat_runway_start = @rwy_ltwhole_base, @long_runway_start = @rwy_lnwhole_base,
                            @lat_runway_end = @rwy_ltwhole_recip, @long_runway_end = @rwy_lnwhole_recip,
                            @structure_ground_elevation = @gnd_elev, @structure_height = @str_hgt,
                            @length_of_longest_runway = @longest_rwy, @min_airport_ground_elevation = @lowest_elev,
                            @type = @type, @oth = 0, @l = 0, @ri = @ri output, @exei = @exei output,
                            @yn = @yn output, @flag = @flag output, @fpei = @fpei output

			-- For some reason the slope stored proc returns these as integers that have
			-- been multiplied by 100 - so we have to divide by 100 to get the right number
			-- I hesitate to change it because they may have had a reason to do this
            select @ddisp_r = round(@ri / 100,2)
            select @ddisp_fpe = round(@fpei / 100,2)
            select @ddisp_exe = abs(round(@exei / 100,2))
            select @ddisp_m = round(@ddisp_r / 5280,2)
            select @disp_m = @ddisp_m

            if @ddisp_r > @test_radius
                goto LOOP2_NEXT

			-- If this facility is for sea planes
            if substring(@air_type_facility,1,4) = 'SEAP'
            begin
                exec ASRS_seaplane	@apt_id = @rwy_id, @call_type = 'R',
								@return_msg = @return_msg output, @msg_flag = @msg_flag output
                if @msg_flag = 'Y'
                begin
                    select @yn = 2
                    goto INSERT_RWY
                end
            end

			-- Flag indicates which end of the runway to deal with
            if @flag = 1 or @flag = 3
            begin
                select	@lat_out_deg = @rwy_ltdeg_base,
                        @lat_out_min = @rwy_ltmin_base,
                        @lat_out_sec = @rwy_ltsec_base,
                        @lon_out_deg = @rwy_lndeg_base,
                        @lon_out_min = @rwy_lnmin_base,
                        @lon_out_sec = @rwy_lnsec_base,
                        @type_cr = 'R'
			end
			if @flag = 2
			begin
				select	@lat_out_deg = @rwy_ltdeg_recip,
                        @lat_out_min = @rwy_ltmin_recip,
                        @lat_out_sec = @rwy_ltsec_recip,
                        @lon_out_deg = @rwy_lndeg_recip,
                        @lon_out_min = @rwy_lnmin_recip,
                        @lon_out_sec = @rwy_lnsec_recip,
                        @type_cr = 'R'
			end
			if @flag = 0
				if @rwy_ltwhole_base = 0
				begin
					select	@lat_out_deg = @rwy_ltdeg_recip,
                            @lat_out_min = @rwy_ltmin_recip,
                            @lat_out_sec = @rwy_ltsec_recip,
                            @lon_out_deg = @rwy_lndeg_recip,
                            @lon_out_min = @rwy_lnmin_recip,
                            @lon_out_sec = @rwy_lnsec_recip,
                            @type_cr = 'B'
				end
			else
			begin
				select	@lat_out_deg = @rwy_ltdeg_base,
                        @lat_out_min = @rwy_ltmin_base,
                        @lat_out_sec = @rwy_ltsec_base,
                        @lon_out_deg = @rwy_lndeg_base,
                        @lon_out_min = @rwy_lnmin_base,
                        @lon_out_sec = @rwy_lnsec_base,
                        @type_cr = 'B'
			end

			exec ASRS_chk_distance	@distance = @ddisp_r,
                                    @longest_rwy = @longest_rwy, @type_char = @air_type_facility,
                                    @return_msg = @return_msg output, @msg_flag = @msg_flag output, 
                                    @slope = @slope output

			if @msg_flag = 'Y'
				goto INSERT_RWY

			exec ASRS_format_msg	@yn = @yn, @distance = @ddisp_r,
                                   	@distance_exceeded = @ddisp_exe,
                                   	@slope = @slope,
                                    @return_msg = @return_msg output,
                                    @msg_flag = @msg_flag output

			if @yn = 1
                select @flag_returned = 2

INSERT_RWY:
			INSERT INTO TOWAIR_EXCEPTIONS (KEY_APPLICATION, FACILITY_TYPE, CR_TYPE,
                        LATITUDE_DEG, LATITUDE_MIN, LATITUDE_SEC, 
                        LONGITUDE_DEG, LONGITUDE_MIN, LONGITUDE_SEC,
                        FACILITY_NAME, CITY, COUNTY, STATE_CODE,
                        LOWEST_ELEVATION, RUNWAY_LENGTH, 
                        RUNWAY_SLOPE_MSG, DISTANCE, SLOPE_FLAG) 
			values (	@key_reg,substring(@air_type_facility,1,4), @type_cr, 
						@lat_out_deg, @lat_out_min, @lat_out_sec, 
						@lon_out_deg, @lon_out_min, @lon_out_sec, 
						@air_name_facility, @air_city, @air_county, @air_state,
						@lowest_elev , @longest_rwy , 
						@return_msg, @ddisp_r, @yn)

LOOP2_NEXT:
			fetch runway_data into	@rwy_site,@rwy_id,@rwy_ltdeg_base,
                                    @rwy_ltdeg_recip, @rwy_ltmin_base, @rwy_ltmin_recip,
                                    @rwy_ltsec_base, @rwy_ltsec_recip, @rwy_ltwhole_base,
                                    @rwy_ltwhole_recip, @rwy_length, @rwy_lndeg_base,
                                    @rwy_lndeg_recip, @rwy_lnmin_base, @rwy_lnmin_recip,
                                    @rwy_lnsec_base, @rwy_lnsec_recip, @rwy_lnwhole_base,
                                    @rwy_lnwhole_recip, @rwy_base_mk, @rwy_recip_mk
		end /* ends the runway while loop */
		close runway_data
		
	/* IF no runways are found then perform slope on airport data */
    if @runway = 0
    begin
        exec ASRS_slope	@latitude = @lat_sec, @longitude = @lon_sec,
						@lat_runway_start = @air_whole_lat, @long_runway_start = @air_whole_lon,
                        @lat_runway_end = 0, @long_runway_end = 0,
                        @structure_ground_elevation = @gnd_elev, @structure_height = @str_hgt,
                        @length_of_longest_runway = @longest_rwy, @min_airport_ground_elevation = @lowest_elev,
                        @type = @type, @oth = 0, @l = 0, @ri = @ri output, @exei = @exei output,
                        @yn = @yn output, @flag = @flag output, @fpei = @fpei output
        select @ddisp_r = @ri / 100
        select @ddisp_fpe = round(@fpei / 100,2)
        select @ddisp_exe =abs(round(@exei / 100,2))
        select @ddisp_m = @ddisp_r / 5280
        select @disp_m = @ddisp_m
        if @ddisp_r > @test_radius
            goto LOOP_END

        if substring(@air_type_facility,1,4) = 'SEAP'
        begin
            exec ASRS_seaplane	@apt_id = @air_seq, @call_type = 'A',
								@return_msg = @return_msg output, @msg_flag = @msg_flag output
		if @msg_flag = 'Y'
		begin
			Select @yn = 2
			goto INSERT_TOWAIR
		end
	end
	exec ASRS_chk_distance	@distance = @ddisp_r,
                            @longest_rwy = @longest_rwy, @type_char = @air_type_facility,
                            @return_msg = @return_msg output, @msg_flag = @msg_flag output,
                            @slope = @slope output
	if @msg_flag = 'Y'
		goto INSERT_TOWAIR
	else
	begin
		exec ASRS_format_msg	@yn = @yn, @distance = @ddisp_r,
                               	@distance_exceeded = @ddisp_exe,
                               	@slope = @slope,
                                @return_msg = @return_msg output,
                                @msg_flag = @msg_flag output
		if @yn = 1
			select @flag_returned = 2
		end

INSERT_TOWAIR:
    INSERT INTO TOWAIR_EXCEPTIONS	(KEY_APPLICATION, FACILITY_TYPE, CR_TYPE,
                                    LATITUDE_DEG, LATITUDE_MIN, LATITUDE_SEC, 
                                    LONGITUDE_DEG, LONGITUDE_MIN, LONGITUDE_SEC,
                                    FACILITY_NAME, CITY, COUNTY, STATE_CODE,
                                    LOWEST_ELEVATION, RUNWAY_LENGTH, 
                                    RUNWAY_SLOPE_MSG, DISTANCE, SLOPE_FLAG)
	values							(@key_reg, substring(@air_type_facility,1,4), 'C',
									@air_lat_deg, @air_lat_min,
									@air_lat_sec, @air_lon_deg, @air_lon_min,
									@air_lon_sec, @air_name_facility, @air_city,
									@air_county, @air_state, @lowest_elev,
									@longest_rwy, @return_msg,@ddisp_r, @yn)
	end  /* End loop for zero runways found */

end /* Ends the Feet > than Rule */
LOOP_END:

Fetch airport_data into @air_seq, @air_city, @air_county, @air_hgt_elev,
     @air_lat_deg, @air_lat_min, @air_lat_sec, @air_whole_lat,
     @air_lon_deg, @air_lon_min, @air_lon_sec, @air_whole_lon,
     @air_name_facility, @air_state, @air_type_facility
end  /* ends the Airport Loop */

select @towair_count = count(*) from TOWAIR_EXCEPTIONS
	where KEY_APPLICATION = @key_reg

/* ### DEFNCOPY: END OF DEFINITION */

end  /* ends procedure */


go
Grant Execute On ASRS_towair To User_grp
go
