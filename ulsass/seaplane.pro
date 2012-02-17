use ULSTower
go

if exists(select name
           from sysobjects
           where name='ASRS_seaplane'
           and type='P')
  drop procedure ASRS_seaplane
go

Create Proc ASRS_seaplane ( 
     @apt_id char(11) ,
     @call_type char(1) ,
     @return_msg varchar(255) output ,
     @msg_flag char(1) output 
                   ) 
As
  Begin
/**********************************************************
*Procedure  Name: ASRS_seaplane
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
Grant Execute On ASRS_seaplane To user_grp
*File Path:
* C:\TEMP\seaplane.PRO
*********************************************************/
declare @count_markings int
select @count_markings = 0

if @call_type = 'A'
	select @count_markings = (select count(*) from RUNWAY where 
                              TYPE_BASE_MARKINGS <> '     ' and 
                              TYPE_RECIP_MARKINGS <> '     ' and
                              TYPE_BASE_MARKINGS <> 'NONE' and
                              TYPE_RECIP_MARKINGS <> 'NONE' and 
                              AIRPORT_SITE_ID = @apt_id)
else
	select @count_markings = (select count(*) from RUNWAY where
                             TYPE_BASE_MARKINGS <> '     ' and
                             TYPE_RECIP_MARKINGS <> '     ' and
                             TYPE_BASE_MARKINGS <> 'NONE' and
                             TYPE_RECIP_MARKINGS <> 'NONE' and
                             RUNWAY_ID = @apt_id)
                           
if @count_markings > 0
begin
    select @return_msg = NULL
    select @msg_flag = 'N'
end
else
begin
    select @msg_flag = 'Y'
    select @return_msg = 'PASS SLOPE: No FAA REQ-Unmarked Seaplane base'
end
                      
/* ### DEFNCOPY: END OF DEFINITION */


End

go
Grant Execute On ASRS_seaplane To user_grp
go
