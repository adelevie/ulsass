use ULSTower
go

if exists(select name
           from sysobjects
           where name='ASRS_format_msg'
           and type='P')
  drop procedure ASRS_format_msg
go

Create Proc ASRS_format_msg ( 
     @yn int ,
     @distance real ,
     @distance_exceeded real ,
     @slope char(7) ,
     @return_msg varchar(255) output ,
     @msg_flag char(1) output 
                   ) 
As
  Begin
/**********************************************************
*Procedure  Name: ASRS_format_msg
*Database: ULSTower
*Server: FCCSUN03W
*CAST SQL-Builder  R3.6
*
*Business Function : 
This routine was copied from the development ASRS tower database dated 4/17/98
The algorithm is not documented and is assumed to be correct.

Based on given code and slope, builds message indicating whether structure's distance (FT & MI)
from an FAA object passes or fails requirements.  See 'chk_distance'.

*Author BF: AOB		Date BF: 10/15/1998
*
*CODE After:
Grant Execute On ASRS_format_msg To user_grp
*File Path:
* C:\TEMP\formatmsg.PRO
*********************************************************/
-- This stored procedure was taken from the ASRS system and contained no comments
-- The old version had parameters ddisp_r (in feet), ddisp_m (in miles) and ddisp_exe (in feet)
-- This version only passes in distance and distance_exceeded, which are in meters
declare @meters_to_feet real
select @meters_to_feet = 3.2808

if @yn = 1
    select @return_msg = 'FAIL SLOPE ' + @slope + 'FAA REQ - ' +
        substring((convert(char(25),round(@distance,2))),1,6) + ' Meters(' +
        substring((convert(char(25),round((@distance * @meters_to_feet),2))),1,5) + ' Feet) away & exceeds by ' +
        substring((convert(char(25),round(@distance_exceeded,2))),1,6) + ' Meters (' +
        substring((convert(char(25),round((@distance_exceeded * @meters_to_feet),2))),1,5) + ' Feet)'
else
    if @yn = 2
        select @return_msg = 'PASS SLOPE' + @slope + 'NO FAA REQ - ' +
            substring((convert(char(25),round(@distance,2))),1,6) + ' Meters (' +
            substring((convert(char(25),round((@distance * @meters_to_feet),2))),1,5) + ' Feet)' + 'away & below slope by ' +
            substring((convert(char(25),round(@distance_exceeded,2))),1,6) + ' Meters (' +
        	substring((convert(char(25),round((@distance_exceeded * @meters_to_feet),2))),1,5) + ' Feet)'
    else
        select @return_msg = 'YN DID NOT EQUAL 1 OR 2 PLEASE CONTACT TECHNICAL SUPPORT'

select @msg_flag = 'Y'

/* ### DEFNCOPY: END OF DEFINITION */


End

go
Grant Execute On ASRS_format_msg To user_grp
go
