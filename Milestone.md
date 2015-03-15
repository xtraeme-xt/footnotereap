# Milestone Goals #

## Version 0.1 (Alpha) ##

The major tasks and [todos](Todo.md) I want to complete for the upcoming milestone are:

**15.** Add a routine to navigate through the local footnote.com folder to double check the IDs to see if additional naming information can be found to validate the current folders (create a new Commands→Tools category). (external tool)

**7.** Automatically generate PDFs and OCR (external tool)

In addition to 16 it would be nice to have a way to send a request to the reaper to auto-startup and grab (or at least test for) missing content and then exit. This would require reworking the preamble of footnotereap so it skips all the user input.

## Version 0.2 ##

**1.** Port to Python

**17.** Platform agnostic (would be nice to get a functioning copy in firefox/chrome again that works on Mac and Linux).

I want to move away from AutoIt ASAP. The debugging is too cumbersome. This is going to be a major time suck.

True platform agnostic functionality may not be possible, but once I have everything running in Python. I'll check to see if I can find a workaround for the Flash bug.

## Version 0.3 ##

**9.** Allow for random-access saves (generate all information based on one page -- difficulties with this is that the ID won't necessarily map with page 1 id).

**10.** Add downloading in reverse

**11.** Add starting from arbitrary points irregardless of direction (need fold3 page1 id for this)

This sprint will be about improving ways that we can get data off fold3. This should make the features of 16 more useful since theoretically when it finds something missing it will be able to hop around between the website with greater agility to fill holes. This will also help with the database features.

## Version 0.4 ##

**14.** Heavy bandwidth causes faulty timing and click misplacement (throttling?)

This is going to be a performance/bug-fix sprint. Any bizarre new issues that crop up will be dealt with here.

## Version 0.5 ##

**8.** Get more metadata per page from JS

**5.** Generate CSV data when locating a new file not already in the local database

This build is going to be all about improving what data we can get and how we store it. This has to come before the database component otherwise the tables will be out of whack. Final data abstractions will happen at this point.

## Version 0.6 (Beta) ##

**2.** Add FTP functionality

**3.** Add database connectivity

**4.** Finish the distributed workload feature

This build will finally implement trying to let other people participate in helping collect data and finding holes in the data set. It's very possible new data will be added to the website. So having spot-checks will be useful. One of the big problems is going to be that since the thing is so huge (~200 GBs) I will need to find a way to hook this all up through NFS / smbfs for the ftp.

It would also be nice to allow people to submit improvements. So if we see the case id is wrong. The database could hold on to the correction and farm that out to everyone else. Maybe even consider trying to automatically send updates to fold3? That is probably too much work, but maybe I could just send them the database? Or participants could manually check off that they logged the problem.

## Version 0.7 ##

**12.** Print live stats on main canvas

**13.** Better support for letting the user input their username / password on resume

Usability and statistics sprint. I want to finally get a nice presentation mechanism in place. I'll probably also want to have live stats on the website as well. Perhaps I'll even consider adding in a contributor feature? This would require changing the database so I'll have to think about this in 0.6.


## Version 0.8 ##

This rev is for anything I haven't currently thought up. All features and other major areas that need to be designed but weren't given a slot will get touched on here.

## Version 0.9 ##

**16.** Auto-update client to new version

**6.** Create an installer

Finishing touches and bug fixes. This is really v1 just in a late beta state

## Version 1 (Release) ##

Should have all [todo items](Todo.md) 1 through 15, but I may be willing to let 8 and 13 slide. At this point I'll do minor fixes, but I want to take what I learn from foonotereap, download-naa-gov and start working on the generalized framework for collecting data across numerous sites. This gets into the idea of the TVS system, IK's TC, and FS's STR.