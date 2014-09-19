# find_missing_files_and_cleanup.py
# 
# author: xtraeme
# date: 2014/09/18
#
# This script does what its name suggests. In addition to finding missing files (typically
# "Page 1.jpg" is the biggest problem due to the file system having to navigate to a new 
# directory -- https://code.google.com/p/footnotereap/issues/detail?id=6#c8 ). It also 
# locates misnamed files like: age1.jpg (which should be: page1.jpg). To help make it 
# easier to clean up the mess it opens the file explorer to the diretcory with the problem
# file and also launches the webbrowser and goes to the page where the content can be 
# checked.
#
# To use this script set the directory to where you store the fold3 content and the path
# to explorer.exe, dopus, total commander, or whatever you use.

#
# TODO: 
# 1. Add a renaming tool to put a prefix in front of the files to make it easier to browser
#    in irfanview.

import os
import ntpath
import re
import bisect
import webbrowser
from subprocess import call

path_to_fold3        = 'G:/F/Media/__By Subject/Speculative/UFOs/Media/Websites/footnote.com/' 
path_to_fileexplorer = "C:\\app\\system\\Directory Opus\\dopus.exe"
base_fold3_uri       = 'http://www.fold3.com/image/1/'

#Set this to true if you want to actively find missing and misnamed files
#IMPORTANT: Set breakpoints on line 57 and 75
cleaningup = False 

def launch_explorer_browser(fold3id, dospath):
    if cleaningup:
        webbrowser.open(base_fold3_uri + fold3id)
        call([path_to_fileexplorer, dospath])    
    
rootdir = path_to_fold3
token_file_re = re.compile(r'page (\d+)\.jpg', re.IGNORECASE)
token_dir_re  = re.compile(r'\/.{4}\..{2} \- (\d+)', re.IGNORECASE) 
rootdir_len = len(rootdir)
for subdir, dirs, files in os.walk(rootdir):
    d = token_dir_re.search(subdir)    
    if d is not None:
        dospath = os.path.normpath(subdir) #ntpath.splitdrive(subdir)
        l = []
        files_maxindex = len(files)-1
        for file in files:
            f = token_file_re.search(file)
            if f is None:
                print os.path.join(subdir[rootdir_len:], file)
                launch_explorer_browser(d.groups()[0], dospath)
                pass            # IMPORTANT: ADD BREAKPOINT HERE IF YOU ENABLE: cleaningup = True
            else:
                pagenum = f.groups()[0]
                position = bisect.bisect(l, pagenum)
                bisect.insort(l, int(pagenum))
                
            if files[files_maxindex] == file:
                l_maxindex = len(l)-1
                for x in range(0, files_maxindex):
                    if x < l_maxindex:
                        page_error = -1
                        if x == 0 and l[x] != 1:
                            page_error = str(1)
                        if int(l[x])+1 != int(l[x+1]):
                            page_error = str(l[x]+1) 
                        if page_error != -1:
                            print subdir[rootdir_len:] + ": PAGE " + page_error + " IS MISSING!"
                            launch_explorer_browser(d.groups()[0], dospath)
                            pass    # IMPORTANT: ADD BREAKPOINT HERE IF YOU ENABLE: cleaningup = True
        