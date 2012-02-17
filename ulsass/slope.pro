use ULSTower
go

if exists(select name
           from sysobjects
           where name='ASRS_slope'
           and type='P')
  drop procedure ASRS_slope
go

Create Proc ASRS_slope ( 
     @latitude real ,
     @longitude real ,
     @lat_runway_start real ,
     @long_runway_start real ,
     @lat_runway_end real ,
     @long_runway_end real ,
     @structure_ground_elevation real ,
     @structure_height real ,
     @length_of_longest_runway real ,
     @min_airport_ground_elevation real ,
     @type int ,
     @oth int ,
     @l int ,
     @ri int output ,
     @exei int output ,
     @yn int output ,
     @flag int output ,
     @fpei int output 
                   ) 
As
  Begin
/**********************************************************
*Procedure  Name: ASRS_slope
*Database: ULSTower
*Server: FCCSUN03W
*CAST SQL-Builder  R3.6
*
*Business Function : 
This routine was copied from the development ASRS tower database dated 4/17/98
The algorithm is not documented and is assumed to be correct.
*Author BF: GEB		Date BF: 10/15/1998
*
*CODE After:
Grant Execute On ASRS_slope To user_grp
*File Path:
* C:\TEMP\slope.PRO
*********************************************************/
-- This stored procedure was taken from the ASRS system and contained no comments
-- Everything has been converted to meters

declare @pi  real,
        @calculated_runway_len  real,  -- The calculated length of the runway using the coordinates of the 2 end points (VALUE IN METERS)
        @dist_to_end_of_runway real,   -- THE DISTANCE TO THE SECOND END OF THE RUNWAY       
        @dist_to_start_of_runway real, -- THE DISTANCE TO THE FIRST END OF THE RUNWAY 
        @dist_to_runway_start_or_end real, -- The distance from the point passed in to the end of the runway that is farthest away
        @s real,       -- the average of the calculated runway length and the two distances from the point passed in 
        @pb real,
        @pc real,
        @anc real,
        @anb real,
        @fpe real,     -- This appears to hold the top elevation that a given slope will create from the @airport_ground_elevation
        @exe real,
        @tth real,
        @feet_to_meters real

/*     initialize variables                    */
select @feet_to_meters = .3048
select @flag = 0
select @pi = 3.14259
select @dist_to_runway_start_or_end = 0.0
select @fpe = 0.0
select @exe = 0.0
select @yn = 0

/*     there are two ends of the runway        */
/*     calculate the length of the runway based on the coordinates passed.  */
if @lat_runway_end <> 0
begin
    exec ASRS_tdist @lat1 = @lat_runway_start,
                    @lon1 = @long_runway_start,
                    @lat2 = @lat_runway_end,
                    @lon2 = @long_runway_end,
                    @meters = @calculated_runway_len output

    -- IF THE CALCULATED LENGTH OF THE RUNWAY IS MORE THAN THE VALUE IN THE
    -- FILE, THE LONGER VALUE IS USED FOR SAFETY FACTOR.                   
    if @length_of_longest_runway < convert(int, @calculated_runway_len)
        select @length_of_longest_runway = convert(int, @calculated_runway_len)
end

-- Determine the distance from the given point to the "start" of the runway
exec ASRS_tdist @lat1 = @lat_runway_start,
                @lon1 = @long_runway_start,
                @lat2 = @latitude,
                @lon2 = @longitude,
                @meters = @dist_to_start_of_runway output

if @lat_runway_end = 0
    select @dist_to_runway_start_or_end = @dist_to_start_of_runway
