#
# Copyright (C) 2003 SecureCiRT Pte Ltd (Singapore)
#
# Authors:
#  Michael Boman <michael.boman@securecirt.com>
#  Jeffrey Lim <jeffrey.lim@securecirt.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
 
INCLUDES=-I'/usr/include/mysql'
LDFLAGS=-L'/usr/lib/mysql' -lmysqlclient -lz -lcrypt -lnsl -lm 
CFLAGS=-g

SOURCE_FILES=extractrules.c rulefunctions.c

all extractrules:
	$(CC) $(CFLAGS) $(INCLUDES) $(LDFLAGS) $(SOURCE_FILES) -o extractrules
debug:
	$(CC) -g $(CFLAGS) $(INCLUDES) $(LDFLAGS) $(SOURCE_FILES) -o extractrules-debug
clean:
	rm -f extractrules *.o *~ sguil.*
indent:
	indent $(SOURCE_FILES) -nut
