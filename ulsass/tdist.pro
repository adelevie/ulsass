use ULSTower
go

if exists(select name
           from sysobjects
           where name='ASRS_tdist'
           and type='P')
  drop procedure ASRS_tdist
go

Create Proc ASRS_tdist ( 
     @lat1 real ,
     @lon1 real ,
     @lat2 real ,
     @lon2 real ,
     @meters real output 
                   ) 
As
  Begin
/**********************************************************
*Procedure  Name: ASRS_tdist
*Database: ULSTower
*Server: FCCSUN03W
*CAST SQL-Builder  R3.6
*
*Business Function : This routine was copied from the development ASRS tower database dated 4/17/98
The algorithm is not documented and is assumed to be correct.

Calculate the Length (Feet & Miles) based on the given Latitude and Longitude.

*Author BF: AOB		Date BF: 10/15/1998
*
*CODE After:
Grant Execute On ASRS_tdist To user_grp
*File Path:
* C:\TEMP\tdist.PRO
*********************************************************/
declare @a real, @d real, @ec2 real, @acnt real, @bcnt real,
        @delat real, @delon real, @avlat real, @xnum real,
        @aa real, @xx real, @b real, @f real, @sd real, @g real,
        @h real, @i real,
        @feet real
        
-- This stored procedure was taken from the ASRS system and contained no comments
-- It previously returned the results in both feet and miles.  The new version
-- of the code is maintaining everything in Metric, so this function will return meters
-- Since the calculations are done in feet, we will do a feet to meters conversion at the end

select @a = 0.4848137E-5, @d = 1.5707963, @ec2 = 0.00672267,
       @acnt = 0.032338997, @bcnt = 0.032559381

select @delat = abs(@lat1 - @lat2),
       @delon = abs(@lon1 - @lon2)

if @delat = 0
   select @delat = 0.01
if @delon = 0
   select @delon = 0.01

select @avlat = @a * ((@lat1 + @lat2)/2)

select @xnum = 1.0 - @ec2 * power(sin(@avlat),2.)

select @aa = @acnt * (power(@xnum,0.5))

select @xx = power(@xnum,3.0)

select @b = @bcnt * (power(@xx,0.5))

select @f = @d - @avlat

select @sd = @delon * sin(@f)/@aa

select @g = @d - @delon * @a/2.0

select @h = @delat * sin(@g)/@b

select @i = atan(@sd/@h)

select @feet = @sd * 3.2808/sin(@i)

select @meters = @feet * .3048		-- Convert from feet to meters


/* ### DEFNCOPY: END OF DEFINITION */


End

go
Grant Execute On ASRS_tdist To user_grp
go
