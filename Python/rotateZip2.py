#!/usr/bin/python
# -*- coding: utf8 -*-

# Description :
#	Stop a Windows Service
#	Rotate logs
#	Start teh Windows Service

import os
import zipfile
from datetime import datetime


PATH = "C:\\xampp\\apache\\logs"
FILES = ["error.log", "access.log"]
COMMANDSTART = "net start NOM_DU_SERVICE"
COMMANDSTOP = "net stop NOM_DU_SERVICE"

date = datetime.today().strftime("%Y-%m-%d")
os.chdir(PATH)

total_zipped = 0

stop = os.system(COMMANDSTOP)
if stop != 0:
	print "Command returned with code %d" % stop
	exit()

for x in os.listdir("."):
	if not os.path.isfile(x):
		continue

	if x not in FILES:
		continue

	name, ext = os.path.splitext(x)
	newname_noext = "%s.%s" % (name, date)
	newname = "%s%s" % (newname_noext, ext)
	os.rename(x, newname)

	zpath = newname_noext + ".zip"
	print zpath
	zfile = zipfile.ZipFile(newname_noext + ".zip", "w")
	zfile.write(newname)
	zfile.close()
	total_zipped += 1

	os.remove(newname)

	open(x, "w").close()

print "Zipped : %d" % total_zipped

ret = os.system(COMMANDSTART)
if ret != 0:
	print "Command returned with code %d" % ret
