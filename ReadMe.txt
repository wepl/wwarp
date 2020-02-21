
Send images using WWarp to a WHDLoad developer
----------------------------------------------

If you get requested to send images of your game using WWarp to a WHDLoad
install author, just do the following:
 - copy the WWarp executable to somewhere it is reachable via your PATH, e.g.
   copy it to C:
 - enter the directory where you like to store the images to create, there
   should be some MB of free store
 - insert the disk to image into your floppy drive and run WWarp with the 
   name of the image to create as argument, if there are multiple disks for
   the game add the disk number to the name, e.g. "wwarp robocop2-d1"
 - if you are using not DF0: but a other drive add the unit number on the
   argument list, e.g. "wwarp robocop2-d1 unit=1" for DF1:
 - each image created by wwarp will have a size between 1 and 4.5 MB
 - at the end pack all images into one lha archive and email this archive
   to the WHDLoad install author
Here an complete example of how to install WWarp and create images for the
game RoboCop2:
	cd <where you have unpacked the wwarp archive>
	copy wwarp c:
	cd <where you like to create your images>
	wwarp robocop2-d1
	wwarp robocop2-d2
	lha a robocop2 #?.wwp
This creates "robocop2.lha" which you can send by email.


Usage
-----

Synopsis:

	WWarp filename[.wwp] [command] [tracks] [args] [options...]

commands:

	C - create wwarp file (default)
	    this will read the disk in the floppy drive and create a image 
	    from, if [tracks] has been specified only these tracks will be 
	    read
	
	D - dump tracks
	    displays info about the specified track and displays the mfm-data
	    (or decoded data if type is not 'raw'), if there is a sync set in
	    the wwarp file the mfm-data will be displayed shifted to the first
	    sync
	    args = [sync[&mask]][,[syncno][,[len][,off]]]
	    	sync[&mask] - the track will be shiftet to that sync and then
	    		displayed
	    	syncno - if multiple syncs are found, the number of the sync
	    		to use for display (first sync is 1)
	    	len - amount of bytes to display
	    	off - offset to start display, can be negative e.g. to view
	    		bytes before the sync, a bit offset will be specified
	    		using $1000.7 for example
	    	leadings args can be ommited, e.g. use ,,16 to see first the
	    	16 bytes

	F - try to decode the specified [tracks] as one of the known formats
	    (less restrictive than the routine used in command C for some
	    custom formats)

	G - save contents as image file, all decoded tracks will be saved in
	    their size, track of type RAW or with a data length of 0 will be
	    saved as $1600 bytes with the contents 'TDIC' (as used with the DIC
	    program), you can save a part of the image or skip tracks by
	    selecting only the whished tracks
	
	I - print informations about wwarp file and tracks contained
	
	L - set track length
	    sets the data length which should be written back to disk. this 
	    length is stored in the wwarp file and will be used on command 'W'
	    (see below), this operation does not modify the stored track data
	    in the wwarp file, this command doesn't work with tracks which are
	    not of type 'raw' of course
	
	M - merge two wwarp files together (not implemented yet)
	
	P - pack wwarp file
	    this removes all unneccessary data from the wwarp file, all tracks
	    of type 'raw' and a valid 'Length' and 'Sync' will be stored
	    starting with 'Sync' and the length 'Length', removed data is lost
	    forever, so be careful

	R - remove tracks from wwarp file
	    deletes the specified [tracks] from the wwarp file, the tracks are
	    lost forever, so be careful

	S - save tracks
	    each track will be saved to a separate file, the filename contains
	    the track number and the format, if the format is raw-single the
	    doubled length will be saved
	
	W - write wwarp file to disk

	Y - set sync
	    sets the syncronization to write the track with sync back to a
	    floppy disk, the sync can consist of upto 16 byte data and a mask
	    of the same length. both, data and mask must be given in
	    hexadecimal notation: "data&mask", the mask can be omitted and
	    will then calculated from the data value (rounded up to byte
	    boundaries)
	    args = [sync[&mask]][,syncno]
	    	sync[&mask] - syncronization to set
	    	syncno - if multiple syncs are found, the number of the sync
	    		to use (first sync is 1)

	Z - write custom format by data file
	    this command does not operate on a wwarp file!
	    the filename specifies the datafile which will be written to the
	    specified track (only one track must be set) in custom format
	    which has been specifed as number, the file length must match the
	    tracklength for the given format
	    e.g. wwarp mynewtrack.47 z 47 17 (writes ZZKJA format)

tracks:
	will be used to specify which tracks should be affected by the command
	 1-5		tracks 1,2,3,4,5
	 2,90		tracks 2 and 90
	 2*2		tracks 2,4,...,156,158
	 10-20*5	tracks 10,15,20
	 1-5,7,99-104*2 tracks 1,2,3,4,5,7,99,101,103
	 *	 	all tracks

