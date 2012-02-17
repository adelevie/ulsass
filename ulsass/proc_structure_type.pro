use ULSTower
go

if exists(select name
           from sysobjects
           where name='ASRS_proc_structure_type'
           and type='P')
  drop procedure ASRS_proc_structure_type
go

Create Proc ASRS_proc_structure_type ( 
     @struc char(6) =null 
                   ) 
As
  Begin
/**********************************************************
*Procedure  Name: ASRS_proc_structure_type
*Database: ULSTower
*Server: FCCSUN03W
*CAST SQL-Builder  R3.6
*
*Business Function : 

Validates normal Stucture Type string ("MAST","PIPE","POLE", etc.)
or Array Structure Type string ("3TA", "4TA", "3TA1", "4TA1", etc.)

*Author BF: AOB		Date BF: 10/15/1998
*
*CODE After:
Grant Execute On ASRS_proc_structure_type To user_grp
*File Path:
* C:\TEMP\procstruct.PRO
*********************************************************/
declare     @first_pos       char(1)
declare     @second_pos      char(1)
declare     @third_pos       char(1)
declare     @fourth_pos      char(1)
declare     @fifth_pos       char(1)
declare     @sixth_pos       char(1)
declare     @struc2          char(5)
declare     @num_five_six    char(2)
declare     @num_one_two     char(2)

if @struc is null
begin
    raiserror 20001 "You must enter a structure type"
    RETURN
end
 
select @first_pos = substring(@struc,1,1)
select @second_pos = substring(@struc,2,1)
select @third_pos = substring(@struc,3,1)
select @fourth_pos = substring(@struc,4,1)
select @fifth_pos = substring(@struc,5,1)
select @sixth_pos = substring(@struc,6,1)
select @struc2 = substring(@struc,2,5)

-- If the structure type that was passed in is in the lookup table, but is not 
-- one of the template structure types (where the user must replace the N's with numbers)
IF 	rtrim(@struc) IN	(SELECT STRUCTURE_TYPE_CODE FROM LOOKUP_STRUCTURE_TYPE) AND
	(rtrim(@struc2) NOT IN ("NNTANN", "NTOWER"))                                
	RETURN  
ELSE
	IF @first_pos LIKE "[123456789]"
		GOTO array_process
	ELSE
	begin
		raiserror 20100 "Invalid structure type"
		RETURN
	end 

array_process:
IF @second_pos = "T" and @third_pos = "A" and @fourth_pos != "N"
	GOTO single_array 
ELSE
	-- Structure types can have an array value placed in front of them
	IF 	(CONVERT(int,@first_pos) > 1) AND
		(rtrim(@struc2) IN (SELECT STRUCTURE_TYPE_CODE FROM LOOKUP_STRUCTURE_TYPE)) AND
		(rtrim(@struc2) NOT IN ("NNTANN", "NTOWER"))
		RETURN  
	ELSE
		IF @second_pos LIKE "[1234567890]"
			GOTO double_array
		ELSE
		begin
			raiserror 20100 "Invalid structure type"
			RETURN
		end

single_array:
-- There should not be an array of one.
IF CONVERT(int,@first_pos) < 2
begin
    raiserror 20100 "Invalid structure type"
    RETURN
end
ELSE
	IF substring(@struc,4,3) = "   " AND substring(@struc,2,2) = "TA" 
		RETURN
	ELSE
		IF 	(CONVERT(int,@fourth_pos) BETWEEN 1 and 9) AND
			(substring(@struc,5,2) = "  ") AND 
			CONVERT(int,@fourth_pos) <= CONVERT(int,@first_pos)
			RETURN
		ELSE
		begin
			raiserror 20200 "Array Position Incorrect!"
			RETURN
		end

double_array:
IF 	(CONVERT(int,@second_pos) BETWEEN 1 and 9) AND
	(substring(@struc,3,2) = "TA") AND
	(substring(@struc,5,2) = "  ")
	RETURN     
ELSE
	IF @fifth_pos LIKE "[123456789]" AND @sixth_pos LIKE "[0123456789 ]"
	begin
		select @num_five_six = @fifth_pos + @sixth_pos
		select @num_one_two = @first_pos + @second_pos
		IF CONVERT(int,@num_five_six) <= CONVERT(int,@num_one_two)
			RETURN  
		ELSE
		begin
			raiserror 20200 "Array Position Incorrect!"
			RETURN
		end
	end
	ELSE
	begin
		raiserror 20100 "Invalid structure type!" 
	end
End

go
Grant Execute On ASRS_proc_structure_type To user_grp
go
