#!/usr/bin/env python

"""pglog: enable change logs on a PostgreSQL database.

$Id$

THIS SOFTWARE IS UNDER MIT LICENSE.
(C) 2006 Perillo Manlio (manlio.perillo@gmail.com)

Read LICENSE file for more informations.
"""

# Install script
# XXX TODO: psql returns 0 even if some command fails


from os import system
from sys import stderr, exit
from optparse import OptionParser


usage = "usage: %prog options command"
parser = OptionParser(usage)
parser.add_option("-U", dest="user",
                  help="the login name for database (must be superuser)")
parser.add_option("-d", dest="db",
                  help="the database in witch to install pglog (like template1)")


(options, args) = parser.parse_args()

if len(args) != 1:
    parser.error("you must specify install or unistall")
if not options.user:
    parser.error("you must specify an username (superuser)")
if not options.db:
    parser.error("you must specify a database (like template1)")


if args[0] == "install":
    # run psql
    cmd = "psql -U %s -d %s -f pglog.sql" % (options.user, options.db)
    ret = system(cmd)
    if ret:
        print >> stderr, "install failed"
        exit(1)
elif args[0] == "uninstall":
    # run psql
    cmd = "psql -U %s -d %s -f pglog-uninstall.sql" % (options.user,
                                                       options.db)
    ret = system(cmd)
    if ret:
        print >> stderr, "uninstall failed"
        exit(1)
else:
    print >> stderr, "invalid command", args[0]
    exit(1)