options:

	BPT=BytesPerTrack/K - amount of bytes to rawread and write to the
		wwarp file if nothing will be detected, default $6c00

	DBG/K/N - enable debugging messages (see chapter below for more infos)

	Force/S - enable detection of formats with flag force

	Import/K - import alien file via trackwarp.library, must be used with
		in conjunction with command C

	NoFmt/K - don't try to detect known formats which are specified,
		formats are given by their number as listed when WWarp is
		called without arguments, multiple formats are delimited
		with comma, e.g. NoFmt=16,30,33 disables detection of
		slackskin, twilight1 and twilight2 formats

	NoStd/S - don't try to detect any known formats

	NV=NoVerify/S - disables verify on write operations, verify is
		supported with all modes!

	RC=RetryCnt/N/K - number of read retries before a track is stored as
		'nonsingle' 'raw', default 6

	SYBIL/S - use SYBIL hardware to write long track formats and formats
		with variable bitcell densities (see chapter below for more
		infos)

	Unit/N/K - trackdisk.device unit number, use 1 for DF1: etc.


Tips & Tricks
-------------

* use 'wwarp' without arguments for a short decription of the available
  options and to display all supported custom formats

* to write back an image:
  for that are usually multiple steps necessary because you have to say WWarp
  how to write back the track data.
  first step:
    'wwarp filename f' - that command forces WWarp to try to decode all
    tracks, thats recommended because WWarp by default saves standard AmigaDos
    tracks in decoded format only if the mfm data is absolutely clean. most
    format programs are weak in their job, e.g. formatting not the full track
    to save some miliseconds or do not init the sector headers correctly.
    because such differences could be used as a copy protection WWarp saves
    such tracks as raw by default. anyway usually you can use the F(orce)
    command to ignore such specials.
  second step:
    'wwarp filename y 2-159 9521000044&ffff0000ff' - set the sync, that must
    be done for all tracks which are not detected as a supported format by
    WWarp. WWarp needs that information to know where the track data starts.
    You should make sure that the specified sync is only one time contained
    on the track, otherwise WWarp may start on the wrong sector. If the disk
    format uses multiple sectores you have to set the sync that it refers the
    first sector after the inter sector gap. For example if you would like to
    write back a standard AmigaDOS track (which is unnecessary because WWarp
    knows that format ;-) you had to use:
    448944895500000555000001&ffffffffff000055ff000055
  third step:
    'wwarp filename l 2-159 $3050' - set the write length, that step is optional
    but recommended, WWarp needs that information to know how many bytes must
    be written to the disk. when writing WWarp will check if your drive is
    capable of writing the requested amount of bytes, e.g. it will say you if
    you try to write a long track on a normal drive
    if you don't set the length WWarp will write as much bytes as possible
    depending on the drive speed
  forth step:
    'wwarp filename w' - that will write back the tracks to disk, if you have
    prepared the wwarp file correctly and there are no specials preventing the
    write back operation you will have another duplicate of your original and
    saved this piece of software history for your sons and daughters ;)

* to check if the right sync has been set use:
	wwarp filename d 2-159 ,,32
  which will display the first 32 mfm bytes of the selected tracks, you will
  also see if the sync has been found and if its present multiple times

* if a disk is very weak and you have problems to warp it increase the
  RetryCnt, for example use:
  	wwarp filename c 10-14*2 RetryCnt=50
  get some coffee, watch some tv and after that maybe wwarp could read the
  tracks after several retries

* when WWarp detects the Rob Northen 12 sector format it also calculates the
  lower 31 bit of the DiskKey (bit #31 cannot be calculated, but seems to be
  most time zero, in the warp file that bit is always set!), this key is saved
  in front of the decoded track data in the warp file, to see it just use the
  (I)nfo command
  wwarp removes the gap between the sectors when writing the format back, that
  makes it possible to write also the long track variants of the format on
  standard disk drives

Using High-Density Floppy+Disk
------------------------------

There is some support for using HD disks. There are several limitations but it
may be useful under some conditions.

* WWarp will automatically detect if there is an HD floppy in a HD drive and
  some operations will be performed slightly different

* the following applies to standard AmigaDOS tracks: a track on a HD is not
  $1600 but $2c00 bytes in length, that requires some work arounds, WWarp will
  still write $1600 for each track but with the offset as it would be a DD
  disk, that means that track #1 will be physically located on the second half
  of track #0, tracks in std format will not be written using TD_FORMAT but
  TD_WRITE, as result the tracks must be formatted correctly before

SYBIL
-----

The SYBIL hardware has been created by Jim Drew of Utilities Unlimited
International. The hardware was created to read/write 800KB Macintosh Disks
which uses different speed zones. It seems there was also a successor called
AMIA which could be used together with Emplant (Mac-Emulator) which was also
from UU. The hardware consists of two cards connected with some wires. One card
connects to the parallel port, the other to the video port. The SYBIL is
controlled via the parallel port and changes the clocking of the custom chips
via the genlock interface. Because the disk controller is part of these chips
also the bitcell timing on writing is affected by the genlock interface.
Using the SYBIL hardware with WWarp you can write tracks with standard drives
(300 rpm) from $3000 bytes upto $3580 bytes length.

Debug output
------------

Setting the option DBG/K/N you can increase the amount of messages wwarp will
print on several operations. Following the additional messages depending on
the value specified:

 1    * on write operation of custom formats check the mfm data for "11" and
	"0000" sequences which are illegal for mfm
      * on read print each unsuccessful tried custom format
 2    * on write operation of custom formats dump encoded mfm data
 3    *	on retrying raw read because track length could not be estimated the
	head will be moved, now instead the dot the cylinder will be printed

MORE QUESTIONS? so check the source ;-)

