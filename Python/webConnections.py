#!/usr/bin/python
#
# Filename : webConnections.py
# Version  : 1.0
# Author   : Olivier Renard
# Contrib  : Dorian Devaux
# Description : List all web connections to server (remote IP)
#

from optparse import OptionParser
import commands

aparser = OptionParser()
aparser.add_option("-p", "--panic", action='store_true', help="Send email with all web connections in body")
options, args = aparser.parse_args()

def getWebConnections():
    return commands.getoutput("netstat -antp | grep -E ':(80|443)' | awk '{print $5}' | cut -d':' -f1")

body = getWebConnections()

if not options.panic:
    print body
else:
    import smtplib
    from socket import gethostname

    sender = 'root@'+gethostname()
    receiver = ['system@intuitiv.fr']

    message = """From: From Server Admin <%s>
To: To System <%s>
Subject: [Web connections list] %s

%s""" %(sender, receiver, gethostname(), body)

    try:
        smtpObj = smtplib.SMTP('localhost')
        smtpObj.sendmail(sender, receiver, message)
        print "Successfully sent email"
    except smtplib.SMTPException as ex:
        print "Error: unable to send email"
        print ex
    except Exception as ex:
    	print "Unknown error"
    	print ex