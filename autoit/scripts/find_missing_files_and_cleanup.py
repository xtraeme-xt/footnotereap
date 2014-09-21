# find_missing_files_and_cleanup.py
# 
# author: xtraeme
# date: 2014/09/18
#
# In addition to finding missing and misnamed files (typically "Page 1.jpg," often misnamed
# "age1.jpg", because of how the system code navigates to a new directory -- 
# https://code.google.com/p/footnotereap/issues/detail?id=6#c8 ). The script also makes it 
# easier to locate out of sequence files and files that are missing between a set of two 
# pages (e.g. "Page 2.jpg" and "Page 4.jpg" exist, but "Page 3.jpg" doesn't.) 
#
# To use the script set the directory to where you store the fold3 content and fill in the
# path to explorer.exe, dopus, total commander, or whatever you use.
#
# For more serious cleanup jobs, you'll want to set:
# cleaningup = True 
#
# This instructs the script to open a file explorer window to the problem directory and 
# after that spawns a webbrowser window to the case id. This makes it easier to check 
# whether the content is valid or if the content needs to be redownloaded.
#


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
        
