use ULSTower
go

if exists(select name
           from sysobjects
           where name='ASRS_chk_distance'
           and type='P')
  drop procedure ASRS_chk_distance
go

Create Proc ASRS_chk_distance ( 
     @distance real ,
     @longest_rwy int ,
     @type_char char(13) ,
     @return_msg varchar(255) output ,
     @msg_flag char(1) output ,
     @slope char(7) output 
                   ) 
As
  Begin
/**********************************************************
*Procedure  Name: ASRS_chk_distance
*Database: ULSTower
*Server: FCCSUN03W
*CAST SQL-Builder  R3.6
*
*Business Function : 
This routine was copied from the development ASRS tower database dated 4/17/98
The algorithm is not documented and is assumed to be correct.

Builds message indicating that the structure's distance (FT & MI) from an
FAA object passes requirements.  Otherwise, the distance requires FAA involvement,
and the required slope (ratio) is returned.

  Ex:  If structure is far enough away from a Heliport, then the following message is returned:
         PASS SLOPE(25:1):  NO FAA REQ-HELIPORT  5280 FT (1 MI) AWAY
  Ex:  If structure is NOT far enough away from a Heliport, then the following slope is returned:
         (25:1)

*Author BF: AOB		Date BF: 10/15/1998
*
*CODE After:
Grant Execute On ASRS_chk_distance To user_grp
*File Path:
* C:\TEMP\chk_dist.PRO
*********************************************************/
-- This stored procedure was taken from the ASRS system and contained no comments
-- The old version had parameters ddisp_r (in feet), ddisp_m (in miles)
-- This version only passes in distance, which is in meters
declare @feet_to_meters real,
		@meters_to_feet real
select @feet_to_meters = .3048 
select @meters_to_feet = 3.2808

select @return_msg = null
select @msg_flag = 'N'
select @slope = null

-- If the facility that we are dealing with is a heliport 
if substring(@type_char,1,4) = 'HELI'
begin
	-- If the distance is greater than 5000 feet (FCC rule)
    if @distance > (5000 * @feet_to_meters)		-- Convert 5000 feet to its metric equivalent
    begin
    	-- Prepare the output message
        select @return_msg = 'PASS SLOPE(25:1):  No FAA REQ-Heliport ' +
            substring((convert(char(25),round(@distance,2))),1,7) + ' Meters (' +
            substring((convert(char(25),round((@distance * @meters_to_feet),2))),1,7) + ' Feet) away'
        select @msg_flag = 'Y'
    end
    else
    begin
        select @slope = '(25:1)'
        select @msg_flag = 'N'
    end
end
-- The facility is NOT a heliport 
else
begin
	-- The longest runway is over 3200 feet
    if @longest_rwy > (3200 * @feet_to_meters)		-- Convert 3200 feet to its metric equivalent
    begin
        if @distance > (20000 * @feet_to_meters)		-- Convert 20000 feet to its metric equivalent 
        begin
            select @return_msg = 'PASS SLOPE(100:1): No FAA REQ-Runway more than ' + 
            	substring((convert(char(25),round((3200 * @feet_to_meters),2))),1,7) + ' (3200 FT) & ' +  
            	substring((convert(char(25),round(@distance,2))),1,7) + ' Meters (' +
                substring((convert(char(25),round((@distance * @meters_to_feet),2))),1,7) + ' Feet) away'
            select @msg_flag = 'Y'
        end
        else
        begin
            select  @slope = '(100:1)'
            select @msg_flag = 'N'
        end
    end
    -- The longest runway is less than or equal to 3200 feet
    else
    begin
        if @distance > (10000 * @feet_to_meters)		-- Convert 10000 feet to its metric equivalent  
        begin
            select @return_msg = 'PASS SLOPE(50:1): No FAA Req-Runway ' + 
            	substring((convert(char(25),round((3200 * @feet_to_meters), 2))),1,7) + ' Meters (3200 FT) OR LESS & ' +
                substring((convert(char(25),round(@distance,2))),1,7) + ' Meters (' +
                substring((convert(char(25),round((@distance * @meters_to_feet),2))),1,7) + ' ) Feet away'
            select @msg_flag = 'Y'
        end
        else
        begin
            select @slope = '(50:1)'
            select @msg_flag = 'N'
        end
	end
end

/* ### DEFNCOPY: END OF DEFINITION */


End

go
Grant Execute On ASRS_chk_distance To user_grp
go
