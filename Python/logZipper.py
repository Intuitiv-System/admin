#!/usr/bin/python
#
# Filename : logZipper.py
# Version  : 1.0
# Author   : dorian devaux
# Contrib  : 
# Description : logrototate - scan in PATH folder,
#	zip all *.log files and delete *.log
#

# coding=utf8
import os
import zipfile
 
 
PATH = "/Users/ddevaux/Perso/rotateZip/test"
 
EXCLUDES = ["error.log", "access.log"]
EXTENSIONS = [".log"]
 
os.chdir(PATH)
 
total_zipped = 0
 
for x in os.listdir("."):
	if not os.path.isfile(x):
		continue
 
	if x in EXCLUDES:
		continue
 
	name, ext = os.path.splitext(x)
	if ext in EXTENSIONS:
		zfile = zipfile.ZipFile(x + ".zip", "w")
		zfile.write(x)
		zfile.close()
		total_zipped += 1
 
		os.remove(x)
 
print "Zipped : %d" % total_zipped
