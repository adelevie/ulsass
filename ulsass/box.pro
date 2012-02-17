use ULSTower
go

if exists(select name
           from sysobjects
           where name='ASRS_box'
           and type='P')
  drop procedure ASRS_box
go

Create Proc ASRS_box ( 
     @latitude_in real =0 ,
     @longitude_in real =0 ,
     @radius_in int =0 ,
     @max_north_latitude real =0 output ,
     @max_south_latitude real =0 output ,
     @max_east_longitude real =0 output ,
     @max_west_longitude real =0 output 
                   ) 
As
  Begin
/**********************************************************
*Procedure  Name: ASRS_box
*Database: ULSTower
*Server: FCCSUN03W
*CAST SQL-Builder  R3.6
*
*Business Function : This sp will define the maximum size of a box on the North, East, South and West borders 
that can be made by a point and a radius.

This routine was copied from the development ASRS tower database dated 4/17/98
The algorithm is not documented and is assumed to be correct.
*Author BF: Gary Ebert		Date BF: 10/15/1998
*
*CODE After:
Grant Execute On ASRS_box To user_grp
*File Path:
* C:\TEMP\box.PRO
*********************************************************/
declare @radius  real, 
		@delta   real, 
		@adj   real, 
		@deltag   real,
		@radius_in_in_meters real

-- This stored procedure was taken from the ASRS system and contained no comments
-- The ASRS system passed radius in feet.  Since we don't
-- know what all of the calculations are for, we need to 
-- convert the meters that are passed in to feet.
select @radius_in_in_meters = @radius_in * 3.2808	-- Convert Meters to feet

select @radius = @radius_in_in_meters * .00994318	-- Unknown constant .00994318 - perhaps a conversion to distance in lat/long?
select @delta = convert(int, (@radius + .5))		-- Round up to the nearest whole #
select @adj = @latitude_in / (3600.0 * 57.3)    	-- 57.3 is 1 radian (360 degrees is 2 Pi radians)
select @deltag = convert(int, (@radius / cos(@adj) + .5)) -- calculation to determine the lat/long delta
if @delta < 1
    select @delta = 1
if @deltag < 1
    select @deltag = 1

-- return the box that would hold the circle indicated by the radius_in
-- around the lat/long that was passed in
select @max_south_latitude = @latitude_in - @delta
select @max_north_latitude = @latitude_in + @delta
select @max_east_longitude = @longitude_in - @deltag
select @max_west_longitude = @longitude_in + @deltag

End

go
Grant Execute On ASRS_box To user_grp
go