else
begin
    -- Determine the distance from the given point to the "end" of the runway
   exec ASRS_tdist  @lat1 = @lat_runway_end,
                    @lon1 = @long_runway_end,
                    @lat2 = @latitude,
                    @lon2 = @longitude,
                    @meters = @dist_to_end_of_runway output

    if @dist_to_start_of_runway < @dist_to_end_of_runway
        select @flag = 1

    if @dist_to_end_of_runway < @dist_to_start_of_runway
        select @flag = 2

    -- take the average of the calculated runway length and the two distances from the point
    select @s = (@calculated_runway_len + @dist_to_end_of_runway + @dist_to_start_of_runway) / 2.0

    -- Make sure that the average length of the runway is larger than the distances to the start/end of the runway
    if @s - @dist_to_end_of_runway < .01
        select @s = @dist_to_end_of_runway + 0.01

    if @s - @dist_to_start_of_runway < .01
        select @s = @dist_to_start_of_runway + 0.01

    select @pb = power(((@s - @calculated_runway_len)*(@s - @dist_to_start_of_runway)/(@s * (@s - @dist_to_end_of_runway))),.5)
    select @pc = power(((@s - @calculated_runway_len)*(@s - @dist_to_end_of_runway)/(@s * (@s - @dist_to_start_of_runway))),.5)

    select @anc = 2.0 * atan(@pc)
    select @anb = 2.0 * atan(@pb)

    if (@anb > (@pi/2.0)) or (@anc > (@pi/2.0))
    begin
        if @dist_to_start_of_runway > @dist_to_end_of_runway
            select @dist_to_runway_start_or_end = @dist_to_end_of_runway
        else
            select @dist_to_runway_start_or_end = @dist_to_start_of_runway
    end
    else
    begin
        select @flag = 3
        select @dist_to_runway_start_or_end = @dist_to_start_of_runway *sin(@anb)
    end
end
if @length_of_longest_runway = 0
    select @length_of_longest_runway = (13728.0 * @feet_to_meters)  -- convert to meters
if @l = 0
    select @l = @length_of_longest_runway
if @lat_runway_end = 0
    select @dist_to_runway_start_or_end = @dist_to_runway_start_or_end - @length_of_longest_runway
if @dist_to_runway_start_or_end < 0.0
    select @dist_to_runway_start_or_end = 0.0

-- If this is a heliport, but has a runway > 3200 feet - change its type    
if @type = 2 and @length_of_longest_runway > (3200.0 * @feet_to_meters) -- convert to meters
    select @type = 1

-- Determine the maximum elevation at an airport - given the slope as a constant.    
if @type = 1    -- Airport with a runway > 3200 feet
    select @fpe = @dist_to_runway_start_or_end / 100.0 + @min_airport_ground_elevation
if @type = 2    -- Airport with a runway <= 3200 feet
    select @fpe = @dist_to_runway_start_or_end / 50.0 + @min_airport_ground_elevation
if @type = 3    -- heliport
    select @fpe = @dist_to_runway_start_or_end / 25.0 + @min_airport_ground_elevation

select @oth = @structure_ground_elevation + @structure_height
select @tth = convert(real,@oth)
select @exe = @tth - @fpe

-- Set up certain output variables as integers 
-- I think that they are multiplied by 100 to preserve some of the precision.
-- This should probably be removed because the caller must now remember to divide by 100
-- to get the proper values
select @ri = convert(int,(@dist_to_runway_start_or_end * 100.0 + .5))
select @fpei = convert(int,(@fpe * 100.0 + .5))
select @exei = convert(int,(@exe * 100.0 + .5))

if @dist_to_runway_start_or_end > (20000.0 * @feet_to_meters)   -- convert to meters
begin
    select @yn = 2
    return
end
if @dist_to_runway_start_or_end > (10000.0 * @feet_to_meters) and @type = 2 -- convert to meters
begin
    select @yn = 2
    return
end
if @dist_to_runway_start_or_end > (5000.0 * @feet_to_meters) and @type = 3  -- convert to meters
begin
    select @yn = 2
    return
end
if @exe > 0.0
begin
    select @yn = 1
    return
end
if @exe < 0.0
begin
    select @yn = 2
    return
end

select @yn = 1
return


/* ### DEFNCOPY: END OF DEFINITION */


End

go
Grant Execute On ASRS_slope To user_grp
go
