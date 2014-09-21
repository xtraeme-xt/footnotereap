# create_sym_links_with_padded_zeros.py (CSLPZ)
# 
# author: xtraeme
# date: 2014/09/20
#
# The Blue Book NARA pages adhere to the following naming convention and increment like so:
# Page 1, Page 2, ... Page 10, ..., Page 20, etc. 
#
# Since the filenames don't have padded zeroes, navigating through the files using a normal 
# image viewing tool like Irfanview results in Page 1 being shown first, Page 10 second, 
# Page 11 third, -after seven more pages- Page 19, Page 2, and then Page 20. 
#
# Ideally we would like to read the pages in their intended proper order. A naive solution 
# is to just rename the files. However this breaks footnotereaper and requires resyncing all 
# of the files in BitTorrent Sync. 
#
# The best workaround I could think of was to create a symbolic link structure with the padded 
# filenames all placed in an alternate, but identical directory tree parallel to the actual 
# documents (by default the program uses the current directory name plus "- browse"). 
#
# So, in practice, if the base directory is "footnote.com" the sym-linked folder will be named
# "footnote.com - browse."
#
# To initialize the program, provide the path to your Fold3 working directory or to the 
# specific case that you want see symlinked and padded (see line 78). For example,
#
# create_sym_links_with_padded_zeros.py [fold3 base directory]
#
# Note: The script only has to be run once to generate the symbolic link structure.
#
# Platform Notes: 
# ---------------
# CSLPZ should work on Windows, Mac, and Linux. However I have only tested the script in 
# Windows. So if something isn't working, check line 160 and debug the "ln -s" section.


import os
import sys
from sys import platform as _platform
import argparse
import ntpath
import re
import bisect
import subprocess
from subprocess import call
import math


class CSLPZParser(argparse.ArgumentParser):
    def usage(self, msg):
        self.print_help()
        sys.exit(0)
        
    def error(self, error, msg):
        self.print_help()
        print "\nError: " + msg
        #    print >>sys.stderr, globals()['__doc__']
        #    print >>sys.stderr, error        
        sys.exit(error)


text_desc = ("Creates a new parent directory with the base name plus '- browse' (ex. 'footnote.com' becomes 'footnote.com - browse') and "
            "sym-links the newly named files to the originals files. The largest page number (ex. Page 203) is used to pad smaller page "
            "values with the appropriate number of zeros (ex. 'Page 1' becomes 'Page 001').")

parser = CSLPZParser(description = text_desc)
parser.add_argument('path', metavar = 'path', type=str, nargs='?', help='path to fold3 data directory (default: footnote.com)')
parser.add_argument('-q', '--quiet', action='store_true', help="quiet (no output)")
parser.add_argument('-v', '--verbose', action='count', default=0, help="increase output verbosity")
args = parser.parse_args()

if(args.path):
    if(os.path.isdir(args.path)):
        path_to_fold3 = os.path.normpath(args.path)
    else:
        parser.error(1, "Fold3 Path is invalid: " + args.path)
else:
    path_to_fold3        = 'G:/F/Media/__By Subject/Speculative/UFOs/Media/Websites/footnote.com' 
    if(not os.path.isdir(path_to_fold3)):
        parser.error(1, "No Fold3 Path found")

path_to_target = os.path.join(os.path.abspath(os.path.join(path_to_fold3, os.pardir)), os.path.basename(os.path.normpath(path_to_fold3)) + " - browse")   #'G:/F/Media/__By Subject/Speculative/UFOs/Media/Websites/footnote.com - browse'

rootdir = path_to_fold3
token_file_re = re.compile(r'page (\d+)\.\w{3}', re.IGNORECASE)
token_dir_re  = re.compile(r'[\/|\\](.{4}\..{2} \- (\d+).*$)', re.IGNORECASE) 
rootdir_len = len(rootdir)

#DEBUG CODE: TO DELETE UNNECESSARY FILES
#path_to_fileexplorer = "C:\\app\\system\\Directory Opus\\dopus.exe"
#count = 0
#lastdir = ""

for subdir, dirs, files in os.walk(rootdir):
    d = token_dir_re.search(subdir)    
    if d is not None:
        dospath = os.path.normpath(subdir) #ntpath.splitdrive(subdir)
        if(not args.quiet):
            print "Working on: " + dospath
        
        numlist = []
        files_maxindex = len(files)-1
        
        targetpath = os.path.join(path_to_target, d.groups()[0])
        
        if not os.path.isdir(targetpath):
            os.makedirs(targetpath)
            
        for file in files:
            f = token_file_re.search(file)
            if f is not None:
                pagenum = f.groups()[0]
                position = bisect.bisect(numlist, pagenum)
                bisect.insort(numlist, int(pagenum))
                
            if files[files_maxindex] == file:
                
                if f is not None:
                    l_maxindex = len(numlist)-1
                
                    #The ceiling of Log_10 (any number) will return the length of the number except for 10 
                    maxdigits = math.ceil(math.log10(numlist[l_maxindex]) if numlist[l_maxindex] != 10 else 2)
                
                for file in files:
                    f = token_file_re.search(file)                    
                    if f is not None:
                        #Create padding
                        filenum = f.groups()[0]         #filenum = (file[5:])[:-4]
                        newnum = '{s:{c}>{n}}'.format(s=filenum,n=int(maxdigits),c='0')
                        newfile = "Page "+ newnum + ".jpg"
                    else:
                        #We want to include all files even if they don't follow our search pattern
                        newfile = file
                        
                    targetfile = os.path.normpath(os.path.join(targetpath, newfile))  #.replace(r"\\", r"\")
                    
                    #DEBUG CODE: TO DELETE UNNECESSARY FILES
                    #if l_maxindex == 9: #"Meadow Vista" in subdir:
                        #count = count+1 if lastdir != subdir else count
                        #lastdir = subdir
                        #if count >= 7:
                            #call([path_to_fileexplorer, targetfile])  
                        #for x in range(1, 10):
                        #    potentialfile = os.path.normpath(os.path.join(targetpath, "Page " + str(x) + ".jpg"))
                        #    if(os.path.exists(potentialfile)):
                        #        os.remove(potentialfile)
                        #break
                    
                    if(not os.path.exists(targetfile)):
                        origfile = os.path.normpath(os.path.join(subdir, file))
                        if _platform == "win32":
                            run = subprocess.Popen([r"mklink", 
                                                    targetfile,
                                                    origfile],
                                                    shell = True,
                                                    stdout = subprocess.PIPE, 
                                                    stderr = subprocess.PIPE) 
                        else:
                            #NOTE: THIS IS UNTESTED!!!
                            run = subprocess.Popen([r"ln", 
                                                    "-s",
                                                    origfile,
                                                    targetfile],
                                                    shell = True,
                                                    stdout = subprocess.PIPE, 
                                                    stderr = subprocess.PIPE)
                        out,err =  [e.splitlines() for e in run.communicate() ]

                        if(args.verbose):
                            for line in out:
                                print line
                        
                        if(not args.quiet):
                            for line in err:
                                print err
        
                
        